import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_admin/features/auth/presentation/auth_controller.dart';
import 'package:skp_admin/features/support/data/support_query.dart';
import 'package:skp_admin/features/support/data/support_repository.dart';

final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => SupportRepository(ref.watch(apiClientProvider)),
);

class SupportState {
  const SupportState({
    this.items = const [],
    this.openCount = 0,
    this.status = 'open',
    this.source = 'all',
    this.kiosk = 'all',
    this.loading = false,
    this.refreshing = false,
    this.acting = false,
    this.error,
  });

  final List<SupportQuery> items;
  final int openCount;
  final String status;
  final String source;
  final String kiosk;
  final bool loading;
  final bool refreshing;
  final bool acting;
  final String? error;

  List<String> get kioskNames {
    final names = items
        .map((item) => item.kioskName)
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    names.sort();
    return names;
  }

  List<SupportQuery> get visible {
    if (kiosk == 'all' || !kioskNames.contains(kiosk)) return items;
    return items.where((item) => item.kioskName == kiosk).toList();
  }

  SupportQuery? byId(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  SupportState copyWith({
    List<SupportQuery>? items,
    int? openCount,
    String? status,
    String? source,
    String? kiosk,
    bool? loading,
    bool? refreshing,
    bool? acting,
    String? error,
    bool clearError = false,
  }) {
    return SupportState(
      items: items ?? this.items,
      openCount: openCount ?? this.openCount,
      status: status ?? this.status,
      source: source ?? this.source,
      kiosk: kiosk ?? this.kiosk,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      acting: acting ?? this.acting,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class SupportNotifier extends Notifier<SupportState> {
  @override
  SupportState build() {
    ref.listen(staffAuthProvider, (previous, next) {
      if (next.isAuthenticated) {
        Future.microtask(load);
      } else if (!next.restoring) {
        state = const SupportState();
      }
    });
    if (ref.read(staffAuthProvider).isAuthenticated) {
      Future.microtask(load);
    }
    return const SupportState(loading: true);
  }

  Future<void> load() async {
    if (!ref.read(staffAuthProvider).isAuthenticated) return;
    state = state.copyWith(
      loading: state.items.isEmpty,
      refreshing: state.items.isNotEmpty,
      clearError: true,
    );
    try {
      final result = await ref.read(supportRepositoryProvider).list(
        status: state.status,
        source: state.source,
      );
      state = state.copyWith(
        items: result.items,
        openCount: result.openCount,
        loading: false,
        refreshing: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(loading: false, refreshing: false, error: '$error');
    }
  }

  Future<void> setStatusFilter(String status) async {
    state = state.copyWith(status: status);
    await load();
  }

  Future<void> setSourceFilter(String source) async {
    state = state.copyWith(source: source);
    await load();
  }

  void setKioskFilter(String kiosk) {
    state = state.copyWith(kiosk: kiosk);
  }

  Future<void> resolve(String queryId, String resolution) async {
    state = state.copyWith(acting: true, clearError: true);
    try {
      final updated = await ref.read(supportRepositoryProvider).resolve(queryId, resolution);
      _apply(updated);
      state = state.copyWith(acting: false);
    } catch (error) {
      state = state.copyWith(acting: false, error: '$error');
    }
  }

  Future<void> resendOtp(String queryId) async {
    state = state.copyWith(acting: true, clearError: true);
    try {
      final updated = await ref.read(supportRepositoryProvider).resendOtp(queryId);
      _apply(updated);
      state = state.copyWith(acting: false);
    } catch (error) {
      state = state.copyWith(acting: false, error: '$error');
    }
  }

  void _apply(SupportQuery updated) {
    final next = state.items.map((item) => item.id == updated.id ? updated : item).toList();
    final visible = state.status == 'all' || updated.status == state.status
        ? next
        : next.where((item) => item.id != updated.id).toList();
    final openCount = updated.status == 'resolved' && state.openCount > 0
        ? state.openCount - 1
        : state.openCount;
    state = state.copyWith(items: visible, openCount: openCount, acting: false);
  }
}

final supportProvider = NotifierProvider<SupportNotifier, SupportState>(SupportNotifier.new);
