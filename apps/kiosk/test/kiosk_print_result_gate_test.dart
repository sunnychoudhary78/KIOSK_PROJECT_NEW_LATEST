import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/ui/kiosk_print_result.dart';
import 'package:skp_kiosk/features/service_ratings/application/service_ratings_gate.dart';
import 'package:skp_kiosk/features/service_ratings/domain/service_rating_keys.dart';

void main() {
  testWidgets('print rating marks family so session prompt is blocked', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: KioskPrintResult(
              confirmed: true,
              autoReturn: null,
              ratingServiceKey: ServiceRatingKeys.wellBeingPrint,
              onHome: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Done'));
    await tester.pump();

    expect(find.text('How was your experience?'), findsOneWidget);
    expect(
      container
          .read(serviceRatingsGateProvider.notifier)
          .shouldPrompt(ServiceRatingKeys.familyWellBeing),
      isFalse,
    );
  });
}
