import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_state.dart';
import 'package:skp_kiosk/features/well_being/application/well_being_controller.dart';
import 'package:skp_kiosk/features/well_being/application/well_being_state.dart';
import 'package:skp_kiosk/features/well_being/domain/well_being_phase.dart';

/// Firmware-matched pulse oximeter flow (USB Serial).
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wellBeingControllerProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Well Being'),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: 'Serial Debug',
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.serialDebug);
              },
              icon: Icon(
                Icons.bug_report_outlined,
                color: scheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ConnectionBanner(
                    label: state.connectionLabel,
                    portName: state.portName,
                    status: state.connectionStatus,
                    fingerDetected: state.fingerDetected,
                    error: state.lastError,
                    onRetry: state.connectionStatus ==
                                SerialConnectionStatus.error ||
                            state.connectionStatus ==
                                SerialConnectionStatus.disconnected
                        ? () => ref
                            .read(wellBeingControllerProvider.notifier)
                            .retryConnect()
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: switch (state.phase) {
                        WellBeingPhase.idle => _IdleView(
                            key: const ValueKey('idle'),
                            connected: state.isConnected,
                          ),
                        WellBeingPhase.measuring => _MeasuringView(
                            key: const ValueKey('measuring'),
                            state: state,
                          ),
                        WellBeingPhase.cancelled => const _CancelledView(
                            key: ValueKey('cancelled'),
                          ),
                        WellBeingPhase.complete => _CompleteView(
                            key: const ValueKey('complete'),
                            state: state,
                          ),
                      },
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

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({
    required this.label,
    required this.status,
    required this.fingerDetected,
    this.portName,
    this.error,
    this.onRetry,
  });

  final String label;
  final SerialConnectionStatus status;
  final bool fingerDetected;
  final String? portName;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = switch (status) {
      SerialConnectionStatus.connected =>
        fingerDetected ? scheme.tertiary : scheme.primary,
      SerialConnectionStatus.connecting ||
      SerialConnectionStatus.reconnecting =>
        scheme.tertiary,
      SerialConnectionStatus.error => scheme.error,
      SerialConnectionStatus.disconnected =>
        scheme.onSurface.withValues(alpha: 0.45),
    };

    final fingerLabel = !status.isConnected
        ? label
        : (fingerDetected ? 'Finger detected' : 'No finger detected');

    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              status.isConnected
                  ? (fingerDetected ? Icons.back_hand : Icons.sensors)
                  : Icons.sensors_off,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fingerLabel,
                    style: theme.textTheme.titleMedium?.copyWith(color: color),
                  ),
                  Text(
                    [label, ?portName].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  if (error != null && status == SerialConnectionStatus.error)
                    Text(
                      error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                ],
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

extension on SerialConnectionStatus {
  bool get isConnected => this == SerialConnectionStatus.connected;
}

class _IdleView extends StatelessWidget {
  const _IdleView({super.key, required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),
          Icon(Icons.back_hand_outlined, size: 88, color: scheme.primary),
          const SizedBox(height: 20),
          Text(
            connected
                ? 'Place your finger gently on the sensor'
                : 'Connect the sensor to begin',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The measurement starts automatically once your finger is detected.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to place your finger',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
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
                        Text('•  ', style: theme.textTheme.bodyLarge),
                        Expanded(
                          child: Text(tip, style: theme.textTheme.bodyLarge),
                        ),
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

class _MeasuringView extends StatelessWidget {
  const _MeasuringView({super.key, required this.state});

  final WellBeingUiState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            'Keep your finger still',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Do not move or press too hard during measurement.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 20),
          _ValidCountPipeline(validCount: state.validCount),
          const SizedBox(height: 24),
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: state.measureProgress,
                    strokeWidth: 10,
                    backgroundColor: scheme.primary.withValues(alpha: 0.15),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${state.secondsRemaining}',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                    Text(
                      'SECONDS',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Signal: ${state.signalLabel}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Heart Rate',
                  value: state.liveHeartRate == null
                      ? 'Calculating…'
                      : '${state.liveHeartRate!.round()}',
                  unit: 'BPM',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Blood Oxygen',
                  value: state.liveSpO2 == null
                      ? 'Calculating…'
                      : '${state.liveSpO2!.round()}',
                  unit: 'SpO₂',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ValidCountPipeline extends StatelessWidget {
  const _ValidCountPipeline({required this.validCount});

  final int validCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 3; i++) ...[
          if (i > 1)
            Container(
              width: 36,
              height: 2,
              color: i <= validCount
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.15),
            ),
          _PipelineDot(
            index: i,
            complete: i <= validCount,
            current: i == validCount + 1 && validCount < 3,
          ),
        ],
      ],
    );
  }
}

class _PipelineDot extends StatelessWidget {
  const _PipelineDot({
    required this.index,
    required this.complete,
    required this.current,
  });

  final int index;
  final bool complete;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = complete
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: 0.08);
    final fg = complete ? scheme.onPrimary : scheme.onSurface.withValues(alpha: 0.55);

    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(
              color: current || complete
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.15),
              width: 2,
            ),
          ),
          child: Text(
            '$index',
            style: theme.textTheme.titleSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Reading $index',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.55),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CancelledView extends StatelessWidget {
  const _CancelledView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.highlight_off, size: 72, color: scheme.error),
        const SizedBox(height: 16),
        Text(
          'Finger Removed',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: scheme.error,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Measurement cancelled. Place your finger again to restart.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _CompleteView extends StatelessWidget {
  const _CompleteView({super.key, required this.state});

  final WellBeingUiState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SingleChildScrollView(
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: scheme.primary),
          const SizedBox(height: 12),
          Text(
            'Measurement Complete',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You may now remove your finger',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Heart Rate',
                  value: state.finalHeartRate == null
                      ? '—'
                      : '${state.finalHeartRate!.round()}',
                  unit: 'BPM',
                  caption: state.heartRateInterpretation,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Blood Oxygen',
                  value: state.finalSpO2 == null
                      ? '—'
                      : '${state.finalSpO2!.round()}',
                  unit: 'SpO₂',
                  caption: state.spo2Interpretation,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.onSurface.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reference ranges',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Heart rate (adult): 60 – 100 BPM',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  'Blood oxygen: 95 – 100%',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
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
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.55),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            unit,
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 10),
            Text(
              caption!,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
