import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_state.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';
import 'package:skp_kiosk/features/well_being/application/well_being_controller.dart';
import 'package:skp_kiosk/features/well_being/application/well_being_state.dart';
import 'package:skp_kiosk/features/well_being/domain/well_being_mode.dart';
import 'package:skp_kiosk/features/well_being/domain/well_being_phase.dart';

/// Dual-sensor Well Being flow (USB Serial JSON protocol).
class WellBeingPage extends ConsumerStatefulWidget {
  const WellBeingPage({super.key});

  @override
  ConsumerState<WellBeingPage> createState() => _WellBeingPageState();
}

class _WellBeingPageState extends ConsumerState<WellBeingPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(wellBeingControllerProvider.notifier).startSession();
    });
  }

  Future<void> _endSession() {
    return ref
        .read(kioskSessionControllerProvider.notifier)
        .endVisitorSession(attract: false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wellBeingControllerProvider);
    final controller = ref.read(wellBeingControllerProvider.notifier);
    final showBack = state.phase != WellBeingPhase.choose &&
        state.connectionStatus != SerialConnectionStatus.connecting;
    final complete = state.phase == WellBeingPhase.oxiComplete ||
        state.phase == WellBeingPhase.tempComplete;

    return VisitorSessionPopScope(
      child: KioskShell(
        title: 'Well Being',
        onHome: _endSession,
        headerExtra: kDebugMode
            ? IconButton(
                tooltip: 'Serial Debug',
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.serialDebug);
                },
                icon: const Icon(Icons.bug_report_outlined, color: SkpColors.muted),
              )
            : null,
        stepLabel: switch (state.phase) {
          WellBeingPhase.choose => 'Choose',
          WellBeingPhase.oxiIdle ||
          WellBeingPhase.oxiMeasuring ||
          WellBeingPhase.oxiCancelled =>
            'Blood oxygen',
          WellBeingPhase.oxiComplete => 'Results',
          WellBeingPhase.tempMeasuring => 'Temperature',
          WellBeingPhase.tempComplete => 'Results',
        },
        footerLeading: showBack
            ? KioskGhostButton(
                label: 'Back',
                icon: Icons.arrow_back,
                onPressed: () => controller.returnToHub(),
              )
            : KioskGhostButton(label: 'Cancel', onPressed: _endSession),
        footerTrailing: complete
            ? KioskPrimaryButton(
                label: 'Done',
                onPressed: () => controller.returnToHub(),
              )
            : null,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(32, 12, 32, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ConnectionBanner(
                label: state.connectionLabel,
                portName: state.portName,
                status: state.connectionStatus,
                activeMode: state.activeMode,
                fingerDetected: state.fingerDetected,
                error: state.lastError,
                onRetry: state.connectionStatus == SerialConnectionStatus.error ||
                        state.connectionStatus == SerialConnectionStatus.disconnected
                    ? () => controller.retryConnect()
                    : null,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: switch (state.phase) {
                    WellBeingPhase.choose => _ChooseView(
                        key: const ValueKey('choose'),
                        connected: state.isConnected,
                        onOxygen: () => controller.startOxygen(),
                        onTemperature: () => controller.startTemperature(),
                      ),
                    WellBeingPhase.oxiIdle => _OxiIdleView(
                        key: const ValueKey('oxiIdle'),
                        connected: state.isConnected,
                      ),
                    WellBeingPhase.oxiMeasuring => _OxiMeasuringView(
                        key: const ValueKey('oxiMeasuring'),
                        state: state,
                      ),
                    WellBeingPhase.oxiCancelled => const _OxiCancelledView(
                        key: ValueKey('oxiCancelled'),
                      ),
                    WellBeingPhase.oxiComplete => _OxiCompleteView(
                        key: const ValueKey('oxiComplete'),
                        state: state,
                      ),
                    WellBeingPhase.tempMeasuring => _TempMeasuringView(
                        key: const ValueKey('tempMeasuring'),
                        state: state,
                      ),
                    WellBeingPhase.tempComplete => _TempCompleteView(
                        key: const ValueKey('tempComplete'),
                        state: state,
                      ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({
    required this.label,
    required this.status,
    required this.activeMode,
    required this.fingerDetected,
    this.portName,
    this.error,
    this.onRetry,
  });

  final String label;
  final SerialConnectionStatus status;
  final WellBeingMode activeMode;
  final bool fingerDetected;
  final String? portName;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      SerialConnectionStatus.connected =>
        fingerDetected || activeMode == WellBeingMode.temp
            ? KioskBannerTone.success
            : KioskBannerTone.info,
      SerialConnectionStatus.connecting ||
      SerialConnectionStatus.reconnecting =>
        KioskBannerTone.warning,
      SerialConnectionStatus.error => KioskBannerTone.danger,
      SerialConnectionStatus.disconnected => KioskBannerTone.warning,
    };

    final detailLabel = !status.isConnected
        ? label
        : switch (activeMode) {
            WellBeingMode.oxi =>
              fingerDetected ? 'Finger detected' : 'No finger detected',
            WellBeingMode.temp => 'Temperature mode',
            WellBeingMode.none => 'Ready',
          };

    return KioskStatusBanner(
      message: detailLabel,
      detail: [label, ?portName, if (error != null && status == SerialConnectionStatus.error) error!].join(' · '),
      tone: tone,
      icon: status.isConnected
          ? switch (activeMode) {
              WellBeingMode.temp => Icons.thermostat,
              WellBeingMode.oxi => fingerDetected ? Icons.back_hand : Icons.sensors,
              WellBeingMode.none => Icons.favorite_outline,
            }
          : Icons.sensors_off,
      actionLabel: onRetry != null ? 'Retry' : null,
      onAction: onRetry,
    );
  }
}

extension on SerialConnectionStatus {
  bool get isConnected => this == SerialConnectionStatus.connected;
}

class _ChooseView extends StatelessWidget {
  const _ChooseView({
    super.key,
    required this.connected,
    required this.onOxygen,
    required this.onTemperature,
  });

  final bool connected;
  final VoidCallback onOxygen;
  final VoidCallback onTemperature;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          connected ? 'Choose a measurement' : 'Connect the sensor to begin',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Select Blood Oxygen or Temperature. Only one sensor runs at a time.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: SkpColors.muted),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _ModeOptionCard(
                  icon: Icons.bloodtype_outlined,
                  title: 'Blood Oxygen',
                  subtitle: 'Heart rate and SpO₂ with your fingertip (~20s)',
                  enabled: connected,
                  onTap: onOxygen,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ModeOptionCard(
                  icon: Icons.thermostat_outlined,
                  title: 'Temperature',
                  subtitle: 'Non-contact reading — hold near the sensor (~30s)',
                  enabled: connected,
                  onTap: onTemperature,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeOptionCard extends StatelessWidget {
  const _ModeOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: enabled ? SkpColors.panel : SkpColors.canvas,
      borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
            border: Border.all(
              color: enabled ? SkpColors.accent.withValues(alpha: 0.45) : SkpColors.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 48,
                color: enabled ? SkpColors.accentBright : SkpColors.muted,
              ),
              const Spacer(),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: enabled ? SkpColors.text : SkpColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: enabled ? SkpColors.muted : SkpColors.muted.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OxiIdleView extends StatelessWidget {
  const _OxiIdleView({super.key, required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        children: [
          const Icon(Icons.back_hand_outlined, size: 88, color: SkpColors.accentBright),
          const SizedBox(height: 16),
          Text(
            connected
                ? 'Place your finger gently on the sensor'
                : 'Connect the sensor to begin',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Measurement starts automatically once your finger is detected.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: SkpColors.muted),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SkpColors.panel,
              borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
              border: Border.all(color: SkpColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to place your finger',
                  style: theme.textTheme.titleMedium?.copyWith(color: SkpColors.accentBright),
                ),
                const SizedBox(height: 12),
                ...const [
                  'Rest your fingertip flat over the sensor window.',
                  'Apply light, steady pressure — do not press hard.',
                  'Keep your hand relaxed and still.',
                  'Stay still for the full measurement once it begins.',
                ].map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ', style: TextStyle(color: SkpColors.gold)),
                        Expanded(child: Text(tip, style: theme.textTheme.bodyLarge)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OxiMeasuringView extends StatelessWidget {
  const _OxiMeasuringView({super.key, required this.state});

  final WellBeingUiState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text('Keep your finger still', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            state.statusMessage ?? 'Do not move or press too hard during measurement.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: SkpColors.muted),
          ),
          const SizedBox(height: 24),
          _TimerRing(seconds: state.secondsRemaining, progress: state.measureProgress),
          const SizedBox(height: 24),
          const Row(
            children: [
              Expanded(child: _MetricCard(title: 'Heart Rate', value: '…', unit: 'BPM')),
              SizedBox(width: 12),
              Expanded(child: _MetricCard(title: 'Blood Oxygen', value: '…', unit: 'SpO₂')),
            ],
          ),
        ],
      ),
    );
  }
}

class _OxiCancelledView extends StatelessWidget {
  const _OxiCancelledView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.highlight_off, size: 72, color: SkpColors.danger),
        const SizedBox(height: 16),
        Text(
          'Finger Removed',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: SkpColors.danger),
        ),
        const SizedBox(height: 8),
        Text(
          'Measurement cancelled. Returning to options…',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: SkpColors.muted),
        ),
      ],
    );
  }
}

