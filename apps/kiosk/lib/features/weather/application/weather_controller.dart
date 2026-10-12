import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/features/weather/data/weather_repository.dart';
import 'package:skp_kiosk/features/weather/domain/weather_snapshot.dart';

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return WeatherRepository(ref.watch(apiClientProvider));
});

class WeatherUiState {
  const WeatherUiState({this.snapshot, this.loading = false});

  final WeatherSnapshot? snapshot;
  final bool loading;

  WeatherUiState copyWith({
    WeatherSnapshot? snapshot,
    bool? loading,
    bool clearSnapshot = false,
  }) {
    return WeatherUiState(
      snapshot: clearSnapshot ? null : snapshot ?? this.snapshot,
      loading: loading ?? this.loading,
    );
  }
}

final weatherControllerProvider =
    NotifierProvider<WeatherController, WeatherUiState>(WeatherController.new);

class WeatherController extends Notifier<WeatherUiState> {
  static const refreshInterval = Duration(minutes: 15);

  Timer? _timer;
  bool _started = false;

  @override
  WeatherUiState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
      _started = false;
    });
    return const WeatherUiState();
  }

  WeatherRepository get _repository => ref.read(weatherRepositoryProvider);

  Future<void> startWatching() async {
    if (_started) {
      return;
    }
    _started = true;
    await refresh();
    _timer?.cancel();
    _timer = Timer.periodic(refreshInterval, (_) {
      unawaited(refresh());
    });
  }

  void stopWatching() {
    _timer?.cancel();
    _timer = null;
    _started = false;
    state = const WeatherUiState();
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true);
    try {
      final snapshot = await _repository.fetch();
      state = WeatherUiState(
        snapshot: snapshot.hasDisplayableData ? snapshot : null,
        loading: false,
      );
    } catch (_) {
      // Soft-fail: keep last good snapshot if any; otherwise stay empty.
      state = state.copyWith(loading: false);
    }
  }
}
