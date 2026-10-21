import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/ui/kiosk_shell.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/astrology_birth_form.dart';

void main() {
  testWidgets('kundali form has Material and fits 1280x720 with an error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final name = TextEditingController();
    final place = TextEditingController();
    addTearDown(name.dispose);
    addTearDown(place.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: KioskShell(
          title: 'My Kundali',
          cosmic: true,
          stepLabel: 'Details',
          footerTrailing: const SizedBox(width: 180, height: 56),
          body: AstrologyBirthFormPanel(
            nameController: name,
            placeController: place,
            dob: DateTime(1995),
            birthTime: const TimeOfDay(hour: 12, minute: 0),
            timeUnknown: false,
            gender: 'female',
            focus: 0,
            error: 'Name and birth place are required',
            onFocus: (_) {},
            onDob: (_) {},
            onTime: (_) {},
            onTimeUnknown: (_) {},
            onGender: (_) {},
            onKey: (_) {},
            onBackspace: () {},
            footer: AstrologyStyleSegment(style: 'north', onStyle: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Name and birth place are required'), findsOneWidget);
    expect(find.byType(Material), findsWidgets);
  });
}
