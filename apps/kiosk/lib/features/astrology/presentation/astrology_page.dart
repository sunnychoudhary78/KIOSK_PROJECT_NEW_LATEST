import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/hardware/camera/camera_lease.dart';
import 'package:skp_kiosk/core/input/kiosk_hardware_key_map.dart';
import 'package:skp_kiosk/core/hardware/camera/kiosk_camera.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_controller.dart';
import 'package:skp_kiosk/features/astrology/application/palm_jpeg.dart';
import 'package:skp_kiosk/features/astrology/application/palm_quality_checker.dart';
import 'package:skp_kiosk/features/astrology/data/astrology_repository.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_phase.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_assets.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_casting_view.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_print_shell.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_result_view.dart';
import 'package:skp_kiosk/features/astrology/presentation/astrology_theme.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/astrology_birth_form.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/glass_panel.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/palm_analyzing_view.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/palm_capture_viewport.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/reading_mark.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';

class AstrologyPage extends ConsumerStatefulWidget {
  const AstrologyPage({super.key});

  @override
  ConsumerState<AstrologyPage> createState() => _AstrologyPageState();
}

class _AstrologyPageState extends ConsumerState<AstrologyPage> {
  CameraController? _camera;
  String? _cameraError;
  bool _cameraReady = false;
  bool _sampling = false;
  int _cameraSession = 0;

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
  void initState() {
    super.initState();
    Future.microtask(_openCamera);
  }

  @override
  void dispose() {
    _cameraSession++;
    _name.dispose();
    _place.dispose();
    _releasePalmCamera();
    super.dispose();
  }

  Future<void> _endSession() {
    return ref
        .read(kioskSessionControllerProvider.notifier)
        .endVisitorSession(attract: false);
  }

