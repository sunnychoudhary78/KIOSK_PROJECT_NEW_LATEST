import 'package:flutter/material.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';

/// Cream / soft teal atmospheric background with consistent SafeArea padding.
class SkpScaffold extends StatelessWidget {
  const SkpScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottom,
    this.padding = SkpTokens.pagePadding,
    this.safeAreaBottom = true,
    this.useAtmosphere = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottom;
  final EdgeInsetsGeometry padding;
  final bool safeAreaBottom;
  final bool useAtmosphere;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SkpColors.cream,
      extendBodyBehindAppBar: appBar != null,
      appBar: appBar,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (useAtmosphere) const _Atmosphere(),
          SafeArea(
            bottom: safeAreaBottom,
            child: Padding(
              padding: padding,
              child: body,
            ),
          ),
        ],
      ),
      bottomNavigationBar: bottom == null
          ? null
          : Material(
              color: SkpColors.panel.withValues(alpha: 0.96),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: bottom,
                ),
              ),
            ),
    );
  }
}

class _Atmosphere extends StatelessWidget {
  const _Atmosphere();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            SkpColors.atmosphere,
            SkpColors.cream,
            SkpColors.creamDeep.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: const Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _Blob(
              size: 220,
              color: Color(0x1A0F6A5A),
            ),
          ),
          Positioned(
            bottom: 40,
            left: -90,
            child: _Blob(
              size: 260,
              color: Color(0x120F6A5A),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
