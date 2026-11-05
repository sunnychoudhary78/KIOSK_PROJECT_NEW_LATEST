import 'package:flutter/material.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_insights.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_theme.dart';

class AstrologyLocaleSwitch extends StatelessWidget {
  const AstrologyLocaleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.accent = AstrologyColors.gold,
  });

  final AstrologyInsightLocale value;
  final ValueChanged<AstrologyInsightLocale> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1738) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF332A55) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final locale in AstrologyInsightLocale.values)
            _LocaleChip(
              label: locale.label,
              selected: value == locale,
              accent: accent,
              onTap: () => onChanged(locale),
            ),
        ],
      ),
    );
  }
}

class _LocaleChip extends StatelessWidget {
  const _LocaleChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: selected
          ? (isDark ? accent.withValues(alpha: 0.3) : accent)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected
                  ? (isDark ? Colors.white : Colors.white)
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }
}

class AstrologyInsightsPanel extends StatelessWidget {
  const AstrologyInsightsPanel({
    super.key,
    required this.bullets,
    required this.locale,
    required this.onLocaleChanged,
    this.title = 'AI insights',
    this.accent = AstrologyColors.gold,
    this.compact = false,
  });

  final List<String> bullets;
  final AstrologyInsightLocale locale;
  final ValueChanged<AstrologyInsightLocale> onLocaleChanged;
  final String title;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (bullets.isEmpty) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome, size: 14, color: accent),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
            AstrologyLocaleSwitch(
              value: locale,
              onChanged: onLocaleChanged,
              accent: accent,
            ),
          ],
        ),
        SizedBox(height: compact ? 8 : 12),
        for (var i = 0; i < bullets.length; i++) ...[
          if (i > 0) SizedBox(height: compact ? 6 : 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1738).withValues(alpha: 0.6)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accent.withValues(alpha: isDark ? 0.25 : 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    bullets[i],
                    maxLines: compact ? 4 : 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
