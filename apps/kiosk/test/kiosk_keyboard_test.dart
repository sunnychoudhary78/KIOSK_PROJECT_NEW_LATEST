import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/ui/kiosk_keyboard.dart';

void main() {
  testWidgets('symbol layout keeps a single ABC key', (tester) async {
    tester.view.physicalSize = const Size(1100, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 280,
            child: KioskKeyboard(onKey: (_) {}, onBackspace: () {}),
          ),
        ),
      ),
    );

    expect(find.text('Shift'), findsOneWidget);
    expect(find.text('?123'), findsOneWidget);
    expect(find.text('ABC'), findsNothing);

    await tester.tap(find.text('?123'));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('ABC'), findsOneWidget);
    expect(find.text('Shift'), findsNothing);
    expect(find.text('?123'), findsNothing);

    await tester.tap(find.text('ABC'));
    await tester.pump();

    expect(find.text('Shift'), findsOneWidget);
    expect(find.text('?123'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
  });
}
