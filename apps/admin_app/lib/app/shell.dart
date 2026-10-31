import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_admin/features/fleet/presentation/home_page.dart';
import 'package:skp_admin/features/fleet/presentation/kiosks_page.dart';
import 'package:skp_admin/features/print_jobs/presentation/print_jobs_page.dart';
import 'package:skp_admin/features/support/presentation/support_controller.dart';
import 'package:skp_admin/features/support/presentation/support_page.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final openCount = ref.watch(supportProvider.select((state) => state.openCount));
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomePage(),
          KiosksPage(),
          PrintJobsPage(),
          SupportPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.devices_outlined), label: 'Kiosks'),
          const NavigationDestination(icon: Icon(Icons.print_outlined), label: 'Jobs'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: openCount > 0,
              label: Text(openCount > 99 ? '99+' : '$openCount'),
              child: const Icon(Icons.support_agent_outlined),
            ),
            label: 'Support',
          ),
        ],
      ),
    );
  }
}
