import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/hardware/serial/relay_command.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_device.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_provider.dart';
import 'package:skp_kiosk/core/hardware/serial/shutter_commands.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/core/logging/diagnostic_categories.dart';
import 'package:skp_kiosk/features/cabinet_light/application/cabinet_light_schedule.dart';
import 'package:skp_kiosk/services/printer/print_coordinator.dart';

final cabinetLightControllerProvider =
    NotifierProvider<CabinetLightController, CabinetLightConfig>(
  CabinetLightController.new,
);

/// Shared hardware poll: cabinet light (relay 2) + admin shutter open/close.
///
/// The ESP32 has no clock, so the kiosk applies light schedule over serial.
/// Admin shutter commands arrive on the same `/hardware-control` poll.
class CabinetLightController extends Notifier<CabinetLightConfig> {
  Timer? _timer;
  bool? _appliedOn;
  bool _ticking = false;
  bool _wasConnected = false;

  @override
  CabinetLightConfig build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    ref.listen(deviceAuthProvider, (_, next) {
      if (next.isAuthenticated) {
        _start();
      } else {
        _timer?.cancel();
        _timer = null;
        _appliedOn = null;
        _wasConnected = false;
      }
    });
    ref.listen(serialControllerProvider, (previous, next) {
      final connected = next.isConnected;
      if (connected && !_wasConnected) {
        // Port just came up (or came back). Firmware may have reset relays.
        _appliedOn = null;
        if (ref.read(deviceAuthProvider).isAuthenticated) {
          unawaited(_tick());
        }
      }
      _wasConnected = connected;
    });
    if (ref.read(deviceAuthProvider).isAuthenticated) {
      Future.microtask(_start);
    }
    _wasConnected = ref.read(serialControllerProvider).isConnected;
    return CabinetLightConfig.defaults;
  }

  void _start() {
    _timer ??= Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_tick());
    });
    unawaited(_tick());
  }

  Future<void> _tick() async {
    if (_ticking || !ref.mounted) return;
    if (!ref.read(deviceAuthProvider).isAuthenticated) return;
    _ticking = true;
    try {
      final payload = await _loadHardwareControl();
      if (!ref.mounted) return;
      state = payload.config;
      await _applyLight(payload.config);
      await _applyShutter(payload.shutter);
    } catch (error) {
      AppLogger.error('Hardware control tick failed', error);
    } finally {
      _ticking = false;
    }
  }

  Future<({CabinetLightConfig config, _PendingShutter? shutter})>
      _loadHardwareControl() async {
    final json = await ref.read(apiClientProvider).get('/hardware-control');
    final lightRaw = json['cabinetLight'];
    final config = lightRaw is Map
        ? CabinetLightConfig.fromJson(Map<String, dynamic>.from(lightRaw))
        : CabinetLightConfig.defaults;
    final shutterRaw = json['shutter'];
    return (config: config, shutter: _PendingShutter.tryParse(shutterRaw));
  }

  Future<void> _applyLight(CabinetLightConfig config) async {
    final wantOn = config.shouldBeOn(DateTime.now());
    if (_appliedOn == wantOn) {
      return;
    }
    final sent = await _sendRelay(wantOn);
    if (sent) {
      _appliedOn = wantOn;
      AppLogger.info('Cabinet light relay 2 ${wantOn ? 'on' : 'off'}');
    }
  }

  Future<void> _applyShutter(_PendingShutter? pending) async {
    if (pending == null) return;

    final deviceId = ref.read(deviceAuthProvider).deviceId;
    if (deviceId == null || deviceId.isEmpty) return;

    if (pending.expired) {
      Diag.shutterWarn(
        'shutter.admin_expired',
        'Admin shutter command expired before apply',
        {'action': pending.action, 'requestedAt': pending.requestedAt},
      );
      await _ackShutter(deviceId, pending.requestedAt, 'expired');
      return;
    }

    final coordinator = ref.read(printCoordinatorProvider);
    if (coordinator.isShutterBusy) {
      Diag.shutterWarn(
        'shutter.admin_skipped_busy',
        'Admin shutter deferred — print in progress',
        {'action': pending.action, 'requestedAt': pending.requestedAt},
      );
      return;
    }

    final line = pending.action == 'open'
        ? ShutterCommands.open()
        : ShutterCommands.close();

    final serial = ref.read(serialControllerProvider.notifier);
    if (!ref.read(serialControllerProvider).isConnected) {
      final opened = await _openPort();
      if (!opened) {
        Diag.shutterError(
          'shutter.admin_failed',
          'Admin shutter failed — serial not connected',
          {'action': pending.action, 'requestedAt': pending.requestedAt},
        );
        await _ackShutter(deviceId, pending.requestedAt, 'failed');
        return;
      }
    }

    try {
      await serial.sendLine(line);
      AppLogger.info('Admin shutter ${pending.action} sent');
      Diag.shutterInfo(
        pending.action == 'open'
            ? 'shutter.admin_open_sent'
            : 'shutter.admin_close_sent',
        'Admin shutter ${pending.action} sent',
        {'action': pending.action, 'requestedAt': pending.requestedAt},
      );
      await _ackShutter(deviceId, pending.requestedAt, 'applied');
    } catch (error) {
      AppLogger.error('Admin shutter serial failed: $line', error);
      Diag.shutterError(
        'shutter.admin_failed',
        'Admin shutter serial send failed',
        {
          'action': pending.action,
          'requestedAt': pending.requestedAt,
          'error': error.toString(),
        },
      );
      await _ackShutter(deviceId, pending.requestedAt, 'failed');
    }
  }

  Future<void> _ackShutter(
    String deviceId,
    String requestedAt,
    String result,
  ) async {
    try {
      await ref.read(apiClientProvider).post(
        '/devices/$deviceId/shutter/ack',
        body: {
          'requestedAt': requestedAt,
          'result': result,
        },
      );
    } catch (error) {
      AppLogger.error('Shutter ack failed ($result)', error);
    }
  }

  Future<bool> _sendRelay(bool on) async {
    final serial = ref.read(serialControllerProvider.notifier);
    if (!ref.read(serialControllerProvider).isConnected) {
      final opened = await _openPort();
      if (!opened) return false;
    }
    try {
      await serial.sendLine(RelayCommands.setState(relay: 2, on: on));
      return true;
    } catch (error) {
      AppLogger.error('Cabinet light serial send failed', error);
      return false;
    }
  }

  Future<bool> _openPort() async {
    final serial = ref.read(serialControllerProvider.notifier);
    await serial.refreshPorts();
    if (!ref.mounted) return false;
    final ports = ref.read(serialControllerProvider).ports;
    if (ports.isEmpty) return false;
    serial.selectPort(_preferPort(ports));
    await serial.connect();
    return ref.read(serialControllerProvider).isConnected;
  }

  String _preferPort(List<SerialDevice> ports) {
    final selected = ref.read(serialControllerProvider).selectedPortName;
    if (selected != null && ports.any((port) => port.name == selected)) {
      return selected;
    }
    for (final port in ports) {
      final label = port.displayLabel.toLowerCase();
      if (label.contains('cp210') ||
          label.contains('silicon') ||
          label.contains('ch340') ||
          label.contains('usb')) {
        return port.name;
      }
    }
    return ports.first.name;
  }
}

class _PendingShutter {
  const _PendingShutter({
    required this.action,
    required this.requestedAt,
    required this.expired,
  });

  final String action;
  final String requestedAt;
  final bool expired;

  static _PendingShutter? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final action = raw['action']?.toString();
    final requestedAt = raw['requestedAt']?.toString();
    if (action == null ||
        (action != 'open' && action != 'close') ||
        requestedAt == null ||
        requestedAt.isEmpty) {
      return null;
    }
    return _PendingShutter(
      action: action,
      requestedAt: requestedAt,
      expired: raw['expired'] == true,
    );
  }
}
