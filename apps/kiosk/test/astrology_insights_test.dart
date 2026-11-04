import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/ui/kiosk_shell.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_insights.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_reading.dart';
import 'package:skp_kiosk/features/astrology/domain/kundali_result.dart';
import 'package:skp_kiosk/features/astrology/domain/match_kundali_result.dart';
import 'package:skp_kiosk/features/astrology/domain/today_periods_result.dart';
import 'package:skp_kiosk/features/astrology/presentation/match_kundali_page.dart';
import 'package:skp_kiosk/features/astrology/presentation/my_kundali_page.dart';
import 'package:skp_kiosk/features/astrology/presentation/today_periods_page.dart';

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><text>D1</text></svg>';

void main() {
  test('LocaleBullets and KundaliInsights parse bilingual JSON', () {
    final bullets = LocaleBullets.fromJson({
      'en': ['One', 'Two', 'Three'],
      'hi': ['एक', 'दो', 'तीन'],
    });
    expect(bullets.forLocale(AstrologyInsightLocale.en), ['One', 'Two', 'Three']);
    expect(bullets.forLocale(AstrologyInsightLocale.hi), ['एक', 'दो', 'तीन']);

    final kundali = KundaliResult.fromJson({
      'disclaimer': 'Entertainment only',
      'subject': {'name': 'Asha'},
      'style': 'north',
      'chartType': 'RasiD1',
      'svg': _svg,
      'chart': {'lagna': 'Pisces'},
      'charts': {
        'RasiD1': {'svg': _svg, 'title': 'Birth', 'subtitle': 'Rasi'},
      },
      'insights': {
        'RasiD1': {
          'en': ['Birth EN 1', 'Birth EN 2', 'Birth EN 3'],
          'hi': ['जन्म 1', 'जन्म 2', 'जन्म 3'],
        },
      },
    });
    expect(kundali.insights.rasiD1?.en.first, 'Birth EN 1');
    expect(
      kundali.insights.forChart('RasiD1')?.forLocale(AstrologyInsightLocale.hi).first,
      'जन्म 1',
    );

    final match = MatchKundaliResult.fromJson({
      'disclaimer': 'Entertainment only',
      'groom': {'name': 'Arjun'},
      'bride': {'name': 'Asha'},
      'score': {
        'total': 25,
        'max': 36,
        'summary': 'Strong',
        'tone': 'good',
      },
      'kutas': const [],
      'insights': {
        'en': ['Match EN 1', 'Match EN 2', 'Match EN 3'],
        'hi': ['मैच 1', 'मैच 2', 'मैच 3'],
      },
    });
    expect(match.insights.hi[1], 'मैच 2');

    final today = TodayPeriodsResult.fromJson({
      'disclaimer': 'Entertainment only',
      'subject': {'name': 'Asha'},
      'asOf': '2026-11-03T10:00:00.000Z',
      'panchang': {'weekday': 'Tuesday'},
      'dasha': {'label': 'Rahu – Saturn', 'levels': ['Rahu', 'Saturn']},
      'insights': {
        'en': ['Today EN 1', 'Today EN 2', 'Today EN 3'],
        'hi': ['आज 1', 'आज 2', 'आज 3'],
      },
    });
    expect(today.insights.en.length, 3);
  });

  testWidgets('kundali locale switch shows Hindi bullets', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final result = KundaliResult(
      disclaimer: 'For entertainment only.',
      name: 'Asha',
      style: 'north',
      chartType: 'RasiD1',
      svg: _svg,
      chart: const AstrologyChartSummary(lagna: 'Pisces'),
      charts: const {
        'RasiD1': KundaliChartEntry(
          svg: _svg,
          title: 'Birth',
          subtitle: 'Rasi',
        ),
      },
      insights: const KundaliInsights(
        rasiD1: LocaleBullets(
          en: ['Steady growth', 'Clear habits', 'Finish started work'],
          hi: ['स्थिर विकास', 'स्पष्ट आदतें', 'अधूरा काम पूरा करें'],
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: KioskShell(
            title: 'My Kundali',
            stepLabel: 'Result',
            body: KundaliResultView(result: result),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Steady growth'), findsOneWidget);
    expect(find.text('स्थिर विकास'), findsNothing);
    expect(find.text('Lagna'), findsOneWidget);
    expect(find.text('Pisces'), findsOneWidget);
    expect(find.text('AI insights'), findsOneWidget);

    await tester.tap(find.text('हिं'));
    await tester.pump();

    expect(find.text('स्थिर विकास'), findsOneWidget);
    expect(find.text('Steady growth'), findsNothing);
    expect(find.text('लग्न'), findsOneWidget);
    expect(find.text('मीन'), findsOneWidget);
    expect(find.text('एआई अंतर्दृष्टि'), findsOneWidget);
  });

  testWidgets('match locale switch shows Hindi bullets', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final result = MatchKundaliResult(
      disclaimer: 'For entertainment only.',
      groomName: 'Arjun',
      brideName: 'Asha',
      score: const MatchScore(
        total: 25,
        max: 36,
        summary: 'Strong compatibility',
        tone: 'good',
      ),
      kutas: const [],
      insights: const LocaleBullets(
        en: ['Good match overall', 'Talk openly', 'Share routines'],
        hi: ['कुल मिलाकर अच्छा मेल', 'खुलकर बात करें', 'दिनचर्या साझा करें'],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: KioskShell(
            title: 'Match',
            stepLabel: 'Result',
            body: MatchKundaliResultView(result: result),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Good match overall'), findsOneWidget);
    await tester.tap(find.text('हिं'));
    await tester.pump();
    expect(find.text('कुल मिलाकर अच्छा मेल'), findsOneWidget);
  });

  testWidgets('today locale switch shows Hindi bullets', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final result = TodayPeriodsResult(
      disclaimer: 'For entertainment only.',
      name: 'Asha',
      asOf: DateTime.utc(2026, 11, 3, 10),
      panchang: const TodayPanchang(weekday: 'Tuesday', tithi: 'Ekadasi'),
      dasha: const TodayDasha(label: 'Rahu – Saturn', levels: ['Rahu', 'Saturn']),
      insights: const LocaleBullets(
        en: ['Favor calm work', 'Rest well tonight', 'Keep promises small'],
        hi: ['शांत काम अनुकूल', 'आज अच्छी नींद लें', 'छोटे वादे निभाएं'],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: KioskShell(
            title: 'Today',
            stepLabel: 'Result',
            body: TodayPeriodsResultView(result: result),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Favor calm work'), findsOneWidget);
    await tester.tap(find.text('हिं'));
    await tester.pump();
    expect(find.text('शांत काम अनुकूल'), findsOneWidget);
  });
}
