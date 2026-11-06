import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/ui/kiosk_numeric_keypad.dart';
import 'package:skp_kiosk/core/ui/kiosk_text_caret.dart';

enum KioskPhoneOtpMode { phone, otp }

/// Read-only digit display + [KioskNumericKeypad] for kiosk phone / OTP entry.
/// Avoids focusable [TextField] so Windows does not show a system keyboard.
class KioskPhoneOtpEntry extends StatelessWidget {
  const KioskPhoneOtpEntry({
    super.key,
    required this.value,
    required this.mode,
    required this.onChanged,
    this.enabled = true,
  });

  final String value;
  final KioskPhoneOtpMode mode;
  final ValueChanged<String> onChanged;
  final bool enabled;

  int get _maxLength => mode == KioskPhoneOtpMode.phone ? 10 : 8;

  String get _digitsOnly => value.replaceAll(RegExp(r'\D'), '');

  void _emit(String next) {
    if (!enabled) return;
    final clipped = next.length > _maxLength ? next.substring(0, _maxLength) : next;
    onChanged(clipped);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final digits = _digitsOnly;
    final display = mode == KioskPhoneOtpMode.phone
        ? '+91 $digits'
        : digits;
    final hint = mode == KioskPhoneOtpMode.phone
        ? 'Mobile number'
        : 'OTP';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF101828);
    final mutedColor = isDark ? const Color(0xFFCBD2E1) : const Color(0xFF64748B);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF211747) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF4A347D) : const Color(0xFFDCE4EE),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0x332E2452)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hint,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
              ),
              const SizedBox(height: 6),
              KioskCaretText(
                text: display,
                hint: digits.isEmpty && mode == KioskPhoneOtpMode.otp && !enabled
                    ? '—'
                    : null,
                showCaret: enabled,
                caretHeight: 28,
                caretColor: titleColor,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: theme.textTheme.headlineSmall?.fontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: mode == KioskPhoneOtpMode.otp ? 4 : 0.5,
                  color: digits.isEmpty ? mutedColor : titleColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: IgnorePointer(
            ignoring: !enabled,
            child: Opacity(
              opacity: enabled ? 1 : 0.45,
              child: KioskNumericKeypad(
                onDigit: (digit) {
                  if (digits.length >= _maxLength) return;
                  _emit('$digits$digit');
                },
                onBackspace: () {
                  if (digits.isEmpty) return;
                  _emit(digits.substring(0, digits.length - 1));
                },
                onClear: () => _emit(''),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
