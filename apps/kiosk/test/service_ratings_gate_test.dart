import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/features/service_ratings/application/service_ratings_gate.dart';
import 'package:skp_kiosk/features/service_ratings/domain/service_rating_keys.dart';

void main() {
  test('gate allows first prompt then blocks until clear', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final gate = container.read(serviceRatingsGateProvider.notifier);

    expect(gate.shouldPrompt(ServiceRatingKeys.familyWellBeing), isTrue);
    gate.markPrompted(ServiceRatingKeys.familyWellBeing);
    expect(gate.shouldPrompt(ServiceRatingKeys.familyWellBeing), isFalse);
    expect(gate.shouldPrompt(ServiceRatingKeys.familyAstrology), isTrue);

    gate.clear();
    expect(gate.shouldPrompt(ServiceRatingKeys.familyWellBeing), isTrue);
    expect(gate.shouldPrompt(ServiceRatingKeys.familyAstrology), isTrue);
  });

  test('familyFor maps print and session keys', () {
    expect(
      ServiceRatingKeys.familyFor(ServiceRatingKeys.wellBeingPrint),
      ServiceRatingKeys.familyWellBeing,
    );
    expect(
      ServiceRatingKeys.familyFor(ServiceRatingKeys.wellBeingSession),
      ServiceRatingKeys.familyWellBeing,
    );
    expect(
      ServiceRatingKeys.familyFor(ServiceRatingKeys.astrologyPrint),
      ServiceRatingKeys.familyAstrology,
    );
    expect(
      ServiceRatingKeys.familyFor(ServiceRatingKeys.astrologySession),
      ServiceRatingKeys.familyAstrology,
    );
    expect(ServiceRatingKeys.familyFor(ServiceRatingKeys.otpPrint), isNull);
  });
}
