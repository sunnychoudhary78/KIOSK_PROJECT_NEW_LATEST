import 'package:flutter/material.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';

class SkpPanelCard extends StatelessWidget {
  const SkpPanelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.radius = SkpTokens.radiusLg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: const BorderSide(color: SkpColors.line),
    );
    return Material(
      color: SkpColors.panel,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

class SkpIconWell extends StatelessWidget {
  const SkpIconWell({
    super.key,
    required this.icon,
    this.size = 52,
    this.iconSize = 24,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: SkpColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
      ),
      child: Icon(icon, color: SkpColors.accent, size: iconSize),
    );
  }
}
