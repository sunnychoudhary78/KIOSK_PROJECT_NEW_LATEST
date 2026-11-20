import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/features/astrology/data/astrology_contacts_repository.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_contact.dart';

final astrologyContactsRepositoryProvider =
    Provider<AstrologyContactsRepository>((ref) {
  return AstrologyContactsRepository(ref.watch(apiClientProvider));
});

class AstrologyContactsState {
  const AstrologyContactsState({
    this.loading = false,
    this.contacts = const [],
    this.error,
  });

  final bool loading;
  final List<AstrologyContact> contacts;
  final String? error;

  AstrologyContactsState copyWith({
    bool? loading,
    List<AstrologyContact>? contacts,
    String? error,
    bool clearError = false,
  }) {
    return AstrologyContactsState(
      loading: loading ?? this.loading,
      contacts: contacts ?? this.contacts,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AstrologyContactsController extends Notifier<AstrologyContactsState> {
  @override
  AstrologyContactsState build() => const AstrologyContactsState();

  Future<void> load(AstrologyContactKind kind) async {
    state = const AstrologyContactsState(loading: true);
    try {
      final items =
          await ref.read(astrologyContactsRepositoryProvider).list(kind: kind);
      state = AstrologyContactsState(contacts: items);
    } catch (_) {
      state = const AstrologyContactsState(
        error: 'Could not load contacts right now.',
      );
    }
  }
}

final astrologyContactsControllerProvider =
    NotifierProvider<AstrologyContactsController, AstrologyContactsState>(
  AstrologyContactsController.new,
);
