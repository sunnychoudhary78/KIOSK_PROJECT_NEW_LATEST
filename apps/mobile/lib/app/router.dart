import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';
import 'package:skp_mobile/features/auth/presentation/login_page.dart';
import 'package:skp_mobile/features/home/presentation/home_page.dart';
import 'package:skp_mobile/features/nearby_kiosks/application/nearby_kiosks_controller.dart';
import 'package:skp_mobile/features/nearby_kiosks/presentation/nearby_kiosks_map_page.dart';
import 'package:skp_mobile/features/nearby_kiosks/presentation/nearby_kiosks_page.dart';
import 'package:skp_mobile/features/otp_print/presentation/otp_print_page.dart';
import 'package:skp_mobile/features/otp_print/presentation/otp_print_payment_page.dart';
import 'package:skp_mobile/features/otp_print/presentation/otp_print_success_page.dart';
import 'package:skp_mobile/features/profile/presentation/profile_page.dart';

class AppRoutes {
  static const home = '/';
  static const login = '/login';
  static const otpPrint = '/otp-print';
  static const otpPrintPayment = '/otp-print/payment';
  static const otpPrintSuccess = '/otp-print/success';
  static const nearbyKiosks = '/nearby-kiosks';
  static const nearbyKiosksMap = '/nearby-kiosks/map';
  static const profile = '/profile';
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case AppRoutes.otpPrint:
        return MaterialPageRoute(
          builder: (_) => const _AuthGate(child: OtpPrintPage()),
        );
      case AppRoutes.otpPrintPayment:
        return MaterialPageRoute(
          builder: (_) => const _AuthGate(child: OtpPrintPaymentPage()),
        );
      case AppRoutes.otpPrintSuccess:
        return MaterialPageRoute(
          builder: (_) => const _AuthGate(child: OtpPrintSuccessPage()),
        );
      case AppRoutes.nearbyKiosks:
        return MaterialPageRoute(
          builder: (_) => const _AuthGate(child: NearbyKiosksPage()),
        );
      case AppRoutes.nearbyKiosksMap:
        final args = settings.arguments;
        final kiosks = args is List<NearbyKiosk>
            ? args
            : const <NearbyKiosk>[];
        return MaterialPageRoute(
          builder: (_) => _AuthGate(
            child: NearbyKiosksMapPage(kiosks: kiosks),
          ),
        );
      case AppRoutes.profile:
        return MaterialPageRoute(
          builder: (_) => const _AuthGate(child: ProfilePage()),
        );
      case AppRoutes.home:
      default:
        return MaterialPageRoute(builder: (_) => const HomePage());
    }
  }
}

/// Redirects unauthenticated users to login.
class _AuthGate extends ConsumerWidget {
  const _AuthGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(citizenAuthProvider);

    if (auth.restoring) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.login);
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return child;
  }
}
