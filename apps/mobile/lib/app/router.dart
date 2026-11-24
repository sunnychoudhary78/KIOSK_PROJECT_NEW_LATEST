import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';
import 'package:skp_mobile/features/auth/presentation/login_page.dart';
import 'package:skp_mobile/features/home/presentation/home_page.dart';
import 'package:skp_mobile/features/nearby_kiosks/application/nearby_kiosks_controller.dart';
import 'package:skp_mobile/features/nearby_kiosks/presentation/nearby_kiosks_map_page.dart';
import 'package:skp_mobile/features/nearby_kiosks/presentation/nearby_kiosks_page.dart';
import 'package:skp_mobile/features/otp_print/presentation/otp_print_page.dart';
import 'package:skp_mobile/features/otp_print/presentation/otp_print_payment_page.dart';
import 'package:skp_mobile/features/otp_print/presentation/payment_support_page.dart';
import 'package:skp_mobile/features/otp_print/presentation/otp_print_success_page.dart';
import 'package:skp_mobile/features/find_services/domain/local_service.dart';
import 'package:skp_mobile/features/find_services/presentation/find_service_contacts_page.dart';
import 'package:skp_mobile/features/find_services/presentation/find_services_page.dart';
import 'package:skp_mobile/features/astrology_contacts/domain/astrology_contact.dart';
import 'package:skp_mobile/features/astrology_contacts/presentation/astrology_contacts_page.dart';
import 'package:skp_mobile/features/fuel_stations/presentation/fuel_stations_page.dart';
import 'package:skp_mobile/features/profile/presentation/about_page.dart';
import 'package:skp_mobile/features/profile/presentation/how_it_works_page.dart';
import 'package:skp_mobile/features/profile/presentation/profile_page.dart';

class AppRoutes {
  static const home = '/';
  static const login = '/login';
  static const otpPrint = '/otp-print';
  static const otpPrintPayment = '/otp-print/payment';
  static const otpPrintSupport = '/otp-print/support';
  static const otpPrintSuccess = '/otp-print/success';
  static const nearbyKiosks = '/nearby-kiosks';
  static const nearbyKiosksMap = '/nearby-kiosks/map';
  static const findServices = '/find-services';
  static const findServiceContacts = '/find-services/contacts';
  static const fuelStations = '/fuel-stations';
  static const astrologyPandit = '/astrology/contact-pandit';
  static const profile = '/profile';
  static const howItWorks = '/how-it-works';
  static const about = '/about';
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
      case AppRoutes.otpPrintSupport:
        final supportArgs = settings.arguments;
        return MaterialPageRoute(
          builder: (_) => _AuthGate(
            child: PaymentSupportPage(
              args: supportArgs is PaymentSupportArgs
                  ? supportArgs
                  : const PaymentSupportArgs(
                      challengeId: '',
                      amountLabel: '',
                      kioskName: 'Kiosk',
                    ),
            ),
          ),
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
      case AppRoutes.findServices:
        return MaterialPageRoute(
          builder: (_) => const _AuthGate(child: FindServicesPage()),
        );
      case AppRoutes.findServiceContacts:
        final contactArgs = settings.arguments;
        final category = contactArgs is LocalServiceCategory
            ? contactArgs
            : const LocalServiceCategory(
                id: '',
                slug: '',
                name: 'Service',
                contacts: [],
              );
        return MaterialPageRoute(
          builder: (_) => _AuthGate(
            child: FindServiceContactsPage(category: category),
          ),
        );
      case AppRoutes.fuelStations:
        return MaterialPageRoute(
          builder: (_) => const _AuthGate(child: FuelStationsPage()),
        );
      case AppRoutes.astrologyPandit:
        return MaterialPageRoute(
          builder: (_) => const _AuthGate(
            child: AstrologyContactsPage(kind: AstrologyContactKind.pandit),
          ),
        );
      case AppRoutes.profile:
        return MaterialPageRoute(
          builder: (_) => const _AuthGate(child: ProfilePage()),
        );
      case AppRoutes.howItWorks:
        return MaterialPageRoute(
          builder: (_) => const _AuthGate(child: HowItWorksPage()),
        );
      case AppRoutes.about:
        return MaterialPageRoute(
          builder: (_) => const _AuthGate(child: AboutPage()),
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
      return const SkpScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.login);
        }
      });
      return const SkpScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return child;
  }
}
