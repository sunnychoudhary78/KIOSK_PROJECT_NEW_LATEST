import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/kiosk_numeric_keypad.dart';

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
        ? (digits.isEmpty ? '+91 ' : '+91 $digits')
        : (digits.isEmpty ? '—' : digits);
    final hint = mode == KioskPhoneOtpMode.phone
        ? 'Mobile number'
        : 'OTP';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: SkpColors.raised,
            borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
            border: Border.all(color: SkpColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hint,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: SkpColors.muted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                display,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: mode == KioskPhoneOtpMode.otp ? 4 : 0.5,
                  color: digits.isEmpty ? SkpColors.muted : SkpColors.text,
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
