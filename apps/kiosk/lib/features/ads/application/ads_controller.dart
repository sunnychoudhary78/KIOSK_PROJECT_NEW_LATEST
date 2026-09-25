import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/features/ads/data/ads_media_cache.dart';
import 'package:skp_kiosk/features/ads/data/ads_repository.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';

final adsRepositoryProvider = Provider<AdsRepository>((ref) {
  return AdsRepository(ref.watch(apiClientProvider));
});

class AdsUiState {
  const AdsUiState({
    this.playlist = const AdPlaylist(idle: [], homeBanners: [], homeCarousels: []),
    this.idleVisible = false,
    this.loading = false,
    this.error,
  });

  final AdPlaylist playlist;
  final bool idleVisible;
  final bool loading;
  final String? error;

  AdsUiState copyWith({
    AdPlaylist? playlist,
    bool? idleVisible,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return AdsUiState(
      playlist: playlist ?? this.playlist,
      idleVisible: idleVisible ?? this.idleVisible,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final adsControllerProvider =
    NotifierProvider<AdsController, AdsUiState>(AdsController.new);

class AdsController extends Notifier<AdsUiState> {
  Timer? _pollTimer;
  Timer? _idleTimer;
  static const idleTimeout = Duration(seconds: 18);
  static const pollInterval = Duration(seconds: 60);

  AdsRepository get _repo => ref.read(adsRepositoryProvider);

  @override
  AdsUiState build() {
    ref.onDispose(() {
      _pollTimer?.cancel();
      _idleTimer?.cancel();
    });
    ref.listen<KioskSessionState>(kioskSessionControllerProvider, (previous, next) {
      if (previous?.onHome == next.onHome) {
        return;
      }
      if (next.onHome) {
        resetIdleTimer();
      } else {
        _pauseAttract();
      }
    });
    return const AdsUiState();
  }

  void startWatching() {
    _pollTimer?.cancel();
    unawaited(refreshPlaylist());
    _pollTimer = Timer.periodic(pollInterval, (_) {
      unawaited(refreshPlaylist());
    });
    resetIdleTimer();
  }

  void stopWatching() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _idleTimer?.cancel();
    _idleTimer = null;
    state = state.copyWith(idleVisible: false);
  }

  Future<void> refreshPlaylist() async {
    final auth = ref.read(deviceAuthProvider);
    if (!auth.isAuthenticated) {
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final playlist = await _repo.fetchPlaylist();
      state = state.copyWith(playlist: playlist, loading: false);
      _armIdleTimerIfNeeded();
      unawaited(_prefetchIdleMedia(playlist));
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  /// Dismiss idle overlay (if showing) and restart the inactivity timer.
  void resetIdleTimer() {
    _idleTimer?.cancel();
    if (state.idleVisible) {
      state = state.copyWith(idleVisible: false);
    }
    _armIdleTimerIfNeeded();
  }

  /// Hide attract immediately and do not re-arm while a service route is open.
  void _pauseAttract() {
    _idleTimer?.cancel();
    _idleTimer = null;
    if (state.idleVisible) {
      state = state.copyWith(idleVisible: false);
    }
  }

  bool get _onHome => ref.read(kioskSessionControllerProvider).onHome;

  /// Arm timer only on home, when overlay is hidden and idle creatives exist.
  void _armIdleTimerIfNeeded() {
    if (!_onHome) {
      _idleTimer?.cancel();
      _idleTimer = null;
      return;
    }
    if (state.idleVisible) {
      return;
    }
    if (state.playlist.idle.isEmpty) {
      _idleTimer?.cancel();
      _idleTimer = null;
      return;
    }
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, () {
      if (!_onHome || state.playlist.idle.isEmpty) {
        return;
      }
      state = state.copyWith(idleVisible: true);
    });
  }

  @visibleForTesting
  void replacePlaylist(AdPlaylist playlist) {
    state = state.copyWith(playlist: playlist);
    _armIdleTimerIfNeeded();
  }

  void dismissIdle() {
    state = state.copyWith(idleVisible: false);
    resetIdleTimer();
  }

  /// Show the attract loop immediately (idle-timeout visitor reset).
  void showIdleNow() {
    _idleTimer?.cancel();
    _idleTimer = null;
    if (state.playlist.idle.isEmpty) {
      resetIdleTimer();
      return;
    }
    state = state.copyWith(idleVisible: true);
  }

  Future<void> _prefetchIdleMedia(AdPlaylist playlist) async {
    try {
      final cache = ref.read(adsMediaCacheProvider);
      await cache.pruneKeepIds(AdsMediaCache.idsInIdle(playlist.idle));
      await cache.prefetchIdle(playlist.idle);
    } catch (_) {}
  }

  Future<void> reportEvent({
    required String campaignId,
    required String creativeId,
    required String eventType,
  }) async {
    try {
      await _repo.reportEvents([
        {
          'campaignId': campaignId,
          'creativeId': creativeId,
          'eventType': eventType,
          'occurredAt': DateTime.now().toUtc().toIso8601String(),
        },
      ]);
    } catch (_) {
      // Non-blocking for UX
    }
  }
}
