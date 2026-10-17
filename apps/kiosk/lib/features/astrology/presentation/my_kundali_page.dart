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
                    subtitle:
                        'Accurate birth time makes a clearer Lagna. Pick North or South style.',
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

class _KundaliResultView extends StatelessWidget {
  const _KundaliResultView({super.key, required this.result});

  final KundaliResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chart = result.chart;
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
    ];

    final styleLabel =
        result.style == 'south' ? 'South Indian' : 'North Indian';
    final title = result.name.isEmpty ? 'Your kundali' : "${result.name}'s kundali";

    return Stack(
      fit: StackFit.expand,
      children: [
        const CosmicBackdrop(),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
              children: [
                GlassPanel(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AstrologyColors.gold,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$styleLabel · Rasi (D1)',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AstrologyColors.muted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        result.disclaimer,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AstrologyColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GlassPanel(
                  padding: const EdgeInsets.all(16),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ColoredBox(
                      color: Colors.white,
                      child: SvgPicture.string(
                        result.svg,
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
                if (tiles.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final tile in tiles)
                        SizedBox(
                          width: 210,
                          child: GlassPanel(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                if (tile.art != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: AstrologyAssetImage(
                                      asset: tile.art!,
                                      width: 48,
                                      height: 48,
                                    ),
                                  )
                                else
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AstrologyColors.raised,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome,
                                      color: AstrologyColors.gold,
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tile.label,
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          color: AstrologyColors.muted,
                                        ),
                                      ),
                                      Text(
                                        tile.value,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          color: AstrologyColors.text,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
