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
        color: SkpColors.scrim,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.fromLTRB(36, 36, 36, 32),
              decoration: BoxDecoration(
                color: SkpColors.panel,
                borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
                border: Border.all(color: SkpColors.line),
              ),
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
                      fontSize: 140,
                      height: 1,
                      color: SkpColors.accent,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 420,
                    child: KioskPrimaryButton(
                      label: "I'm still here",
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
