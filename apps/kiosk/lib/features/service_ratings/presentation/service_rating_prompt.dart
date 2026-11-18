import 'dart:async';

import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/kiosk_buttons.dart';

/// Optional 1–5 star prompt. Skip / timeout / tap-star all finish via callbacks.
class ServiceRatingPrompt extends StatefulWidget {
  const ServiceRatingPrompt({
    super.key,
    required this.onRated,
    required this.onSkip,
    this.autoContinue = const Duration(seconds: 10),
    this.title = 'How was your experience?',
    this.subtitle = 'Tap a star to rate, or skip.',
  });

  final ValueChanged<int> onRated;
  final VoidCallback onSkip;
  final Duration? autoContinue;
  final String title;
  final String subtitle;

  @override
  State<ServiceRatingPrompt> createState() => _ServiceRatingPromptState();
}

class _ServiceRatingPromptState extends State<ServiceRatingPrompt> {
  Timer? _timer;
  var _finished = false;
  int _preview = 0;

  @override
  void initState() {
    super.initState();
    final wait = widget.autoContinue;
    if (wait != null) {
      _timer = Timer(wait, _skip);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _skip() {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    widget.onSkip();
  }

  void _rate(int stars) {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    setState(() => _preview = stars);
    widget.onRated(stars);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: SkpTokens.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Icon(Icons.star_outline_rounded, size: 72, color: SkpColors.gold),
          const SizedBox(height: 24),
          Text(
            widget.title,
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            widget.subtitle,
            style: theme.textTheme.titleMedium?.copyWith(color: SkpColors.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: IconButton(
                    onPressed: () => _rate(i),
                    iconSize: 56,
                    icon: Icon(
                      i <= _preview ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: SkpColors.gold,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          KioskGhostButton(
            label: 'Skip',
            icon: Icons.close,
            onPressed: _skip,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
