import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:skp_kiosk/features/astrology/application/astrology_controller.dart';
import 'package:skp_kiosk/features/astrology/application/palm_path.dart';
import 'package:skp_kiosk/features/astrology/application/palm_roi.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_phase.dart';

Uint8List _palmPng() {
  const size = 160;
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(20, 20, 20));
  final crop = PalmRoi.crop(size, size);
  final palm = openPalmPath(
    Rect.fromLTWH(
      crop.left.toDouble(),
      crop.top.toDouble(),
      crop.width.toDouble(),
      crop.height.toDouble(),
    ),
  );
  for (var y = crop.top; y < crop.top + crop.height; y++) {
    for (var x = crop.left; x < crop.left + crop.width; x++) {
      if (palm.contains(Offset(x + 0.5, y + 0.5))) {
        image.setPixelRgb(x, y, 180, 120, 80);
      }
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    container.listen(astrologyControllerProvider, (_, __) {});
  });

  tearDown(() => container.dispose());

  test('first good still waits; a second new still after the hold captures', () {
    final notifier = container.read(astrologyControllerProvider.notifier);
    final firstStill = _palmPng();
    final secondStill = _palmPng();
    final t0 = DateTime(2026, 1, 1);

    final first = notifier.evaluateFrame(firstStill, now: t0);
    expect(first.ok, isTrue);
    expect(container.read(astrologyControllerProvider).phase, AstrologyPhase.capture);
    expect(container.read(astrologyControllerProvider).palmBytes, isNull);

    notifier.evaluateFrame(
      secondStill,
      now: t0.add(AstrologyController.autoCaptureHold),
    );
    final state = container.read(astrologyControllerProvider);
    expect(state.phase, AstrologyPhase.form);
    expect(state.palmBytes, same(secondStill));
  });

  test('a single good still after the hold is not enough', () {
    final notifier = container.read(astrologyControllerProvider.notifier);
    final palm = _palmPng();
    final t0 = DateTime(2026, 1, 1);
    notifier.evaluateFrame(palm, now: t0);
    expect(container.read(astrologyControllerProvider).phase, AstrologyPhase.capture);
  });

  test('a bad frame resets so auto-capture does not fire', () {
    final notifier = container.read(astrologyControllerProvider.notifier);
    final palm = _palmPng();
    final t0 = DateTime(2026, 1, 1);

    notifier.evaluateFrame(palm, now: t0);
    final blank = img.Image(width: 96, height: 96);
    img.fill(blank, color: img.ColorRgb8(8, 8, 8));
    notifier.evaluateFrame(
      Uint8List.fromList(img.encodePng(blank)),
      now: t0.add(const Duration(milliseconds: 100)),
    );

    notifier.evaluateFrame(
      palm,
      now: t0.add(AstrologyController.autoCaptureHold),
    );
    expect(container.read(astrologyControllerProvider).phase, AstrologyPhase.capture);
    expect(container.read(astrologyControllerProvider).palmBytes, isNull);
  });

  test('manual accept with a looser gate still stores the palm', () {
    final notifier = container.read(astrologyControllerProvider.notifier);
    notifier.acceptPalm(_palmPng(), strict: false);
    final state = container.read(astrologyControllerProvider);
    expect(state.phase, AstrologyPhase.form);
    expect(state.palmBytes, isNotNull);
  });
}
