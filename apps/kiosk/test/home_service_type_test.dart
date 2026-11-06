import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/ui/kiosk_service_tile.dart';

void main() {
  testWidgets('home service cards fit a kiosk window with larger type', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const titles = [
      ('Print Documents', 'Phone, OTP, or DigiLocker'),
      ('Find Services', 'Mechanics, tailors, carpenters, and more'),
      ('Well Being', 'Heart rate, blood oxygen, and temperature'),
      ('Phone Charging', 'Watch a short message, then charge your phone'),
      ('Astrology', 'Kundali · Palm · Match · Today'),
      ('Fuel Stations', 'Petrol, diesel, CNG, and EV stations nearby'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 12),
            child: SizedBox(
              height: 420,
              child: Column(
              children: [
                for (var row = 0; row < 3; row++) ...[
                  if (row > 0) const SizedBox(height: 14),
                  Expanded(
                    child: Row(
                      children: [
                        for (var col = 0; col < 2; col++) ...[
                          if (col > 0) const SizedBox(width: 14),
                          Expanded(
                            child: KioskServiceTile(
                              icon: Icons.circle,
                              title: titles[row * 2 + col].$1,
                              subtitle: titles[row * 2 + col].$2,
                              onTap: () {},
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Find Services'), findsOneWidget);
    expect(find.text('Mechanics, tailors, carpenters, and more'), findsOneWidget);
  });
}
