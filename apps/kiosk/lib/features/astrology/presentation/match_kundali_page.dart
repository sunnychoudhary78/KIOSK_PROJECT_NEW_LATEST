import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/input/kiosk_hardware_key_map.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/astrology/application/match_kundali_controller.dart';
import 'package:skp_kiosk/features/astrology/data/astrology_repository.dart';
import 'package:skp_kiosk/features/astrology/domain/match_kundali_phase.dart';
import 'package:skp_kiosk/features/astrology/domain/match_kundali_result.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_casting_view.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_theme.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/astrology_birth_form.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/cosmic_backdrop.dart';
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
  }) {
    return MatchPersonInput(
      name: name.text.trim(),
      dateOfBirth: _date(dob),
      birthTime: timeUnknown ? '12:00' : _time(time),
      birthPlace: place.text.trim(),
      birthTimeUnknown: timeUnknown,
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
          ),
          bride: _person(
            name: _brideName,
            place: _bridePlace,
            dob: _brideDob,
            time: _brideTime,
            timeUnknown: _brideTimeUnknown,
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
    setState(() => _focus = 0);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchKundaliControllerProvider);
    final formPhase =
        state.phase == MatchKundaliPhase.groom ||
        state.phase == MatchKundaliPhase.bride;

    Widget? leading;
    Widget? trailing;
    switch (state.phase) {
      case MatchKundaliPhase.groom:
        leading = KioskGhostButton(
          label: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        );
        trailing = KioskPrimaryButton(
          label: 'Continue',
          gold: true,
          onPressed: _continueToBride,
        );
      case MatchKundaliPhase.bride:
        leading = KioskGhostButton(
          label: 'Groom details',
          onPressed: _backToGroom,
        );
        trailing = KioskPrimaryButton(
          label: 'Match kundalis',
          gold: true,
          onPressed: _submit,
        );
      case MatchKundaliPhase.loading:
        break;
      case MatchKundaliPhase.result:
        leading = KioskGhostButton(label: 'New match', onPressed: _reset);
        trailing = KioskPrimaryButton(
          label: 'Done',
          gold: true,
          onPressed: _endSession,
        );
    }

    Widget page = VisitorSessionPopScope(
      child: KioskShell(
        title: 'Match Kundalis',
        cosmic: true,
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
              name: _groomName,
              place: _groomPlace,
              dob: _groomDob,
              time: _groomTime,
              timeUnknown: _groomTimeUnknown,
              error: state.error,
              onDob: (value) => setState(() => _groomDob = value),
              onTime: (value) => setState(() => _groomTime = value),
              onUnknown: (value) => setState(() => _groomTimeUnknown = value),
            ),
            MatchKundaliPhase.bride => _birthForm(
              key: const ValueKey('match-bride'),
              title: 'Bride details',
              subtitle: 'Add the second birth chart',
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
            ),
            MatchKundaliPhase.loading => const AstrologyCastingView(
              key: ValueKey('match-loading'),
              lines: [
                'Comparing moon signs…',
                'Calculating Gun Milan…',
                'Preparing compatibility…',
              ],
            ),
            MatchKundaliPhase.result when state.result != null =>
              MatchKundaliResultView(
                key: const ValueKey('match-result'),
                result: state.result!,
              ),
            MatchKundaliPhase.result => const AstrologyCastingView(
              key: ValueKey('match-result-empty'),
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
    String? error,
    Widget? leading,
  }) {
    return Stack(
      key: key,
      fit: StackFit.expand,
      children: [
        const CosmicBackdrop(),
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
          onFocus: (value) => setState(() => _focus = value),
          onDob: onDob,
          onTime: onTime,
          onTimeUnknown: onUnknown,
          onGender: (_) {},
          onKey: _type,
          onBackspace: _backspace,
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
class MatchKundaliResultView extends StatelessWidget {
  const MatchKundaliResultView({super.key, required this.result});

  final MatchKundaliResult result;

  Color _toneColor(String tone) {
    return switch (tone.toLowerCase()) {
      'good' => AstrologyColors.accent,
      'poor' || 'bad' => AstrologyColors.danger,
      _ => AstrologyColors.gold,
    };
  }

  @override
  Widget build(BuildContext context) {
    final score = result.score;
    final kutas = padMatchKutas(result.kutas);
    final tone = _toneColor(score.tone);
    final note = result.accuracyNote ?? result.disclaimer;
    return Stack(
      fit: StackFit.expand,
      children: [
        const CosmicBackdrop(),
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
                            const Icon(
                              Icons.favorite,
                              color: AstrologyColors.gold,
                              size: 46,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${score.total.toStringAsFixed(score.total % 1 == 0 ? 0 : 1)} / ${score.max.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.displayMedium
                                  ?.copyWith(
                                    color: tone,
                                    fontWeight: FontWeight.w900,
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
                            Text(
                              '${result.groomName}  ×  ${result.brideName}',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: AstrologyColors.goldSoft),
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
                          for (var row = 0; row < 4; row++) ...[
                            if (row > 0) const SizedBox(height: 8),
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
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
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
                const SizedBox(height: 3),
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
