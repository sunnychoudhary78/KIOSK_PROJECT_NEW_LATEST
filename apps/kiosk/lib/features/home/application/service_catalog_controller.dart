import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/features/home/data/service_catalog_repository.dart';
import 'package:skp_kiosk/features/home/domain/kiosk_home_service.dart';

final serviceCatalogRepositoryProvider = Provider<ServiceCatalogRepository>((ref) {
  return ServiceCatalogRepository(ref.watch(apiClientProvider));
});

class ServiceCatalogState {
  const ServiceCatalogState({
    this.byCode,
    this.loading = false,
    this.loadedOnce = false,
  });

  /// Null until the first successful fetch (treat home services as enabled).
  final Map<String, bool>? byCode;
  final bool loading;
  final bool loadedOnce;

  ServiceCatalogState copyWith({
    Map<String, bool>? byCode,
    bool? loading,
    bool? loadedOnce,
  }) {
    return ServiceCatalogState(
      byCode: byCode ?? this.byCode,
      loading: loading ?? this.loading,
      loadedOnce: loadedOnce ?? this.loadedOnce,
    );
  }

  bool isHomeServiceEnabled(KioskHomeService service) {
    return service.isEnabled(byCode);
  }
}

final serviceCatalogControllerProvider =
    NotifierProvider<ServiceCatalogController, ServiceCatalogState>(
  ServiceCatalogController.new,
);

class ServiceCatalogController extends Notifier<ServiceCatalogState> {
  static const pollInterval = Duration(seconds: 60);

  Timer? _timer;
  bool _started = false;

  @override
  ServiceCatalogState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
      _started = false;
    });
    return const ServiceCatalogState();
  }

  ServiceCatalogRepository get _repo => ref.read(serviceCatalogRepositoryProvider);

  Future<void> startWatching() async {
    if (_started) {
      return;
    }
    _started = true;
    await refresh();
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) {
      unawaited(refresh());
    });
  }

  void stopWatching() {
    _timer?.cancel();
    _timer = null;
    _started = false;
    state = const ServiceCatalogState();
  }

  Future<void> refresh() async {
    final auth = ref.read(deviceAuthProvider);
    if (!auth.isAuthenticated) {
      return;
    }
    state = state.copyWith(loading: true);
    try {
      final map = await _repo.fetchEnabledByCode();
      state = ServiceCatalogState(
        byCode: Map<String, bool>.unmodifiable(map),
        loading: false,
        loadedOnce: true,
      );
    } catch (_) {
      // Soft-fail: keep last known map so a blip does not brick the kiosk.
      state = state.copyWith(loading: false);
    }
  }
}
