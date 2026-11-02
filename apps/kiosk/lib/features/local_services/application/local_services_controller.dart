import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';
import 'package:skp_kiosk/features/local_services/data/local_services_repository.dart';
import 'package:skp_kiosk/features/local_services/domain/local_service.dart';

final localServicesRepositoryProvider = Provider<LocalServicesRepository>((ref) {
  return LocalServicesRepository(ref.watch(apiClientProvider));
});

class LocalServicesState {
  const LocalServicesState({
    this.loading = false,
    this.categories = const [],
    this.error,
  });

  final bool loading;
  final List<LocalServiceCategory> categories;
  final String? error;

  LocalServicesState copyWith({
    bool? loading,
    List<LocalServiceCategory>? categories,
    String? error,
    bool clearError = false,
  }) {
    return LocalServicesState(
      loading: loading ?? this.loading,
      categories: categories ?? this.categories,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class LocalServicesController extends Notifier<LocalServicesState> {
  @override
  LocalServicesState build() => const LocalServicesState();

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final categories = await ref.read(localServicesRepositoryProvider).list();
      state = state.copyWith(loading: false, categories: categories);
    } catch (error) {
      state = state.copyWith(
        loading: false,
        categories: const [],
        error: userFacingError(error),
      );
    }
  }
}

final localServicesControllerProvider =
    NotifierProvider.autoDispose<LocalServicesController, LocalServicesState>(
  LocalServicesController.new,
);
