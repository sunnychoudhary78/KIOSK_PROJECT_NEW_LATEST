import 'dart:async';

import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/kiosk_buttons.dart';

/// Full-screen end of a print. Home ends the visitor session immediately,
/// and again on its own if nobody taps.
class KioskPrintResult extends StatefulWidget {
  const KioskPrintResult({
    super.key,
    required this.confirmed,
    required this.onHome,
    this.detail,
    this.autoReturn = const Duration(seconds: 20),
  });

  final bool confirmed;
  final VoidCallback onHome;
  final String? detail;
  final Duration autoReturn;

  @override
  State<KioskPrintResult> createState() => _KioskPrintResultState();
}

class _KioskPrintResultState extends State<KioskPrintResult> {
  Timer? _timer;
  var _left = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.autoReturn, _goHome);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goHome() {
    if (_left) return;
    _left = true;
    _timer?.cancel();
    widget.onHome();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.confirmed ? 'Print successful' : 'Print not confirmed';
    final line = widget.confirmed
        ? 'Collect your pages from the printer'
        : (widget.detail ?? 'Staff will review this print.');
    return Padding(
      padding: SkpTokens.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(
            widget.confirmed ? Icons.check_circle : Icons.help_outline,
            size: 88,
            color: widget.confirmed ? SkpColors.accent : SkpColors.gold,
          ),
          const SizedBox(height: 24),
          Text(title, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            line,
            style: theme.textTheme.titleMedium?.copyWith(color: SkpColors.muted),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          KioskPrimaryButton(label: 'Home', icon: Icons.home, onPressed: _goHome),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
