import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/ui/kiosk_shell.dart';
import 'package:skp_kiosk/features/astrology/application/today_periods_controller.dart';
import 'package:skp_kiosk/features/astrology/domain/today_periods_phase.dart';
import 'package:skp_kiosk/features/astrology/domain/today_periods_result.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_hub_page.dart';
import 'package:skp_kiosk/features/astrology/presentation/today_periods_page.dart';

TodayPeriodsResult _result() {
  return TodayPeriodsResult(
    disclaimer: 'For entertainment only.',
    name: 'Asha',
    asOf: DateTime.utc(2026, 10, 21, 10, 21),
    panchang: const TodayPanchang(
      weekday: 'Wednesday',
      tithi: 'Ekadasi (Sukla)',
      nakshatra: 'Dhanishta - 4',
      yoga: 'Ganda',
      karana: 'Vanija',
      lunarMonth: 'Aaswayuja',
      sunrise: '06:33',
      sunset: '17:49',
      horaLord: 'Saturn',
      dishaShool: 'North',
    ),
    dasha: const TodayDasha(
      label: 'Rahu – Saturn',
      levels: ['Rahu', 'Saturn'],
    ),
  );
}

void main() {
  testWidgets('today result fits panchang and dasha at 1280x720', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: KioskShell(
          title: 'Today & Periods',
          cosmic: true,
          stepLabel: 'Today',
          body: TodayPeriodsResultView(result: _result()),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Today’s panchang'), findsOneWidget);
    expect(find.text('Rahu – Saturn'), findsOneWidget);
    expect(find.text('Ekadasi (Sukla)'), findsOneWidget);
    expect(find.byKey(const ValueKey('today-panchang-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('today-dasha-card')), findsOneWidget);
    expect(tester.getSize(find.byType(KioskShell)), const Size(1280, 720));
  });

  testWidgets('hub Today & Periods tile opens the birth form', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: AstrologyHubPage(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Today & Periods'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Birth details'), findsOneWidget);
    expect(find.text("Get today's reading"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalidating today state restores the form phase', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TodayPeriodsPage())),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TodayPeriodsPage)),
    );
    container.read(todayPeriodsControllerProvider.notifier);
    // Force a non-form phase via private state path: submit with empty fields
    // keeps form; invalidate after manually setting is covered by source test.
    // Here we only verify invalidate restores defaults after a failed submit.
    await container
        .read(todayPeriodsControllerProvider.notifier)
        .submit(
          name: '',
          gender: 'female',
          dateOfBirth: '1992-03-18',
          birthTime: '12:00',
          birthPlace: '',
          birthTimeUnknown: false,
        );
    expect(
      container.read(todayPeriodsControllerProvider).phase,
      TodayPeriodsPhase.form,
    );
    expect(
      container.read(todayPeriodsControllerProvider).error,
      'Name and birth place are required',
    );

    container.invalidate(todayPeriodsControllerProvider);
    await tester.pump();
    expect(
      container.read(todayPeriodsControllerProvider).phase,
      TodayPeriodsPhase.form,
    );
    expect(container.read(todayPeriodsControllerProvider).error, isNull);
  });
}
