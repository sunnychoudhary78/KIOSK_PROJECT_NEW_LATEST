import 'package:flutter/material.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';

class SkpPrimaryButton extends StatelessWidget {
  const SkpPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled || loading ? 1 : 0.55,
      child: Container(
        height: SkpTokens.buttonHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
          gradient: SkpColors.brandGradient,
          boxShadow: [
            BoxShadow(
              color: SkpColors.accentBright.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
          child: InkWell(
            borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class SkpSecondaryButton extends StatelessWidget {
  const SkpSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class SkpTextLink extends StatelessWidget {
  const SkpTextLink({
    super.key,
    required this.label,
    this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: SkpColors.accent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      child: Text(label),
    );
  }
}
