import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';
import 'package:skp_mobile/features/otp_print/application/otp_print_models.dart';

class PrintHistoryNotifier extends AsyncNotifier<List<OtpChallenge>> {
  @override
  Future<List<OtpChallenge>> build() async {
    final auth = ref.watch(citizenAuthProvider);
    if (!auth.isAuthenticated) return const [];
    return _fetch();
  }

  Future<List<OtpChallenge>> _fetch() async {
    final result = await ref.read(apiClientProvider).get('/otp-challenges');
    final raw = result['items'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(OtpChallenge.fromJson)
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final printHistoryProvider =
    AsyncNotifierProvider<PrintHistoryNotifier, List<OtpChallenge>>(
  PrintHistoryNotifier.new,
);

OtpChallenge? activeChallengeOf(List<OtpChallenge> items) {
  for (final item in items) {
    if (item.isActive) return item;
  }
  return null;
}
