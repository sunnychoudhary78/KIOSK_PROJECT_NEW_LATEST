import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/features/otp_print/application/otp_print_controller.dart';
import 'package:skp_kiosk/features/otp_print/domain/otp_redeem_result.dart';
import 'package:skp_kiosk/features/otp_print/presentation/otp_print_page.dart';
import 'package:skp_kiosk/features/quick_print/application/quick_print_controller.dart';
import 'package:skp_kiosk/features/quick_print/domain/quick_print_session.dart';

void main() {
  test('OTP listPrintLabel is Print vs Print all from unprinted count', () {
    const one = OtpPrintUiState(
      phase: OtpPrintPhase.documents,
      redeemResult: OtpRedeemResult(
        challengeId: 'c1',
        title: 'Bundle',
        documents: [
          OtpDocumentRef(
            id: 'a',
            fileName: 'a.pdf',
            pageCount: 1,
            contentPath: '/a',
          ),
        ],
      ),
    );
    expect(one.listPrintLabel, 'Print');
    expect(one.unprintedCount, 1);

    const two = OtpPrintUiState(
      phase: OtpPrintPhase.documents,
      redeemResult: OtpRedeemResult(
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
            pageCount: 1,
            contentPath: '/b',
          ),
        ],
      ),
    );
    expect(two.listPrintLabel, 'Print all');
    expect(two.unprintedCount, 2);

    final afterOne = two.copyWith(
      redeemResult: two.redeemResult!.withDocumentPrinted('a', printJobId: 'j1'),
    );
    expect(afterOne.listPrintLabel, 'Print');
    expect(afterOne.unprintedCount, 1);
  });

  test('QuickPrint listPrintLabel follows unprinted count', () {
    const claim = QuickPrintClaim(
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
          pageCount: 1,
          contentPath: '/b',
        ),
      ],
    );
    const state = QuickPrintUiState(
      phase: QuickPrintPhase.documents,
      claim: claim,
    );
    expect(state.listPrintLabel, 'Print all');
    expect(
      state.copyWith(claim: claim.withDocumentPrinted('a')).listPrintLabel,
      'Print',
    );
  });

  testWidgets('OTP document list shows Cancel left and Print all', (tester) async {
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

    expect(find.text('New OTP'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Print all'), findsOneWidget);
    expect(find.text('Finish'), findsNothing);
    expect(find.text('Preview'), findsNWidgets(2));
  });
}
