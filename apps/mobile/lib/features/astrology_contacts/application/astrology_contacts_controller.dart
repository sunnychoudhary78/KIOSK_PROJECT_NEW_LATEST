import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/core/network/api_client.dart';
import 'package:skp_mobile/features/astrology_contacts/domain/astrology_contact.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';

class AstrologyContactsState {
  const AstrologyContactsState({
    this.contacts = const [],
    this.loading = false,
    this.error,
  });

  final List<AstrologyContact> contacts;
  final bool loading;
  final String? error;
}

class AstrologyContactsNotifier extends Notifier<AstrologyContactsState> {
  @override
  AstrologyContactsState build() => const AstrologyContactsState();

  Future<void> load(AstrologyContactKind kind) async {
    state = const AstrologyContactsState(loading: true);
    try {
      final result = await ref.read(apiClientProvider).get(
        '/astrology-contacts',
        query: {'kind': kind.name},
      );
      state = AstrologyContactsState(contacts: _parseItems(result, kind));
    } on ApiException catch (error) {
      // Citizen is not allowed on this endpoint yet — show Coming Soon, not a raw error.
      if (_isComingSoon(error)) {
        state = const AstrologyContactsState(contacts: []);
        return;
      }
      state = AstrologyContactsState(error: error.toString());
    } catch (error) {
      state = AstrologyContactsState(error: error.toString());
    }
  }

  bool _isComingSoon(ApiException error) {
    if (error.statusCode == 403 || error.statusCode == 404) return true;
    final message = error.message.toLowerCase();
    final code = (error.code ?? '').toLowerCase();
    return code == 'forbidden' ||
        message.contains('principal type not allowed') ||
        message.contains('forbidden');
  }

  List<AstrologyContact> _parseItems(
    Map<String, dynamic> result,
    AstrologyContactKind kind,
  ) {
    final raw = result['items'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          AstrologyContact.fromJson(Map<String, dynamic>.from(item)),
    ].where((c) => c.kind == kind).toList(growable: false);
  }
}

final astrologyContactsProvider =
    NotifierProvider<AstrologyContactsNotifier, AstrologyContactsState>(
  AstrologyContactsNotifier.new,
);
