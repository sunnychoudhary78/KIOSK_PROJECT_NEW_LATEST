import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/input/kiosk_hardware_key_map.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/astrology/application/today_periods_controller.dart';
import 'package:skp_kiosk/features/astrology/data/astrology_repository.dart';
import 'package:skp_kiosk/features/astrology/domain/today_periods_phase.dart';
import 'package:skp_kiosk/features/astrology/domain/today_periods_result.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_casting_view.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_theme.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/astrology_birth_form.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/cosmic_backdrop.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/glass_panel.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';

class TodayPeriodsPage extends ConsumerStatefulWidget {
  const TodayPeriodsPage({super.key});

  @override
  ConsumerState<TodayPeriodsPage> createState() => _TodayPeriodsPageState();
}

class _TodayPeriodsPageState extends ConsumerState<TodayPeriodsPage> {
  final _name = TextEditingController();
  final _place = TextEditingController();
  DateTime _dob = DateTime(1995, 1, 1);
  TimeOfDay _birthTime = const TimeOfDay(hour: 12, minute: 0);
  bool _timeUnknown = false;
  String _gender = 'female';
  int _focus = 0;
  int _stepperColumn = 0;
  ResolvedBirthPlace? _placeCoords;

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
    ref
        .read(todayPeriodsControllerProvider.notifier)
        .submit(
          name: _name.text,
          gender: _gender,
          dateOfBirth: _formatDob(_dob),
          birthTime: _formatTime(_birthTime),
          birthPlace: _place.text,
          birthTimeUnknown: _timeUnknown,
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
    ref.read(todayPeriodsControllerProvider.notifier).reset();
    setState(() {
      _focus = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todayPeriodsControllerProvider);

    Widget? leading;
    Widget? trailing;
    var step = 'Details';
    switch (state.phase) {
      case TodayPeriodsPhase.form:
        leading = KioskGhostButton(
          label: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        );
        trailing = KioskPrimaryButton(
          label: "Get today's reading",
          gold: true,
          onPressed: _submit,
        );
        step = 'Details';
      case TodayPeriodsPhase.loading:
        step = 'Reading';
      case TodayPeriodsPhase.result:
        leading = KioskGhostButton(label: 'New reading', onPressed: _resetForm);
        trailing = KioskPrimaryButton(
          label: 'Done',
          gold: true,
          onPressed: _endSession,
        );
        step = 'Today';
    }

    Widget page = VisitorSessionPopScope(
      child: KioskShell(
        title: 'Today & Periods',
        cosmic: true,
        onHome: _endSession,
        stepLabel: step,
        footerLeading: leading,
        footerTrailing: trailing,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: switch (state.phase) {
            TodayPeriodsPhase.form => Stack(
              key: const ValueKey('today-form'),
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
                  subtitle: 'Panchang for today · current dasha from your chart',
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
                ),
              ],
            ),
            TodayPeriodsPhase.loading => const AstrologyCastingView(
              key: ValueKey('today-loading'),
              lines: [
                'Reading today’s panchang…',
                'Finding your current dasha…',
                'Preparing periods…',
              ],
            ),
            TodayPeriodsPhase.result when state.result != null =>
              TodayPeriodsResultView(
                key: const ValueKey('today-result'),
                result: state.result!,
              ),
            TodayPeriodsPhase.result => const AstrologyCastingView(
              key: ValueKey('today-result-empty'),
              lines: ['Preparing periods…'],
            ),
          },
        ),
      ),
    );

    if (state.phase != TodayPeriodsPhase.form) {
      return page;
    }
    return KioskHardwareKeys(onKeyEvent: _handleFormKey, child: page);
  }
}

@visibleForTesting
class TodayPeriodsResultView extends StatelessWidget {
  const TodayPeriodsResultView({super.key, required this.result});

  final TodayPeriodsResult result;

  String _asOfLabel() {
    final asOf = result.asOf?.toLocal();
    if (asOf == null) return 'Today';
    final day = asOf.day.toString().padLeft(2, '0');
    final month = asOf.month.toString().padLeft(2, '0');
    final year = asOf.year.toString();
    final hour = asOf.hour.toString().padLeft(2, '0');
    final minute = asOf.minute.toString().padLeft(2, '0');
    return '$day/$month/$year · $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = result.panchang.rows;
    final note = result.accuracyNote ?? result.disclaimer;
    final levels = result.dasha.levels;
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
                    Expanded(
                      flex: 6,
                      child: GlassPanel(
                        key: const ValueKey('today-panchang-card'),
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Today’s panchang',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: AstrologyColors.gold,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _asOfLabel(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AstrologyColors.muted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: rows.isEmpty
                                  ? Center(
                                      child: Text(
                                        'Panchang details unavailable',
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              color: AstrologyColors.muted,
                                            ),
                                      ),
                                    )
                                  : Column(
                                      children: [
                                        for (
                                          var i = 0;
                                          i < rows.length;
                                          i++
                                        ) ...[
                                          if (i > 0) const SizedBox(height: 6),
                                          Expanded(
                                            child: _PanchangRow(
                                              label: rows[i].label,
                                              value: rows[i].value,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: GlassPanel(
                        key: const ValueKey('today-dasha-card'),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                        borderColor: AstrologyColors.gold.withValues(
                          alpha: 0.55,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.auto_graph,
                              color: AstrologyColors.gold,
                              size: 42,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Current dasha',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AstrologyColors.goldSoft,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              result.dasha.label.isEmpty
                                  ? '—'
                                  : result.dasha.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: AstrologyColors.text,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (levels.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  for (var i = 0; i < levels.length; i++)
                                    _DashaLevelChip(
                                      label: i == 0 ? 'Maha' : 'Bhukti',
                                      value: levels[i],
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 18),
                            Text(
                              result.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AstrologyColors.muted,
                              ),
                            ),
                          ],
                        ),
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
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AstrologyColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PanchangRow extends StatelessWidget {
  const _PanchangRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AstrologyColors.raised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AstrologyColors.line),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AstrologyColors.goldSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AstrologyColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashaLevelChip extends StatelessWidget {
  const _DashaLevelChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AstrologyColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AstrologyColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AstrologyColors.muted,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AstrologyColors.gold,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
