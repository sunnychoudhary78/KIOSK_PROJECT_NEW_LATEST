import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/ui/kiosk_keyboard.dart';
import 'package:skp_kiosk/core/ui/kiosk_shell.dart';
import 'package:skp_kiosk/features/astrology/application/match_kundali_controller.dart';
import 'package:skp_kiosk/features/astrology/domain/match_kundali_phase.dart';
import 'package:skp_kiosk/features/astrology/domain/match_kundali_result.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_hub_page.dart';
import 'package:skp_kiosk/features/astrology/presentation/match_kundali_page.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/astrology_birth_form.dart';

MatchKundaliResult _result() {
  const names = [
    ('varna', 'Varna', 1),
    ('vasya', 'Vasya', 2),
    ('dina', 'Dina (Tara)', 3),
    ('yoni', 'Yoni', 4),
    ('graha-maitri', 'Graha Maitri', 5),
    ('gana', 'Gana', 6),
    ('rasi', 'Rasi (Bhakoot)', 7),
    ('nadi', 'Nadi', 8),
  ];
  return MatchKundaliResult(
    disclaimer: 'For entertainment only.',
    groomName: 'Arjun',
    brideName: 'Asha',
    score: const MatchScore(
      total: 25,
      max: 36,
      summary: 'Strong compatibility',
      tone: 'good',
    ),
    kutas: [
      for (final entry in names)
        MatchKuta(
          key: entry.$1,
          name: entry.$2,
          maxPoints: entry.$3.toDouble(),
          nature: 'Good',
          verdict: 'Supportive compatibility indicator.',
        ),
    ],
  );
}

void main() {
  testWidgets('match result fits score and eight kutas at 1280x720', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: KioskShell(
          title: 'Match Kundalis',
          cosmic: true,
          stepLabel: 'Gun Milan',
          body: MatchKundaliResultView(result: _result()),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('25 / 36'), findsOneWidget);
    expect(find.byKey(const ValueKey('match-score-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('match-kuta-grid')), findsOneWidget);
    for (final kuta in _result().kutas) {
      expect(find.text(kuta.name), findsOneWidget);
    }
    expect(
      tester.getSize(find.byType(KioskShell)),
      const Size(1280, 720),
    );
  });

  testWidgets('padded kutas keep the result grid from overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: KioskShell(
          title: 'Match Kundalis',
          cosmic: true,
          stepLabel: 'Gun Milan',
          body: MatchKundaliResultView(
            result: MatchKundaliResult(
              disclaimer: 'For entertainment only.',
              groomName: 'Arjun',
              brideName: 'Asha',
              score: const MatchScore(
                total: 18,
                max: 36,
                summary: 'Moderate compatibility',
                tone: 'mixed',
              ),
              kutas: const [],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('18 / 36'), findsOneWidget);
    for (final spec in matchKutaSpecs) {
      expect(find.text(spec.$2), findsOneWidget);
    }
  });

  testWidgets('bride form fits the groom summary without scrolling', (
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
      ProviderScope(
        child: MaterialApp(
          home: KioskShell(
            title: 'Match Kundalis',
            cosmic: true,
            stepLabel: 'Bride',
            body: AstrologyBirthFormPanel(
              nameController: name,
              placeController: place,
              dob: DateTime(1995),
              birthTime: const TimeOfDay(hour: 12, minute: 0),
              timeUnknown: false,
              gender: 'female',
              showGender: false,
              focus: 0,
              onFocus: (_) {},
              onDob: (_) {},
              onTime: (_) {},
              onTimeUnknown: (_) {},
              onGender: (_) {},
              onKey: (_) {},
              onBackspace: () {},
              leading: const GroomSummaryCard(
                name: 'Arjun',
                dateOfBirth: '1990-01-15',
                birthPlace: 'Jaipur',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Arjun'), findsOneWidget);
    expect(find.text('Gender'), findsNothing);
    expect(
      tester.getSize(find.byType(KioskShell)),
      const Size(1280, 720),
    );
  });

  testWidgets('hub Match Kundalis tile opens the groom form', (tester) async {
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

    await tester.tap(find.text('Match Kundalis'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Groom details'), findsOneWidget);
    expect(find.text('Gender'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('groom step validates then preserves details on the bride form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MatchKundaliPage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Name and birth place are required'), findsOneWidget);
    expect(find.text('Groom details'), findsOneWidget);

    Future<void> tapKey(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(KioskKeyboard),
          matching: find.text(label),
        ),
      );
      await tester.pump();
    }

    await tapKey('A');
    for (final letter in ['r', 'j', 'u', 'n']) {
      await tapKey(letter);
    }
    await tester.tap(find.text('Place of birth'));
    await tester.pump();
    await tapKey('Shift');
    await tapKey('J');
    for (final letter in ['a', 'i', 'p', 'u', 'r']) {
      await tapKey(letter);
    }

    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Bride details'), findsOneWidget);
    expect(find.text('Arjun'), findsOneWidget);
    expect(find.text('Jaipur'), findsOneWidget);
    expect(find.text('Gender'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Groom details'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Groom details'), findsOneWidget);
    expect(find.text('Arjun'), findsOneWidget);
  });

  testWidgets('invalidating match state restores the groom phase', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MatchKundaliPage()),
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MatchKundaliPage)),
    );
    container.read(matchKundaliControllerProvider.notifier).showBride();
    expect(
      container.read(matchKundaliControllerProvider).phase,
      MatchKundaliPhase.bride,
    );

    container.invalidate(matchKundaliControllerProvider);
    await tester.pump();
    expect(
      container.read(matchKundaliControllerProvider).phase,
      MatchKundaliPhase.groom,
    );
  });
}
