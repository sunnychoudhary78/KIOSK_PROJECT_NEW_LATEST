import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/kiosk_buttons.dart';
import 'package:skp_kiosk/features/service_ratings/application/service_ratings_gate.dart';
import 'package:skp_kiosk/features/service_ratings/application/service_ratings_tracker.dart';
import 'package:skp_kiosk/features/service_ratings/domain/service_rating_keys.dart';
import 'package:skp_kiosk/features/service_ratings/presentation/service_rating_prompt.dart';

/// Full-screen end of a print.
///
/// [onHome] ends the visitor session. When [onContinue] is set (more documents
/// remain), show **Print another** and do not auto-return home.
///
/// When [ratingServiceKey] is set and [confirmed] is true, Done / auto-return
/// shows an optional star rating before calling [onHome].
class KioskPrintResult extends ConsumerStatefulWidget {
  const KioskPrintResult({
    super.key,
    required this.confirmed,
    required this.onHome,
    this.detail,
    this.autoReturn = const Duration(seconds: 20),
    this.onNotReceived,
    this.onContinue,
    this.continueLabel = 'Print another',
    this.doneLabel = 'Done',
    this.ratingServiceKey,
  });

  final bool confirmed;
  final VoidCallback onHome;
  final String? detail;
  final Duration? autoReturn;
  final Future<void> Function()? onNotReceived;

  /// When set, visitor can return to the document list instead of leaving.
  final VoidCallback? onContinue;
  final String continueLabel;
  final String doneLabel;

  /// When set on a confirmed print, prompt for stars before [onHome].
  final String? ratingServiceKey;

  @override
  ConsumerState<KioskPrintResult> createState() => _KioskPrintResultState();
}

class _KioskPrintResultState extends ConsumerState<KioskPrintResult> {
  Timer? _timer;
  var _left = false;
  var _noting = false;
  var _noted = false;
  var _promptingRating = false;
  String? _noteError;

  bool get _hasContinue => widget.onContinue != null;

  bool get _shouldPromptRating {
    final key = widget.ratingServiceKey;
    return widget.confirmed && key != null && key.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    final wait = widget.autoReturn;
    // Only auto-home when there is nothing left to print.
    if (wait != null && !_hasContinue) {
      _timer = Timer(wait, _goHome);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _reportMissing() async {
    final report = widget.onNotReceived;
    if (report == null || _noting || _noted) return;
    _timer?.cancel();
    setState(() {
      _noting = true;
      _noteError = null;
    });
    try {
      await report();
      if (!mounted) return;
      setState(() {
        _noted = true;
        _noting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _noting = false;
        _noteError = '$error';
      });
    }
  }

  void _goHome() {
    if (_left || _promptingRating) return;
    _timer?.cancel();
    if (_shouldPromptRating) {
      final family = ServiceRatingKeys.familyFor(widget.ratingServiceKey!);
      if (family != null) {
        ref.read(serviceRatingsGateProvider.notifier).markPrompted(family);
      }
      setState(() => _promptingRating = true);
      return;
    }
    _finishHome();
  }

  void _finishHome() {
    if (_left) return;
    _left = true;
    _timer?.cancel();
    widget.onHome();
  }

  void _goContinue() {
    if (_left || _promptingRating) return;
    _left = true;
    _timer?.cancel();
    widget.onContinue?.call();
  }

  void _onRated(int stars) {
    final key = widget.ratingServiceKey;
    if (key != null && key.isNotEmpty) {
      unawaited(ref.read(serviceRatingsTrackerProvider).submit(key, stars));
    }
    _finishHome();
  }

  @override
  Widget build(BuildContext context) {
    if (_promptingRating) {
      return ServiceRatingPrompt(
        onRated: _onRated,
        onSkip: _finishHome,
      );
    }

    final theme = Theme.of(context);
    final title = widget.confirmed ? 'Print successful' : 'Print not confirmed';
    final line = widget.confirmed
        ? (_hasContinue
            ? 'Collect your pages, then print another document or tap Done.'
            : 'Collect your pages from the printer')
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
          if (_noted)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'We received this. Staff will review.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            )
          else if (widget.confirmed && widget.onNotReceived != null) ...[
            TextButton(
              onPressed: _noting ? null : _reportMissing,
              child: Text(_noting ? 'Sending…' : 'Didn\'t receive the print?'),
            ),
            if (_noteError != null)
              Text(
                _noteError!,
                style: theme.textTheme.bodyMedium?.copyWith(color: SkpColors.danger),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),
          ],
          if (_hasContinue) ...[
            KioskPrimaryButton(
              label: widget.continueLabel,
              icon: Icons.print,
              onPressed: _goContinue,
            ),
            const SizedBox(height: 12),
            KioskGhostButton(
              label: widget.doneLabel,
              icon: Icons.home,
              onPressed: _goHome,
            ),
          ] else
            KioskPrimaryButton(
              label: widget.doneLabel,
              icon: Icons.home,
              onPressed: _goHome,
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
