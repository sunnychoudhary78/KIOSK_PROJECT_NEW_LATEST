import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';

enum ServiceOperationalStatus {
  available,
  underMaintenance,
  outOfService,
}

ServiceOperationalStatus parseServiceStatus(Object? raw) {
  switch (raw?.toString()) {
    case 'under_maintenance':
      return ServiceOperationalStatus.underMaintenance;
    case 'out_of_service':
      return ServiceOperationalStatus.outOfService;
    default:
      return ServiceOperationalStatus.available;
  }
}

String serviceStatusLabel(ServiceOperationalStatus status) {
  switch (status) {
    case ServiceOperationalStatus.available:
      return 'Available';
    case ServiceOperationalStatus.underMaintenance:
      return 'Under maintenance';
    case ServiceOperationalStatus.outOfService:
      return 'Out of service';
  }
}

class ServiceStatusState {
  const ServiceStatusState({
    this.byCode = const {},
    this.loading = false,
    this.error,
  });

  final Map<String, ServiceOperationalStatus> byCode;
  final bool loading;
  final String? error;

  ServiceOperationalStatus statusFor(String code) =>
      byCode[code] ?? ServiceOperationalStatus.available;

  ServiceStatusState copyWith({
    Map<String, ServiceOperationalStatus>? byCode,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return ServiceStatusState(
      byCode: byCode ?? this.byCode,
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class ServiceStatusController extends Notifier<ServiceStatusState> {
  Timer? _poll;

  @override
  ServiceStatusState build() {
    ref.onDispose(() => _poll?.cancel());
    ref.listen(deviceAuthProvider, (previous, next) {
      if (next.isAuthenticated) {
        _start();
      } else {
        _poll?.cancel();
        _poll = null;
        state = const ServiceStatusState();
      }
    });
    if (ref.read(deviceAuthProvider).isAuthenticated) {
      Future.microtask(_start);
    }
    return const ServiceStatusState();
  }

  void _start() {
    _poll ??= Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(refresh());
    });
    unawaited(refresh());
  }

  Future<void> refresh() async {
    if (!ref.read(deviceAuthProvider).isAuthenticated) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final json = await ref.read(apiClientProvider).get('/services');
      final rawItems = json['items'];
      final next = <String, ServiceOperationalStatus>{};
      if (rawItems is List) {
        for (final item in rawItems) {
          if (item is! Map) continue;
          final code = item['code']?.toString();
          if (code == null || code.isEmpty) continue;
          next[code] = parseServiceStatus(item['status']);
        }
      }
      if (!ref.mounted) return;
      state = ServiceStatusState(byCode: next);
    } catch (error) {
      AppLogger.error('Service status refresh failed', error);
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        error: error.toString(),
      );
    }
  }
}

final serviceStatusControllerProvider =
    NotifierProvider<ServiceStatusController, ServiceStatusState>(
  ServiceStatusController.new,
);
