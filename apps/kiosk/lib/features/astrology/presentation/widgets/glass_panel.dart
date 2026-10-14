import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_theme.dart';

/// Frosted glass panel for astrology cards and form surfaces.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.borderColor,
    this.color,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Color? borderColor;
  final Color? color;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? SkpTokens.radiusLg;
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AstrologyColors.panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? AstrologyColors.glassBorder,
          width: SkpTokens.hairline,
        ),
        boxShadow: [
          BoxShadow(
            color: AstrologyColors.gold.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
