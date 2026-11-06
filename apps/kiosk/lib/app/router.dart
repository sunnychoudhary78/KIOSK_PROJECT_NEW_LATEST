import 'package:flutter/material.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_hub_page.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_page.dart';
import 'package:skp_kiosk/features/astrology/presentation/match_kundali_page.dart';
import 'package:skp_kiosk/features/astrology/presentation/my_kundali_page.dart';
import 'package:skp_kiosk/features/astrology/presentation/today_periods_page.dart';
import 'package:skp_kiosk/features/charging/presentation/charging_page.dart';
import 'package:skp_kiosk/features/fuel_stations/presentation/fuel_stations_page.dart';
import 'package:skp_kiosk/features/digilocker_print/presentation/digilocker_print_page.dart';
import 'package:skp_kiosk/features/emergency/presentation/emergency_page.dart';
import 'package:skp_kiosk/features/home/presentation/home_page.dart';
import 'package:skp_kiosk/features/support/presentation/support_page.dart';
import 'package:skp_kiosk/features/local_services/domain/local_service.dart';
import 'package:skp_kiosk/features/local_services/presentation/local_service_contacts_page.dart';
import 'package:skp_kiosk/features/local_services/presentation/local_services_page.dart';
import 'package:skp_kiosk/features/otp_print/presentation/otp_print_page.dart';
import 'package:skp_kiosk/features/print/presentation/print_chooser_page.dart';
import 'package:skp_kiosk/features/quick_print/presentation/quick_print_page.dart';
import 'package:skp_kiosk/features/serial_debug/presentation/serial_debug_page.dart';
import 'package:skp_kiosk/features/well_being/presentation/well_being_page.dart';

final GlobalKey<NavigatorState> kioskNavigatorKey = GlobalKey<NavigatorState>();

class AppRoutes {
  static const home = '/';
  static const print = '/print';
  static const otpPrint = '/otp-print';
  static const quickPrint = '/quick-print';
  static const digilockerPrint = '/digilocker-print';
  static const wellBeing = '/well-being';
  static const charging = '/charging';
  static const astrology = '/astrology';
  static const astrologyPalm = '/astrology/palm';
  static const astrologyKundali = '/astrology/kundali';
  static const astrologyMatch = '/astrology/match';
  static const astrologyToday = '/astrology/today';
  static const fuelStations = '/fuel-stations';
  static const localServices = '/local-services';
  static const localServiceContacts = '/local-services/contacts';
  static const emergency = '/emergency';
  static const support = '/support';
  static const serialDebug = '/serial-debug';
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    Route<dynamic> page(WidgetBuilder builder) {
      return MaterialPageRoute(builder: builder, settings: settings);
    }

    switch (settings.name) {
      case AppRoutes.print:
        return page((_) => const PrintChooserPage());
      case AppRoutes.otpPrint:
        return page((_) => const OtpPrintPage());
      case AppRoutes.quickPrint:
        return page((_) => const QuickPrintPage());
      case AppRoutes.digilockerPrint:
        return page((_) => const DigilockerPrintPage());
      case AppRoutes.wellBeing:
        return page((_) => const WellBeingPage());
      case AppRoutes.charging:
        return page((_) => const ChargingPage());
      case AppRoutes.astrology:
        return page((_) => const AstrologyHubPage());
      case AppRoutes.astrologyPalm:
        return page((_) => const AstrologyPage());
      case AppRoutes.astrologyKundali:
        return page((_) => const MyKundaliPage());
      case AppRoutes.astrologyMatch:
        return page((_) => const MatchKundaliPage());
      case AppRoutes.astrologyToday:
        return page((_) => const TodayPeriodsPage());
      case AppRoutes.fuelStations:
        return page((_) => const FuelStationsPage());
      case AppRoutes.localServices:
        return page((_) => const LocalServicesPage());
      case AppRoutes.localServiceContacts:
        final category = settings.arguments;
        if (category is! LocalServiceCategory) {
          return page((_) => const LocalServicesPage());
        }
        return page((_) => LocalServiceContactsPage(category: category));
      case AppRoutes.emergency:
        return page((_) => const EmergencyPage());
      case AppRoutes.support:
        return page((_) => const SupportPage());
      case AppRoutes.serialDebug:
        return page((_) => const SerialDebugPage());
      case AppRoutes.home:
      default:
        return page((_) => const HomePage());
    }
  }
}
