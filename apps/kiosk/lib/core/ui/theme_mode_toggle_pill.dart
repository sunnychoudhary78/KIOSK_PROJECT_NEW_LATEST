import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';
import 'package:skp_kiosk/core/theme/theme_mode_controller.dart';

/// Top bar pill button that toggles between Dark & Light mode.
/// Defaults to system theme, matches the active brightness, and lets
/// the user toggle anytime.
class ThemeModeTogglePill extends ConsumerWidget {
  const ThemeModeTogglePill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.athenaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mode = ref.watch(themeModeControllerProvider);
    final isSystem = mode == ThemeMode.system;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ref.read(themeModeControllerProvider.notifier).toggle(context);
        },
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colors.topBarPillBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colors.topBarPillBorder,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0x307928CA)
                    : const Color(0x0A000000),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sun icon (Light)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: !isDark
                      ? const Color(0xFFFFB703).withValues(alpha: 0.22)
                      : Colors.transparent,
                ),
                child: Icon(
                  Icons.wb_sunny_rounded,
                  size: 16,
                  color: !isDark
                      ? const Color(0xFFF77F00)
                      : colors.textSecondary.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 4),
              // Moon icon (Dark)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? AthenaColors.neonPink.withValues(alpha: 0.25)
                      : Colors.transparent,
                ),
                child: Icon(
                  Icons.nightlight_round,
                  size: 16,
                  color: isDark
                      ? AthenaColors.neonPink
                      : colors.textSecondary.withValues(alpha: 0.5),
                ),
              ),
              if (isSystem) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.accentMagenta.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'AUTO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: colors.accentMagenta,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