class _OxiCompleteView extends StatelessWidget {
  const _OxiCompleteView({super.key, required this.state});

  final WellBeingUiState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline, size: 64, color: SkpColors.accentBright),
          const SizedBox(height: 12),
          Text('Measurement Complete', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'You may now remove your finger',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: SkpColors.muted),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Heart Rate',
                  value: state.finalHeartRate == null ? '—' : '${state.finalHeartRate!.round()}',
                  unit: 'BPM',
                  caption: state.heartRateInterpretation,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Blood Oxygen',
                  value: state.finalSpO2 == null ? '—' : '${state.finalSpO2!.round()}',
                  unit: 'SpO₂',
                  caption: state.spo2Interpretation,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _ReferenceCard(
            lines: [
              'Heart rate (adult): 60 – 100 BPM',
              'Blood oxygen: 95 – 100%',
            ],
          ),
          const SizedBox(height: 12),
          const _MedicalDisclaimer(),
        ],
      ),
    );
  }
}

class _TempMeasuringView extends StatelessWidget {
  const _TempMeasuringView({super.key, required this.state});

  final WellBeingUiState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const Icon(Icons.thermostat, size: 72, color: SkpColors.accentBright),
          const SizedBox(height: 12),
          Text('Temperature', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            state.statusMessage ?? 'Hold steady near the temperature sensor',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: SkpColors.muted),
          ),
          const SizedBox(height: 24),
          _TimerRing(seconds: state.secondsRemaining, progress: state.measureProgress),
        ],
      ),
    );
  }
}

