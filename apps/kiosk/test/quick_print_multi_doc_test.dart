import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/features/quick_print/domain/quick_print_session.dart';

void main() {
  test('QuickPrintClaim withDocumentPrinted tracks remaining docs', () {
    const start = QuickPrintClaim(
      sessionId: 's1',
      title: 'Bundle',
      documents: [
        QuickPrintDocumentRef(
          id: 'a',
          fileName: 'a.pdf',
          pageCount: 1,
          contentPath: '/a',
        ),
        QuickPrintDocumentRef(
          id: 'b',
          fileName: 'b.pdf',
          pageCount: 2,
          contentPath: '/b',
        ),
      ],
    );

    expect(start.hasUnprinted, isTrue);
    final afterA = start.withDocumentPrinted('a', printJobId: 'j1');
    expect(afterA.documents[0].printed, isTrue);
    expect(afterA.hasUnprinted, isTrue);
    expect(afterA.withDocumentPrinted('b').hasUnprinted, isFalse);
  });
}
