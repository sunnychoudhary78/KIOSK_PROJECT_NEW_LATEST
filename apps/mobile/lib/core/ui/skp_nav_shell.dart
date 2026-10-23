import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/core/navigation/nav_tab.dart';
import 'package:skp_mobile/features/home/presentation/home_tab.dart';
import 'package:skp_mobile/features/history/presentation/history_page.dart';
import 'package:skp_mobile/features/nearby_kiosks/presentation/nearby_kiosks_page.dart';
import 'package:skp_mobile/features/profile/presentation/profile_page.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';

class SkpNavShell extends ConsumerStatefulWidget {
  const SkpNavShell({super.key});

  @override
  ConsumerState<SkpNavShell> createState() => _SkpNavShellState();
}

class _SkpNavShellState extends ConsumerState<SkpNavShell> {
  bool _nearbyMounted = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final index = ref.watch(navTabProvider);
    if (index == NavTabs.nearby) {
      _nearbyMounted = true;
    }

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          const HomeTab(),
          const HistoryPage(),
          _nearbyMounted
              ? const NearbyKiosksPage(embedded: true)
              : const SizedBox.shrink(),
          const ProfilePage(embedded: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) =>
            ref.read(navTabProvider.notifier).select(value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l10n.tabHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long_rounded),
            label: l10n.tabHistory,
          ),
          NavigationDestination(
            icon: const Icon(Icons.location_on_outlined),
            selectedIcon: const Icon(Icons.location_on_rounded),
            label: l10n.tabNearby,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: l10n.tabProfile,
          ),
        ],
      ),
    );
  }
}
