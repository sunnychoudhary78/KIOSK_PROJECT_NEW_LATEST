import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';

class KioskPrimaryButton extends StatelessWidget {
  const KioskPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.expand = true,
    this.gold = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool expand;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final child = loading
        ? const SizedBox(
            height: 26,
            width: 26,
            child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 24),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label),
                ),
              ),
            ],
          );

    final button = FilledButton(
      onPressed: enabled ? onPressed : null,
      style: FilledButton.styleFrom(
        backgroundColor: gold ? SkpColors.gold : SkpColors.accent,
        foregroundColor: gold ? SkpColors.canvas : Colors.white,
        disabledBackgroundColor: SkpColors.raised,
        disabledForegroundColor: SkpColors.muted,
        minimumSize: Size(
          expand ? double.infinity : 180,
          SkpTokens.primaryButtonHeight,
        ),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 20),
      ),
      child: child,
    );

    return expand ? SizedBox(width: double.infinity, height: SkpTokens.primaryButtonHeight, child: button) : button;
  }
}

class KioskGhostButton extends StatelessWidget {
  const KioskGhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label),
          ),
        ),
      ],
    );

    return SizedBox(
      height: SkpTokens.tapMin,
      width: expand ? double.infinity : null,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: Size(expand ? double.infinity : 140, SkpTokens.tapMin),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 18),
        ),
        child: child,
      ),
    );
  }
}
