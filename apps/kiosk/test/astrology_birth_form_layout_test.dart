import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/core/ui/kiosk_shell.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_controller.dart';
import 'package:skp_kiosk/features/astrology/data/astrology_repository.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/astrology_birth_form.dart';

class _FakePlacesRepository extends AstrologyRepository {
  _FakePlacesRepository() : super(ApiClient());

  @override
  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    return [
      PlaceSuggestion(
        id: 'om:26.91,75.78|Jaipur',
        label: 'Jaipur',
        subtitle: 'Rajasthan, India',
      ),
    ];
  }

  @override
  Future<ResolvedBirthPlace> resolvePlace(String id) async {
    return const ResolvedBirthPlace(
      id: 'om:26.91,75.78|Jaipur',
      name: 'Jaipur, Rajasthan, India',
      latitude: 26.91,
      longitude: 75.78,
    );
  }
}

void main() {
  testWidgets('kundali form has Material and fits 1280x720 with an error', (
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
            title: 'My Kundali',
            cosmic: true,
            stepLabel: 'Details',
            footerLeading: const SizedBox(width: 120, height: 56),
            footerTrailing: const SizedBox(width: 180, height: 56),
            body: AstrologyBirthFormPanel(
              nameController: name,
              placeController: place,
              dob: DateTime(1995),
              birthTime: const TimeOfDay(hour: 12, minute: 0),
              timeUnknown: false,
              gender: 'female',
              focus: 0,
              error: 'Name and birth place are required',
              title: 'Birth details',
              subtitle: 'Accurate birth time · pick chart style',
              onFocus: (_) {},
              onDob: (_) {},
              onTime: (_) {},
              onTimeUnknown: (_) {},
              onGender: (_) {},
              onKey: (_) {},
              onBackspace: () {},
              footer: AstrologyStyleSegment(style: 'north', onStyle: (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Name and birth place are required'), findsOneWidget);
    expect(find.text('North Indian'), findsOneWidget);
    expect(find.byType(Material), findsWidgets);
  });

  testWidgets('place suggestions fit 1280x720 and selection fills coords', (
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
    ResolvedBirthPlace? resolved;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          astrologyRepositoryProvider.overrideWithValue(
            _FakePlacesRepository(),
          ),
        ],
        child: MaterialApp(
          home: KioskShell(
            title: 'My Kundali',
            cosmic: true,
            stepLabel: 'Details',
            footerTrailing: const SizedBox(width: 180, height: 56),
            body: AstrologyBirthFormPanel(
              nameController: name,
              placeController: place,
              dob: DateTime(1995),
              birthTime: const TimeOfDay(hour: 12, minute: 0),
              timeUnknown: false,
              gender: 'female',
              focus: 1,
              onFocus: (_) {},
              onDob: (_) {},
              onTime: (_) {},
              onTimeUnknown: (_) {},
              onGender: (_) {},
              onKey: (value) => place.text = '${place.text}$value',
              onBackspace: () {},
              onPlaceResolved: (value) => resolved = value,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    place.text = 'Ja';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('place-suggestions')), findsOneWidget);
    expect(find.text('Jaipur'), findsOneWidget);

    await tester.tap(find.text('Jaipur'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(place.text, 'Jaipur, Rajasthan, India');
    expect(resolved?.latitude, 26.91);
    expect(resolved?.longitude, 75.78);
  });
}
