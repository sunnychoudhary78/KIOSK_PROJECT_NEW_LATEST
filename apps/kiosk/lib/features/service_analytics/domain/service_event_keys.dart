import 'package:flutter/widgets.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/features/local_services/domain/local_service.dart';

/// Stable dotted keys for service navigation analytics.
abstract final class ServiceEventKeys {
  static const homePrint = 'home.print';
  static const homeLocalServices = 'home.local_services';
  static const homeWellBeing = 'home.well_being';
  static const homeCharging = 'home.charging';
  static const homeAstrology = 'home.astrology';
  static const homeFuelStations = 'home.fuel_stations';
  static const homeEmergency = 'home.emergency';
  static const homeSupport = 'home.support';
  static const supportSubmit = 'support.submit';

  static const printQuick = 'print.quick_print';
  static const printOtp = 'print.otp_print';
  static const printDigilocker = 'print.digilocker_print';

  static const astrologyKundali = 'astrology.kundali';
  static const astrologyPalm = 'astrology.palm';
  static const astrologyMatch = 'astrology.match';
  static const astrologyToday = 'astrology.today';

  static const wellBeingOxygen = 'well_being.path.oxygen';
  static const wellBeingTemperature = 'well_being.path.temperature';

  static const fuelDirections = 'fuel_stations.directions';

  static String localServicesCategory(String slug) => 'local_services.$slug';

  static String fuelFilter(String kind) => 'fuel_stations.filter.$kind';

  /// Maps a pushed [RouteSettings] to an event key, or null to skip.
  static String? fromRoute(RouteSettings settings) {
    final name = settings.name;
    if (name == null || name == AppRoutes.home || name == AppRoutes.serialDebug) {
      return null;
    }

    switch (name) {
      case AppRoutes.print:
        return homePrint;
      case AppRoutes.localServices:
        return homeLocalServices;
      case AppRoutes.wellBeing:
        return homeWellBeing;
      case AppRoutes.charging:
        return homeCharging;
      case AppRoutes.astrology:
        return homeAstrology;
      case AppRoutes.fuelStations:
        return homeFuelStations;
      case AppRoutes.emergency:
        return homeEmergency;
      case AppRoutes.support:
        return homeSupport;
      case AppRoutes.quickPrint:
        return printQuick;
      case AppRoutes.otpPrint:
        return printOtp;
      case AppRoutes.digilockerPrint:
        return printDigilocker;
      case AppRoutes.astrologyKundali:
        return astrologyKundali;
      case AppRoutes.astrologyPalm:
        return astrologyPalm;
      case AppRoutes.astrologyMatch:
        return astrologyMatch;
      case AppRoutes.astrologyToday:
        return astrologyToday;
      case AppRoutes.localServiceContacts:
        final args = settings.arguments;
        if (args is LocalServiceCategory && args.slug.isNotEmpty) {
          return localServicesCategory(args.slug);
        }
        return null;
      default:
        return null;
    }
  }
}
