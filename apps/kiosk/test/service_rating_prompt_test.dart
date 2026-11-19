import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/ui/kiosk_keyboard.dart';
import 'package:skp_kiosk/features/service_ratings/presentation/service_rating_prompt.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  testWidgets('5 stars shows Submit without keyboard; Submit sends null feedback',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    int? stars;
    String? feedback;
    var skipped = false;

    await tester.pumpWidget(
      wrap(
        ServiceRatingPrompt(
          autoContinue: null,
          onSkip: () => skipped = true,
          onSubmitted: (s, f) {
            stars = s;
            feedback = f;
          },
        ),
      ),
    );

    await tester.tap(find.byType(IconButton).at(4));
    await tester.pump();

    expect(find.byType(KioskKeyboard), findsNothing);
    expect(find.text('What could we improve?'), findsNothing);

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(stars, 5);
    expect(feedback, isNull);
    expect(skipped, isFalse);
  });

  testWidgets('2 stars shows keyboard; typed feedback is submitted', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    int? stars;
    String? feedback;

    await tester.pumpWidget(
      wrap(
        ServiceRatingPrompt(
          autoContinue: null,
          onSkip: () {},
          onSubmitted: (s, f) {
            stars = s;
            feedback = f;
          },
        ),
      ),
    );

    await tester.tap(find.byType(IconButton).at(1)); // 2 stars
    await tester.pump();

    expect(find.byType(KioskKeyboard), findsOneWidget);
    expect(find.text('What could we improve?'), findsOneWidget);

    await tester.tap(find.text('H'));
    await tester.pump();
    await tester.tap(find.text('i'));
    await tester.pump();

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(stars, 2);
    expect(feedback, 'Hi');
  });

  testWidgets('2 stars with empty feedback still submits', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    int? stars;
    Object? feedback = 'sentinel';

    await tester.pumpWidget(
      wrap(
        ServiceRatingPrompt(
          autoContinue: null,
          onSkip: () {},
          onSubmitted: (s, f) {
            stars = s;
            feedback = f;
          },
        ),
      ),
    );

    await tester.tap(find.byType(IconButton).at(1));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(stars, 2);
    expect(feedback, isNull);
  });

  testWidgets('auto-timeout only when no stars selected', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var skipped = false;
    var submitted = false;

    await tester.pumpWidget(
      wrap(
        ServiceRatingPrompt(
          autoContinue: const Duration(seconds: 2),
          onSkip: () => skipped = true,
          onSubmitted: (_, __) => submitted = true,
        ),
      ),
    );

    await tester.tap(find.byType(IconButton).at(4));
    await tester.pump();

    await tester.pump(const Duration(seconds: 3));
    expect(skipped, isFalse);
    expect(submitted, isFalse);

    await tester.tap(find.text('Submit'));
    await tester.pump();
    expect(submitted, isTrue);
  });

  testWidgets('auto-timeout skips when idle', (tester) async {
    var skipped = false;

    await tester.pumpWidget(
      wrap(
        ServiceRatingPrompt(
          autoContinue: const Duration(seconds: 2),
          onSkip: () => skipped = true,
          onSubmitted: (_, __) {},
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    expect(skipped, isTrue);
  });
}
