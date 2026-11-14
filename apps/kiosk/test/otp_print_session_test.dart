import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/features/otp_print/application/otp_print_controller.dart';
import 'package:skp_kiosk/features/otp_print/domain/otp_redeem_result.dart';
import 'package:skp_kiosk/features/otp_print/presentation/otp_print_page.dart';
import 'package:skp_kiosk/features/session/application/visitor_session_reset.dart';

void main() {
  testWidgets('OTP back does not leak documents to the next visitor', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Avoid real spooler clear hanging the session reset in widget tests.
          visitorSessionResetProvider.overrideWith((ref) {
            return ({required bool attract}) async {
              if (ref.exists(otpPrintControllerProvider)) {
                ref.read(otpPrintControllerProvider.notifier).reset();
              }
              kioskNavigatorKey.currentState?.popUntil((route) => route.isFirst);
              ref.invalidate(otpPrintControllerProvider);
            };
          }),
        ],
        child: MaterialApp(
          navigatorKey: kioskNavigatorKey,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const OtpPrintPage(),
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(OtpPrintPage));
    final container = ProviderScope.containerOf(element);
    container.read(otpPrintControllerProvider.notifier).debugLoadRedeemResult(
          const OtpRedeemResult(
            challengeId: 'c1',
            title: 'Prior visitor',
            printColorMode: 'bw',
            documents: [
              OtpDocumentRef(
                id: 'd1',
                fileName: 'secret.pdf',
                pageCount: 1,
                contentPath: '/x',
              ),
            ],
          ),
        );
    await tester.pump();
    expect(find.text('secret.pdf'), findsOneWidget);

    await tester.tap(find.text('Home'));
    // Session reset awaits spooler clear + frame; allow async work to finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.byType(OtpPrintPage), findsNothing);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(OtpPrintPage), findsOneWidget);
    expect(find.text('secret.pdf'), findsNothing);
    // Fresh visit starts on OTP entry (not the prior visitor's document list).
    expect(find.text('Preview'), findsNothing);
    expect(find.text('Back'), findsOneWidget);
  });
}
