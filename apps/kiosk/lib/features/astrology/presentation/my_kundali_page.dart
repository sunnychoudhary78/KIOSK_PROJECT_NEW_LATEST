import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:skp_kiosk/core/input/kiosk_hardware_key_map.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/astrology/application/my_kundali_controller.dart';
import 'package:skp_kiosk/features/astrology/data/astrology_repository.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_insights.dart';
import 'package:skp_kiosk/features/astrology/domain/kundali_locale.dart';
import 'package:skp_kiosk/features/astrology/domain/kundali_phase.dart';
import 'package:skp_kiosk/features/astrology/domain/kundali_result.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_assets.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_casting_view.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_form_defaults.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_print_shell.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_theme.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/astrology_birth_form.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/astrology_insights_panel.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/reading_mark.dart';
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
  ResolvedBirthPlace? _placeCoords;
  String _selectedChartKey = 'RasiD1';

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

  Future<void> _verifyOtpAndShowQuota(MyKundaliController controller) async {
    final summary = await controller.verifyPrintPhoneOtp();
    if (!mounted || summary == null) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Free print check'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary.remainingLabel,
                style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                summary.printCostLine,
                style: Theme.of(dialogContext).textTheme.bodyLarge,
              ),
              if (summary.message != null &&
                  summary.message!.trim().isNotEmpty &&
                  !summary.freeEligible) ...[
                const SizedBox(height: 12),
                Text(
                  summary.message!,
                  style: Theme.of(dialogContext).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
          actions: [
            KioskPrimaryButton(
              label: 'OK',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    await controller.continueAfterQuotaSummary(summary);
  }

  void _goBack() {
    Navigator.of(context).pop();
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
    ref
        .read(myKundaliControllerProvider.notifier)
        .submit(
          name: _name.text,
          gender: _gender,
          dateOfBirth: _formatDob(_dob),
          birthTime: _formatTime(_birthTime),
          birthPlace: _place.text,
          birthTimeUnknown: _timeUnknown,
          style: _style,
          latitude: _placeCoords?.latitude,
          longitude: _placeCoords?.longitude,
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
      _focus = reverse
          ? (_focus == 0 ? max : _focus - 1)
          : (_focus == max ? 0 : _focus + 1);
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
          _dob = KioskDateStepper.stepColumn(
            _dob,
            column: _stepperColumn,
            delta: delta,
          );
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
    _name.clear();
    _place.clear();
    setState(() {
      _dob = AstrologyFormDefaults.dob;
      _birthTime = AstrologyFormDefaults.birthTime;
      _timeUnknown = false;
      _gender = AstrologyFormDefaults.gender;
      _style = AstrologyFormDefaults.chartStyle;
      _placeCoords = null;
      _focus = 0;
      _stepperColumn = 0;
      _selectedChartKey = AstrologyFormDefaults.selectedChartKey;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myKundaliControllerProvider);
    final controller = ref.read(myKundaliControllerProvider.notifier);

    ref.listen(myKundaliControllerProvider, (previous, next) {
      holdSessionForAstrologyPrint(ref, next.print);
    });

    final paused = astrologyPausedShell(
      ref: ref,
      print: state.print,
      title: 'My Kundali',
      onHome: _endSession,
    );
    if (paused != null) return paused;

    if (astrologyPrintIsActive(state.print)) {
      return AstrologyPrintShell(
        title: 'My Kundali',
        print: state.print,
        onHome: _endSession,
        onBackFromPreview: controller.backFromPrintFlow,
        onConfirmPrint: controller.confirmPrint,
        onTellStaff: controller.tellStaffPrint,
        onClearResult: controller.clearPrintResult,
        onReportMissing: controller.reportPrintPagesMissing,
        onChoosePhoneQuota: controller.choosePhoneQuota,
        onChoosePayDirect: controller.choosePayDirect,
        onPhoneChanged: controller.setPrintPhoneDigits,
        onOtpChanged: controller.setPrintOtpDigits,
        onRequestOtp: controller.requestPrintPhoneOtp,
        onVerifyOtp: () => _verifyOtpAndShowQuota(controller),
      );
    }

    Widget? leading;
    Widget? trailing;
    var step = 'Details';
    switch (state.phase) {
      case KundaliPhase.form:
        leading = KioskGhostButton(
          label: 'Back',
          icon: Icons.arrow_back,
          onPressed: _goBack,
        );
        trailing = KioskPrimaryButton(
          label: 'Draw kundali',
          onPressed: _submit,
        );
        step = 'Details';
      case KundaliPhase.loading:
        step = 'Drawing';
      case KundaliPhase.result:
        leading = KioskGhostButton(label: 'New kundali', onPressed: _resetForm);
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KioskGhostButton(
              label: 'Done',
              onPressed: _endSession,
            ),
            const SizedBox(width: 12),
            KioskPrimaryButton(
              label: 'Print',
              icon: Icons.print,
              expand: false,
              onPressed: () =>
                  controller.preparePrint(chartKey: _selectedChartKey),
            ),
          ],
        );
        step = 'Result';
    }

    Widget page = VisitorSessionPopScope(
      endSessionOnPop: false,
      child: KioskShell(
        title: 'My Kundali',
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
                  accent: AstrologyColors.kundali,
                  emblem: AstrologyReadingKind.kundali,
                  onFocus: (value) => setState(() {
                    _focus = value;
                    _clampStepperColumn();
                  }),
                  onDob: (value) => setState(() => _dob = value),
                  onTime: (value) => setState(() => _birthTime = value),
                  onTimeUnknown: (value) =>
                      setState(() => _timeUnknown = value),
                  onGender: (value) => setState(() => _gender = value),
                  onKey: _type,
                  onBackspace: _backspace,
                  onPlaceResolved: (value) =>
                      setState(() => _placeCoords = value),
                  footer: AstrologyStyleSegment(
                    style: _style,
                    accent: AstrologyColors.kundali,
                    onStyle: (value) => setState(() => _style = value),
                  ),
                ),
              ],
            ),
            KundaliPhase.loading => const AstrologyCastingView(
              key: ValueKey('kundali-loading'),
              accent: AstrologyColors.kundali,
              lines: [
                'Drawing your kundali…',
                'Mapping houses & signs…',
                'Preparing your chart…',
              ],
            ),
            KundaliPhase.result when state.result != null =>
                astrologyResultWithError(
              key: const ValueKey('kundali-result'),
              error: state.error,
              child: KundaliResultView(
                result: state.result!,
                onChartTabChanged: (key) =>
                    setState(() => _selectedChartKey = key),
              ),
            ),
            KundaliPhase.result => const AstrologyCastingView(
              key: ValueKey('kundali-result-empty'),
              accent: AstrologyColors.kundali,
              lines: ['Preparing your chart…'],
            ),
          },
        ),
      ),
    );

    if (state.phase != KundaliPhase.form) {
      return page;
    }
    return KioskHardwareKeys(onKeyEvent: _handleFormKey, child: page);
  }
}

