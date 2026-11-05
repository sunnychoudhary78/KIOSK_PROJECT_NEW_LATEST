import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';

class KioskPinField extends StatelessWidget {
  const KioskPinField({
    super.key,
    required this.value,
    this.length = 6,
  });

  final String value;
  final int length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : length * SkpTokens.pinSlotSize;
        final slot = ((available - gap * (length - 1)) / length)
            .clamp(40.0, SkpTokens.pinSlotSize);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              _Slot(
                size: slot,
                filled: i < value.length,
                char: i < value.length ? value[i] : '',
                active: i == value.length,
                style: theme.textTheme.headlineMedium,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.size,
    required this.filled,
    required this.char,
    required this.active,
    required this.style,
  });

  final double size;
  final bool filled;
  final String char;
  final bool active;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDark
        ? const Color(0xFF241A4C)
        : (filled ? Colors.white : const Color(0xFFF1F5F9));

    final Color borderColor = active
        ? const Color(0xFFE6007A)
        : (filled
            ? const Color(0xFF0084FF)
            : (isDark ? const Color(0xFF4A347D) : const Color(0xFFDCE4EE)));

    final Color textColor = isDark ? Colors.white : const Color(0xFF1B2234);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: active ? 2.0 : 1.2,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: const Color(0xFFE6007A).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Text(
        char,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontWeight: FontWeight.w700,
          color: textColor,
          fontSize: size * 0.44,
        ),
      ),
    );
  }
}
