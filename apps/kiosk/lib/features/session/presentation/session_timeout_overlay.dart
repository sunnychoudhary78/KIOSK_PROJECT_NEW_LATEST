import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';

class SessionTimeoutOverlay extends ConsumerWidget {
  const SessionTimeoutOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(kioskSessionControllerProvider);
    if (session.phase != KioskSessionPhase.warning) {
      return const SizedBox.shrink();
    }

    final seconds = session.warningRemaining.inSeconds;
    final theme = Theme.of(context);

    return Positioned.fill(
      child: Material(
        color: const Color(0xE60B1419),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Are you still there?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    seconds <= 1
                        ? 'Returning home in 1 second'
                        : 'Returning home in $seconds seconds',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(color: SkpColors.muted),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    '$seconds',
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 160,
                      height: 1,
                      color: SkpColors.gold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 420,
                    child: KioskPrimaryButton(
                      label: "I'm still here",
                      gold: true,
                      onPressed: () => ref
                          .read(kioskSessionControllerProvider.notifier)
                          .noteActivity(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
