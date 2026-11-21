import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/surveillance/application/surveillance_controller.dart';

/// Polls Admin-issued surveillance maintenance commands (heal / retry / prune).
class SurveillanceCommandsController extends Notifier<void> {
  Timer? _timer;
  bool _ticking = false;
  String? _inFlightCommandId;

  @override
  void build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    ref.listen(deviceAuthProvider, (_, next) {
      if (next.isAuthenticated) {
        _startPolling();
      } else {
        _timer?.cancel();
        _timer = null;
      }
    });
    if (ref.read(deviceAuthProvider).isAuthenticated) {
      Future.microtask(_startPolling);
    }
  }

  void _startPolling() {
    if (!Platform.isWindows) {
      return;
    }
    _timer ??= Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_tick());
    });
    unawaited(_tick());
  }

  Future<void> _tick() async {
    if (_ticking || !ref.mounted) {
      return;
    }
    final auth = ref.read(deviceAuthProvider);
    if (!auth.isAuthenticated || auth.deviceId == null) {
      return;
    }
    _ticking = true;
    try {
      final json = await ref
          .read(apiClientProvider)
          .get('/devices/${auth.deviceId}/surveillance/commands/pending');
      if (!ref.mounted) {
        return;
      }

      final raw = json['command'];
      if (raw is! Map) {
        return;
      }
      final command = Map<String, dynamic>.from(raw);
      final commandId = command['id']?.toString();
      final type = command['type']?.toString();
      final status = command['status']?.toString();
      if (commandId == null ||
          commandId.isEmpty ||
          type == null ||
          type.isEmpty) {
        return;
      }
      if (status != 'pending' && status != 'running') {
        return;
      }
      if (_inFlightCommandId == commandId) {
        return;
      }
      _inFlightCommandId = commandId;
      try {
        await _runAndAck(
          deviceId: auth.deviceId!,
          commandId: commandId,
          type: type,
        );
      } finally {
        if (_inFlightCommandId == commandId) {
          _inFlightCommandId = null;
        }
      }
    } catch (error) {
      AppLogger.error('SURVEILLANCE_COMMAND_POLL_FAILED', error);
    } finally {
      _ticking = false;
    }
  }

  Future<void> _runAndAck({
    required String deviceId,
    required String commandId,
    required String type,
  }) async {
    final api = ref.read(apiClientProvider);
    AppLogger.info('SURVEILLANCE_COMMAND_RUN id=$commandId type=$type');
    try {
      final Map<String, int> result;
      if (type == 'restart_recording') {
        result =
            await ref.read(surveillanceControllerProvider.notifier).forceRestart();
      } else {
        final sink = ref.read(surveillanceUploadSinkProvider);
        await sink.attach(deviceId: deviceId);
        result = await sink.runMaintenanceCommand(type);
      }
      await api.post(
        '/devices/$deviceId/surveillance/commands/$commandId/ack',
        body: {'ok': true, 'result': result},
      );
      AppLogger.info(
        'SURVEILLANCE_COMMAND_OK id=$commandId type=$type result=$result',
      );
    } catch (error) {
      AppLogger.error('SURVEILLANCE_COMMAND_FAILED id=$commandId type=$type', error);
      try {
        await api.post(
          '/devices/$deviceId/surveillance/commands/$commandId/ack',
          body: {
            'ok': false,
            'error': error.toString().length > 500
                ? error.toString().substring(0, 500)
                : error.toString(),
          },
        );
      } catch (ackError) {
        AppLogger.error('SURVEILLANCE_COMMAND_ACK_FAILED id=$commandId', ackError);
      }
    }
  }
}

final surveillanceCommandsControllerProvider =
    NotifierProvider<SurveillanceCommandsController, void>(
  SurveillanceCommandsController.new,
);
