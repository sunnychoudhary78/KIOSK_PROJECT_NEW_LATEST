import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_controller.dart';
import 'package:skp_kiosk/features/astrology/application/today_periods_controller.dart';
import 'package:skp_kiosk/features/astrology/data/astrology_repository.dart';
import 'package:skp_kiosk/features/astrology/domain/today_periods_phase.dart';
import 'package:skp_kiosk/features/astrology/domain/today_periods_result.dart';

class _FakeAstrologyRepository extends AstrologyRepository {
  _FakeAstrologyRepository() : super(ApiClient());

  @override
  Future<TodayPeriodsResult> createToday(TodaySubmitInput input) async {
    return TodayPeriodsResult(
      disclaimer: 'For entertainment only.',
      name: input.name,
      asOf: DateTime.utc(2026, 10, 21, 10, 21),
      panchang: const TodayPanchang(
        weekday: 'Wednesday',
        tithi: 'Ekadasi (Sukla)',
        nakshatra: 'Dhanishta - 4',
      ),
      dasha: const TodayDasha(
        label: 'Rahu – Saturn',
        levels: ['Rahu', 'Saturn'],
      ),
      accuracyNote: input.birthTimeUnknown
          ? 'An unknown birth time was set to 12:00; current dasha may be less precise.'
          : null,
    );
  }
}

void main() {
  test('today controller moves through loading and result', () async {
    final container = ProviderContainer(
      overrides: [
        astrologyRepositoryProvider.overrideWithValue(
          _FakeAstrologyRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(todayPeriodsControllerProvider, (_, _) {});
    final controller = container.read(todayPeriodsControllerProvider.notifier);

    expect(
      container.read(todayPeriodsControllerProvider).phase,
      TodayPeriodsPhase.form,
    );

    await controller.submit(
      name: 'Asha',
      gender: 'female',
      dateOfBirth: '1992-03-18',
      birthTime: '12:00',
      birthPlace: 'Jaipur',
      birthTimeUnknown: true,
    );

    final state = container.read(todayPeriodsControllerProvider);
    expect(state.phase, TodayPeriodsPhase.result);
    expect(state.result?.dasha.label, 'Rahu – Saturn');
    expect(state.result?.panchang.tithi, 'Ekadasi (Sukla)');
    expect(state.result?.accuracyNote, contains('12:00'));

    controller.reset();
    expect(
      container.read(todayPeriodsControllerProvider).phase,
      TodayPeriodsPhase.form,
    );
  });

  test('today result JSON maps panchang and dasha', () {
    final result = TodayPeriodsResult.fromJson({
      'disclaimer': 'For entertainment only.',
      'subject': {'name': 'Asha'},
      'asOf': '2026-10-21T10:21:00.000Z',
      'panchang': {
        'weekday': 'Wednesday',
        'tithi': 'Ekadasi (Sukla)',
        'nakshatra': 'Dhanishta - 4',
        'yoga': 'Ganda',
        'karana': 'Vanija',
        'lunarMonth': 'Aaswayuja',
        'sunrise': '06:33',
        'sunset': '17:49',
        'horaLord': 'Saturn',
        'dishaShool': 'North',
      },
      'dasha': {
        'label': 'Rahu – Saturn',
        'levels': ['Rahu', 'Saturn'],
      },
    });
    expect(result.name, 'Asha');
    expect(result.dasha.levels, ['Rahu', 'Saturn']);
    expect(result.panchang.rows, hasLength(10));
  });

  test('visitor session reset invalidates today periods state', () {
    final source = File(
      'lib/features/session/application/visitor_session_reset.dart',
    ).readAsStringSync();
    expect(source.contains('todayPeriodsControllerProvider'), isTrue);
  });
}
