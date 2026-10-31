import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_admin/features/auth/presentation/auth_controller.dart';
import 'package:skp_admin/features/print_jobs/data/print_job.dart';
import 'package:skp_admin/features/print_jobs/data/print_jobs_repository.dart';

final printJobsRepositoryProvider = Provider<PrintJobsRepository>(
  (ref) => PrintJobsRepository(ref.watch(apiClientProvider)),
);

class PrintJobsState {
  const PrintJobsState({
    this.items = const [],
    this.loading = false,
    this.refreshing = false,
    this.error,
  });

  final List<PrintJob> items;
  final bool loading;
  final bool refreshing;
  final String? error;

  PrintJobsState copyWith({
    List<PrintJob>? items,
    bool? loading,
    bool? refreshing,
    String? error,
    bool clearError = false,
  }) {
    return PrintJobsState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class PrintJobsNotifier extends Notifier<PrintJobsState> {
  @override
  PrintJobsState build() {
    ref.listen(staffAuthProvider, (previous, next) {
      if (next.isAuthenticated) {
        Future.microtask(load);
      } else if (!next.restoring) {
        state = const PrintJobsState();
      }
    });
    if (ref.read(staffAuthProvider).isAuthenticated) {
      Future.microtask(load);
    }
    return const PrintJobsState(loading: true);
  }

  Future<void> load() async {
    if (!ref.read(staffAuthProvider).isAuthenticated) return;
    state = state.copyWith(
      loading: state.items.isEmpty,
      refreshing: state.items.isNotEmpty,
      clearError: true,
    );
    try {
      final items = await ref.read(printJobsRepositoryProvider).list();
      state = state.copyWith(items: items, loading: false, refreshing: false, clearError: true);
    } catch (error) {
      state = state.copyWith(loading: false, refreshing: false, error: '$error');
    }
  }
}

final printJobsProvider = NotifierProvider<PrintJobsNotifier, PrintJobsState>(
  PrintJobsNotifier.new,
);
