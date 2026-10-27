import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/ui/kiosk_print_result.dart';

void main() {
  testWidgets('verified print tells the visitor to collect the pages', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KioskPrintResult(confirmed: true, onHome: () {}),
        ),
      ),
    );

    expect(find.text('Print successful'), findsOneWidget);
    expect(find.text('Collect your pages from the printer'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Print not confirmed'), findsNothing);
  });

  testWidgets('unconfirmed print shows the staff review message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KioskPrintResult(
            confirmed: false,
            detail: 'Print could not be confirmed within 3 minutes. Staff will review.',
            onHome: () {},
          ),
        ),
      ),
    );

    expect(find.text('Print not confirmed'), findsOneWidget);
    expect(
      find.text('Print could not be confirmed within 3 minutes. Staff will review.'),
      findsOneWidget,
    );
    expect(find.text('Print successful'), findsNothing);
    expect(find.text('Collect your pages from the printer'), findsNothing);
  });

  testWidgets('Home returns once and cancels the automatic return', (tester) async {
    var homes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KioskPrintResult(
            confirmed: true,
            onHome: () => homes += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));

    expect(homes, 1);
  });
}
