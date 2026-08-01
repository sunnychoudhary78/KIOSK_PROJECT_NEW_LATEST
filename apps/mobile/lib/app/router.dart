import 'package:flutter/material.dart';
import 'package:skp_mobile/features/auth/presentation/login_page.dart';
import 'package:skp_mobile/features/home/presentation/home_page.dart';
import 'package:skp_mobile/features/otp_print/presentation/otp_print_page.dart';
import 'package:skp_mobile/features/profile/presentation/profile_page.dart';

class AppRoutes {
  static const home = '/';
  static const login = '/login';
  static const otpPrint = '/otp-print';
  static const profile = '/profile';
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case AppRoutes.otpPrint:
        return MaterialPageRoute(builder: (_) => const OtpPrintPage());
      case AppRoutes.profile:
        return MaterialPageRoute(builder: (_) => const ProfilePage());
      case AppRoutes.home:
      default:
        return MaterialPageRoute(builder: (_) => const HomePage());
    }
  }
}
