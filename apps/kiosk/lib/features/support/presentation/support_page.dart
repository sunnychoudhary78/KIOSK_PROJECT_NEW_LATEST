import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';
import 'package:skp_kiosk/features/support/application/support_controller.dart';
import 'package:skp_kiosk/features/support/domain/support_category.dart';

class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({super.key});

  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  Timer? _homeTimer;

  @override
  void dispose() {
    _homeTimer?.cancel();
    super.dispose();
  }

  Future<void> _endSession() {
    return ref
        .read(kioskSessionControllerProvider.notifier)
        .endVisitorSession(attract: false);
  }

  void _scheduleHome() {
    _homeTimer?.cancel();
    _homeTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final state = ref.watch(supportControllerProvider);
    final controller = ref.read(supportControllerProvider.notifier);

    ref.listen<SupportFormState>(supportControllerProvider, (previous, next) {
      if (previous?.submitted != true && next.submitted) {
        _scheduleHome();
      }
    });

    return VisitorSessionPopScope(
      endSessionOnPop: false,
      child: KioskShell(
        title: 'Support',
        onHome: _endSession,
        footerLeading: KioskGhostButton(
          label: 'Back',
          icon: Icons.arrow_back,
          onPressed: state.submitting
              ? null
              : () => Navigator.of(context).maybePop(),
        ),
        footerTrailing: state.submitted
            ? KioskPrimaryButton(
                label: 'Done',
                icon: Icons.check,
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              )
            : KioskPrimaryButton(
                label: 'Send',
                icon: Icons.send_rounded,
                loading: state.submitting,
                onPressed: state.canSubmit ? () => controller.submit() : null,
              ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 8),
          child: state.submitted
              ? _SuccessView(colors: colors)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tell us what needs help',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Staff will see this on the Support inbox',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: colors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final category in SupportCategory.values)
                          _CategoryChip(
                            label: category.label,
                            selected: state.category == category,
                            onTap: () => controller.selectCategory(category),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      flex: 2,
                      child: _FieldCard(
                        label: 'Message',
                        requiredMark: true,
                        expandChild: true,
                        selected: state.focus == SupportFormFocus.message,
                        onTap: () =>
                            controller.setFocus(SupportFormFocus.message),
                        child: KioskCaretText(
                          text: state.message,
                          hint: 'Describe the issue…',
                          showCaret: state.focus == SupportFormFocus.message,
                          caretHeight: 22,
                          caretColor: colors.textPrimary,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: colors.textPrimary,
                                height: 1.35,
                              ),
                          hintStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: colors.textSecondary,
                                height: 1.35,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _FieldCard(
                      label: 'Callback phone (optional)',
                      selected: state.focus == SupportFormFocus.phone,
                      onTap: () => controller.setFocus(SupportFormFocus.phone),
                      child: KioskCaretText(
                        text: state.phone.isEmpty
                            ? (state.focus == SupportFormFocus.phone
                                ? '+91 '
                                : '+91 —')
                            : '+91 ${state.phone}',
                        showCaret: state.focus == SupportFormFocus.phone,
                        caretHeight: 22,
                        caretColor: colors.textPrimary,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: state.phone.isEmpty &&
                                      state.focus != SupportFormFocus.phone
                                  ? colors.textSecondary
                                  : colors.textPrimary,
                              letterSpacing: 0.4,
                            ),
                      ),
                    ),
                    if (state.error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        state.error!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 210,
                      child: IgnorePointer(
                        ignoring: state.submitting,
                        child: Opacity(
                          opacity: state.submitting ? 0.5 : 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: SkpColors.panel,
                              borderRadius:
                                  BorderRadius.circular(SkpTokens.radiusMd),
                              border: Border.all(color: SkpColors.line),
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(SkpTokens.radiusMd),
                              child: state.focus == SupportFormFocus.phone
                                  ? Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: KioskNumericKeypad(
                                        onDigit: (digit) =>
                                            controller.setPhone(
                                          '${state.phone}$digit',
                                        ),
                                        onBackspace: controller.backspace,
                                        onClear: () => controller.setPhone(''),
                                      ),
                                    )
                                  : KioskKeyboard(
                                      onKey: controller.typeKey,
                                      onBackspace: controller.backspace,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.colors});

  final AthenaColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 72, color: colors.accentCyan),
          const SizedBox(height: 16),
          Text(
            'Message sent',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Staff will review this shortly.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? colors.accentCyan.withValues(alpha: 0.16)
                : colors.surfaceCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? colors.accentCyan : SkpColors.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w700,
              color: selected ? colors.accentCyan : colors.textPrimary,
            ),
          ),
        ),
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
