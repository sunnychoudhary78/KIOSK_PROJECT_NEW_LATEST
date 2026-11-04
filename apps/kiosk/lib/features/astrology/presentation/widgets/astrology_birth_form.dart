import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_controller.dart';
import 'package:skp_kiosk/features/astrology/data/astrology_repository.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_theme.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/glass_panel.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/reading_mark.dart';

/// Shared birth-detail fields for palm and kundali flows.
class AstrologyBirthFormPanel extends ConsumerStatefulWidget {
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
    this.onPlaceResolved,
    this.error,
    this.title = 'Birth details',
    this.subtitle = 'Tell the stars a little about you',
    this.leading,
    this.footer,
    this.showGender = true,
    this.accent = AstrologyColors.gold,
    this.emblem,
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
  final ValueChanged<ResolvedBirthPlace?>? onPlaceResolved;
  final String? error;
  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? footer;
  final bool showGender;
  final Color accent;
  final AstrologyReadingKind? emblem;

  @override
  ConsumerState<AstrologyBirthFormPanel> createState() =>
      _AstrologyBirthFormPanelState();
}

class _AstrologyBirthFormPanelState
    extends ConsumerState<AstrologyBirthFormPanel> {
  Timer? _placeDebounce;
  int _placeSearchToken = 0;
  List<PlaceSuggestion> _suggestions = const [];
  bool _searchingPlaces = false;

  @override
  void initState() {
    super.initState();
    widget.placeController.addListener(_onPlaceTextChanged);
  }

  @override
  void didUpdateWidget(covariant AstrologyBirthFormPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placeController != widget.placeController) {
      oldWidget.placeController.removeListener(_onPlaceTextChanged);
      widget.placeController.addListener(_onPlaceTextChanged);
    }
    if (oldWidget.focus != widget.focus && widget.focus != 1) {
      _clearSuggestions();
    }
  }

  @override
  void dispose() {
    _placeDebounce?.cancel();
    widget.placeController.removeListener(_onPlaceTextChanged);
    super.dispose();
  }

  void _clearSuggestions() {
    if (_suggestions.isEmpty && !_searchingPlaces) {
      return;
    }
    setState(() {
      _suggestions = const [];
      _searchingPlaces = false;
    });
  }

  void _onPlaceTextChanged() {
    _placeSearchToken++;
    widget.onPlaceResolved?.call(null);
    if (widget.focus != 1) {
      _clearSuggestions();
      return;
    }
    final query = widget.placeController.text.trim();
    _placeDebounce?.cancel();
    if (query.length < 2) {
      _clearSuggestions();
      return;
    }
    _placeDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_searchPlaces(query));
    });
  }

  Future<void> _searchPlaces(String query) async {
    final token = ++_placeSearchToken;
    setState(() => _searchingPlaces = true);
    try {
      final results = await ref
          .read(astrologyRepositoryProvider)
          .searchPlaces(query);
      if (!mounted || token != _placeSearchToken) {
        return;
      }
      setState(() {
        _suggestions = results.take(5).toList();
        _searchingPlaces = false;
      });
    } catch (_) {
      if (!mounted || token != _placeSearchToken) {
        return;
      }
      setState(() {
        _suggestions = const [];
        _searchingPlaces = false;
      });
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    _placeDebounce?.cancel();
    final token = ++_placeSearchToken;
    setState(() {
      _suggestions = const [];
      _searchingPlaces = true;
    });
    try {
      final resolved = await ref
          .read(astrologyRepositoryProvider)
          .resolvePlace(suggestion.id);
      if (!mounted || token != _placeSearchToken) {
        return;
      }
      widget.placeController.removeListener(_onPlaceTextChanged);
      widget.placeController.text = resolved.name;
      widget.placeController.addListener(_onPlaceTextChanged);
      widget.onPlaceResolved?.call(resolved);
      setState(() => _searchingPlaces = false);
    } catch (_) {
      if (!mounted || token != _placeSearchToken) {
        return;
      }
      setState(() => _searchingPlaces = false);
    }
  }

  void _type(String value) {
    widget.onKey(value);
  }

  @override
  Widget build(BuildContext context) {
    final showKeyboard = widget.focus == 0 || widget.focus == 1;
    final showDate = widget.focus == 2;
    final showTime = widget.focus == 3 && !widget.timeUnknown;
    final showSuggestions =
        widget.focus == 1 && (_suggestions.isNotEmpty || _searchingPlaces);
    final theme = Theme.of(context);
    final timeValue =
        '${widget.birthTime.hour.toString().padLeft(2, '0')}:${widget.birthTime.minute.toString().padLeft(2, '0')}';
    final nameController = widget.nameController;
    final placeController = widget.placeController;
    final dob = widget.dob;
    final birthTime = widget.birthTime;
    final timeUnknown = widget.timeUnknown;
    final gender = widget.gender;
    final focus = widget.focus;
    final onFocus = widget.onFocus;
    final onDob = widget.onDob;
    final onTime = widget.onTime;
    final onTimeUnknown = widget.onTimeUnknown;
    final onGender = widget.onGender;
    final onBackspace = widget.onBackspace;
    final error = widget.error;
    final title = widget.title;
    final subtitle = widget.subtitle;
    final leading = widget.leading;
    final footer = widget.footer;
    final showGender = widget.showGender;
    final accent = widget.accent;
    final emblem = widget.emblem;
    // Keep intrinsic heights under the 720p form budget (keyboard is fixed).
    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AstrologyCosmicTextField(
          label: 'Name',
          value: nameController.text,
          focused: focus == 0,
          accent: accent,
          onTap: () => onFocus(0),
        ),
        const SizedBox(height: 8),
        AstrologyCosmicTextField(
          label: 'Place of birth',
          value: placeController.text,
          focused: focus == 1,
          accent: accent,
          onTap: () => onFocus(1),
        ),
        if (footer != null) ...[const SizedBox(height: 8), footer],
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showGender) ...[
          Semantics(
            label: 'Gender',
            child: AstrologyGenderSegment(
              gender: gender,
              onGender: onGender,
              accent: accent,
            ),
          ),
          const SizedBox(height: 8),
        ],
        AstrologyCosmicTextField(
          label: 'Date of birth',
          value: dob.toIso8601String().split('T').first,
          focused: focus == 2,
          accent: accent,
          onTap: () => onFocus(2),
        ),
        if (!timeUnknown) ...[
          const SizedBox(height: 8),
          AstrologyCosmicTextField(
            label: 'Birth time',
            value: timeValue,
            focused: focus == 3,
            accent: accent,
            onTap: () => onFocus(3),
          ),
        ],
        const SizedBox(height: 8),
        AstrologyUnknownTimeRow(
          selected: timeUnknown,
          accent: accent,
          onTap: () => onTimeUnknown(!timeUnknown),
        ),
      ],
    );

    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (emblem != null) ...[
              ReadingEmblem(kind: emblem, size: 28, color: accent),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
        if (subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AstrologyColors.muted,
              height: 1.1,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    leftColumn,
                    if (showSuggestions)
                      Positioned(
                        key: const ValueKey('place-suggestions'),
                        left: 0,
                        right: 0,
                        top:
                            AstrologyCosmicTextField.height +
                            8 +
                            AstrologyCosmicTextField.height,
                        bottom: 0,
                        child: GlassPanel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: _searchingPlaces && _suggestions.isEmpty
                              ? const Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _suggestions.length,
                                  separatorBuilder: (_, _) => Divider(
                                    height: 1,
                                    color: AstrologyColors.line.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                  itemBuilder: (context, index) {
                                    final suggestion = _suggestions[index];
                                    return InkWell(
                                      onTap: () =>
                                          _selectSuggestion(suggestion),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.place_outlined,
                                              color: AstrologyColors.gold,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    suggestion.label,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          color:
                                                              AstrologyColors
                                                                  .text,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                  if (suggestion
                                                      .subtitle
                                                      .isNotEmpty)
                                                    Text(
                                                      suggestion.subtitle,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color:
                                                                AstrologyColors
                                                                    .muted,
                                                          ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: rightColumn),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            borderColor: AstrologyColors.danger.withValues(alpha: 0.55),
            color: AstrologyColors.danger.withValues(alpha: 0.18),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AstrologyColors.danger,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AstrologyColors.text,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    final keyboardTheme = Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          surface: AstrologyColors.panelSolid,
          onSurface: AstrologyColors.text,
        ),
      ),
      child: KioskKeyboard(onKey: _type, onBackspace: onBackspace),
    );

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 6, 32, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 16)],
                Expanded(
                  child: GlassPanel(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                    borderColor: accent.withValues(alpha: 0.5),
                    child: SizedBox.expand(child: fields),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showKeyboard)
          SizedBox(height: 180, child: keyboardTheme)
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

class AstrologyCosmicTextField extends StatefulWidget {
  const AstrologyCosmicTextField({
    super.key,
    required this.label,
    required this.value,
    required this.focused,
    required this.onTap,
    this.accent = AstrologyColors.gold,
  });

  final String label;
  final String value;
  final bool focused;
  final VoidCallback onTap;
  final Color accent;

  static const double height = 50;

  @override
  State<AstrologyCosmicTextField> createState() =>
      _AstrologyCosmicTextFieldState();
}

class _AstrologyCosmicTextFieldState extends State<AstrologyCosmicTextField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _caretBlink;

  @override
  void initState() {
    super.initState();
    _caretBlink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    );
    if (widget.focused) {
      _caretBlink.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AstrologyCosmicTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focused && !_caretBlink.isAnimating) {
      _caretBlink.repeat(reverse: true);
    } else if (!widget.focused && _caretBlink.isAnimating) {
      _caretBlink.stop();
      _caretBlink.value = 0;
    }
  }

  @override
  void dispose() {
    _caretBlink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focused = widget.focused;
    final accent = widget.accent;
    final value = widget.value;
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        height: AstrologyCosmicTextField.height,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AstrologyColors.raised,
          borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
          border: Border.all(
            color: focused ? accent : AstrologyColors.line,
            width: focused ? 2 : SkpTokens.hairline,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: focused ? accent : AstrologyColors.muted,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 1),
            Row(
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AstrologyColors.text,
                      height: 1.05,
                    ),
                  ),
                ),
                if (focused)
                  FadeTransition(
                    opacity: _caretBlink,
                    child: Container(
                      width: 2,
                      height: 18,
                      margin: const EdgeInsets.only(left: 1),
                      color: accent,
                    ),
                  ),
              ],
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
    this.accent = AstrologyColors.gold,
  });

  final String gender;
  final ValueChanged<String> onGender;
  final Color accent;

  static const double height = 42;

  @override
  Widget build(BuildContext context) {
    const options = [
      ('female', 'Female'),
      ('male', 'Male'),
      ('other', 'Other'),
    ];
    return _AstrologyPillSegment(
      height: height,
      accent: accent,
      options: options,
      selected: gender,
      onSelected: onGender,
    );
  }
}