  Future<void> _goBack() async {
    _releasePalmCamera();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _releasePalmCamera() {
    final camera = _camera;
    _camera = null;
    if (camera != null) {
      unawaited(camera.dispose());
    }
    ref.read(cameraLeaseProvider.notifier).release(CameraHolder.palm);
  }

  Future<void> _openCamera() async {
    final session = ++_cameraSession;
    setState(() {
      _cameraError = null;
      _cameraReady = false;
    });
    final lease = ref.read(cameraLeaseProvider.notifier);
    try {
      await lease.acquire(CameraHolder.palm);
    } catch (_) {
      if (mounted && session == _cameraSession) {
        setState(() => _cameraError = 'Could not open the camera. Check Windows camera privacy settings.');
      }
      return;
    }
    if (!mounted || session != _cameraSession) {
      if (!mounted) {
        lease.release(CameraHolder.palm);
      }
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (session == _cameraSession && _camera == null) {
          lease.release(CameraHolder.palm);
        }
        if (mounted && session == _cameraSession) {
          setState(() => _cameraError = 'No camera found. Connect the USB camera and retry.');
        }
        return;
      }
      final camera = pickKioskCamera(cameras);
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted || session != _cameraSession) {
        await controller.dispose();
        if (!mounted && _camera == null) {
          lease.release(CameraHolder.palm);
        }
        return;
      }
      await _camera?.dispose();
      _camera = controller;
      setState(() => _cameraReady = true);
      unawaited(_sampleLoop(session));
    } catch (_) {
      if (session == _cameraSession && _camera == null) {
        lease.release(CameraHolder.palm);
      }
      if (mounted && session == _cameraSession) {
        setState(() => _cameraError = 'Could not open the camera. Check Windows camera privacy settings.');
      }
    }
  }

  Future<void> _sampleLoop(int session) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    var backoffMs = 250;
    while (mounted && session == _cameraSession) {
      if (ref.read(astrologyControllerProvider).phase != AstrologyPhase.capture) {
        break;
      }

      final bytes = await _sampleOnce();
      if (!mounted || session != _cameraSession) {
        break;
      }

      final notifier = ref.read(astrologyControllerProvider.notifier);
      final state = ref.read(astrologyControllerProvider);
      if (state.phase != AstrologyPhase.capture) {
        break;
      }

      if (bytes == null) {
        notifier.reportCameraStatus('Camera busy, retrying…');
        backoffMs = (backoffMs * 2).clamp(250, 2000);
        await Future<void>.delayed(Duration(milliseconds: backoffMs));
        continue;
      }

      // Keep sampling while quality is ok so the streak / hold can complete.
      backoffMs = 250;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  Future<Uint8List?> _sampleOnce() async {
    final controller = _camera;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _sampling) {
      return null;
    }
    _sampling = true;
    try {
      final shot = await controller.takePicture();
      final bytes = await _jpegFromShot(shot);
      if (!mounted) {
        return bytes;
      }
      ref.read(astrologyControllerProvider.notifier).evaluateFrame(bytes);
      return bytes;
    } catch (_) {
      return null;
    } finally {
      _sampling = false;
    }
  }

  Future<void> _captureNow() async {
    final controller = _camera;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    for (var i = 0; i < 20 && _sampling; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted || controller != _camera) {
      return;
    }
    if (ref.read(astrologyControllerProvider).phase != AstrologyPhase.capture) {
      return;
    }

    final paused = ++_cameraSession;
    _sampling = true;
    try {
      final shot = await controller.takePicture();
      final bytes = await _jpegFromShot(shot);
      if (!mounted) {
        return;
      }
      ref.read(astrologyControllerProvider.notifier).acceptPalm(bytes, strict: false);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not capture. Try again.')),
        );
      }
    } finally {
      _sampling = false;
      if (mounted &&
          paused == _cameraSession &&
          ref.read(astrologyControllerProvider).phase == AstrologyPhase.capture) {
        final resume = ++_cameraSession;
        unawaited(_sampleLoop(resume));
      }
    }
  }

  Future<Uint8List> _jpegFromShot(XFile shot) async {
    final raw = await File(shot.path).readAsBytes();
    try {
      await File(shot.path).delete();
    } catch (_) {}
    return toJpegBytes(raw);
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
    ref.read(astrologyControllerProvider.notifier).submit(
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
    _name.clear();
    _place.clear();
    setState(() {
      _dob = DateTime(1995, 1, 1);
      _timeUnknown = false;
      _focus = 0;
      _placeCoords = null;
    });
    ref.read(astrologyControllerProvider.notifier).retake();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(astrologyControllerProvider);
    ref.listen(astrologyControllerProvider, (previous, next) {
      if (previous?.phase == AstrologyPhase.capture && next.phase != AstrologyPhase.capture) {
        _cameraSession++;
        _releasePalmCamera();
        if (mounted) {
          setState(() => _cameraReady = false);
        }
      }
      if (previous?.phase != AstrologyPhase.capture && next.phase == AstrologyPhase.capture) {
        unawaited(_openCamera());
      }
    });

    final controller = ref.read(astrologyControllerProvider.notifier);

    ref.listen(astrologyControllerProvider, (previous, next) {
      holdSessionForAstrologyPrint(ref, next.print);
    });

    final paused = astrologyPausedShell(
      ref: ref,
      print: state.print,
      title: 'Astrology',
      onHome: _endSession,
    );
    if (paused != null) return paused;

    if (astrologyPrintIsActive(state.print)) {
      return AstrologyPrintShell(
        title: 'Astrology',
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
    String step = 'Palm';
    final palmReady = state.quality?.ok == true;
    switch (state.phase) {
      case AstrologyPhase.capture:
        leading = KioskGhostButton(
          label: 'Back',
          icon: Icons.arrow_back,
          onPressed: _goBack,
        );
        trailing = KioskPrimaryButton(
          label: palmReady ? 'Seal palm reading' : 'Capture palm',
          onPressed: _cameraReady ? _captureNow : null,
        );
        step = 'Palm';
      case AstrologyPhase.form:
        leading = KioskGhostButton(
          label: 'Retake palm',
          onPressed: () => ref.read(astrologyControllerProvider.notifier).retake(),
        );
        trailing = KioskPrimaryButton(
          label: 'Get reading',
          onPressed: _submit,
        );
        step = 'Details';
      case AstrologyPhase.submitting:
        step = 'Casting';
      case AstrologyPhase.result:
        leading = KioskGhostButton(label: 'New reading', onPressed: _resetForm);
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KioskGhostButton(label: 'Done', onPressed: _endSession),
            const SizedBox(width: 12),
            KioskPrimaryButton(
              label: 'Print',
              icon: Icons.print,
              expand: false,
              onPressed: controller.preparePrint,
            ),
          ],
        );
        step = 'Result';
    }

    Widget page = VisitorSessionPopScope(
      endSessionOnPop: false,
      child: KioskShell(
        title: 'Astrology',
        onHome: _endSession,
        stepLabel: step,
        footerLeading: leading,
        footerTrailing: trailing,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: switch (state.phase) {
            AstrologyPhase.capture => _CaptureView(
                key: const ValueKey('capture'),
                camera: _camera,
                cameraReady: _cameraReady,
                cameraError: _cameraError,
                quality: state.quality,
                onRetryCamera: _openCamera,
              ),
            AstrologyPhase.form => _FormView(
                key: const ValueKey('form'),
                nameController: _name,
                placeController: _place,
                dob: _dob,
                birthTime: _birthTime,
                timeUnknown: _timeUnknown,
                gender: _gender,
                palmPreview: state.palmBytes,
                error: state.error,
                focus: _focus,
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
                onPlaceResolved: (value) =>
                    setState(() => _placeCoords = value),
              ),
            AstrologyPhase.submitting => const PalmAnalyzingView(
                key: ValueKey('submitting'),
              ),
            AstrologyPhase.result when state.reading != null => AstrologyResultView(
                key: const ValueKey('result'),
                reading: state.reading!,
              ),
            AstrologyPhase.result => const AstrologyCastingView(
                key: ValueKey('result-empty'),
                accent: AstrologyColors.palm,
              ),
          },
        ),
      ),
    );

    if (state.phase != AstrologyPhase.form) {
      return page;
    }
    return KioskHardwareKeys(
      onKeyEvent: _handleFormKey,
      child: page,
    );
  }
}

