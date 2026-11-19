import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/ui/kiosk_print_result.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('single-doc success shows Done and auto-homes', (tester) async {
    var home = 0;
    await tester.pumpWidget(
      _wrap(
        KioskPrintResult(
          confirmed: true,
          autoReturn: const Duration(milliseconds: 50),
          onHome: () => home++,
        ),
      ),
    );

    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Print another'), findsNothing);

    await tester.pump(const Duration(milliseconds: 60));
    expect(home, 1);
  });

  testWidgets('multi-doc success offers Print another and skips auto-home', (tester) async {
    var home = 0;
    var cont = 0;
    await tester.pumpWidget(
      _wrap(
        KioskPrintResult(
          confirmed: true,
          autoReturn: const Duration(milliseconds: 50),
          onHome: () => home++,
          onContinue: () => cont++,
        ),
      ),
    );

    expect(find.text('Print another'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 60));
    expect(home, 0);

    await tester.tap(find.text('Print another'));
    await tester.pump();
    expect(cont, 1);
    expect(home, 0);
  });

  testWidgets('confirmed print with rating key prompts before home', (tester) async {
    var home = 0;
    await tester.pumpWidget(
      _wrap(
        KioskPrintResult(
          confirmed: true,
          autoReturn: null,
          ratingServiceKey: 'print.otp_print',
          onHome: () => home++,
        ),
      ),
    );

    await tester.tap(find.text('Done'));
    await tester.pump();

    expect(find.text('How was your experience?'), findsOneWidget);
    expect(home, 0);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(home, 1);
  });

  testWidgets('failed print does not prompt for rating', (tester) async {
    var home = 0;
    await tester.pumpWidget(
      _wrap(
        KioskPrintResult(
          confirmed: false,
          autoReturn: null,
          ratingServiceKey: 'print.otp_print',
          onHome: () => home++,
        ),
      ),
    );

    await tester.tap(find.text('Done'));
    await tester.pump();

    expect(find.text('How was your experience?'), findsNothing);
    expect(home, 1);
  });

  testWidgets('rating auto-timeout still calls onHome', (tester) async {
    var home = 0;
    await tester.pumpWidget(
      _wrap(
        KioskPrintResult(
          confirmed: true,
          autoReturn: null,
          ratingServiceKey: 'print.otp_print',
          onHome: () => home++,
        ),
      ),
    );

    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(find.text('How was your experience?'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    expect(home, 1);
  });

  testWidgets('tapping a star alone does not leave; Submit does', (tester) async {
    var home = 0;
    await tester.pumpWidget(
      _wrap(
        KioskPrintResult(
          confirmed: true,
          autoReturn: null,
          ratingServiceKey: 'print.otp_print',
          onHome: () => home++,
        ),
      ),
    );

    await tester.tap(find.text('Done'));
    await tester.pump();

    // Fifth star (high rating — no keyboard).
    await tester.tap(find.byType(IconButton).at(4));
    await tester.pump();
    expect(home, 0);
    expect(find.text('How was your experience?'), findsOneWidget);

    await tester.tap(find.text('Submit'));
    await tester.pump();
    expect(home, 1);
  });
}
