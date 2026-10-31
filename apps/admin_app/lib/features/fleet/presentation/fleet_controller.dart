import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_admin/features/auth/presentation/auth_controller.dart';
import 'package:skp_admin/features/fleet/data/device.dart';
import 'package:skp_admin/features/fleet/data/devices_repository.dart';

final devicesRepositoryProvider = Provider<DevicesRepository>(
  (ref) => DevicesRepository(ref.watch(apiClientProvider)),
);

class FleetState {
  const FleetState({
    this.devices = const [],
    this.loading = false,
    this.refreshing = false,
    this.submitting = false,
    this.error,
  });

  final List<KioskDevice> devices;
  final bool loading;
  final bool refreshing;
  final bool submitting;
  final String? error;

  List<KioskDevice> get attention => devices.where(kioskNeedsAttention).toList();

  KioskDevice? byId(String id) {
    for (final device in devices) {
      if (device.id == id) return device;
    }
    return null;
  }

  FleetState copyWith({
    List<KioskDevice>? devices,
    bool? loading,
    bool? refreshing,
    bool? submitting,
    String? error,
    bool clearError = false,
  }) {
    return FleetState(
      devices: devices ?? this.devices,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      submitting: submitting ?? this.submitting,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class FleetNotifier extends Notifier<FleetState> {
  @override
  FleetState build() {
    ref.listen(staffAuthProvider, (previous, next) {
      if (next.isAuthenticated) {
        Future.microtask(load);
      } else if (!next.restoring) {
        state = const FleetState();
      }
    });
    if (ref.read(staffAuthProvider).isAuthenticated) {
      Future.microtask(load);
    }
    return const FleetState(loading: true);
  }

  Future<void> load() async {
    if (!ref.read(staffAuthProvider).isAuthenticated) return;
    state = state.copyWith(
      loading: state.devices.isEmpty,
      refreshing: state.devices.isNotEmpty,
      clearError: true,
    );
    try {
      final devices = await ref.read(devicesRepositoryProvider).list();
      state = state.copyWith(devices: devices, loading: false, refreshing: false, clearError: true);
    } catch (error) {
      state = state.copyWith(loading: false, refreshing: false, error: '$error');
    }
  }

  void replaceAll(List<KioskDevice> devices) {
    state = state.copyWith(devices: devices, clearError: true);
  }

  void upsert(KioskDevice device) {
    final next = [...state.devices];
    final index = next.indexWhere((item) => item.id == device.id);
    if (index >= 0) next[index] = device;
    state = state.copyWith(devices: next);
  }

  Future<void> setStatus(KioskDevice device, String status) async {
    if (state.submitting) return;
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final updated = await ref.read(devicesRepositoryProvider).setStatus(device.id, status);
      upsert(updated);
      state = state.copyWith(submitting: false);
    } catch (error) {
      state = state.copyWith(submitting: false, error: '$error');
    }
  }
}

final fleetProvider = NotifierProvider<FleetNotifier, FleetState>(FleetNotifier.new);
