import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/ui/kiosk_shell.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_reading.dart';
import 'package:skp_kiosk/features/astrology/domain/kundali_result.dart';
import 'package:skp_kiosk/features/astrology/presentation/my_kundali_page.dart';

const _svgStart =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">';

KundaliResult _result() {
  return const KundaliResult(
    disclaimer: 'For entertainment only.',
    name: 'Asha',
    style: 'north',
    chartType: 'RasiD1',
    svg: '$_svgStart<text>D1</text></svg>',
    chart: AstrologyChartSummary(
      lagna: 'Pisces',
      sunSign: 'Aries',
      moonSign: 'Taurus',
      currentDasha: 'Rahu – Saturn',
    ),
    charts: {
      'RasiD1': KundaliChartEntry(
        svg: '$_svgStart<text>D1</text></svg>',
        title: 'Birth',
        subtitle: 'Rasi',
      ),
      'NavamshaD9': KundaliChartEntry(
        svg: '$_svgStart<text>D9</text></svg>',
        title: 'Marriage',
        subtitle: 'Navamsha',
      ),
      'DashamamshaD10': KundaliChartEntry(
        svg: '$_svgStart<text>D10</text></svg>',
        title: 'Career',
        subtitle: 'Dashamsha',
      ),
    },
  );
}

void main() {
  testWidgets('Marriage and Career tabs replace the displayed SVG', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: KioskShell(
          title: 'My Kundali',
          cosmic: true,
          stepLabel: 'Result',
          body: KundaliResultView(result: _result()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
    expect(find.text("Asha's kundali"), findsNothing);
    expect(find.byKey(const ValueKey('kundali-chart-RasiD1')), findsOneWidget);
    expect(find.text('Rasi'), findsOneWidget);
    final stageSize = tester.getSize(
      find.byKey(const ValueKey('kundali-chart-stage')),
    );
    expect(stageSize.height, greaterThanOrEqualTo(500));
    expect(stageSize.width, greaterThan(stageSize.height));
    final stageRect = tester.getRect(
      find.byKey(const ValueKey('kundali-chart-stage')),
    );
    final controlsRect = tester.getRect(
      find.byKey(const ValueKey('kundali-chart-controls')),
    );
    expect(controlsRect.left, greaterThan(stageRect.right));

    await tester.tap(find.text('Marriage'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.byKey(const ValueKey('kundali-chart-NavamshaD9')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('kundali-chart-RasiD1')), findsNothing);
    expect(find.text('Navamsha'), findsOneWidget);

    await tester.tap(find.text('Career'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.byKey(const ValueKey('kundali-chart-DashamamshaD10')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('kundali-chart-NavamshaD9')),
      findsNothing,
    );
    expect(find.text('Dashamsha'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
