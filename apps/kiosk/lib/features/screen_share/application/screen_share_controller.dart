import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/core/network/api_client.dart';

enum ScreenShareState { idle, connecting, sharing, failed }

class ScreenShareStatus {
  const ScreenShareStatus({
    this.state = ScreenShareState.idle,
    this.sessionId,
    this.lastError,
  });

  final ScreenShareState state;
  final String? sessionId;
  final String? lastError;

  ScreenShareStatus copyWith({
    ScreenShareState? state,
    String? sessionId,
    String? lastError,
    bool clearError = false,
  }) {
    return ScreenShareStatus(
      state: state ?? this.state,
      sessionId: sessionId ?? this.sessionId,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

final screenShareControllerProvider =
    NotifierProvider<ScreenShareController, ScreenShareStatus>(
  ScreenShareController.new,
);

/// Polls for admin-requested LiveKit screen share and publishes the primary display.
class ScreenShareController extends Notifier<ScreenShareStatus> {
  static const _failedRetryCooldown = Duration(seconds: 30);

  Timer? _timer;
  bool _ticking = false;
  Room? _room;
  LocalVideoTrack? _track;
  String? _activeSessionId;
  String? _lastFailedSessionId;
  DateTime? _lastFailedAt;

  @override
  ScreenShareStatus build() {
    ref.onDispose(() {
      _timer?.cancel();
      unawaited(_stop(ackEnded: false));
    });
    ref.listen(deviceAuthProvider, (_, next) {
      if (next.isAuthenticated) {
        _startPolling();
      } else {
        _timer?.cancel();
        _timer = null;
        unawaited(_stop(ackEnded: false));
      }
    });
    if (ref.read(deviceAuthProvider).isAuthenticated) {
      Future.microtask(_startPolling);
    }
    return const ScreenShareStatus();
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
    if (_ticking || !ref.mounted) return;
    final auth = ref.read(deviceAuthProvider);
    if (!auth.isAuthenticated || auth.deviceId == null) return;
    _ticking = true;
    try {
      final json = await ref
          .read(apiClientProvider)
          .get('/devices/${auth.deviceId}/screen-share/pending');
      if (!ref.mounted) return;

      final sessionRaw = json['session'];
      if (sessionRaw is! Map) {
        if (_activeSessionId != null) {
          await _stop(ackEnded: false);
        }
        return;
      }

      final session = Map<String, dynamic>.from(sessionRaw);
      final sessionId = session['id']?.toString();
      final status = session['status']?.toString();
      if (sessionId == null || sessionId.isEmpty) {
        return;
      }

      if (status == 'ended' || status == 'expired' || status == 'failed') {
        if (_activeSessionId == sessionId) {
          await _stop(ackEnded: false);
        }
        return;
      }

      if (status != 'pending' && status != 'active') {
        return;
      }

      // Already publishing this session.
      if (_activeSessionId == sessionId && _room != null) {
        return;
      }
      // Avoid hammering LiveKit after a connect failure; retry after cooldown
      // or immediately when admin starts a new session id.
      if (_lastFailedSessionId == sessionId &&
          _lastFailedAt != null &&
          DateTime.now().difference(_lastFailedAt!) < _failedRetryCooldown) {
        return;
      }

      final livekitUrl = json['livekitUrl']?.toString();
      final token = json['token']?.toString();
      if (livekitUrl == null ||
          livekitUrl.isEmpty ||
          token == null ||
          token.isEmpty) {
        return;
      }

      await _startShare(
        deviceId: auth.deviceId!,
        sessionId: sessionId,
        livekitUrl: livekitUrl,
        token: token,
      );
    } on ApiException catch (error) {
      // 503 when LiveKit unset on API — stay quiet.
      if (error.code != 'livekit_not_configured') {
        AppLogger.warn(
          'screen_share_poll_failed code=${error.code} message=${error.message}',
        );
      }
    } catch (error) {
      AppLogger.error('Screen share poll failed', error);
    } finally {
      _ticking = false;
    }
  }

  Future<void> _startShare({
    required String deviceId,
    required String sessionId,
    required String livekitUrl,
    required String token,
  }) async {
    await _stop(ackEnded: false);
    if (!ref.mounted) return;
    state = state.copyWith(
      state: ScreenShareState.connecting,
      sessionId: sessionId,
      clearError: true,
    );

    Room? room;
    LocalVideoTrack? track;
    try {
      final sources = await desktopCapturer.getSources(
        types: [SourceType.Screen],
      );
      if (sources.isEmpty) {
        throw StateError('No screen capture sources available');
      }
      final source = sources.first;

      room = Room();
      await room.connect(livekitUrl, token);
      track = await LocalVideoTrack.createScreenShareTrack(
        ScreenShareCaptureOptions(
          sourceId: source.id,
          maxFrameRate: 15,
        ),
      );
      await room.localParticipant?.publishVideoTrack(track);

      _room = room;
      _track = track;
      _activeSessionId = sessionId;
      _lastFailedSessionId = null;
      _lastFailedAt = null;
      room = null;
      track = null;

      await ref.read(apiClientProvider).post(
        '/devices/$deviceId/screen-share/ack',
        body: {
          'sessionId': sessionId,
          'result': 'started',
        },
      );

      if (!ref.mounted) return;
      state = state.copyWith(state: ScreenShareState.sharing, sessionId: sessionId);
      AppLogger.info('screen_share_started sessionId=$sessionId source=${source.id}');
    } catch (error) {
      AppLogger.error('Screen share start failed', error);
      final message = error.toString();
      try {
        await track?.stop();
      } catch (_) {}
      try {
        await room?.disconnect();
      } catch (_) {}
      try {
        await ref.read(apiClientProvider).post(
          '/devices/$deviceId/screen-share/ack',
          body: {
            'sessionId': sessionId,
            'result': 'failed',
            'error': message.length > 500 ? message.substring(0, 500) : message,
          },
        );
      } catch (_) {}
      // Full cleanup so a later poll can reconnect without an app restart.
      await _stop(ackEnded: false);
      _lastFailedSessionId = sessionId;
      _lastFailedAt = DateTime.now();
      if (!ref.mounted) return;
      state = state.copyWith(
        state: ScreenShareState.failed,
        lastError: message,
        sessionId: sessionId,
      );
    }
  }

  Future<void> _stop({required bool ackEnded}) async {
    final sessionId = _activeSessionId;
    final deviceId = ref.read(deviceAuthProvider).deviceId;
    final track = _track;
    final room = _room;
    _track = null;
    _room = null;
    _activeSessionId = null;

    try {
      await track?.stop();
    } catch (_) {}
    try {
      await room?.disconnect();
    } catch (_) {}

    if (ackEnded && sessionId != null && deviceId != null) {
      try {
        await ref.read(apiClientProvider).post(
          '/devices/$deviceId/screen-share/ack',
          body: {
            'sessionId': sessionId,
            'result': 'ended',
          },
        );
      } catch (_) {}
    }

    if (ref.mounted) {
      state = const ScreenShareStatus();
    }
  }
}
