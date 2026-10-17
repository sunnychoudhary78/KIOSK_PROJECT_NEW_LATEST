import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_theme.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/glass_panel.dart';

/// Shared birth-detail fields for palm and kundali flows.
class AstrologyBirthFormPanel extends StatelessWidget {
  const AstrologyBirthFormPanel({
    super.key,
    required this.nameController,
    required this.placeController,
    required this.dob,
    required this.birthTime,
    required this.timeUnknown,
    required this.gender,
    required this.focus,
    required this.onFocus,
    required this.onDob,
    required this.onTime,
    required this.onTimeUnknown,
    required this.onGender,
    required this.onKey,
    required this.onBackspace,
    this.error,
    this.title = 'Birth details',
    this.subtitle = 'Tell the stars a little about you',
    this.leading,
    this.footer,
  });

  final TextEditingController nameController;
  final TextEditingController placeController;
  final DateTime dob;
  final TimeOfDay birthTime;
  final bool timeUnknown;
  final String gender;
  final int focus;
  final ValueChanged<int> onFocus;
  final ValueChanged<DateTime> onDob;
  final ValueChanged<TimeOfDay> onTime;
  final ValueChanged<bool> onTimeUnknown;
  final ValueChanged<String> onGender;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final String? error;
  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final showKeyboard = focus == 0 || focus == 1;
    final showDate = focus == 2;
    final showTime = focus == 3 && !timeUnknown;
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 20),
                ],
                Expanded(
                  child: GlassPanel(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: ListView(
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AstrologyColors.gold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AstrologyColors.muted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        AstrologyCosmicTextField(
                          label: 'Name',
                          hint: 'Your name',
                          value: nameController.text,
                          focused: focus == 0,
                          onTap: () => onFocus(0),
                        ),
                        const SizedBox(height: 10),
                        AstrologyCosmicTextField(
                          label: 'Place of birth',
                          hint: 'City, State',
                          value: placeController.text,
                          focused: focus == 1,
                          onTap: () => onFocus(1),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Gender',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AstrologyColors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AstrologyGenderSegment(
                          gender: gender,
                          onGender: onGender,
                        ),
                        const SizedBox(height: 12),
                        AstrologyCosmicTextField(
                          label: 'Date of birth',
                          value: dob.toIso8601String().split('T').first,
                          focused: focus == 2,
                          onTap: () => onFocus(2),
                        ),
                        const SizedBox(height: 10),
                        AstrologyChoiceTile(
                          label: 'I do not know the birth time',
                          selected: timeUnknown,
                          onTap: () => onTimeUnknown(!timeUnknown),
                        ),
                        if (!timeUnknown) ...[
                          const SizedBox(height: 10),
                          AstrologyCosmicTextField(
                            label: 'Birth time',
                            value:
                                '${birthTime.hour.toString().padLeft(2, '0')}:${birthTime.minute.toString().padLeft(2, '0')}',
                            focused: focus == 3,
                            onTap: () => onFocus(3),
                          ),
                        ],
                        if (footer != null) ...[
                          const SizedBox(height: 14),
                          footer!,
                        ],
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          GlassPanel(
                            padding: const EdgeInsets.all(14),
                            borderColor:
                                AstrologyColors.danger.withValues(alpha: 0.55),
                            color:
                                AstrologyColors.danger.withValues(alpha: 0.18),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AstrologyColors.danger,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    error!,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: AstrologyColors.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showKeyboard)
          SizedBox(
            height: 220,
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                      surface: AstrologyColors.panelSolid,
                      onSurface: AstrologyColors.text,
                    ),
              ),
              child: KioskKeyboard(onKey: onKey, onBackspace: onBackspace),
            ),
          )
        else if (showDate)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
            child: SizedBox(
              height: 200,
              child: KioskDateStepper(value: dob, onChanged: onDob),
            ),
          )
        else if (showTime)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
            child: SizedBox(
              height: 200,
              child: KioskTimeStepper(value: birthTime, onChanged: onTime),
            ),
          ),
      ],
    );
  }
}

class AstrologyCosmicTextField extends StatelessWidget {
  const AstrologyCosmicTextField({
    super.key,
    required this.label,
    required this.value,
    required this.focused,
    required this.onTap,
    this.hint,
  });

  final String label;
  final String value;
  final bool focused;
  final VoidCallback onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: SkpTokens.tapMin),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AstrologyColors.raised,
          borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
          border: Border.all(
            color: focused ? AstrologyColors.gold : AstrologyColors.line,
            width: focused ? 2 : SkpTokens.hairline,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: AstrologyColors.gold.withValues(alpha: 0.22),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: focused ? AstrologyColors.gold : AstrologyColors.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value.isEmpty ? (hint ?? '') : value,
              style: theme.textTheme.titleLarge?.copyWith(
                color:
                    value.isEmpty ? AstrologyColors.muted : AstrologyColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AstrologyGenderSegment extends StatelessWidget {
  const AstrologyGenderSegment({
    super.key,
    required this.gender,
    required this.onGender,
  });

  final String gender;
  final ValueChanged<String> onGender;

  @override
  Widget build(BuildContext context) {
    const options = [
      ('female', 'Female'),
      ('male', 'Male'),
      ('other', 'Other'),
    ];
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AstrologyColors.raised,
        borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
        border: Border.all(color: AstrologyColors.line),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: InkWell(
                onTap: () => onGender(option.$1),
                borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: gender == option.$1
                            ? AstrologyColors.gold
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    option.$2,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: gender == option.$1
                              ? AstrologyColors.gold
                              : AstrologyColors.muted,
                          fontWeight: gender == option.$1
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AstrologyChoiceTile extends StatelessWidget {
  const AstrologyChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AstrologyColors.gold.withValues(alpha: 0.18)
          : AstrologyColors.raised,
      borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
        child: Container(
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
            border: Border.all(
              color: selected ? AstrologyColors.gold : AstrologyColors.line,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? AstrologyColors.gold : AstrologyColors.text,
                ),
          ),
        ),
      ),
    );
  }
}

class AstrologyStyleSegment extends StatelessWidget {
  const AstrologyStyleSegment({
    super.key,
    required this.style,
    required this.onStyle,
  });

  final String style;
  final ValueChanged<String> onStyle;

  @override
  Widget build(BuildContext context) {
    const options = [
      ('north', 'North Indian'),
      ('south', 'South Indian'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chart style',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AstrologyColors.text,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 64,
          decoration: BoxDecoration(
            color: AstrologyColors.raised,
            borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
            border: Border.all(color: AstrologyColors.line),
          ),
          child: Row(
            children: [
              for (final option in options)
                Expanded(
                  child: InkWell(
                    onTap: () => onStyle(option.$1),
                    borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: style == option.$1
                                ? AstrologyColors.gold
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        option.$2,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: style == option.$1
                                  ? AstrologyColors.gold
                                  : AstrologyColors.muted,
                              fontWeight: style == option.$1
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
