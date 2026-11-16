import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/ui/kiosk_print_result.dart';

void main() {
  testWidgets('single-doc success shows Done and auto-homes', (tester) async {
    var home = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KioskPrintResult(
            confirmed: true,
            autoReturn: const Duration(milliseconds: 50),
            onHome: () => home++,
          ),
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
      MaterialApp(
        home: Scaffold(
          body: KioskPrintResult(
            confirmed: true,
            autoReturn: const Duration(milliseconds: 50),
            onHome: () => home++,
            onContinue: () => cont++,
          ),
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
}