class _CaptureView extends StatefulWidget {
  const _CaptureView({
    super.key,
    required this.camera,
    required this.cameraReady,
    required this.cameraError,
    required this.quality,
    required this.onRetryCamera,
  });

  final CameraController? camera;
  final bool cameraReady;
  final String? cameraError;
  final PalmQualityResult? quality;
  final VoidCallback onRetryCamera;

  @override
  State<_CaptureView> createState() => _CaptureViewState();
}

class _CaptureViewState extends State<_CaptureView>
    with TickerProviderStateMixin {
  late final AnimationController _orbit;
  late final AnimationController _pulse;
  late final AnimationController _seal;
  late final AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10000),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _seal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _syncReady(widget.quality?.ok == true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(AstrologyAssets.palmGuide), context);
    precacheImage(const AssetImage(AstrologyAssets.palmCircleFrame), context);
  }

  @override
  void didUpdateWidget(covariant _CaptureView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncReady(widget.quality?.ok == true);
  }

  void _syncReady(bool ok) {
    if (ok) {
      if (!_pulse.isAnimating) {
        _pulse.repeat(reverse: true);
      }
      if (!_sweep.isAnimating) {
        _sweep.repeat();
      }
      if (_seal.status != AnimationStatus.completed) {
        _seal.forward();
      }
    } else {
      _pulse.stop();
      _pulse.value = 0;
      _sweep.stop();
      _sweep.value = 0;
      _seal.reverse();
    }
  }

  @override
  void dispose() {
    _orbit.dispose();
    _pulse.dispose();
    _seal.dispose();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = widget.quality?.ok == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PalmFlowStepRail(activeIndex: 0),
          const SizedBox(height: 4),
          Text(
            'Position your palm',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AstrologyColors.palm,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            ok
                ? 'Hold steady — sealing your reading'
                : 'Place your open palm inside the guide',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AstrologyColors.muted,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: PalmCaptureViewport(
              camera: widget.camera,
              cameraReady: widget.cameraReady,
              cameraError: widget.cameraError,
              quality: widget.quality,
              onRetryCamera: widget.onRetryCamera,
              orbit: _orbit,
              pulse: _pulse,
              seal: _seal,
              sweep: _sweep,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  const _FormView({
    super.key,
    required this.nameController,
    required this.placeController,
    required this.dob,
    required this.birthTime,
    required this.timeUnknown,
    required this.gender,
    required this.palmPreview,
    required this.error,
    required this.focus,
    required this.onFocus,
    required this.onDob,
    required this.onTime,
    required this.onTimeUnknown,
    required this.onGender,
    required this.onKey,
    required this.onBackspace,
    required this.onPlaceResolved,
  });

  final TextEditingController nameController;
  final TextEditingController placeController;
  final DateTime dob;
  final TimeOfDay birthTime;
  final bool timeUnknown;
  final String gender;
  final Uint8List? palmPreview;
  final String? error;
  final int focus;
  final ValueChanged<int> onFocus;
  final ValueChanged<DateTime> onDob;
  final ValueChanged<TimeOfDay> onTime;
  final ValueChanged<bool> onTimeUnknown;
  final ValueChanged<String> onGender;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final ValueChanged<ResolvedBirthPlace?> onPlaceResolved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget? leading;
    if (palmPreview != null) {
      leading = SizedBox(
        width: 220,
        child: GlassPanel(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  const ClipOval(
                    child: AstrologyAssetImage(
                      asset: AstrologyAssets.sealMedallion,
                      width: 36,
                      height: 36,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AstrologyColors.palm.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AstrologyColors.palm.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Text(
                        'PALM LOCKED',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AstrologyColors.palm,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(
                        palmPreview!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                    const Positioned(
                      right: 8,
                      bottom: 8,
                      child: AstrologyAssetImage(
                        asset: AstrologyAssets.sealMedallion,
                        width: 48,
                        height: 48,
                        opacity: 0.9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        AstrologyBirthFormPanel(
          nameController: nameController,
          placeController: placeController,
          dob: dob,
          birthTime: birthTime,
          timeUnknown: timeUnknown,
          gender: gender,
          focus: focus,
          error: error,
          leading: leading,
          accent: AstrologyColors.palm,
          emblem: AstrologyReadingKind.palm,
          onFocus: onFocus,
          onDob: onDob,
          onTime: onTime,
          onTimeUnknown: onTimeUnknown,
          onGender: onGender,
          onKey: onKey,
          onBackspace: onBackspace,
          onPlaceResolved: onPlaceResolved,
        ),
      ],
    );
  }
}
