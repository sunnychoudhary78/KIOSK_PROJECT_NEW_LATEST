import 'dart:async';

import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/kiosk_buttons.dart';
import 'package:skp_kiosk/core/ui/kiosk_keyboard.dart';

/// Optional 1–5 star prompt. Stars select only; Submit sends the rating.
/// For 1–3 stars, shows optional feedback with [KioskKeyboard].
class ServiceRatingPrompt extends StatefulWidget {
  const ServiceRatingPrompt({
    super.key,
    required this.onSubmitted,
    required this.onSkip,
    this.autoContinue = const Duration(seconds: 10),
    this.title = 'How was your experience?',
    this.subtitle = 'Tap a star to rate, then submit — or skip.',
    this.maxFeedbackLength = 280,
  });

  final void Function(int stars, String? feedback) onSubmitted;
  final VoidCallback onSkip;
  final Duration? autoContinue;
  final String title;
  final String subtitle;
  final int maxFeedbackLength;

  @override
  State<ServiceRatingPrompt> createState() => _ServiceRatingPromptState();
}

class _ServiceRatingPromptState extends State<ServiceRatingPrompt> {
  Timer? _timer;
  var _finished = false;
  int _selectedStars = 0;
  String _feedback = '';

  bool get _needsFeedback => _selectedStars >= 1 && _selectedStars <= 3;

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
    // Auto-timeout only when no stars selected (user not engaged).
    if (_selectedStars > 0 && _timer != null) {
      return;
    }
    _finished = true;
    _timer?.cancel();
    widget.onSkip();
  }

  void _selectStars(int stars) {
    if (_finished) return;
    _timer?.cancel();
    _timer = null;
    setState(() {
      _selectedStars = stars;
      if (stars > 3) {
        _feedback = '';
      }
    });
  }

  void _typeKey(String value) {
    if (_finished || !_needsFeedback) return;
    if (_feedback.length >= widget.maxFeedbackLength) return;
    setState(() => _feedback = '$_feedback$value');
  }

  void _backspace() {
    if (_finished || _feedback.isEmpty) return;
    setState(() => _feedback = _feedback.substring(0, _feedback.length - 1));
  }

  void _submit() {
    if (_finished || _selectedStars < 1) return;
    _finished = true;
    _timer?.cancel();
    final trimmed = _feedback.trim();
    final feedback =
        _needsFeedback && trimmed.isNotEmpty ? trimmed : null;
    widget.onSubmitted(_selectedStars, feedback);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showKeyboard = _needsFeedback;
    return Padding(
      padding: SkpTokens.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!showKeyboard) const Spacer(flex: 2),
          if (!showKeyboard) ...[
            const Icon(Icons.star_outline_rounded, size: 72, color: SkpColors.gold),
            const SizedBox(height: 16),
          ],
          Text(
            widget.title,
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            style: theme.textTheme.titleMedium?.copyWith(color: SkpColors.muted),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: showKeyboard ? 12 : 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: IconButton(
                    onPressed: () => _selectStars(i),
                    iconSize: showKeyboard ? 44 : 56,
                    icon: Icon(
                      i <= _selectedStars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: SkpColors.gold,
                    ),
                  ),
                ),
            ],
          ),
          if (showKeyboard) ...[
            const SizedBox(height: 12),
            Text(
              'What could we improve?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: SkpColors.panel,
                borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
                border: Border.all(color: SkpColors.line),
              ),
              child: Text(
                _feedback.isEmpty ? 'Optional — tap keys below' : _feedback,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: _feedback.isEmpty ? SkpColors.muted : null,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 210,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: SkpColors.panel,
                  borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
                  border: Border.all(color: SkpColors.line),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
                  child: KioskKeyboard(
                    onKey: _typeKey,
                    onBackspace: _backspace,
                  ),
                ),
              ),
            ),
          ] else
            const Spacer(flex: 3),
          const SizedBox(height: 12),
          KioskPrimaryButton(
            label: 'Submit',
            icon: Icons.check,
            onPressed: _selectedStars >= 1 ? _submit : null,
          ),
          const SizedBox(height: 10),
          KioskGhostButton(
            label: 'Skip',
            icon: Icons.close,
            onPressed: () {
              if (_finished) return;
              _finished = true;
              _timer?.cancel();
              widget.onSkip();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
