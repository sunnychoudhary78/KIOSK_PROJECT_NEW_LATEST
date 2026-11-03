import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:skp_kiosk/features/astrology/application/palm_quality_checker.dart';
import 'package:skp_kiosk/features/astrology/application/palm_roi.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_assets.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_theme.dart';
import 'package:skp_kiosk/features/astrology/presentation/palm_overlay.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/palm_seal_ring.dart';

/// Large circular live preview with orbital rings and optional scan sweep.
class PalmCaptureViewport extends StatelessWidget {
  const PalmCaptureViewport({
    super.key,
    required this.camera,
    required this.cameraReady,
    required this.cameraError,
    required this.quality,
    required this.onRetryCamera,
    required this.orbit,
    required this.pulse,
    required this.seal,
    required this.sweep,
  });

  final CameraController? camera;
  final bool cameraReady;
  final String? cameraError;
  final PalmQualityResult? quality;
  final VoidCallback onRetryCamera;
  final Animation<double> orbit;
  final Animation<double> pulse;
  final Animation<double> seal;
  final Animation<double> sweep;

  @override
  Widget build(BuildContext context) {
    final ready = quality?.ok == true;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([orbit, pulse, seal, sweep]),
                  builder: (context, child) {
                    final glow = ready ? 0.38 + pulse.value * 0.42 : 0.16;
                    final frameOpacity = ready ? 0.98 : 0.88;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          painter: _OrbitRingsPainter(
                            t: orbit.value,
                            ready: ready,
                            pulse: pulse.value,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(side * 0.08),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AstrologyColors.gold
                                        .withValues(alpha: glow * 0.45),
                                    blurRadius:
                                        34 + (ready ? pulse.value * 18 : 0),
                                    spreadRadius: ready ? 1 : 0,
                                  ),
                                  BoxShadow(
                                    color: AstrologyColors.palm
                                        .withValues(alpha: glow),
                                    blurRadius:
                                        26 + (ready ? pulse.value * 14 : 0),
                                    spreadRadius: ready ? 2 : 0,
                                  ),
                                ],
                              ),
                              child: ClipOval(child: child),
                            ),
                          ),
                        ),
                        // AI ornamental frame — slow opposite spin over the camera hole.
                        IgnorePointer(
                          child: Transform.rotate(
                            angle: orbit.value * math.pi * 2 * 0.15,
                            child: Opacity(
                              opacity: frameOpacity,
                              child: SizedBox(
                                width: side,
                                height: side,
                                child: const AstrologyAssetImage(
                                  asset: AstrologyAssets.palmCircleFrame,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  child: _PreviewStack(
                    camera: camera,
                    cameraReady: cameraReady,
                    cameraError: cameraError,
                    quality: quality,
                    onRetryCamera: onRetryCamera,
                    seal: seal,
                    sweep: sweep,
                  ),
                ),
                Positioned(
                  left: side * 0.08,
                  right: side * 0.08,
                  bottom: side * 0.05,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PalmQualityChips(quality: quality, compact: true),
                      if (quality?.message != null) ...[
                        const SizedBox(height: 6),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AstrologyColors.panel.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child: Text(
                              quality!.message,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: ready
                                        ? AstrologyColors.palm
                                        : AstrologyColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PreviewStack extends StatelessWidget {
  const _PreviewStack({
    required this.camera,
    required this.cameraReady,
    required this.cameraError,
    required this.quality,
    required this.onRetryCamera,
    required this.seal,
    required this.sweep,
  });

  final CameraController? camera;
  final bool cameraReady;
  final String? cameraError;
  final PalmQualityResult? quality;
  final VoidCallback onRetryCamera;
  final Animation<double> seal;
  final Animation<double> sweep;

  @override
  Widget build(BuildContext context) {
    final ready = quality?.ok == true;
    if (cameraError != null) {
      return ColoredBox(
        color: AstrologyColors.raised,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cameraError!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onRetryCamera,
                  child: const Text('Retry camera'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!cameraReady || camera == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: AstrologyColors.palm),
        ),
      );
    }

    final preview = camera!.value.previewSize;
    final previewW = preview?.height ?? 1280.0;
    final previewH = preview?.width ?? 720.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Colors.black,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: previewW,
                  height: previewH,
                  child: CameraPreview(camera!),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: PalmOverlayPainter(ready: ready),
              ),
            ),
            // Visual guide ~1.28x PalmRoi (quality ROI constants unchanged).
            Positioned(
              left: w * (PalmRoi.centerX - 0.64 / 2),
              top: h * (PalmRoi.centerY - 0.82 / 2),
              width: w * 0.64,
              height: h * 0.82,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: ready ? 0.86 : 0.74,
                  child: const AstrologyAssetImage(
                    asset: AstrologyAssets.palmGuide,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: seal,
                builder: (context, _) => PalmSealRing(progress: seal.value),
              ),
            ),
            if (ready)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: sweep,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _ScanSweepPainter(t: sweep.value),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OrbitRingsPainter extends CustomPainter {
  const _OrbitRingsPainter({
    required this.t,
    required this.ready,
    required this.pulse,
  });

  final double t;
  final bool ready;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = size.shortestSide * 0.5;
    final accent = ready ? AstrologyColors.palm : AstrologyColors.accent;
    final gold = AstrologyColors.gold;

    // Light motion rings — AI frame carries the ornate chrome.
    for (var i = 0; i < 3; i++) {
      final radius =
          base * (0.88 + i * 0.035) + (ready ? pulse * (1.2 + i * 0.3) : 0);
      final ringColor = i.isEven ? accent : gold;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = ringColor.withValues(alpha: 0.18 - i * 0.04)
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == 0 ? 1.8 : 1.2,
      );

      final dir = i.isEven ? 1.0 : -1.0;
      final start = dir * t * math.pi * 2 + i * 1.05;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        math.pi * (0.32 + i * 0.06),
        false,
        Paint()
          ..color = ringColor.withValues(alpha: 0.55 - i * 0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitRingsPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.ready != ready ||
      oldDelegate.pulse != pulse;
}

class _ScanSweepPainter extends CustomPainter {
  const _ScanSweepPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * (0.16 + t * 0.68);

    // Soft trail behind the beam.
    final trail = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          AstrologyColors.accent.withValues(alpha: 0.12),
          AstrologyColors.palm.withValues(alpha: 0.22),
        ],
      ).createShader(Rect.fromLTWH(0, y - 48, size.width, 48));
    canvas.drawRect(Rect.fromLTWH(0, y - 48, size.width, 48), trail);

    final glow = Paint()
      ..color = AstrologyColors.gold.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawRect(Rect.fromLTWH(0, y - 18, size.width, 36), glow);

    final rect = Rect.fromLTWH(0, y - 2.5, size.width, 5);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          AstrologyColors.accent.withValues(alpha: 0.75),
          AstrologyColors.gold.withValues(alpha: 0.95),
          AstrologyColors.palm.withValues(alpha: 1),
          AstrologyColors.gold.withValues(alpha: 0.95),
          AstrologyColors.accent.withValues(alpha: 0.75),
          Colors.transparent,
        ],
      ).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawRect(rect, paint);

    // Bright core line.
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.08, y - 1, size.width * 0.84, 2),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _ScanSweepPainter oldDelegate) =>
      oldDelegate.t != t;
}

/// Compact Scan · Analyze · Insights rail.
class PalmFlowStepRail extends StatelessWidget {
  const PalmFlowStepRail({super.key, required this.activeIndex});

  final int activeIndex;

  static const _labels = ['Scan', 'Analyze', 'Insights'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: i <= activeIndex
                    ? AstrologyColors.palm.withValues(alpha: 0.65)
                    : AstrologyColors.line,
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= activeIndex
                      ? AstrologyColors.palm.withValues(alpha: 0.16)
                      : AstrologyColors.raised,
                  border: Border.all(
                    color: i == activeIndex
                        ? AstrologyColors.palm
                        : i < activeIndex
                            ? AstrologyColors.palm.withValues(alpha: 0.55)
                            : AstrologyColors.line,
                    width: i == activeIndex ? 2 : 1,
                  ),
                ),
                child: Text(
                  '${i + 1}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: i <= activeIndex
                        ? AstrologyColors.palm
                        : AstrologyColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _labels[i],
                style: theme.textTheme.labelSmall?.copyWith(
                  color: i == activeIndex
                      ? AstrologyColors.palm
                      : AstrologyColors.muted,
                  fontWeight:
                      i == activeIndex ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Hand / lighting / position chips from [PalmQualityResult] metrics.
class PalmQualityChips extends StatelessWidget {
  const PalmQualityChips({
    super.key,
    required this.quality,
    this.compact = false,
  });

  final PalmQualityResult? quality;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final q = quality;
    final handOk = q != null &&
        q.skinRatio >= PalmQualityChecker.manualMinInsideSkinRatio &&
        q.fingerSkinRatio >= PalmQualityChecker.manualMinFingerSkinRatio;
    final lightOk = q != null &&
        q.brightness >= PalmQualityChecker.minBrightness &&
        q.brightness <= PalmQualityChecker.maxBrightness &&
        q.blur >= PalmQualityChecker.manualMinBlur;
    final positionOk = q?.ok == true ||
        (q != null &&
            q.centroidOk &&
            q.skinRatio - q.outsideSkinRatio >=
                PalmQualityChecker.manualMinSkinContrast &&
            q.outsideSkinRatio <=
                PalmQualityChecker.manualMaxOutsideSkinRatio &&
            q.roiSkinRatio <= PalmQualityChecker.manualMaxRoiSkinRatio &&
            handOk);

    return Row(
      children: [
        Expanded(
          child: _Chip(
            label: compact ? 'Hand' : 'Hand detected',
            ok: handOk,
            compact: compact,
          ),
        ),
        SizedBox(width: compact ? 6 : 10),
        Expanded(
          child: _Chip(
            label: compact ? 'Lighting' : 'Good lighting',
            ok: lightOk,
            compact: compact,
          ),
        ),
        SizedBox(width: compact ? 6 : 10),
        Expanded(
          child: _Chip(
            label: compact ? 'Position' : 'Proper position',
            ok: positionOk,
            compact: compact,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.ok,
    this.compact = false,
  });

  final String label;
  final bool ok;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AstrologyColors.palm : AstrologyColors.muted;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: ok
            ? AstrologyColors.palm.withValues(alpha: compact ? 0.88 : 0.12)
            : AstrologyColors.panel.withValues(alpha: compact ? 0.88 : 1),
        borderRadius: BorderRadius.circular(compact ? 10 : 14),
        border: Border.all(
          color: ok
              ? AstrologyColors.palm.withValues(alpha: 0.45)
              : AstrologyColors.line,
        ),
        boxShadow: compact
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: compact ? 14 : 18,
            color: compact && ok ? Colors.white : color,
          ),
          SizedBox(width: compact ? 5 : 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: compact && ok ? Colors.white : color,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 11 : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
