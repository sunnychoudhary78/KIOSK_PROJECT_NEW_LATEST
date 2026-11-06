import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_admin/core/network/api_client.dart';
import 'package:skp_admin/features/auth/presentation/auth_controller.dart';
import 'package:skp_admin/features/cabinet_light/data/cabinet_light.dart';
import 'package:skp_admin/features/cabinet_light/data/cabinet_light_repository.dart';

final cabinetLightRepositoryProvider = Provider<CabinetLightRepository>(
  (ref) => CabinetLightRepository(ref.watch(apiClientProvider)),
);

class CabinetLightState {
  const CabinetLightState({
    this.config = CabinetLightConfig.defaults,
    this.loading = false,
    this.saving = false,
    this.error,
    this.notice,
  });

  final CabinetLightConfig config;
  final bool loading;
  final bool saving;
  final String? error;
  final String? notice;

  CabinetLightState copyWith({
    CabinetLightConfig? config,
    bool? loading,
    bool? saving,
    String? error,
    bool clearError = false,
    String? notice,
    bool clearNotice = false,
  }) {
    return CabinetLightState(
      config: config ?? this.config,
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      error: clearError ? null : error ?? this.error,
      notice: clearNotice ? null : notice ?? this.notice,
    );
  }
}

class CabinetLightNotifier extends Notifier<CabinetLightState> {
  @override
  CabinetLightState build() => const CabinetLightState();

  CabinetLightRepository get _repo => ref.read(cabinetLightRepositoryProvider);

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final config = await _repo.load();
      state = state.copyWith(loading: false, config: config, clearError: true);
    } catch (error) {
      state = state.copyWith(loading: false, error: _message(error));
    }
  }

  void setTime({required bool on, required String value}) {
    state = state.copyWith(
      config: on ? state.config.copyWith(onTime: value) : state.config.copyWith(offTime: value),
      clearNotice: true,
    );
  }

  Future<void> turnOn() => _save(state.config.copyWith(enabled: true, mode: 'on'));

  Future<void> turnOff() => _save(state.config.copyWith(enabled: true, mode: 'off'));

  Future<void> followSchedule() => _save(state.config.copyWith(enabled: true, mode: 'schedule'));

  Future<void> _save(CabinetLightConfig config) async {
    state = state.copyWith(saving: true, clearError: true, clearNotice: true);
    try {
      await _repo.save(config);
      state = state.copyWith(
        saving: false,
        config: config,
        notice: 'Saved. The kiosk applies this within about 20 seconds.',
      );
    } catch (error) {
      state = state.copyWith(saving: false, error: _message(error));
    }
  }

  String _message(Object error) {
    if (error is ApiException) return error.message;
    return 'Something went wrong. Try again.';
  }
}

final cabinetLightProvider = NotifierProvider<CabinetLightNotifier, CabinetLightState>(
  CabinetLightNotifier.new,
);
