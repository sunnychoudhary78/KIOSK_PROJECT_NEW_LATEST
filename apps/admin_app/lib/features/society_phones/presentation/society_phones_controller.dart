import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_admin/core/network/api_client.dart';
import 'package:skp_admin/features/auth/presentation/auth_controller.dart';
import 'package:skp_admin/features/society_phones/data/society_phone.dart';
import 'package:skp_admin/features/society_phones/data/society_phones_repository.dart';

final societyPhonesRepositoryProvider = Provider<SocietyPhonesRepository>(
  (ref) => SocietyPhonesRepository(ref.watch(apiClientProvider)),
);

class SocietyPhonesState {
  const SocietyPhonesState({
    this.quota = SocietyQuota.defaults,
    this.items = const [],
    this.total = 0,
    this.query = '',
    this.loading = false,
    this.savingQuota = false,
    this.adding = false,
    this.removingId,
    this.error,
    this.notice,
  });

  final SocietyQuota quota;
  final List<SocietyPhone> items;
  final int total;
  final String query;
  final bool loading;
  final bool savingQuota;
  final bool adding;
  final String? removingId;
  final String? error;
  final String? notice;

  SocietyPhonesState copyWith({
    SocietyQuota? quota,
    List<SocietyPhone>? items,
    int? total,
    String? query,
    bool? loading,
    bool? savingQuota,
    bool? adding,
    String? removingId,
    bool clearRemovingId = false,
    String? error,
    bool clearError = false,
    String? notice,
    bool clearNotice = false,
  }) {
    return SocietyPhonesState(
      quota: quota ?? this.quota,
      items: items ?? this.items,
      total: total ?? this.total,
      query: query ?? this.query,
      loading: loading ?? this.loading,
      savingQuota: savingQuota ?? this.savingQuota,
      adding: adding ?? this.adding,
      removingId: clearRemovingId ? null : removingId ?? this.removingId,
      error: clearError ? null : error ?? this.error,
      notice: clearNotice ? null : notice ?? this.notice,
    );
  }
}

class SocietyPhonesNotifier extends Notifier<SocietyPhonesState> {
  @override
  SocietyPhonesState build() => const SocietyPhonesState();

  SocietyPhonesRepository get _repo => ref.read(societyPhonesRepositoryProvider);

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final quota = await _repo.loadQuota();
      final list = await _repo.list(query: state.query);
      state = state.copyWith(
        loading: false,
        quota: quota,
        items: list.items,
        total: list.total,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: _message(error));
    }
  }

  Future<void> search(String query) async {
    state = state.copyWith(query: query.trim());
    await load();
  }

  Future<bool> saveQuota({
    required String period,
    required String bwRaw,
    required String colorRaw,
  }) async {
    final bw = parseQuotaPages(bwRaw);
    final color = parseQuotaPages(colorRaw);
    if (bw == null || color == null) {
      state = state.copyWith(
        error: 'Free pages must be a whole number from 0 to 500.',
        clearNotice: true,
      );
      return false;
    }
    state = state.copyWith(savingQuota: true, clearError: true, clearNotice: true);
    try {
      final quota = SocietyQuota(period: period, freeBwPages: bw, freeColorPages: color);
      await _repo.saveQuota(quota);
      state = state.copyWith(
        savingQuota: false,
        quota: quota,
        notice: 'Society free limit saved.',
      );
      return true;
    } catch (error) {
      state = state.copyWith(savingQuota: false, error: _message(error));
      return false;
    }
  }

  Future<bool> addPhone(String raw) async {
    final invalid = validateSocietyPhone(raw);
    if (invalid != null) {
      state = state.copyWith(error: invalid, clearNotice: true);
      return false;
    }
    state = state.copyWith(adding: true, clearError: true, clearNotice: true);
    try {
      await _repo.add(raw);
      state = state.copyWith(adding: false, notice: 'Number added.');
      await load();
      return true;
    } catch (error) {
      state = state.copyWith(adding: false, error: _message(error));
      return false;
    }
  }

  Future<void> removePhone(String id) async {
    state = state.copyWith(removingId: id, clearError: true, clearNotice: true);
    try {
      await _repo.remove(id);
      state = state.copyWith(clearRemovingId: true, notice: 'Number removed.');
      await load();
    } catch (error) {
      state = state.copyWith(clearRemovingId: true, error: _message(error));
    }
  }

  String _message(Object error) {
    if (error is ApiException) return error.message;
    return 'Something went wrong. Try again.';
  }
}

final societyPhonesProvider = NotifierProvider<SocietyPhonesNotifier, SocietyPhonesState>(
  SocietyPhonesNotifier.new,
);
