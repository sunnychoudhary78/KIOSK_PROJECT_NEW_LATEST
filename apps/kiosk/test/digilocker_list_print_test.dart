import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/features/digilocker_print/application/digilocker_controller.dart';
import 'package:skp_kiosk/features/digilocker_print/data/digilocker_print_repository.dart';

void main() {
  test('DigiLocker listPrintLabel and printed tracking', () {
    const docs = [
      DigilockerDocument(id: 'a', name: 'Aadhaar', issuer: 'UIDAI'),
      DigilockerDocument(id: 'b', name: 'PAN', issuer: 'ITD'),
    ];
    var state = DigilockerUiState(
      phase: DigilockerPhase.ready,
      documents: docs,
    );
    expect(state.listPrintLabel, 'Print all');
    expect(state.hasUnprintedDocuments, isTrue);
    expect(state.isDocPrinted('a'), isFalse);

    state = state.copyWith(printedDocumentIds: {'a'});
    expect(state.listPrintLabel, 'Print');
    expect(state.unprintedCount, 1);
    expect(state.isDocPrinted('a'), isTrue);

    state = state.copyWith(printedDocumentIds: {'a', 'b'});
    expect(state.hasUnprintedDocuments, isFalse);
    expect(state.listPrintLabel, 'Print');
  });
}
