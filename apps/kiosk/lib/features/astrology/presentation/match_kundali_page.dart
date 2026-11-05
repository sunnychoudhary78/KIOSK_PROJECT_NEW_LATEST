import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/input/kiosk_hardware_key_map.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/astrology/application/match_kundali_controller.dart';
import 'package:skp_kiosk/features/astrology/data/astrology_repository.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_insights.dart';
import 'package:skp_kiosk/features/astrology/domain/match_kundali_phase.dart';
import 'package:skp_kiosk/features/astrology/domain/match_kundali_result.dart';
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

class MatchKundaliPage extends ConsumerStatefulWidget {
  const MatchKundaliPage({super.key});

  @override
  ConsumerState<MatchKundaliPage> createState() => _MatchKundaliPageState();
}

class _MatchKundaliPageState extends ConsumerState<MatchKundaliPage> {
  final _groomName = TextEditingController();
  final _groomPlace = TextEditingController();
  final _brideName = TextEditingController();
  final _bridePlace = TextEditingController();
  DateTime _groomDob = DateTime(1992, 1, 1);
  DateTime _brideDob = DateTime(1995, 1, 1);
  TimeOfDay _groomTime = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _brideTime = const TimeOfDay(hour: 12, minute: 0);
  bool _groomTimeUnknown = false;
  bool _brideTimeUnknown = false;
  int _focus = 0;
  int _stepperColumn = 0;
  ResolvedBirthPlace? _groomPlaceCoords;
  ResolvedBirthPlace? _bridePlaceCoords;
  AstrologyInsightLocale _insightLocale = AstrologyInsightLocale.en;

  bool get _isBride =>
      ref.read(matchKundaliControllerProvider).phase == MatchKundaliPhase.bride;

  TextEditingController get _activeName => _isBride ? _brideName : _groomName;
  TextEditingController get _activePlace =>
      _isBride ? _bridePlace : _groomPlace;
  bool get _activeTimeUnknown =>
      _isBride ? _brideTimeUnknown : _groomTimeUnknown;

  @override
  void dispose() {
    _groomName.dispose();
    _groomPlace.dispose();
    _brideName.dispose();
    _bridePlace.dispose();
    super.dispose();
  }

