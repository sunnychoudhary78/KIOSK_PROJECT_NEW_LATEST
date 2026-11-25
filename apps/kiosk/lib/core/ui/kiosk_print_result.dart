import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/kiosk_buttons.dart';
import 'package:skp_kiosk/core/ui/kiosk_keyboard.dart';
import 'package:skp_kiosk/core/ui/kiosk_numeric_keypad.dart';
import 'package:skp_kiosk/core/ui/kiosk_text_caret.dart';
import 'package:skp_kiosk/features/service_ratings/application/service_ratings_gate.dart';
import 'package:skp_kiosk/features/service_ratings/application/service_ratings_tracker.dart';
import 'package:skp_kiosk/features/service_ratings/domain/service_rating_keys.dart';
import 'package:skp_kiosk/features/service_ratings/presentation/service_rating_prompt.dart';

typedef PrintNotReceivedReport = Future<void> Function({
  required String name,
  required String phone,
  required String message,
});

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
  final PrintNotReceivedReport? onNotReceived;

  /// When set, visitor can return to the document list instead of leaving.
  final VoidCallback? onContinue;
  final String continueLabel;
  final String doneLabel;

  /// When set on a confirmed print, prompt for stars before [onHome].
  final String? ratingServiceKey;

  @override
  ConsumerState<KioskPrintResult> createState() => _KioskPrintResultState();
}

enum _ComplaintFocus { name, phone, message }

class _KioskPrintResultState extends ConsumerState<KioskPrintResult> {
  Timer? _timer;
  var _left = false;
  var _noting = false;
  var _noted = false;
  var _promptingRating = false;
  var _showComplaint = false;
  String? _noteError;

  var _focus = _ComplaintFocus.name;
  var _name = '';
  var _phone = '';
  var _message = '';

  bool get _hasContinue => widget.onContinue != null;

  bool get _shouldPromptRating {
    final key = widget.ratingServiceKey;
    return widget.confirmed && key != null && key.isNotEmpty;
  }

