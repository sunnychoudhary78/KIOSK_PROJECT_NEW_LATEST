import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/features/fuel_stations/data/fuel_stations_repository.dart';
import 'package:skp_kiosk/features/fuel_stations/domain/fuel_station.dart';
import 'package:skp_kiosk/features/service_analytics/application/service_analytics_tracker.dart';
import 'package:skp_kiosk/features/service_analytics/domain/service_event_keys.dart';

final fuelStationsRepositoryProvider = Provider<FuelStationsRepository>((ref) {
  return FuelStationsRepository(ref.watch(apiClientProvider));
});

class FuelStationsState {
  const FuelStationsState({
    this.loading = false,
    this.kind = FuelKind.fuel,
    this.items = const [],
    this.error,
  });

  final bool loading;
  final FuelKind kind;
  final List<FuelStation> items;
  final String? error;

  FuelStationsState copyWith({
    bool? loading,
    FuelKind? kind,
    List<FuelStation>? items,
    String? error,
    bool clearError = false,
  }) {
    return FuelStationsState(
      loading: loading ?? this.loading,
      kind: kind ?? this.kind,
      items: items ?? this.items,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class FuelStationsController extends Notifier<FuelStationsState> {
  int _request = 0;

  @override
  FuelStationsState build() => const FuelStationsState();

  FuelStationsRepository get _repository => ref.read(fuelStationsRepositoryProvider);

  Future<void> load({FuelKind? kind}) async {
    final nextKind = kind ?? state.kind;
    final filterChanged = kind != null && kind != state.kind;
    final request = ++_request;
    state = state.copyWith(loading: true, kind: nextKind, clearError: true);
    if (filterChanged) {
      // ignore: discarded_futures
      ref
          .read(serviceAnalyticsTrackerProvider)
          .track(ServiceEventKeys.fuelFilter(nextKind.name));
    }
    try {
      final items = await _repository.list(kind: nextKind);
      if (request != _request) {
        return;
      }
      state = state.copyWith(loading: false, items: items);
    } catch (error) {
      if (request != _request) {
        return;
      }
      state = state.copyWith(
        loading: false,
        items: const [],
        error: userFacingError(error),
      );
    }
  }
}

final fuelStationsControllerProvider =
    NotifierProvider.autoDispose<FuelStationsController, FuelStationsState>(
  FuelStationsController.new,
);
