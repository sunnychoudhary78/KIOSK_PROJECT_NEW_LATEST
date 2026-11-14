import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/features/otp_print/application/otp_print_controller.dart';
import 'package:skp_kiosk/features/otp_print/domain/otp_redeem_result.dart';
import 'package:skp_kiosk/features/otp_print/presentation/otp_print_page.dart';

void main() {
  test('withDocumentPrinted tracks remaining unprinted docs', () {
    const start = OtpRedeemResult(
      challengeId: 'c1',
      title: 'Bundle',
      documents: [
        OtpDocumentRef(
          id: 'a',
          fileName: 'a.pdf',
          pageCount: 1,
          contentPath: '/a',
        ),
        OtpDocumentRef(
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
    expect(afterA.documents[0].printJobId, 'j1');
    expect(afterA.hasUnprinted, isTrue);
    final afterBoth = afterA.withDocumentPrinted('b', printJobId: 'j2');
    expect(afterBoth.hasUnprinted, isFalse);
  });

  testWidgets('document list shows Cancel, Printed badges, and New OTP', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          navigatorKey: kioskNavigatorKey,
          home: const OtpPrintPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(OtpPrintPage));
    final container = ProviderScope.containerOf(element);
    container.read(otpPrintControllerProvider.notifier).debugLoadRedeemResult(
          const OtpRedeemResult(
            challengeId: 'c1',
            title: 'Bundle',
            documents: [
              OtpDocumentRef(
                id: 'a',
                fileName: 'a.pdf',
                pageCount: 1,
                contentPath: '/a',
                printed: true,
                printJobId: 'j1',
              ),
              OtpDocumentRef(
                id: 'b',
                fileName: 'b.pdf',
                pageCount: 2,
                contentPath: '/b',
              ),
            ],
          ),
        );
    await tester.pump();

    final state = container.read(otpPrintControllerProvider);
    expect(state.hasUnprintedDocuments, isTrue);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('New OTP'), findsOneWidget);
    expect(find.text('Print'), findsOneWidget);
    expect(find.text('Finish'), findsNothing);
    expect(find.text('Printed'), findsWidgets);
    expect(find.text('Preview'), findsOneWidget);
  });
}
