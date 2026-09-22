import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/theme/app_theme.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/presentation/kiosk_activity_scope.dart';
import 'package:skp_kiosk/features/session/presentation/kiosk_session_route_observer.dart';
import 'package:skp_kiosk/features/session/presentation/session_timeout_overlay.dart';
import 'package:skp_kiosk/features/surveillance/application/surveillance_controller.dart';

class SkpKioskApp extends ConsumerStatefulWidget {
  const SkpKioskApp({super.key});

  @override
  ConsumerState<SkpKioskApp> createState() => _SkpKioskAppState();
}

class _SkpKioskAppState extends ConsumerState<SkpKioskApp> {
  late final KioskSessionRouteObserver _routeObserver;

  @override
  void initState() {
    super.initState();
    ref.read(surveillanceControllerProvider);
    _routeObserver = KioskSessionRouteObserver(
      onHomeChanged: (onHome) {
        ref.read(kioskSessionControllerProvider.notifier).setOnHome(onHome);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Kiosk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      navigatorKey: kioskNavigatorKey,
      navigatorObservers: [_routeObserver],
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
      builder: (context, child) {
        return KioskActivityScope(
          child: Stack(
            fit: StackFit.expand,
            children: [
              child ?? const SizedBox.shrink(),
              const SessionTimeoutOverlay(),
            ],
          ),
        );
      },
    );
  }
}
