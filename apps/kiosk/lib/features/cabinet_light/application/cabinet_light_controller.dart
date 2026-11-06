import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/hardware/serial/relay_command.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_device.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_provider.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/features/cabinet_light/application/cabinet_light_schedule.dart';

final cabinetLightControllerProvider =
    NotifierProvider<CabinetLightController, CabinetLightConfig>(
  CabinetLightController.new,
);

/// Applies the admin light schedule on firmware relay 2.
///
/// The ESP32 has no clock, so the kiosk sends `{"relay":2,"state":"on"|"off"}`
/// when the desired state changes.
class CabinetLightController extends Notifier<CabinetLightConfig> {
  Timer? _timer;
  bool? _appliedOn;
  bool _ticking = false;

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
      }
    });
    if (ref.read(deviceAuthProvider).isAuthenticated) {
      Future.microtask(_start);
    }
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
      final config = await _load();
      if (!ref.mounted) return;
      state = config;
      final wantOn = config.shouldBeOn(DateTime.now());
      final sent = await _send(wantOn);
      if (sent && _appliedOn != wantOn) {
        _appliedOn = wantOn;
        AppLogger.info('Cabinet light relay 2 ${wantOn ? 'on' : 'off'}');
      }
    } catch (error) {
      AppLogger.error('Cabinet light tick failed', error);
    } finally {
      _ticking = false;
    }
  }

  Future<CabinetLightConfig> _load() async {
    final json = await ref.read(apiClientProvider).get('/cabinet-light');
    return CabinetLightConfig.fromJson(json);
  }

  Future<bool> _send(bool on) async {
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
