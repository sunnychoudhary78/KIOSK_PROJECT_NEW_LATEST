import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/core/navigation/nav_tab.dart';
import 'package:skp_mobile/features/home/presentation/home_tab.dart';
import 'package:skp_mobile/features/history/presentation/history_page.dart';
import 'package:skp_mobile/features/nearby_kiosks/presentation/nearby_kiosks_page.dart';
import 'package:skp_mobile/features/profile/presentation/profile_page.dart';

class SkpNavShell extends ConsumerStatefulWidget {
  const SkpNavShell({super.key});

  @override
  ConsumerState<SkpNavShell> createState() => _SkpNavShellState();
}

class _SkpNavShellState extends ConsumerState<SkpNavShell> {
  bool _nearbyMounted = false;

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(navTabProvider);
    if (index == NavTabs.nearby) {
      _nearbyMounted = true;
    }

    // Bottom navbar removed — destinations live in the top hamburger menu.
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
    );
  }
}
