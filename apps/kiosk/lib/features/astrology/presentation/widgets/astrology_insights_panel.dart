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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AstrologyColors.raised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AstrologyColors.line),
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
    return Material(
      color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? accent : AstrologyColors.muted,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
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
        SizedBox(height: compact ? 6 : 8),
        for (var i = 0; i < bullets.length; i++) ...[
          if (i > 0) SizedBox(height: compact ? 4 : 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bullets[i],
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AstrologyColors.text,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
