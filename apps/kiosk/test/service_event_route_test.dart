import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/features/local_services/domain/local_service.dart';
import 'package:skp_kiosk/features/service_analytics/domain/service_event_keys.dart';

void main() {
  test('named routes keep their name so a tap can be counted', () {
    const names = [
      AppRoutes.print,
      AppRoutes.quickPrint,
      AppRoutes.otpPrint,
      AppRoutes.digilockerPrint,
      AppRoutes.astrology,
      AppRoutes.astrologyKundali,
      AppRoutes.astrologyPalm,
      AppRoutes.astrologyMatch,
      AppRoutes.astrologyToday,
      AppRoutes.localServices,
      AppRoutes.wellBeing,
      AppRoutes.charging,
      AppRoutes.fuelStations,
      AppRoutes.emergency,
      AppRoutes.support,
    ];

    for (final name in names) {
      final route = AppRouter.onGenerateRoute(RouteSettings(name: name));
      expect(route.settings.name, name, reason: name);
      expect(ServiceEventKeys.fromRoute(route.settings), isNotNull, reason: name);
    }
  });

  test('a trade tap keeps the category slug on the route', () {
    const category = LocalServiceCategory(
      slug: 'plumber',
      name: 'Plumber',
      contacts: [],
    );
    final route = AppRouter.onGenerateRoute(
      const RouteSettings(
        name: AppRoutes.localServiceContacts,
        arguments: category,
      ),
    );
    expect(
      ServiceEventKeys.fromRoute(route.settings),
      'local_services.plumber',
    );
  });

  test('home and serial debug are not counted', () {
    for (final name in [AppRoutes.home, AppRoutes.serialDebug]) {
      final route = AppRouter.onGenerateRoute(RouteSettings(name: name));
      expect(route.settings.name, name);
      expect(ServiceEventKeys.fromRoute(route.settings), isNull);
    }
  });
}
