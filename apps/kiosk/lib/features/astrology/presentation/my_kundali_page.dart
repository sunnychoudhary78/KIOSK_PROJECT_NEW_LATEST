import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:skp_kiosk/core/input/kiosk_hardware_key_map.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/astrology/application/my_kundali_controller.dart';
import 'package:skp_kiosk/features/astrology/domain/kundali_phase.dart';
import 'package:skp_kiosk/features/astrology/domain/kundali_result.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_assets.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_casting_view.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_theme.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/astrology_birth_form.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/cosmic_backdrop.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/glass_panel.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';

class MyKundaliPage extends ConsumerStatefulWidget {
  const MyKundaliPage({super.key});

  @override
  ConsumerState<MyKundaliPage> createState() => _MyKundaliPageState();
}

class _MyKundaliPageState extends ConsumerState<MyKundaliPage> {
  final _name = TextEditingController();
  final _place = TextEditingController();
  DateTime _dob = DateTime(1995, 1, 1);
  TimeOfDay _birthTime = const TimeOfDay(hour: 12, minute: 0);
  bool _timeUnknown = false;
  String _gender = 'female';
  String _style = 'north';
  int _focus = 0;
  int _stepperColumn = 0;

  @override
  void dispose() {
    _name.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _endSession() {
    return ref
        .read(kioskSessionControllerProvider.notifier)
        .endVisitorSession(attract: false);
  }

  String _formatDob(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _submit() {
    ref.read(myKundaliControllerProvider.notifier).submit(
          name: _name.text,
          gender: _gender,
          dateOfBirth: _formatDob(_dob),
          birthTime: _formatTime(_birthTime),
          birthPlace: _place.text,
          birthTimeUnknown: _timeUnknown,
          style: _style,
        );
  }

  void _type(String value) {
    final controller = _focus == 0 ? _name : _place;
    appendToController(controller, value, maxLength: 64);
    setState(() {});
  }

  void _backspace() {
    backspaceController(_focus == 0 ? _name : _place);
    setState(() {});
  }

  void _cycleFocus({required bool reverse}) {
    final max = _timeUnknown ? 2 : 3;
    setState(() {
      _focus = reverse ? (_focus == 0 ? max : _focus - 1) : (_focus == max ? 0 : _focus + 1);
      _clampStepperColumn();
    });
  }

  void _clampStepperColumn() {
    final maxColumn = _focus == 3 ? 1 : 2;
    if (_stepperColumn > maxColumn) {
      _stepperColumn = maxColumn;
    }
  }

  void _nudgeStepper(int delta, {required bool moveColumn}) {
    if (_focus == 2) {
      setState(() {
        if (moveColumn) {
          _stepperColumn = nextStepperColumn(_stepperColumn, 3, delta);
        } else {
          _dob = KioskDateStepper.stepColumn(_dob, column: _stepperColumn, delta: delta);
        }
      });
      return;
    }
    if (_focus == 3 && !_timeUnknown) {
      setState(() {
        if (moveColumn) {
          _stepperColumn = nextStepperColumn(_stepperColumn, 2, delta);
        } else {
          _birthTime = KioskTimeStepper.stepColumn(
            _birthTime,
            column: _stepperColumn,
            delta: delta,
          );
        }
      });
    }
  }

  KeyEventResult _handleFormKey(KeyEvent event) {
    final command = mapAstrologyHardwareKey(
      event,
      shiftPressed: HardwareKeyboard.instance.isShiftPressed,
    );
    if (command == null) {
      return KeyEventResult.ignored;
    }
    switch (command.action) {
      case AstrologyHardwareAction.character:
        if ((_focus == 0 || _focus == 1) && command.character != null) {
          _type(command.character!);
        }
      case AstrologyHardwareAction.backspace:
        if (_focus == 0 || _focus == 1) {
          _backspace();
        }
      case AstrologyHardwareAction.tab:
        _cycleFocus(reverse: false);
      case AstrologyHardwareAction.shiftTab:
        _cycleFocus(reverse: true);
      case AstrologyHardwareAction.arrowLeft:
        _nudgeStepper(-1, moveColumn: true);
      case AstrologyHardwareAction.arrowRight:
        _nudgeStepper(1, moveColumn: true);
      case AstrologyHardwareAction.arrowUp:
        _nudgeStepper(1, moveColumn: false);
      case AstrologyHardwareAction.arrowDown:
        _nudgeStepper(-1, moveColumn: false);
      case AstrologyHardwareAction.submit:
        _submit();
    }
    return KeyEventResult.handled;
  }

  void _resetForm() {
    ref.read(myKundaliControllerProvider.notifier).reset();
    setState(() {
      _focus = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myKundaliControllerProvider);

    Widget? leading;
    Widget? trailing;
    var step = 'Details';
    switch (state.phase) {
      case KundaliPhase.form:
        leading = KioskGhostButton(
          label: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        );
        trailing = KioskPrimaryButton(
          label: 'Draw kundali',
          gold: true,
          onPressed: _submit,
        );
        step = 'Details';
      case KundaliPhase.loading:
        step = 'Drawing';
      case KundaliPhase.result:
        leading = KioskGhostButton(label: 'New kundali', onPressed: _resetForm);
        trailing = KioskPrimaryButton(
          label: 'Done',
          gold: true,
          onPressed: _endSession,
        );
        step = 'Result';
    }

    Widget page = VisitorSessionPopScope(
      child: KioskShell(
        title: 'My Kundali',
        cosmic: true,
        onHome: _endSession,
        stepLabel: step,
        footerLeading: leading,
        footerTrailing: trailing,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: switch (state.phase) {
            KundaliPhase.form => Stack(
                key: const ValueKey('kundali-form'),
                fit: StackFit.expand,
                children: [
                  const CosmicBackdrop(),
                  AstrologyBirthFormPanel(
                    nameController: _name,
                    placeController: _place,
                    dob: _dob,
                    birthTime: _birthTime,
                    timeUnknown: _timeUnknown,
                    gender: _gender,
                    focus: _focus,
                    error: state.error,
                    title: 'Birth details',
                    subtitle: 'Accurate birth time · pick chart style',
                    onFocus: (value) => setState(() {
                      _focus = value;
                      _clampStepperColumn();
                    }),
                    onDob: (value) => setState(() => _dob = value),
                    onTime: (value) => setState(() => _birthTime = value),
                    onTimeUnknown: (value) => setState(() => _timeUnknown = value),
                    onGender: (value) => setState(() => _gender = value),
                    onKey: _type,
                    onBackspace: _backspace,
                    footer: AstrologyStyleSegment(
                      style: _style,
                      onStyle: (value) => setState(() => _style = value),
                    ),
                  ),
                ],
              ),
            KundaliPhase.loading => const AstrologyCastingView(
                key: ValueKey('kundali-loading'),
                lines: [
                  'Drawing your kundali…',
                  'Mapping houses & signs…',
                  'Preparing your chart…',
                ],
              ),
            KundaliPhase.result when state.result != null => _KundaliResultView(
                key: const ValueKey('kundali-result'),
                result: state.result!,
              ),
            KundaliPhase.result => const AstrologyCastingView(
                key: ValueKey('kundali-result-empty'),
                lines: ['Preparing your chart…'],
              ),
          },
        ),
      ),
    );

    if (state.phase != KundaliPhase.form) {
      return page;
    }
    return KioskHardwareKeys(
      onKeyEvent: _handleFormKey,
      child: page,
    );
  }
}

class _KundaliResultView extends StatefulWidget {
  const _KundaliResultView({super.key, required this.result});

  final KundaliResult result;

  @override
  State<_KundaliResultView> createState() => _KundaliResultViewState();
}

class _KundaliResultViewState extends State<_KundaliResultView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late String _selectedTab;

  @override
  void initState() {
    super.initState();
    final tabs = widget.result.availableTabs;
    _selectedTab = tabs.isNotEmpty ? tabs.first.key : 'RasiD1';
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(_fade);
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;
    final chart = result.chart;
    final tabs = result.availableTabs;
    final selectedEntry = result.charts[_selectedTab] ??
        (tabs.isNotEmpty ? tabs.first.value : null);
    final selectedSvg = selectedEntry?.svg ?? result.svg;
    final tiles = <({String label, String value, String? art})>[
      if (chart.lagna != null)
        (
          label: 'Lagna',
          value: chart.lagna!,
          art: AstrologyAssets.chartArtFor(label: 'Lagna', value: chart.lagna!),
        ),
      if (chart.sunSign != null)
        (
          label: 'Sun',
          value: chart.sunSign!,
          art: AstrologyAssets.chartArtFor(label: 'Sun', value: chart.sunSign!),
        ),
      if (chart.moonSign != null)
        (
          label: 'Moon',
          value: chart.moonSign!,
          art: AstrologyAssets.chartArtFor(label: 'Moon', value: chart.moonSign!),
        ),
      if (chart.nakshatra != null)
        (
          label: 'Nakshatra',
          value: chart.nakshatra!,
          art: AstrologyAssets.chartArtFor(
            label: 'Nakshatra',
            value: chart.nakshatra!,
          ),
        ),
      if (chart.currentDasha != null && chart.currentDasha!.trim().isNotEmpty)
        (
          label: 'Dasha',
          value: chart.currentDasha!,
          art: AstrologyAssets.chartArtFor(
            label: 'Dasha',
            value: chart.currentDasha!,
          ),
        ),
    ];

    final styleLabel =
        result.style == 'south' ? 'South Indian' : 'North Indian';
    final title =
        result.name.isEmpty ? 'Your kundali' : "${result.name}'s kundali";
    final subtitle = selectedEntry == null
        ? null
        : '${selectedEntry.subtitle} · ${selectedEntry.title}';

    return Stack(
      fit: StackFit.expand,
      children: [
        const CosmicBackdrop(),
        FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _KundaliResultHeader(
                    title: title,
                    styleLabel: styleLabel,
                    subtitle: subtitle,
                    tabs: tabs,
                    selectedTab: _selectedTab,
                    onTabSelected: (key) {
                      if (key == _selectedTab) return;
                      setState(() => _selectedTab = key);
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: GlassPanel(
                            padding: const EdgeInsets.all(12),
                            borderColor:
                                AstrologyColors.gold.withValues(alpha: 0.55),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AstrologyColors.gold
                                      .withValues(alpha: 0.35),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AstrologyColors.gold
                                        .withValues(alpha: 0.12),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    switchInCurve: Curves.easeOut,
                                    switchOutCurve: Curves.easeIn,
                                    child: SvgPicture.string(
                                      selectedSvg,
                                      key: ValueKey(_selectedTab),
                                      fit: BoxFit.contain,
                                      placeholderBuilder: (_) => const Center(
                                        child: CircularProgressIndicator(
                                          color: AstrologyColors.gold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (tiles.isNotEmpty) ...[
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                for (var i = 0; i < tiles.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 8),
                                  Expanded(
                                    child: _KundaliSummaryTile(tile: tiles[i]),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.disclaimer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AstrologyColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KundaliResultHeader extends StatelessWidget {
  const _KundaliResultHeader({
    required this.title,
    required this.styleLabel,
    required this.tabs,
    required this.selectedTab,
    required this.onTabSelected,
    this.subtitle,
  });

  final String title;
  final String styleLabel;
  final String? subtitle;
  final List<MapEntry<String, KundaliChartEntry>> tabs;
  final String selectedTab;
  final ValueChanged<String> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AstrologyColors.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AstrologyColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _MetaChip(label: styleLabel),
            ],
          ),
          if (tabs.length > 1) ...[
            const SizedBox(height: 10),
            _ChartTabBar(
              tabs: tabs,
              selectedTab: selectedTab,
              onTabSelected: onTabSelected,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChartTabBar extends StatelessWidget {
  const _ChartTabBar({
    required this.tabs,
    required this.selectedTab,
    required this.onTabSelected,
  });

  final List<MapEntry<String, KundaliChartEntry>> tabs;
  final String selectedTab;
  final ValueChanged<String> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AstrologyColors.raised.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AstrologyColors.gold.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          for (final entry in tabs)
            Expanded(
              child: _ChartTabButton(
                label: entry.value.title,
                selected: entry.key == selectedTab,
                onTap: () => onTabSelected(entry.key),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartTabButton extends StatelessWidget {
  const _ChartTabButton({
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AstrologyColors.gold.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AstrologyColors.gold.withValues(alpha: 0.55)
                  : Colors.transparent,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected
                      ? AstrologyColors.goldSoft
                      : AstrologyColors.muted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AstrologyColors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AstrologyColors.gold.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AstrologyColors.goldSoft,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _KundaliSummaryTile extends StatelessWidget {
  const _KundaliSummaryTile({required this.tile});

  final ({String label, String value, String? art}) tile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          if (tile.art != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AstrologyAssetImage(
                asset: tile.art!,
                width: 44,
                height: 44,
              ),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AstrologyColors.raised,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AstrologyColors.gold,
                size: 22,
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tile.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AstrologyColors.muted,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  tile.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AstrologyColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
