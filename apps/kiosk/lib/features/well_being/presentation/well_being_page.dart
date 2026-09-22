import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_state.dart';
import 'package:skp_kiosk/features/well_being/application/well_being_controller.dart';
import 'package:skp_kiosk/features/well_being/application/well_being_state.dart';
import 'package:skp_kiosk/features/well_being/domain/well_being_mode.dart';
import 'package:skp_kiosk/features/well_being/domain/well_being_phase.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wellBeingControllerProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final controller = ref.read(wellBeingControllerProvider.notifier);
    final showBack = state.phase != WellBeingPhase.choose &&
        state.connectionStatus != SerialConnectionStatus.connecting;

    return VisitorSessionPopScope(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Well Being'),
        leading: showBack
            ? IconButton(
                tooltip: 'Back to options',
                onPressed: () => controller.returnToHub(),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
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
                    activeMode: state.activeMode,
                    fingerDetected: state.fingerDetected,
                    error: state.lastError,
                    onRetry: state.connectionStatus ==
                                SerialConnectionStatus.error ||
                            state.connectionStatus ==
                                SerialConnectionStatus.disconnected
                        ? () => controller.retryConnect()
                        : null,
                  ),
                  const SizedBox(height: 20),
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
                            onDone: () => controller.returnToHub(),
                          ),
                        WellBeingPhase.tempMeasuring => _TempMeasuringView(
                            key: const ValueKey('tempMeasuring'),
                            state: state,
                          ),
                        WellBeingPhase.tempComplete => _TempCompleteView(
                            key: const ValueKey('tempComplete'),
                            state: state,
                            onDone: () => controller.returnToHub(),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = switch (status) {
      SerialConnectionStatus.connected =>
        fingerDetected || activeMode == WellBeingMode.temp
            ? scheme.tertiary
            : scheme.primary,
      SerialConnectionStatus.connecting ||
      SerialConnectionStatus.reconnecting =>
        scheme.tertiary,
      SerialConnectionStatus.error => scheme.error,
      SerialConnectionStatus.disconnected =>
        scheme.onSurface.withValues(alpha: 0.45),
    };

    final detailLabel = !status.isConnected
        ? label
        : switch (activeMode) {
            WellBeingMode.oxi =>
              fingerDetected ? 'Finger detected' : 'No finger detected',
            WellBeingMode.temp => 'Temperature mode',
            WellBeingMode.none => 'Ready',
          };

    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              status.isConnected
                  ? switch (activeMode) {
                      WellBeingMode.temp => Icons.thermostat,
                      WellBeingMode.oxi =>
                        fingerDetected ? Icons.back_hand : Icons.sensors,
                      WellBeingMode.none => Icons.favorite_outline,
                    }
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
                    detailLabel,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            connected ? 'Choose a measurement' : 'Connect the sensor to begin',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select Blood Oxygen or Temperature. Only one sensor runs at a time.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 28),
          _ModeOptionCard(
            icon: Icons.bloodtype_outlined,
            title: 'Blood Oxygen',
            subtitle: 'Heart rate and SpO₂ with your fingertip (~20s)',
            enabled: connected,
            onTap: onOxygen,
          ),
          const SizedBox(height: 16),
          _ModeOptionCard(
            icon: Icons.thermostat_outlined,
            title: 'Temperature',
            subtitle: 'Non-contact reading — hold near the sensor (~60s)',
            enabled: connected,
            onTap: onTemperature,
          ),
        ],
      ),
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
    final scheme = theme.colorScheme;

    return Material(
      color: enabled
          ? scheme.primary.withValues(alpha: 0.08)
          : scheme.onSurface.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled
                  ? scheme.primary.withValues(alpha: 0.25)
                  : scheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 40,
                color: enabled
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.35),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: enabled
                            ? scheme.onSurface
                            : scheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(
                          alpha: enabled ? 0.65 : 0.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: scheme.onSurface.withValues(alpha: enabled ? 0.45 : 0.2),
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
            'Measurement starts automatically once your finger is detected.',
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

class _OxiMeasuringView extends StatelessWidget {
  const _OxiMeasuringView({super.key, required this.state});

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
            state.statusMessage ??
                'Do not move or press too hard during measurement.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 28),
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
                    value: state.measureProgress > 0
                        ? state.measureProgress
                        : null,
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
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Heart Rate',
                  value: '…',
                  unit: 'BPM',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Blood Oxygen',
                  value: '…',
                  unit: 'SpO₂',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Averaging pulse readings — keep your finger still until the timer finishes.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
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
          'Measurement cancelled. Returning to options…',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _OxiCompleteView extends StatelessWidget {
  const _OxiCompleteView({
    super.key,
    required this.state,
    required this.onDone,
  });

  final WellBeingUiState state;
  final VoidCallback onDone;

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
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onDone,
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _TempMeasuringView extends StatelessWidget {
  const _TempMeasuringView({
    super.key,
    required this.state,
  });

  final WellBeingUiState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 12),
          Icon(Icons.thermostat, size: 72, color: scheme.primary),
          const SizedBox(height: 16),
          Text(
            'Temperature',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.statusMessage ??
                'Hold steady near the temperature sensor',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 32),
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
                    value: state.measureProgress > 0
                        ? state.measureProgress
                        : null,
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
          const SizedBox(height: 24),
          Text(
            'Averaging sensor readings — keep still until the timer finishes.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _TempCompleteView extends StatelessWidget {
  const _TempCompleteView({
    super.key,
    required this.state,
    required this.onDone,
  });

  final WellBeingUiState state;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = state.finalTempC;
    final f = state.finalTempF;

    return SingleChildScrollView(
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: scheme.primary),
          const SizedBox(height: 12),
          Text(
            'Temperature Captured',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 28),
          _MetricCard(
            title: 'Temperature',
            value: c == null ? '—' : c.toStringAsFixed(1),
            unit: '°C',
            caption: state.temperatureInterpretation,
          ),
          if (f != null) ...[
            const SizedBox(height: 12),
            Text(
              '${f.toStringAsFixed(1)} °F',
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
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
                  'Typical body temperature: 36.1 – 37.2 °C',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onDone,
            child: const Text('Done'),
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
