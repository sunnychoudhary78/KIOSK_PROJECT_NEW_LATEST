import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';
import 'package:skp_kiosk/core/ui/kiosk_wave_background.dart';

class KioskScaffold extends StatelessWidget {
  const KioskScaffold({
    super.key,
    required this.body,
    this.useAtmosphere = true,
    this.cosmic = false,
  });

  final Widget body;
  final bool useAtmosphere;
  final bool cosmic;

  @override
  Widget build(BuildContext context) {
    if (cosmic) {
      return Material(
        color: const Color(0xFF0B1220),
        child: body,
      );
    }

    if (useAtmosphere) {
      return Material(
        color: Colors.transparent,
        child: KioskWaveBackground(child: body),
      );
    }

    final colors = context.athenaColors;
    return Material(
      color: colors.canvas,
      child: body,
    );
  }
}
