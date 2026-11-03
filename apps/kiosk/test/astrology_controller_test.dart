import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:skp_kiosk/features/astrology/application/astrology_controller.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_phase.dart';

import 'palm_quality_fixtures.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    container.listen(astrologyControllerProvider, (_, __) {});
  });

  tearDown(() => container.dispose());

  test('needs four good stills after the hold to auto-capture', () {
    final notifier = container.read(astrologyControllerProvider.notifier);
    final t0 = DateTime(2026, 1, 1);

    for (var i = 0; i < 3; i++) {
      final q = notifier.evaluateFrame(
        texturedPalmPng(seed: 10 + i),
        now: t0.add(Duration(milliseconds: 200 * i)),
      );
      expect(q.ok, isTrue, reason: 'frame $i: ${q.message}');
      expect(
        container.read(astrologyControllerProvider).phase,
        AstrologyPhase.capture,
      );
    }

    notifier.evaluateFrame(
      texturedPalmPng(seed: 99),
      now: t0.add(AstrologyController.autoCaptureHold),
    );
    final state = container.read(astrologyControllerProvider);
    expect(state.phase, AstrologyPhase.form);
    expect(state.palmBytes, isNotNull);
  });

  test('three good stills after the hold is not enough', () {
    final notifier = container.read(astrologyControllerProvider.notifier);
    final t0 = DateTime(2026, 1, 1);
    for (var i = 0; i < 3; i++) {
      notifier.evaluateFrame(
        texturedPalmPng(seed: 20 + i),
        now: t0.add(
          i == 2
              ? AstrologyController.autoCaptureHold
              : Duration(milliseconds: 100 * i),
        ),
      );
    }
    expect(
      container.read(astrologyControllerProvider).phase,
      AstrologyPhase.capture,
    );
    expect(container.read(astrologyControllerProvider).palmBytes, isNull);
  });

  test('bad frame mid-streak requires a full new streak', () {
    final notifier = container.read(astrologyControllerProvider.notifier);
    final t0 = DateTime(2026, 1, 1);

    notifier.evaluateFrame(texturedPalmPng(seed: 1), now: t0);
    notifier.evaluateFrame(
      texturedPalmPng(seed: 2),
      now: t0.add(const Duration(milliseconds: 150)),
    );

    final blank = img.Image(width: 96, height: 96);
    img.fill(blank, color: img.ColorRgb8(8, 8, 8));
    final resetAt = t0.add(const Duration(milliseconds: 300));
    notifier.evaluateFrame(
      Uint8List.fromList(img.encodePng(blank)),
      now: resetAt,
    );

    final streakStart = resetAt.add(const Duration(milliseconds: 100));
    for (var i = 0; i < 3; i++) {
      notifier.evaluateFrame(
        texturedPalmPng(seed: 40 + i),
        now: streakStart.add(Duration(milliseconds: 150 * i)),
      );
    }
    expect(
      container.read(astrologyControllerProvider).phase,
      AstrologyPhase.capture,
    );

    notifier.evaluateFrame(
      texturedPalmPng(seed: 50),
      now: streakStart.add(AstrologyController.autoCaptureHold),
    );
    expect(
      container.read(astrologyControllerProvider).phase,
      AstrologyPhase.form,
    );
  });

  test('manual accept with a looser gate still stores the palm', () {
    final notifier = container.read(astrologyControllerProvider.notifier);
    notifier.acceptPalm(texturedPalmPng(seed: 3), strict: false);
    final state = container.read(astrologyControllerProvider);
    expect(state.phase, AstrologyPhase.form);
    expect(state.palmBytes, isNotNull);
  });
}
