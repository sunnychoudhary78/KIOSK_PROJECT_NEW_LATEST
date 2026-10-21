import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_theme.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/cosmic_backdrop.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';

class AstrologyHubPage extends ConsumerWidget {
  const AstrologyHubPage({super.key});

  Future<void> _endSession(WidgetRef ref) {
    return ref
        .read(kioskSessionControllerProvider.notifier)
        .endVisitorSession(attract: false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = [
      (
        icon: Icons.auto_awesome,
        title: 'My Kundali',
        subtitle: 'North or South Indian chart',
        onTap: () =>
            Navigator.of(context).pushNamed(AppRoutes.astrologyKundali),
      ),
      (
        icon: Icons.back_hand_outlined,
        title: 'Palm Insights',
        subtitle: 'Photo · Lines · Guidance',
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.astrologyPalm),
      ),
      (
        icon: Icons.favorite_outline,
        title: 'Match Kundalis',
        subtitle: 'Gun milan for two people',
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.astrologyMatch),
      ),
      (
        icon: Icons.calendar_month_outlined,
        title: 'Today & Periods',
        subtitle: 'Panchang · Current dasha',
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.astrologyToday),
      ),
    ];

    return VisitorSessionPopScope(
      child: KioskShell(
        title: 'Astrology',
        cosmic: true,
        onHome: () => _endSession(ref),
        stepLabel: 'Choose',
        footerLeading: KioskGhostButton(
          label: 'Cancel',
          onPressed: () => _endSession(ref),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const CosmicBackdrop(),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Choose a reading',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AstrologyColors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kundali, palm, matching, and daily periods',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AstrologyColors.muted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Column(
                      children: [
                        for (var row = 0; row < 2; row++) ...[
                          if (row > 0) const SizedBox(height: 16),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: KioskServiceTile(
                                    icon: tiles[row * 2].icon,
                                    title: tiles[row * 2].title,
                                    subtitle: tiles[row * 2].subtitle,
                                    onTap: tiles[row * 2].onTap,
                                    tone: KioskServiceTileTone.cosmic,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: KioskServiceTile(
                                    icon: tiles[row * 2 + 1].icon,
                                    title: tiles[row * 2 + 1].title,
                                    subtitle: tiles[row * 2 + 1].subtitle,
                                    onTap: tiles[row * 2 + 1].onTap,
                                    tone: KioskServiceTileTone.cosmic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
