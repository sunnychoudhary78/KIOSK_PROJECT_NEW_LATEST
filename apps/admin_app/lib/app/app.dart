import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_admin/app/shell.dart';
import 'package:skp_admin/core/theme/app_theme.dart';
import 'package:skp_admin/features/auth/presentation/auth_controller.dart';
import 'package:skp_admin/features/auth/presentation/login_page.dart';

class SkpAdminApp extends ConsumerWidget {
  const SkpAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(staffAuthProvider);
    return MaterialApp(
      title: 'Kiosk Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: auth.restoring
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : auth.isAuthenticated
          ? const AdminShell()
          : const LoginPage(),
    );
  }
}