  bool get _canSubmitComplaint {
    return _name.trim().isNotEmpty &&
        RegExp(r'^\d{10}$').hasMatch(_phone.trim()) &&
        _message.trim().isNotEmpty &&
        !_noting;
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

  void _openComplaint() {
    if (widget.onNotReceived == null || _noted || _noting) return;
    _timer?.cancel();
    setState(() {
      _showComplaint = true;
      _noteError = null;
      _focus = _ComplaintFocus.name;
    });
  }

  void _typeKey(String key) {
    setState(() {
      switch (_focus) {
        case _ComplaintFocus.name:
          if (_name.length < 80) _name += key;
        case _ComplaintFocus.message:
          if (_message.length < 400) _message += key;
        case _ComplaintFocus.phone:
          break;
      }
    });
  }

  void _backspace() {
    setState(() {
      switch (_focus) {
        case _ComplaintFocus.name:
          if (_name.isNotEmpty) _name = _name.substring(0, _name.length - 1);
        case _ComplaintFocus.message:
          if (_message.isNotEmpty) {
            _message = _message.substring(0, _message.length - 1);
          }
        case _ComplaintFocus.phone:
          if (_phone.isNotEmpty) _phone = _phone.substring(0, _phone.length - 1);
      }
    });
  }

  void _addPhoneDigit(String digit) {
    if (_phone.length >= 10) return;
    setState(() => _phone += digit);
  }

  Future<void> _submitComplaint() async {
    final report = widget.onNotReceived;
    if (report == null || !_canSubmitComplaint) return;
    setState(() {
      _noting = true;
      _noteError = null;
    });
    try {
      await report(
        name: _name.trim(),
        phone: _phone.trim(),
        message: _message.trim(),
      );
      if (!mounted) return;
      setState(() {
        _noted = true;
        _noting = false;
        _showComplaint = false;
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
    if (_left || _promptingRating || _showComplaint) return;
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
    if (_left || _promptingRating || _showComplaint) return;
    _left = true;
    _timer?.cancel();
    widget.onContinue?.call();
  }

  void _onSubmitted(int stars, String? feedback) {
    final key = widget.ratingServiceKey;
    if (key != null && key.isNotEmpty) {
      unawaited(
        ref.read(serviceRatingsTrackerProvider).submit(
              key,
              stars,
              feedback: feedback,
            ),
      );
    }
    _finishHome();
  }

  @override
  Widget build(BuildContext context) {
    if (_promptingRating) {
      return ServiceRatingPrompt(
        onSubmitted: _onSubmitted,
        onSkip: _finishHome,
      );
    }

    if (_showComplaint) {
      return _ComplaintForm(
        name: _name,
        phone: _phone,
        message: _message,
        focus: _focus,
        submitting: _noting,
        error: _noteError,
        canSubmit: _canSubmitComplaint,
        onFocus: (focus) => setState(() => _focus = focus),
        onTypeKey: _typeKey,
        onBackspace: _backspace,
        onPhoneDigit: _addPhoneDigit,
        onClearPhone: () => setState(() => _phone = ''),
        onCancel: () => setState(() {
          _showComplaint = false;
          _noteError = null;
        }),
        onSubmit: _submitComplaint,
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
                'Complaint sent. Staff will review and contact you.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            )
          else if (widget.confirmed && widget.onNotReceived != null) ...[
            KioskGhostButton(
              label: 'I didn\'t receive the print',
              icon: Icons.report_gmailerrorred_outlined,
              onPressed: _noting ? null : _openComplaint,
            ),
            if (_noteError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _noteError!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: SkpColors.danger),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 12),
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

class _ComplaintForm extends StatelessWidget {
  const _ComplaintForm({
    required this.name,
    required this.phone,
    required this.message,
    required this.focus,
    required this.submitting,
    required this.error,
    required this.canSubmit,
    required this.onFocus,
    required this.onTypeKey,
    required this.onBackspace,
    required this.onPhoneDigit,
    required this.onClearPhone,
    required this.onCancel,
    required this.onSubmit,
  });

  final String name;
  final String phone;
  final String message;
  final _ComplaintFocus focus;
  final bool submitting;
  final String? error;
  final bool canSubmit;
  final ValueChanged<_ComplaintFocus> onFocus;
  final ValueChanged<String> onTypeKey;
  final VoidCallback onBackspace;
  final ValueChanged<String> onPhoneDigit;
  final VoidCallback onClearPhone;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Print not received',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter your details so staff can help. All fields are required.',
            style: theme.textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Column(
              children: [
                _FieldCard(
                  label: 'Your name',
                  requiredMark: true,
                  selected: focus == _ComplaintFocus.name,
                  onTap: () => onFocus(_ComplaintFocus.name),
                  child: KioskCaretText(
                    text: name,
                    hint: 'Full name',
                    showCaret: focus == _ComplaintFocus.name,
                    caretHeight: 22,
                    caretColor: colors.textPrimary,
                    style: theme.textTheme.titleMedium?.copyWith(color: colors.textPrimary),
                    hintStyle: theme.textTheme.titleMedium?.copyWith(color: colors.textSecondary),
                  ),
                ),
                const SizedBox(height: 10),
                _FieldCard(
                  label: 'Callback phone',
                  requiredMark: true,
                  selected: focus == _ComplaintFocus.phone,
                  onTap: () => onFocus(_ComplaintFocus.phone),
                  child: KioskCaretText(
                    text: phone.isEmpty
                        ? (focus == _ComplaintFocus.phone ? '+91 ' : '+91 10-digit number')
                        : '+91 $phone',
                    showCaret: focus == _ComplaintFocus.phone,
                    caretHeight: 22,
                    caretColor: colors.textPrimary,
                    maxLines: 1,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: phone.isEmpty && focus != _ComplaintFocus.phone
                          ? colors.textSecondary
                          : colors.textPrimary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _FieldCard(
                    label: 'What happened?',
                    requiredMark: true,
                    expandChild: true,
                    selected: focus == _ComplaintFocus.message,
                    onTap: () => onFocus(_ComplaintFocus.message),
                    child: KioskCaretText(
                      text: message,
                      hint: 'Describe the issue…',
                      showCaret: focus == _ComplaintFocus.message,
                      caretHeight: 22,
                      caretColor: colors.textPrimary,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        height: 1.35,
                      ),
                      hintStyle: theme.textTheme.titleMedium?.copyWith(
                        color: colors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  height: 200,
                  child: IgnorePointer(
                    ignoring: submitting,
                    child: Opacity(
                      opacity: submitting ? 0.5 : 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: SkpColors.panel,
                          borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
                          border: Border.all(color: SkpColors.line),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
                          child: focus == _ComplaintFocus.phone
                              ? Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: KioskNumericKeypad(
                                    onDigit: onPhoneDigit,
                                    onBackspace: onBackspace,
                                    onClear: onClearPhone,
                                  ),
                                )
                              : KioskKeyboard(
                                  onKey: onTypeKey,
                                  onBackspace: onBackspace,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: KioskGhostButton(
                  label: 'Back',
                  icon: Icons.arrow_back,
                  onPressed: submitting ? null : onCancel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: KioskPrimaryButton(
                  label: submitting ? 'Sending…' : 'Submit complaint',
                  icon: Icons.send_rounded,
                  loading: submitting,
                  onPressed: canSubmit ? onSubmit : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
    this.requiredMark = false,
    this.expandChild = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final bool requiredMark;
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: SkpColors.raised,
            borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
            border: Border.all(
              color: selected ? colors.accentCyan : SkpColors.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.textSecondary,
                      ),
                  children: [
                    if (requiredMark)
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: colors.accentCyan),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              if (expandChild)
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SingleChildScrollView(child: child),
                  ),
                )
              else
                child,
            ],
          ),
        ),
      ),
    );
  }
}
