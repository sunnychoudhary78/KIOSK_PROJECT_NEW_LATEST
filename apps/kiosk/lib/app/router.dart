import 'package:flutter/material.dart';
import 'package:skp_kiosk/features/digilocker_print/presentation/digilocker_print_page.dart';
import 'package:skp_kiosk/features/home/presentation/home_page.dart';
import 'package:skp_kiosk/features/otp_print/presentation/otp_print_page.dart';
import 'package:skp_kiosk/features/serial_debug/presentation/serial_debug_page.dart';
import 'package:skp_kiosk/features/well_being/presentation/well_being_page.dart';

class AppRoutes {
  static const home = '/';
  static const otpPrint = '/otp-print';
  static const digilockerPrint = '/digilocker-print';
  static const wellBeing = '/well-being';
  static const serialDebug = '/serial-debug';
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.otpPrint:
        return MaterialPageRoute(builder: (_) => const OtpPrintPage());
      case AppRoutes.digilockerPrint:
        return MaterialPageRoute(builder: (_) => const DigilockerPrintPage());
      case AppRoutes.wellBeing:
        return MaterialPageRoute(builder: (_) => const WellBeingPage());
      case AppRoutes.serialDebug:
        return MaterialPageRoute(builder: (_) => const SerialDebugPage());
      case AppRoutes.home:
      default:
        return MaterialPageRoute(builder: (_) => const HomePage());
    }
  }
}
