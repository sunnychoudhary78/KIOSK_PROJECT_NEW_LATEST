import 'dart:async';

import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';

class KioskClock extends StatefulWidget {
  const KioskClock({super.key});

  @override
  State<KioskClock> createState() => _KioskClockState();
}

class _KioskClockState extends State<KioskClock> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hh = _now.hour.toString().padLeft(2, '0');
    final mm = _now.minute.toString().padLeft(2, '0');
    return Text(
      '$hh:$mm',
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: SkpColors.text,
            fontFeatures: const [FontFeature.tabularFigures()],
            letterSpacing: 1.2,
          ),
    );
  }
}
