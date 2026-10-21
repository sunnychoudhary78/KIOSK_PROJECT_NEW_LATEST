import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_controller.dart';
import 'package:skp_kiosk/features/astrology/application/match_kundali_controller.dart';
import 'package:skp_kiosk/features/astrology/data/astrology_repository.dart';
import 'package:skp_kiosk/features/astrology/domain/match_kundali_phase.dart';
import 'package:skp_kiosk/features/astrology/domain/match_kundali_result.dart';

class _FakeAstrologyRepository extends AstrologyRepository {
  _FakeAstrologyRepository() : super(ApiClient());

  @override
  Future<MatchKundaliResult> createMatch({
    required MatchPersonInput groom,
    required MatchPersonInput bride,
  }) async {
    return MatchKundaliResult(
      disclaimer: 'For entertainment only.',
      groomName: groom.name,
      brideName: bride.name,
      score: const MatchScore(
        total: 25,
        max: 36,
        summary: 'Strong compatibility',
        tone: 'good',
      ),
      kutas: const [],
    );
  }
}

void main() {
  test('match controller moves through Bride, loading, and result', () async {
    final container = ProviderContainer(
      overrides: [
        astrologyRepositoryProvider.overrideWithValue(
          _FakeAstrologyRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(matchKundaliControllerProvider, (_, _) {});
    final controller = container.read(matchKundaliControllerProvider.notifier);

    expect(
      container.read(matchKundaliControllerProvider).phase,
      MatchKundaliPhase.groom,
    );
    controller.showBride();
    expect(
      container.read(matchKundaliControllerProvider).phase,
      MatchKundaliPhase.bride,
    );

    const groom = MatchPersonInput(
      name: 'Arjun',
      dateOfBirth: '1990-01-15',
      birthTime: '14:20',
      birthPlace: 'Jaipur',
      birthTimeUnknown: false,
    );
    const bride = MatchPersonInput(
      name: 'Asha',
      dateOfBirth: '1992-06-20',
      birthTime: '10:30',
      birthPlace: 'Delhi',
      birthTimeUnknown: false,
    );
    await controller.submit(groom: groom, bride: bride);

    final state = container.read(matchKundaliControllerProvider);
    expect(state.phase, MatchKundaliPhase.result);
    expect(state.result?.score.total, 25);

    controller.reset();
    expect(
      container.read(matchKundaliControllerProvider).phase,
      MatchKundaliPhase.groom,
    );
    expect(container.read(matchKundaliControllerProvider).result, isNull);
  });

  test('match result JSON pads to eight kutas', () {
    final result = MatchKundaliResult.fromJson({
      'disclaimer': 'For entertainment only.',
      'groom': {'name': 'Arjun'},
      'bride': {'name': 'Asha'},
      'score': {
        'total': 20,
        'max': 36,
        'summary': 'Problematic relationship',
        'tone': 'mixed',
      },
      'kutas': [
        {
          'key': 'varna',
          'name': 'Varna',
          'maxPoints': 1,
          'nature': 'Good',
          'verdict': 'compatible values',
        },
      ],
    });
    expect(result.groomName, 'Arjun');
    expect(result.brideName, 'Asha');
    expect(result.score.total, 20);
    expect(result.kutas, hasLength(8));
    expect(result.kutas.map((kuta) => kuta.key).toList(), [
      'varna',
      'vasya',
      'dina',
      'yoni',
      'graha-maitri',
      'gana',
      'rasi',
      'nadi',
    ]);
  });

  test('visitor session reset invalidates match kundali state', () {
    final source = File(
      'lib/features/session/application/visitor_session_reset.dart',
    ).readAsStringSync();
    expect(source.contains('matchKundaliControllerProvider'), isTrue);
  });
}
