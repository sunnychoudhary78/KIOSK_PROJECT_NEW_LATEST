import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/features/weather/application/weather_controller.dart';
import 'package:skp_kiosk/features/weather/domain/air_quality_detail.dart';

class AirQualityUiState {
  const AirQualityUiState({
    this.detail,
    this.history,
    this.loading = false,
    this.historyLoading = false,
    this.error,
    this.historyError,
  });

  final AirQualityDetail? detail;
  final AirQualityHistory? history;
  final bool loading;
  final bool historyLoading;
  final String? error;
  final String? historyError;

  AirQualityUiState copyWith({
    AirQualityDetail? detail,
    AirQualityHistory? history,
    bool? loading,
    bool? historyLoading,
    String? error,
    String? historyError,
    bool clearError = false,
    bool clearHistoryError = false,
  }) {
    return AirQualityUiState(
      detail: detail ?? this.detail,
      history: history ?? this.history,
      loading: loading ?? this.loading,
      historyLoading: historyLoading ?? this.historyLoading,
      error: clearError ? null : error ?? this.error,
      historyError: clearHistoryError ? null : historyError ?? this.historyError,
    );
  }
}

class AirQualityController extends Notifier<AirQualityUiState> {
  int _request = 0;

  @override
  AirQualityUiState build() => const AirQualityUiState();

  Future<void> load() async {
    final request = ++_request;
    state = state.copyWith(
      loading: true,
      historyLoading: true,
      clearError: true,
      clearHistoryError: true,
    );

    final repository = ref.read(weatherRepositoryProvider);
    final detailFuture = repository.fetchAirQualityDetail();
    final historyFuture = repository.fetchAirQualityHistory(hours: 24);

    try {
      final detail = await detailFuture;
      if (request != _request) {
        return;
      }
      state = state.copyWith(
        loading: false,
        detail: detail.hasDisplayableData ? detail : null,
        error: detail.hasDisplayableData
            ? null
            : 'Air quality data is unavailable right now.',
        clearError: detail.hasDisplayableData,
      );
    } catch (error) {
      if (request != _request) {
        return;
      }
      state = state.copyWith(
        loading: false,
        error: userFacingError(error),
      );
    }

    try {
      final history = await historyFuture;
      if (request != _request) {
        return;
      }
      state = state.copyWith(
        historyLoading: false,
        history: history,
        clearHistoryError: true,
      );
    } catch (error) {
      if (request != _request) {
        return;
      }
      state = state.copyWith(
        historyLoading: false,
        historyError: userFacingError(error),
      );
    }
  }
}

final airQualityControllerProvider =
    NotifierProvider<AirQualityController, AirQualityUiState>(
  AirQualityController.new,
);
