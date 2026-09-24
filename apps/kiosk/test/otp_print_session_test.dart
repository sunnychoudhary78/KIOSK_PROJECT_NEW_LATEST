import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/features/otp_print/application/otp_print_controller.dart';
import 'package:skp_kiosk/features/otp_print/domain/otp_redeem_result.dart';
import 'package:skp_kiosk/features/otp_print/presentation/otp_print_page.dart';

void main() {
  testWidgets('OTP back does not leak documents to the next visitor', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
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
            printJobId: 'j1',
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
    await tester.pumpAndSettle();

    expect(find.byType(OtpPrintPage), findsNothing);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('secret.pdf'), findsNothing);
    expect(find.text('Enter the OTP sent by SMS'), findsOneWidget);
  });
}
