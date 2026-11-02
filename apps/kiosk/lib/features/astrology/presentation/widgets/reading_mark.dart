import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_theme.dart';

enum AstrologyReadingKind { kundali, palm, match, today }

extension AstrologyReadingKindStyle on AstrologyReadingKind {
  Color get accent => switch (this) {
    AstrologyReadingKind.kundali => AstrologyColors.kundali,
    AstrologyReadingKind.palm => AstrologyColors.palm,
    AstrologyReadingKind.match => AstrologyColors.matchRose,
    AstrologyReadingKind.today => AstrologyColors.today,
  };
}

/// Drawn mark for a reading. No bitmap artwork.
class ReadingEmblem extends StatelessWidget {
  const ReadingEmblem({
    super.key,
    required this.kind,
    this.size = 56,
    this.color,
  });

  final AstrologyReadingKind kind;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? kind.accent;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ReadingEmblemPainter(kind: kind, color: accent),
      ),
    );
  }
}

class _ReadingEmblemPainter extends CustomPainter {
  const _ReadingEmblemPainter({required this.kind, required this.color});

  final AstrologyReadingKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.46;
    final halo = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, halo);
    final ring = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(center, radius, ring);

    switch (kind) {
      case AstrologyReadingKind.kundali:
        _diamond(canvas, center, radius * 0.62, color);
      case AstrologyReadingKind.palm:
        _palm(canvas, center, radius, color);
      case AstrologyReadingKind.match:
        _rings(canvas, center, radius * 0.42);
      case AstrologyReadingKind.today:
        _crescent(canvas, center, radius * 0.55, color);
    }
  }

  void _diamond(Canvas canvas, Offset center, double half, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 4);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: half * 2, height: half * 2),
      paint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: half * 1.15,
        height: half * 1.15,
      ),
      paint..strokeWidth = 1,
    );
    canvas.restore();
  }

  void _palm(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    final palm = Rect.fromCenter(
      center: center.translate(0, radius * 0.08),
      width: radius * 0.72,
      height: radius * 0.9,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(palm, Radius.circular(radius * 0.28)),
      paint,
    );
    for (var i = 0; i < 3; i++) {
      final y = palm.top + palm.height * (0.32 + i * 0.16);
      final path = Path()
        ..moveTo(palm.left + 6, y)
        ..quadraticBezierTo(
          palm.center.dx,
          y - 6,
          palm.right - 6,
          y + 2,
        );
      canvas.drawPath(path, paint);
    }
  }

  void _rings(Canvas canvas, Offset center, double radius) {
    final left = Paint()
      ..color = AstrologyColors.matchIndigo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final right = Paint()
      ..color = AstrologyColors.matchRose
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(center.translate(-radius * 0.45, 0), radius, left);
    canvas.drawCircle(center.translate(radius * 0.45, 0), radius, right);
  }

  void _crescent(Canvas canvas, Offset center, double radius, Color color) {
    final bounds = Rect.fromCircle(center: center, radius: radius + 2);
    canvas.saveLayer(bounds, Paint());
    canvas.drawCircle(center, radius, Paint()..color = color);
    canvas.drawCircle(
      center.translate(radius * 0.42, -radius * 0.08),
      radius * 0.78,
      Paint()..blendMode = BlendMode.dstOut,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ReadingEmblemPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.color != color;
  }
}

/// Hub tile: accent wash, drawn emblem, and an icon in that accent.
class AstrologyReadingCard extends StatelessWidget {
  const AstrologyReadingCard({
    super.key,
    required this.kind,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final AstrologyReadingKind kind;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = kind.accent;
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Color.alphaBlend(
              accent.withValues(alpha: 0.18),
              AstrologyColors.panelSolid,
            ),
            border: Border.all(color: accent.withValues(alpha: 0.55)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Row(
              children: [
                ReadingEmblem(kind: kind, size: 84),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: accent, size: 26),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AstrologyColors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AstrologyColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
