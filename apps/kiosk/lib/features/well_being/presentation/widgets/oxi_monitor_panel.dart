import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skp_kiosk/features/well_being/application/well_being_state.dart';

/// Clinical monitor style for desktop SpO₂ / BPM (pulse + oxygen waveforms).
class OxiMonitorPanel extends StatefulWidget {
  const OxiMonitorPanel({
    super.key,
    required this.state,
    this.complete = false,
  });

  final WellBeingUiState state;
  final bool complete;

  @override
  State<OxiMonitorPanel> createState() => _OxiMonitorPanelState();
}

class _OxiMonitorPanelState extends State<OxiMonitorPanel>
    with SingleTickerProviderStateMixin {
  static const _pulseColor = Color(0xFFE07A6A);
  static const _spo2Color = Color(0xFF5BDBD3);
  static const _cardBg = Color(0xFF22272B);
  static const _panelBg = Color(0xFF1A1D21);
  static const _muted = Color(0xFF9AA3AB);
  static const _grid = Color(0xFF2E343A);

  late final AnimationController _ticker;
  final List<double> _pulseSamples = <double>[];
  final List<double> _spo2Samples = <double>[];
  double _phase = 0;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 40),
    )..addListener(_onTick);
    if (!widget.complete) {
      _ticker.repeat();
    } else {
      _seedCompleteWaveforms();
    }
  }

  @override
  void didUpdateWidget(covariant OxiMonitorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.complete && !oldWidget.complete) {
      _ticker.stop();
      _seedCompleteWaveforms();
    } else if (!widget.complete && oldWidget.complete) {
      _pulseSamples.clear();
      _spo2Samples.clear();
      _ticker.repeat();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!mounted || widget.complete) return;
    final progress = widget.state.measureProgress.clamp(0.0, 1.0);
    final signal = _signalStrength(progress);
    _phase += 0.22 + (progress * 0.08);

    // PPG-like pulse (sharper peaks).
    final bpmHint = widget.state.liveHeartRate ?? widget.state.finalHeartRate;
    final beatHz = bpmHint == null ? 1.15 : (bpmHint / 60.0).clamp(0.9, 2.2);
    final t = _phase * beatHz;
    final pulseWave = _ppgWave(t) * signal + (1 - signal) * 0.08 * math.sin(t);

    // Smoother SpO₂ baseline oscillation.
    final spo2Wave =
        (0.55 * math.sin(_phase * 0.55) + 0.25 * math.sin(_phase * 0.18 + 1.2)) *
            signal;

    _push(_pulseSamples, pulseWave, max: 180);
    _push(_spo2Samples, spo2Wave, max: 180);
    setState(() {});
  }

  void _seedCompleteWaveforms() {
    _pulseSamples.clear();
    _spo2Samples.clear();
    final bpm = widget.state.finalHeartRate ?? 72;
    final beatHz = (bpm / 60.0).clamp(0.9, 2.2);
    for (var i = 0; i < 180; i++) {
      final t = i * 0.18 * beatHz;
      _pulseSamples.add(_ppgWave(t));
      _spo2Samples.add(
        0.55 * math.sin(i * 0.08) + 0.25 * math.sin(i * 0.03 + 1.2),
      );
    }
  }

  double _signalStrength(double progress) {
    if (widget.complete) return 1;
    if (progress < 0.08) return 0.12;
    if (progress < 0.25) return 0.35;
    return (0.45 + progress * 0.55).clamp(0.0, 1.0);
  }

  double _ppgWave(double t) {
    final cycle = t % (math.pi * 2);
    // Main systolic peak + small dicrotic notch.
    final main = math.exp(-math.pow((cycle - 0.9) * 2.4, 2).toDouble()) * 1.15;
    final notch = math.exp(-math.pow((cycle - 2.0) * 3.2, 2).toDouble()) * 0.35;
    return (main + notch - 0.15).clamp(-0.4, 1.2);
  }

  void _push(List<double> buffer, double value, {required int max}) {
    buffer.add(value);
    while (buffer.length > max) {
      buffer.removeAt(0);
    }
  }

  String _formatValue(double? value, {int digits = 0}) {
    if (value == null) return '– –';
    if (digits == 0) return value.round().toString();
    return value.toStringAsFixed(digits);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final progress = state.measureProgress.clamp(0.0, 1.0);
    final signal = _signalStrength(progress);
    final bpm = widget.complete
        ? state.finalHeartRate
        : (state.liveHeartRate ?? state.finalHeartRate);
    final spo2 = widget.complete
        ? state.finalSpO2
        : (state.liveSpO2 ?? state.finalSpO2);

    final pulseHint = bpm != null
        ? (widget.complete
            ? state.heartRateInterpretation
            : 'Live pulse · keep finger still')
        : (signal < 0.35
            ? 'Signal too weak. Keep still and re-place your finger.'
            : (state.statusMessage ?? 'Acquiring pulse…'));

    final spo2Hint = spo2 != null
        ? (widget.complete
            ? state.spo2Interpretation
            : 'Oxygen reading improving…')
        : (signal < 0.35
            ? 'Signal too weak. Oxygen needs a steady fingertip.'
            : (state.statusMessage ?? 'Acquiring SpO₂…'));

    final bufferedSec =
        ((_pulseSamples.length / 180) * 28).clamp(0, 28).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2C333A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricMonitorCard(
                  label: 'Pulse',
                  value: _formatValue(bpm),
                  unit: 'bpm',
                  accent: _pulseColor,
                  progress: widget.complete ? 1 : signal,
                  hint: pulseHint,
                  cardBg: _cardBg,
                  muted: _muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricMonitorCard(
                  label: 'SpO₂',
                  value: _formatValue(spo2),
                  unit: '%',
                  accent: _spo2Color,
                  progress: widget.complete
                      ? 1
                      : (spo2 != null ? 0.85 : signal * 0.7),
                  hint: spo2Hint,
                  cardBg: _cardBg,
                  muted: _muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _WaveformCard(
            title: 'Pulse waveform',
            trailing: widget.complete
                ? 'session complete'
                : '$bufferedSec s buffered',
            accent: _pulseColor,
            samples: _pulseSamples,
            windowLabelLeft: '-10 s',
            cardBg: _cardBg,
            muted: _muted,
            grid: _grid,
            jagged: true,
          ),
          const SizedBox(height: 12),
          _WaveformCard(
            title: 'SpO₂ waveform',
            trailing: widget.complete ? 'final trend' : 'slow baseline',
            accent: _spo2Color,
            samples: _spo2Samples,
            windowLabelLeft: '-30 s',
            cardBg: _cardBg,
            muted: _muted,
            grid: _grid,
            jagged: false,
          ),
          if (!widget.complete) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: _muted),
                const SizedBox(width: 6),
                Text(
                  state.secondsRemaining > 0
                      ? '${state.secondsRemaining}s remaining'
                      : 'Finishing…',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricMonitorCard extends StatelessWidget {
  const _MetricMonitorCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
    required this.progress,
    required this.hint,
    required this.cardBg,
    required this.muted,
  });

  final String label;
  final String value;
  final String unit;
  final Color accent;
  final double progress;
  final String hint;
  final Color cardBg;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C333A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                unit,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Container(color: const Color(0xFF32383F)),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.04, 1.0),
                    child: Container(color: accent),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.3,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformCard extends StatelessWidget {
  const _WaveformCard({
    required this.title,
    required this.trailing,
    required this.accent,
    required this.samples,
    required this.windowLabelLeft,
    required this.cardBg,
    required this.muted,
    required this.grid,
    required this.jagged,
  });

  final String title;
  final String trailing;
  final Color accent;
  final List<double> samples;
  final String windowLabelLeft;
  final Color cardBg;
  final Color muted;
  final Color grid;
  final bool jagged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C333A)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                trailing,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 110,
            width: double.infinity,
            child: CustomPaint(
              painter: _WaveformPainter(
                samples: samples,
                accent: accent,
                grid: grid,
                jagged: jagged,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                windowLabelLeft,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  color: muted,
                ),
              ),
              const Spacer(),
              Text(
                'now',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  color: muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.samples,
    required this.accent,
    required this.grid,
    required this.jagged,
  });

  final List<double> samples;
  final Color accent;
  final Color grid;
  final bool jagged;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;

    const cols = 10;
    for (var i = 0; i <= cols; i++) {
      final x = size.width * i / cols;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    if (!jagged) {
      for (var i = 0; i <= 3; i++) {
        final y = size.height * i / 3;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    if (samples.length < 2) {
      final idle = Paint()
        ..color = accent.withValues(alpha: 0.35)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final mid = size.height * 0.55;
      canvas.drawLine(Offset(0, mid), Offset(size.width, mid), idle);
      return;
    }

    final path = Path();
    final minV = samples.reduce(math.min);
    final maxV = samples.reduce(math.max);
    final span = (maxV - minV).abs() < 0.05 ? 1.0 : (maxV - minV);
    for (var i = 0; i < samples.length; i++) {
      final x = size.width * i / (samples.length - 1);
      final norm = (samples[i] - minV) / span;
      final y = size.height * (0.82 - norm * 0.68);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final glow = Paint()
      ..color = accent.withValues(alpha: 0.22)
      ..strokeWidth = jagged ? 5 : 4
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final line = Paint()
      ..color = accent
      ..strokeWidth = jagged ? 2.2 : 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, glow);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.accent != accent ||
        oldDelegate.jagged != jagged;
  }
}