class _TempCompleteView extends StatelessWidget {
  const _TempCompleteView({super.key, required this.state});

  final WellBeingUiState state;

  @override
  Widget build(BuildContext context) {
    final c = state.finalTempC;
    final f = state.finalTempF;
    return SingleChildScrollView(
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline, size: 64, color: SkpColors.accentBright),
          const SizedBox(height: 12),
          Text('Temperature Captured', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          _MetricCard(
            title: 'Temperature',
            value: c == null ? '—' : c.toStringAsFixed(1),
            unit: '°C',
            caption: state.temperatureInterpretation,
          ),
          if (f != null) ...[
            const SizedBox(height: 8),
            Text(
              '${f.toStringAsFixed(1)} °F',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: SkpColors.muted),
            ),
          ],
          const SizedBox(height: 16),
          const _ReferenceCard(lines: ['Typical body temperature: 36.1 – 37.2 °C']),
          const SizedBox(height: 12),
          const _MedicalDisclaimer(),
        ],
      ),
    );
  }
}

class _TimerRing extends StatelessWidget {
  const _TimerRing({required this.seconds, required this.progress});

  final int seconds;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: CircularProgressIndicator(
              value: progress > 0 ? progress : null,
              strokeWidth: 12,
              backgroundColor: SkpColors.accent.withValues(alpha: 0.2),
              color: SkpColors.accentBright,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$seconds',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: SkpColors.accentBright,
                    ),
              ),
              Text('SECONDS', style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.unit,
    this.caption,
  });

  final String title;
  final String value;
  final String unit;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
      decoration: BoxDecoration(
        color: SkpColors.panel,
        borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
        border: Border.all(color: SkpColors.line),
      ),
      child: Column(
        children: [
          Text(title, style: theme.textTheme.labelLarge?.copyWith(color: SkpColors.muted)),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.headlineMedium),
          Text(unit, style: theme.textTheme.titleMedium?.copyWith(color: SkpColors.muted)),
          if (caption != null) ...[
            const SizedBox(height: 10),
            Text(
              caption!,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(color: SkpColors.accentBright),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
        border: Border.all(color: SkpColors.line),
        color: SkpColors.raised,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reference ranges',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: SkpColors.muted),
          ),
          const SizedBox(height: 8),
          for (final line in lines) Text(line, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _MedicalDisclaimer extends StatelessWidget {
  const _MedicalDisclaimer();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Not a medical diagnosis. These readings are for general wellness only and are not a substitute for professional medical advice.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
