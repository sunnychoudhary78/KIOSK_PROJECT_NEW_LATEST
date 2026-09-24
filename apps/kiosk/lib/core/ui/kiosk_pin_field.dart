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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SkpColors.raised,
        borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
        border: Border.all(
          color: active
              ? SkpColors.accentBright
              : filled
                  ? SkpColors.accent
                  : SkpColors.line,
          width: active ? 2 : SkpTokens.hairline,
        ),
      ),
      child: Text(
        char,
        style: style?.copyWith(
          fontWeight: FontWeight.w700,
          color: SkpColors.text,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
