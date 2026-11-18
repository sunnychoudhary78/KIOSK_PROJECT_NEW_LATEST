import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks which rating families were already prompted this visitor session.
class ServiceRatingsGate extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  bool shouldPrompt(String family) {
    if (family.isEmpty) return false;
    return !state.contains(family);
  }

  void markPrompted(String family) {
    if (family.isEmpty || state.contains(family)) return;
    state = {...state, family};
  }

  void clear() {
    if (state.isEmpty) return;
    state = <String>{};
  }
}

final serviceRatingsGateProvider =
    NotifierProvider<ServiceRatingsGate, Set<String>>(ServiceRatingsGate.new);