@visibleForTesting
class KundaliResultView extends StatefulWidget {
  const KundaliResultView({
    super.key,
    required this.result,
    this.onLocaleChanged,
    this.onChartTabChanged,
  });

  final KundaliResult result;
  final ValueChanged<AstrologyInsightLocale>? onLocaleChanged;
  final ValueChanged<String>? onChartTabChanged;

  @override
  State<KundaliResultView> createState() => _KundaliResultViewState();
}

class _KundaliResultViewState extends State<KundaliResultView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late String _selectedTab;
  AstrologyInsightLocale _locale = AstrologyInsightLocale.en;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onChartTabChanged?.call(_selectedTab);
    });
  }

  void _setLocale(AstrologyInsightLocale locale) {
    if (locale == _locale) return;
    setState(() => _locale = locale);
    widget.onLocaleChanged?.call(locale);
  }

  void _selectTab(String key) {
    if (key == _selectedTab) return;
    setState(() => _selectedTab = key);
    widget.onChartTabChanged?.call(key);
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
    final selectedEntry =
        result.charts[_selectedTab] ??
        (tabs.isNotEmpty ? tabs.first.value : null);
    final selectedSvg = selectedEntry?.svg ?? result.svg;
    final tiles = <({String label, String value, String? art})>[
      if (chart.lagna != null)
        (
          label: KundaliLocale.fieldLabel('lagna', _locale),
          value: KundaliLocale.localizeChartValue(chart.lagna!, _locale),
          art: AstrologyAssets.chartArtFor(label: 'Lagna', value: chart.lagna!),
        ),
      if (chart.sunSign != null)
        (
          label: KundaliLocale.fieldLabel('sun', _locale),
          value: KundaliLocale.localizeChartValue(chart.sunSign!, _locale),
          art: AstrologyAssets.chartArtFor(label: 'Sun', value: chart.sunSign!),
        ),
      if (chart.moonSign != null)
        (
          label: KundaliLocale.fieldLabel('moon', _locale),
          value: KundaliLocale.localizeChartValue(chart.moonSign!, _locale),
          art: AstrologyAssets.chartArtFor(
            label: 'Moon',
            value: chart.moonSign!,
          ),
        ),
      if (chart.nakshatra != null)
        (
          label: KundaliLocale.fieldLabel('nakshatra', _locale),
          value: KundaliLocale.localizeChartValue(chart.nakshatra!, _locale),
          art: AstrologyAssets.chartArtFor(
            label: 'Nakshatra',
            value: chart.nakshatra!,
          ),
        ),
      if (chart.currentDasha != null && chart.currentDasha!.trim().isNotEmpty)
        (
          label: KundaliLocale.fieldLabel('dasha', _locale),
          value: KundaliLocale.localizeChartValue(chart.currentDasha!, _locale),
          art: AstrologyAssets.chartArtFor(
            label: 'Dasha',
            value: chart.currentDasha!,
          ),
        ),
    ];

    final styleLabel = KundaliLocale.styleLabel(result.style, _locale);
    final insightBullets =
        result.insights.forChart(_selectedTab)?.forLocale(_locale) ??
            const <String>[];

    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: GlassPanel(
                            key: const ValueKey('kundali-chart-stage'),
                            padding: const EdgeInsets.all(10),
                            borderColor: AstrologyColors.kundali.withValues(
                              alpha: 0.75,
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final side = constraints.maxHeight;
                                final showInsights = insightBullets.isNotEmpty;
                                final chart = SizedBox(
                                  width: side,
                                  height: side,
                                  child: CustomPaint(
                                    foregroundPainter:
                                        const _ManuscriptCorners(),
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
                                          padding: const EdgeInsets.all(4),
                                          child: AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 220,
                                            ),
                                            switchInCurve: Curves.easeOut,
                                            switchOutCurve: Curves.easeIn,
                                            child: SvgPicture.string(
                                              selectedSvg,
                                              key: ValueKey(
                                                'kundali-chart-$_selectedTab',
                                              ),
                                              fit: BoxFit.contain,
                                              placeholderBuilder: (_) =>
                                                  const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                  color: AstrologyColors.gold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                                if (!showInsights) {
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: chart,
                                  );
                                }
                                return Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    chart,
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: AstrologyInsightsPanel(
                                          key: const ValueKey(
                                            'kundali-insights-panel',
                                          ),
                                          title: KundaliLocale.insightsTitle(
                                            _locale,
                                          ),
                                          bullets: insightBullets,
                                          locale: _locale,
                                          onLocaleChanged: _setLocale,
                                          accent: AstrologyColors.kundali,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        if (tabs.isNotEmpty || tiles.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 244,
                            child: _KundaliSummaryRail(
                              key: const ValueKey('kundali-chart-controls'),
                              styleLabel: styleLabel,
                              chartLabel: selectedEntry?.subtitle,
                              tabs: tabs,
                              selectedTab: _selectedTab,
                              onTabSelected: _selectTab,
                              tiles: tiles,
                              locale: _locale,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  DisclaimerCaption(
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

class _KundaliSummaryRail extends StatelessWidget {
  const _KundaliSummaryRail({
    super.key,
    required this.styleLabel,
    required this.tabs,
    required this.selectedTab,
    required this.onTabSelected,
    required this.tiles,
    required this.locale,
    this.chartLabel,
  });

  final String styleLabel;
  final String? chartLabel;
  final List<MapEntry<String, KundaliChartEntry>> tabs;
  final String selectedTab;
  final ValueChanged<String> onTabSelected;
  final List<({String label, String value, String? art})> tiles;
  final AstrologyInsightLocale locale;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (tabs.isNotEmpty)
          SizedBox(
            height: 40,
            child: _ChartTabBar(
              tabs: tabs,
              selectedTab: selectedTab,
              onTabSelected: onTabSelected,
              locale: locale,
            ),
          ),
        if (tabs.isNotEmpty) const SizedBox(height: 6),
        Row(
          children: [
            if (chartLabel != null)
              Expanded(
                child: Text(
                  chartLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AstrologyColors.goldSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (chartLabel == null) const Spacer(),
            const SizedBox(width: 6),
            _MetaChip(label: styleLabel),
          ],
        ),
        if (tiles.isNotEmpty) const SizedBox(height: 6),
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          _KundaliSummaryTile(tile: tiles[i]),
        ],
        if (tiles.isNotEmpty) const Spacer(),
      ],
    );
  }
}

class _ChartTabBar extends StatelessWidget {
  const _ChartTabBar({
    required this.tabs,
    required this.selectedTab,
    required this.onTabSelected,
    required this.locale,
  });

  final List<MapEntry<String, KundaliChartEntry>> tabs;
  final String selectedTab;
  final ValueChanged<String> onTabSelected;
  final AstrologyInsightLocale locale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AstrologyColors.raised.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AstrologyColors.gold.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          for (final entry in tabs)
            Expanded(
              child: _ChartTabButton(
                label: KundaliLocale.chartTabTitle(entry.key, locale),
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
          padding: const EdgeInsets.symmetric(vertical: 6),
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
        border: Border.all(color: AstrologyColors.gold.withValues(alpha: 0.45)),
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
    const artSize = 46.0;
    const iconSize = 22.0;
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderColor: AstrologyColors.kundali.withValues(alpha: 0.4),
      child: Row(
        children: [
          Container(
            width: artSize,
            height: artSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AstrologyColors.kundali,
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: AstrologyColors.gold.withValues(alpha: 0.28),
                  blurRadius: 10,
                ),
              ],
            ),
            child: ClipOval(
              child: tile.art != null
                  ? AstrologyAssetImage(
                      asset: tile.art!,
                      width: artSize,
                      height: artSize,
                      fit: BoxFit.cover,
                    )
                  : ColoredBox(
                      color: AstrologyColors.raised,
                      child: Icon(
                        Icons.auto_awesome,
                        color: AstrologyColors.gold,
                        size: iconSize,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tile.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AstrologyColors.muted,
                    height: 1.1,
                  ),
                ),
                Text(
                  tile.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AstrologyColors.text,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
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

class _ManuscriptCorners extends CustomPainter {
  const _ManuscriptCorners();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AstrologyColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const length = 18.0;
    const inset = 4.0;
    void corner(Offset origin, double xSign, double ySign) {
      canvas.drawLine(origin, origin + Offset(xSign * length, 0), paint);
      canvas.drawLine(origin, origin + Offset(0, ySign * length), paint);
    }

    corner(const Offset(inset, inset), 1, 1);
    corner(Offset(size.width - inset, inset), -1, 1);
    corner(Offset(inset, size.height - inset), 1, -1);
    corner(Offset(size.width - inset, size.height - inset), -1, -1);
  }

  @override
  bool shouldRepaint(covariant _ManuscriptCorners oldDelegate) => false;
}
