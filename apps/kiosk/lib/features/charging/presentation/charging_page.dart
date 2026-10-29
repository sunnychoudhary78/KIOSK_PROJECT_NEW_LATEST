import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/charging/application/charging_controller.dart';
import 'package:skp_kiosk/features/charging/domain/charging_monitor.dart';
import 'package:skp_kiosk/features/charging/domain/charging_phase.dart';
import 'package:skp_kiosk/features/charging/presentation/charging_ad_gate.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';

/// Ad-gated phone charging via ESP32 Relay 1 and the INA226 monitor.
class ChargingPage extends ConsumerStatefulWidget {
  const ChargingPage({super.key});

  @override
  ConsumerState<ChargingPage> createState() => _ChargingPageState();
}

class _ChargingPageState extends ConsumerState<ChargingPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(chargingControllerProvider.notifier).startSession();
    });
  }

  Future<void> _endSession() {
    return ref
        .read(kioskSessionControllerProvider.notifier)
        .endVisitorSession(attract: false);
  }

  String _formatCap(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chargingControllerProvider);
    final controller = ref.read(chargingControllerProvider.notifier);
    final theme = Theme.of(context);

    final showDone = state.socketArmed || state.phase == ChargingPhase.done;
    final canCancel =
        state.phase == ChargingPhase.connecting ||
        state.phase == ChargingPhase.watchingAd ||
        state.phase == ChargingPhase.error;

    return VisitorSessionPopScope(
      child: KioskShell(
        title: 'Phone Charging',
        onHome: _endSession,
        stepLabel: switch (state.phase) {
          ChargingPhase.connecting => 'Connect',
          ChargingPhase.watchingAd => 'Sponsored message',
          ChargingPhase.waitingForPhone => 'Plug in',
          ChargingPhase.charging => 'Charging',
          ChargingPhase.done => 'Done',
          ChargingPhase.error => 'Error',
        },
        footerLeading: canCancel
            ? KioskGhostButton(label: 'Cancel', onPressed: _endSession)
            : null,
        footerTrailing: showDone
            ? KioskPrimaryButton(
                label: state.phase == ChargingPhase.done
                    ? 'Back to home'
                    : 'Done charging',
                onPressed: () async {
                  if (state.socketArmed) {
                    await controller.finishCharging();
                  }
                  if (!context.mounted) {
                    return;
                  }
                  await _endSession();
                },
              )
            : state.phase == ChargingPhase.error
            ? KioskPrimaryButton(
                label: 'Retry',
                onPressed: () => controller.retryConnect(),
              )
            : null,
        body: Padding(
          padding: SkpTokens.pagePadding,
          child: switch (state.phase) {
            ChargingPhase.connecting => Center(
              child: KioskLoading(message: state.statusMessage),
            ),
            ChargingPhase.watchingAd => ChargingAdGate(
              onCompleted: () {
                unawaited(controller.onAdCompleted());
              },
            ),
            ChargingPhase.waitingForPhone => _ChargingActiveView(
              charging: false,
              relayOn: state.relayOn,
              statusMessage: state.statusMessage,
              volts: state.volts,
              currentMa: state.currentMa,
              powerW: state.powerW,
            ),
            ChargingPhase.charging => _ChargingActiveView(
              charging: true,
              relayOn: state.relayOn,
              statusMessage: state.statusMessage,
              volts: state.volts,
              currentMa: state.currentMa,
              powerW: state.powerW,
              remainingLabel: _formatCap(
                state.capSecondsRemaining ?? ChargingMonitor.maxChargeSeconds,
              ),
              totalSeconds: ChargingMonitor.maxChargeSeconds,
              secondsRemaining:
                  state.capSecondsRemaining ?? ChargingMonitor.maxChargeSeconds,
            ),
            ChargingPhase.done => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 88,
                    color: SkpColors.accentBright,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    state.stopReason?.title ?? 'Charging finished',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.stopReason?.detail ?? 'The socket is off.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: SkpColors.muted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            ChargingPhase.error => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 72,
                      color: SkpColors.gold,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.statusMessage,
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    if (state.lastError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.lastError!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: SkpColors.muted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          },
        ),
      ),
    );
  }
}

class _ChargingActiveView extends StatelessWidget {
  const _ChargingActiveView({
    required this.charging,
    required this.relayOn,
    required this.statusMessage,
    this.volts,
    this.currentMa,
    this.powerW,
    this.remainingLabel,
    this.totalSeconds,
    this.secondsRemaining,
  });

  final bool charging;
  final bool relayOn;
  final String statusMessage;
  final double? volts;
  final double? currentMa;
  final double? powerW;
  final String? remainingLabel;
  final int? totalSeconds;
  final int? secondsRemaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showCap =
        charging &&
        remainingLabel != null &&
        totalSeconds != null &&
        secondsRemaining != null;
    final progress = !showCap || totalSeconds! <= 0
        ? 0.0
        : 1.0 - (secondsRemaining! / totalSeconds!);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SkpColors.accent.withValues(alpha: 0.18),
              ),
              child: Icon(
                charging ? Icons.battery_charging_full : Icons.power,
                size: 64,
                color: relayOn ? SkpColors.accentBright : SkpColors.muted,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              charging ? 'Phone connected' : 'Socket is on',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            if (statusMessage !=
                (charging ? 'Phone connected' : 'Socket is on')) ...[
              const SizedBox(height: 8),
              Text(
                statusMessage,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: SkpColors.muted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (volts != null || currentMa != null || powerW != null) ...[
              const SizedBox(height: 20),
              Text(
                _readingsLabel(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (showCap) ...[
              const SizedBox(height: 32),
              Text(
                remainingLabel!,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Safety limit remaining',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: SkpColors.muted,
                ),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 12,
                  backgroundColor: SkpColors.raised,
                  color: SkpColors.accentBright,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _readingsLabel() {
    final parts = <String>[];
    if (volts != null) {
      parts.add('${volts!.toStringAsFixed(2)} V');
    }
    if (currentMa != null) {
      parts.add('${currentMa!.round()} mA');
    }
    if (powerW != null) {
      parts.add('${powerW!.toStringAsFixed(2)} W');
    }
    return parts.join('  ·  ');
  }
}
