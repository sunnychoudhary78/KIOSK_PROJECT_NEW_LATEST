import 'package:flutter/material.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/theme/app_theme.dart';

class SkpKioskApp extends StatelessWidget {
  const SkpKioskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Kiosk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
