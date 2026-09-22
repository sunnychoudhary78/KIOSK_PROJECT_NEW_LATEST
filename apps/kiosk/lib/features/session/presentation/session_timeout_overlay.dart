import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final scheme = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Are you still there?',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      seconds <= 1
                          ? 'Returning home in 1 second'
                          : 'Returning home in $seconds seconds',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => ref
                          .read(kioskSessionControllerProvider.notifier)
                          .noteActivity(),
                      child: Text(
                        'Continue',
                        style: TextStyle(color: scheme.onPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