  Future<void> _endSession() {
    return ref
        .read(kioskSessionControllerProvider.notifier)
        .endVisitorSession(attract: false);
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _time(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  MatchPersonInput _person({
    required TextEditingController name,
    required TextEditingController place,
    required DateTime dob,
    required TimeOfDay time,
    required bool timeUnknown,
    ResolvedBirthPlace? placeCoords,
  }) {
    return MatchPersonInput(
      name: name.text.trim(),
      dateOfBirth: _date(dob),
      birthTime: timeUnknown ? '12:00' : _time(time),
      birthPlace: place.text.trim(),
      birthTimeUnknown: timeUnknown,
      latitude: placeCoords?.latitude,
      longitude: placeCoords?.longitude,
    );
  }

  bool _valid(TextEditingController name, TextEditingController place) {
    if (name.text.trim().isEmpty || place.text.trim().length < 2) {
      ref
          .read(matchKundaliControllerProvider.notifier)
          .setError('Name and birth place are required');
      return false;
    }
    return true;
  }

  void _continueToBride() {
    if (!_valid(_groomName, _groomPlace)) return;
    ref.read(matchKundaliControllerProvider.notifier).showBride();
    setState(() {
      _focus = 0;
      _stepperColumn = 0;
    });
  }

  void _submit() {
    if (!_valid(_brideName, _bridePlace)) return;
    ref
        .read(matchKundaliControllerProvider.notifier)
        .submit(
          groom: _person(
            name: _groomName,
            place: _groomPlace,
            dob: _groomDob,
            time: _groomTime,
            timeUnknown: _groomTimeUnknown,
            placeCoords: _groomPlaceCoords,
          ),
          bride: _person(
            name: _brideName,
            place: _bridePlace,
            dob: _brideDob,
            time: _brideTime,
            timeUnknown: _brideTimeUnknown,
            placeCoords: _bridePlaceCoords,
          ),
        );
  }

  void _primaryAction() {
    final phase = ref.read(matchKundaliControllerProvider).phase;
    if (phase == MatchKundaliPhase.groom) {
      _continueToBride();
    } else if (phase == MatchKundaliPhase.bride) {
      _submit();
    }
  }

  void _type(String value) {
    appendToController(
      _focus == 0 ? _activeName : _activePlace,
      value,
      maxLength: 64,
    );
    setState(() {});
  }

  void _backspace() {
    backspaceController(_focus == 0 ? _activeName : _activePlace);
    setState(() {});
  }

  void _cycleFocus({required bool reverse}) {
    final max = _activeTimeUnknown ? 2 : 3;
    setState(() {
      _focus = reverse
          ? (_focus == 0 ? max : _focus - 1)
          : (_focus == max ? 0 : _focus + 1);
      _stepperColumn = _stepperColumn.clamp(0, _focus == 3 ? 1 : 2);
    });
  }

  void _nudgeStepper(int delta, {required bool moveColumn}) {
    if (_focus == 2) {
      setState(() {
        if (moveColumn) {
          _stepperColumn = nextStepperColumn(_stepperColumn, 3, delta);
        } else if (_isBride) {
          _brideDob = KioskDateStepper.stepColumn(
            _brideDob,
            column: _stepperColumn,
            delta: delta,
          );
        } else {
          _groomDob = KioskDateStepper.stepColumn(
            _groomDob,
            column: _stepperColumn,
            delta: delta,
          );
        }
      });
    } else if (_focus == 3 && !_activeTimeUnknown) {
      setState(() {
        if (moveColumn) {
          _stepperColumn = nextStepperColumn(_stepperColumn, 2, delta);
        } else if (_isBride) {
          _brideTime = KioskTimeStepper.stepColumn(
            _brideTime,
            column: _stepperColumn,
            delta: delta,
          );
        } else {
          _groomTime = KioskTimeStepper.stepColumn(
            _groomTime,
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
    if (command == null) return KeyEventResult.ignored;
    switch (command.action) {
      case AstrologyHardwareAction.character:
        if ((_focus == 0 || _focus == 1) && command.character != null) {
          _type(command.character!);
        }
      case AstrologyHardwareAction.backspace:
        if (_focus == 0 || _focus == 1) _backspace();
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
        _primaryAction();
    }
    return KeyEventResult.handled;
  }

  void _backToGroom() {
    ref.read(matchKundaliControllerProvider.notifier).showGroom();
    setState(() {
      _focus = 0;
      _stepperColumn = 0;
    });
  }

  void _reset() {
    ref.read(matchKundaliControllerProvider.notifier).reset();
    _groomName.clear();
    _groomPlace.clear();
    _brideName.clear();
    _bridePlace.clear();
    setState(() {
      _groomDob = AstrologyFormDefaults.groomDob;
      _brideDob = AstrologyFormDefaults.brideDob;
      _groomTime = AstrologyFormDefaults.birthTime;
      _brideTime = AstrologyFormDefaults.birthTime;
      _groomTimeUnknown = false;
      _brideTimeUnknown = false;
      _groomPlaceCoords = null;
      _bridePlaceCoords = null;
      _focus = 0;
      _stepperColumn = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchKundaliControllerProvider);
    final controller = ref.read(matchKundaliControllerProvider.notifier);
    final formPhase =
        state.phase == MatchKundaliPhase.groom ||
        state.phase == MatchKundaliPhase.bride;

    ref.listen(matchKundaliControllerProvider, (previous, next) {
      holdSessionForAstrologyPrint(ref, next.print);
    });

    final paused = astrologyPausedShell(
      ref: ref,
      print: state.print,
      title: 'Match Kundalis',
      onHome: _endSession,
    );
    if (paused != null) return paused;

    if (astrologyPrintIsActive(state.print)) {
      return AstrologyPrintShell(
        title: 'Match Kundalis',
        print: state.print,
        onHome: _endSession,
        onBackFromPreview: controller.cancelPrintPreview,
        onConfirmPrint: controller.confirmPrint,
        onTellStaff: controller.tellStaffPrint,
        onClearResult: controller.clearPrintResult,
        onReportMissing: controller.reportPrintPagesMissing,
      );
    }

    Widget? leading;
    Widget? trailing;
    switch (state.phase) {
      case MatchKundaliPhase.groom:
        leading = KioskGhostButton(
          label: 'Back',
          icon: Icons.arrow_back,
          onPressed: _goBack,
        );
        trailing = KioskPrimaryButton(
          label: 'Continue',
          onPressed: _continueToBride,
        );
      case MatchKundaliPhase.bride:
        leading = KioskGhostButton(
          label: 'Groom details',
          onPressed: _backToGroom,
        );
        trailing = KioskPrimaryButton(
          label: 'Match kundalis',
          onPressed: _submit,
        );
      case MatchKundaliPhase.loading:
        break;
      case MatchKundaliPhase.result:
        leading = KioskGhostButton(label: 'New match', onPressed: _reset);
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KioskGhostButton(label: 'Done', onPressed: _endSession),
            const SizedBox(width: 12),
            KioskPrimaryButton(
              label: 'Print',
              icon: Icons.print,
              expand: false,
              onPressed: () => controller.preparePrint(),
            ),
          ],
        );
    }

    Widget page = VisitorSessionPopScope(
      endSessionOnPop: false,
      child: KioskShell(
        title: 'Match Kundalis',
        onHome: _endSession,
        stepLabel: switch (state.phase) {
          MatchKundaliPhase.groom => 'Groom',
          MatchKundaliPhase.bride => 'Bride',
          MatchKundaliPhase.loading => 'Matching',
          MatchKundaliPhase.result => 'Gun Milan',
        },
        footerLeading: leading,
        footerTrailing: trailing,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: switch (state.phase) {
            MatchKundaliPhase.groom => _birthForm(
              key: const ValueKey('match-groom'),
              title: 'Groom details',
              subtitle: 'Birth details for Gun Milan',
              accent: AstrologyColors.matchIndigo,
              name: _groomName,
              place: _groomPlace,
              dob: _groomDob,
              time: _groomTime,
              timeUnknown: _groomTimeUnknown,
              error: state.error,
              onDob: (value) => setState(() => _groomDob = value),
              onTime: (value) => setState(() => _groomTime = value),
              onUnknown: (value) => setState(() => _groomTimeUnknown = value),
              onPlaceResolved: (value) =>
                  setState(() => _groomPlaceCoords = value),
            ),
            MatchKundaliPhase.bride => _birthForm(
              key: const ValueKey('match-bride'),
              title: 'Bride details',
              subtitle: 'Add the second birth chart',
              accent: AstrologyColors.matchRose,
              name: _brideName,
              place: _bridePlace,
              dob: _brideDob,
              time: _brideTime,
              timeUnknown: _brideTimeUnknown,
              error: state.error,
              leading: GroomSummaryCard(
                name: _groomName.text,
                dateOfBirth: _date(_groomDob),
                birthPlace: _groomPlace.text,
              ),
              onDob: (value) => setState(() => _brideDob = value),
              onTime: (value) => setState(() => _brideTime = value),
              onUnknown: (value) => setState(() => _brideTimeUnknown = value),
              onPlaceResolved: (value) =>
                  setState(() => _bridePlaceCoords = value),
            ),
            MatchKundaliPhase.loading => const AstrologyCastingView(
              key: ValueKey('match-loading'),
              accent: AstrologyColors.matchRose,
              lines: [
                'Comparing moon signs…',
                'Calculating Gun Milan…',
                'Preparing compatibility…',
              ],
            ),
            MatchKundaliPhase.result when state.result != null =>
              astrologyResultWithError(
                key: const ValueKey('match-result'),
                error: state.error,
                child: MatchKundaliResultView(
                  result: state.result!,
                  onLocaleChanged: (locale) =>
                      setState(() => _insightLocale = locale),
                ),
              ),
            MatchKundaliPhase.result => const AstrologyCastingView(
              key: ValueKey('match-result-empty'),
              accent: AstrologyColors.matchRose,
              lines: ['Preparing compatibility…'],
            ),
          },
        ),
      ),
    );
    if (formPhase) {
      page = KioskHardwareKeys(onKeyEvent: _handleFormKey, child: page);
    }
    return page;
  }

  Widget _birthForm({
    required Key key,
    required String title,
    required String subtitle,
    required TextEditingController name,
    required TextEditingController place,
    required DateTime dob,
    required TimeOfDay time,
    required bool timeUnknown,
    required ValueChanged<DateTime> onDob,
    required ValueChanged<TimeOfDay> onTime,
    required ValueChanged<bool> onUnknown,
    required ValueChanged<ResolvedBirthPlace?> onPlaceResolved,
    String? error,
    Widget? leading,
    required Color accent,
  }) {
    return Stack(
      key: key,
      fit: StackFit.expand,
      children: [
        AstrologyBirthFormPanel(
          nameController: name,
          placeController: place,
          dob: dob,
          birthTime: time,
          timeUnknown: timeUnknown,
          gender: _isBride ? 'female' : 'male',
          showGender: false,
          focus: _focus,
          error: error,
          title: title,
          subtitle: subtitle,
          leading: leading,
          accent: accent,
          emblem: AstrologyReadingKind.match,
          onFocus: (value) => setState(() => _focus = value),
          onDob: onDob,
          onTime: onTime,
          onTimeUnknown: onUnknown,
          onGender: (_) {},
          onKey: _type,
          onBackspace: _backspace,
          onPlaceResolved: onPlaceResolved,
        ),
      ],
    );
  }
}

@visibleForTesting
class GroomSummaryCard extends StatelessWidget {
  const GroomSummaryCard({
    super.key,
    required this.name,
    required this.dateOfBirth,
    required this.birthPlace,
  });

  final String name;
  final String dateOfBirth;
  final String birthPlace;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: GlassPanel(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_outline,
              color: AstrologyColors.gold,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              name.isEmpty ? 'Groom' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AstrologyColors.goldSoft,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              dateOfBirth,
              style: const TextStyle(color: AstrologyColors.text),
            ),
            const SizedBox(height: 4),
            Text(
              birthPlace,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AstrologyColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

@visibleForTesting
class MatchKundaliResultView extends StatefulWidget {
  const MatchKundaliResultView({
    super.key,
    required this.result,
    this.onLocaleChanged,
  });

  final MatchKundaliResult result;
  final ValueChanged<AstrologyInsightLocale>? onLocaleChanged;

  @override
  State<MatchKundaliResultView> createState() => _MatchKundaliResultViewState();
}

class _MatchKundaliResultViewState extends State<MatchKundaliResultView> {
  AstrologyInsightLocale _locale = AstrologyInsightLocale.en;

  Color _toneColor(String tone) {
    return switch (tone.toLowerCase()) {
      'good' => AstrologyColors.accent,
      'poor' || 'bad' => AstrologyColors.danger,
      _ => AstrologyColors.gold,
    };
  }

  void _setLocale(AstrologyInsightLocale locale) {
    if (locale == _locale) return;
    setState(() => _locale = locale);
    widget.onLocaleChanged?.call(locale);
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final score = result.score;
    final kutas = padMatchKutas(result.kutas);
    final tone = _toneColor(score.tone);
    final note = result.accuracyNote ?? result.disclaimer;
    final bullets = result.insights.forLocale(_locale);
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 340,
                      child: GlassPanel(
                        key: const ValueKey('match-score-card'),
                        padding: const EdgeInsets.all(22),
                        borderColor: tone.withValues(alpha: 0.65),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 168,
                              height: 168,
                              child: CustomPaint(
                                painter: _ScoreRingPainter(
                                  progress: score.max == 0
                                      ? 0
                                      : (score.total / score.max)
                                            .clamp(0, 1)
                                            .toDouble(),
                                  color: tone,
                                ),
                                child: Center(
                                  child: Text(
                                    '${score.total.toStringAsFixed(score.total % 1 == 0 ? 0 : 1)} / ${score.max.toStringAsFixed(0)}',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          color: tone,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              score.summary,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: AstrologyColors.text,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _PersonNamePill(
                                    name: result.groomName,
                                    color: AstrologyColors.matchIndigo,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    '×',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: AstrologyColors.goldSoft,
                                        ),
                                  ),
                                ),
                                Expanded(
                                  child: _PersonNamePill(
                                    name: result.brideName,
                                    color: AstrologyColors.matchRose,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      key: const ValueKey('match-kuta-grid'),
                      child: Column(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                for (var row = 0; row < 4; row++) ...[
                                  if (row > 0) const SizedBox(height: 6),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _MatchKutaTile(
                                            kuta: kutas[row * 2],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _MatchKutaTile(
                                            kuta: kutas[row * 2 + 1],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (bullets.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            GlassPanel(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                              borderColor: AstrologyColors.matchRose
                                  .withValues(alpha: 0.4),
                              child: AstrologyInsightsPanel(
                                key: const ValueKey('match-insights-panel'),
                                bullets: bullets,
                                locale: _locale,
                                onLocaleChanged: _setLocale,
                                accent: AstrologyColors.matchRose,
                                compact: true,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              DisclaimerCaption(
                note,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AstrologyColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MatchKutaTile extends StatelessWidget {
  const _MatchKutaTile({required this.kuta});

  final MatchKuta kuta;

  @override
  Widget build(BuildContext context) {
    final nature = kuta.nature.toLowerCase();
    final color = nature == 'good'
        ? AstrologyColors.accent
        : nature == 'bad'
        ? AstrologyColors.danger
        : AstrologyColors.gold;
    final scoreText = kuta.points == null
        ? kuta.nature
        : '${kuta.points!.toStringAsFixed(kuta.points! % 1 == 0 ? 0 : 1)} / ${kuta.maxPoints.toStringAsFixed(0)}';
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      borderColor: color.withValues(alpha: 0.4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        kuta.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AstrologyColors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      scoreText,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    value: kuta.maxPoints <= 0 || kuta.points == null
                        ? 0
                        : (kuta.points! / kuta.maxPoints).clamp(0, 1).toDouble(),
                    backgroundColor: AstrologyColors.line,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  kuta.verdict,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AstrologyColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonNamePill extends StatelessWidget {
  const _PersonNamePill({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Text(
        name,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  const _ScoreRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.42;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
