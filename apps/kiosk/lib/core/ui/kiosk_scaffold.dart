import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';

class KioskScaffold extends StatelessWidget {
  const KioskScaffold({
    super.key,
    required this.body,
    this.useAtmosphere = true,
  });

  final Widget body;
  final bool useAtmosphere;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: SkpColors.canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (useAtmosphere) const IgnorePointer(child: KioskAtmosphere()),
          body,
        ],
      ),
    );
  }
}

class KioskAtmosphere extends StatelessWidget {
  const KioskAtmosphere({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.7, -0.85),
              radius: 1.15,
              colors: [
                Color(0x330F6A5A),
                Color(0x000B1419),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.85, 1.05),
              radius: 0.9,
              colors: [
                Color(0x220F6A5A),
                Color(0x000B1419),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
