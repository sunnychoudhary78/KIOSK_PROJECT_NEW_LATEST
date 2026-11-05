import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/features/emergency/data/emergency_contacts_repository.dart';
import 'package:skp_kiosk/features/emergency/domain/emergency_contact.dart';

final emergencyContactsRepositoryProvider =
    Provider<EmergencyContactsRepository>((ref) {
  return EmergencyContactsRepository(ref.watch(apiClientProvider));
});

class EmergencyContactsState {
  const EmergencyContactsState({
    this.loading = false,
    this.contacts = kEmergencyContacts,
    this.fromApi = false,
  });

  final bool loading;
  final List<EmergencyContact> contacts;
  final bool fromApi;

  EmergencyContactsState copyWith({
    bool? loading,
    List<EmergencyContact>? contacts,
    bool? fromApi,
  }) {
    return EmergencyContactsState(
      loading: loading ?? this.loading,
      contacts: contacts ?? this.contacts,
      fromApi: fromApi ?? this.fromApi,
    );
  }
}

class EmergencyContactsController extends Notifier<EmergencyContactsState> {
  @override
  EmergencyContactsState build() => const EmergencyContactsState();

  Future<void> load() async {
    state = state.copyWith(loading: true);
    try {
      final items = await ref.read(emergencyContactsRepositoryProvider).list();
      if (items.isEmpty) {
        state = state.copyWith(
          loading: false,
          contacts: kEmergencyContacts,
          fromApi: false,
        );
        return;
      }
      state = state.copyWith(
        loading: false,
        contacts: items,
        fromApi: true,
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        contacts: kEmergencyContacts,
        fromApi: false,
      );
    }
  }
}

final emergencyContactsControllerProvider =
    NotifierProvider.autoDispose<EmergencyContactsController, EmergencyContactsState>(
  EmergencyContactsController.new,
);