/// Compact toggle for “birth time unknown” (replaces tall choice tile in forms).
class AstrologyUnknownTimeRow extends StatelessWidget {
  const AstrologyUnknownTimeRow({
    super.key,
    required this.selected,
    required this.onTap,
    this.accent = AstrologyColors.gold,
  });

  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.14)
          : AstrologyColors.raised,
      borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
            border: Border.all(
              color: selected ? accent : AstrologyColors.line,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_box : Icons.check_box_outline_blank,
                size: 20,
                color: selected ? accent : AstrologyColors.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Birth time unknown',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: selected ? accent : AstrologyColors.text,
                  ),
                ),
              ),
            ],
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
    this.accent = AstrologyColors.gold,
  });

  final String style;
  final ValueChanged<String> onStyle;
  final Color accent;

  static const double height = 42;

  @override
  Widget build(BuildContext context) {
    const options = [('north', 'North Indian'), ('south', 'South Indian')];
    return Semantics(
      label: 'Chart style',
      child: _AstrologyPillSegment(
        height: height,
        accent: accent,
        options: options,
        selected: style,
        onSelected: onStyle,
      ),
    );
  }
}

class _AstrologyPillSegment extends StatelessWidget {
  const _AstrologyPillSegment({
    required this.height,
    required this.accent,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final double height;
  final Color accent;
  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final onAccent = ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
        ? Colors.white
        : AstrologyColors.text;
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AstrologyColors.raised,
        borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
        border: Border.all(color: AstrologyColors.line),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: selected == option.$1
                      ? accent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(SkpTokens.radiusSm),
                  child: InkWell(
                    onTap: () => onSelected(option.$1),
                    borderRadius: BorderRadius.circular(SkpTokens.radiusSm),
                    child: Center(
                      child: Text(
                        option.$2,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: selected == option.$1
                                  ? onAccent
                                  : AstrologyColors.muted,
                              fontWeight: selected == option.$1
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                      ),
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
