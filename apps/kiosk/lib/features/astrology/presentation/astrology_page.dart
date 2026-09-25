import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/hardware/camera/camera_lease.dart';
import 'package:skp_kiosk/core/input/kiosk_hardware_key_map.dart';
import 'package:skp_kiosk/core/hardware/camera/kiosk_camera.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/ads/presentation/kiosk_wait_ads.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_controller.dart';
import 'package:skp_kiosk/features/astrology/application/palm_jpeg.dart';
import 'package:skp_kiosk/features/astrology/application/palm_quality_checker.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_phase.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_reading.dart';
import 'package:skp_kiosk/features/astrology/presentation/palm_overlay.dart';
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

      backoffMs = 250;
      if (state.quality?.ok == true) {
        await Future<void>.delayed(AstrologyController.autoCaptureHold);
        continue;
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));
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

    Widget? leading;
    Widget? trailing;
    String step = 'Palm';
    switch (state.phase) {
      case AstrologyPhase.capture:
        leading = KioskGhostButton(label: 'Cancel', onPressed: _endSession);
        trailing = KioskPrimaryButton(
          label: 'Capture palm',
          onPressed: _cameraReady ? _captureNow : null,
        );
        step = 'Palm';
      case AstrologyPhase.form:
        leading = KioskGhostButton(
          label: 'Retake palm',
          onPressed: () => ref.read(astrologyControllerProvider.notifier).retake(),
        );
        trailing = KioskPrimaryButton(label: 'Get reading', onPressed: _submit);
        step = 'Details';
      case AstrologyPhase.submitting:
        step = 'Reading';
      case AstrologyPhase.result:
        leading = KioskGhostButton(label: 'New reading', onPressed: _resetForm);
        trailing = KioskPrimaryButton(label: 'Done', onPressed: _endSession);
        step = 'Result';
    }

    Widget page = VisitorSessionPopScope(
      child: KioskShell(
        title: 'Astrology',
        onHome: _endSession,
        stepLabel: step,
        footerLeading: leading,
        footerTrailing: trailing,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
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
              ),
            AstrologyPhase.submitting => const KioskWaitAds(
                key: ValueKey('submitting'),
                message: 'Preparing your reading…',
              ),
            AstrologyPhase.result when state.reading != null => _ResultView(
                key: const ValueKey('result'),
                reading: state.reading!,
              ),
            AstrologyPhase.result => const KioskWaitAds(
                key: ValueKey('result-empty'),
                message: 'Preparing your reading…',
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

class _CaptureView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Place your open palm inside the outline',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
              child: ColoredBox(
                color: Colors.black,
                child: cameraError != null
                    ? _CameraError(message: cameraError!, onRetry: onRetryCamera)
                    : !cameraReady || camera == null
                        ? const Center(child: CircularProgressIndicator())
                        : Center(
                            child: AspectRatio(
                              aspectRatio: camera!.value.aspectRatio == 0
                                  ? 16 / 9
                                  : camera!.value.aspectRatio,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CameraPreview(camera!),
                                  const Positioned.fill(
                                    child: CustomPaint(painter: PalmOverlayPainter()),
                                  ),
                                ],
                              ),
                            ),
                          ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _QualityBanner(quality: quality),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            KioskPrimaryButton(label: 'Retry camera', onPressed: onRetry, expand: false),
          ],
        ),
      ),
    );
  }
}

class _QualityBanner extends StatelessWidget {
  const _QualityBanner({required this.quality});

  final PalmQualityResult? quality;

  @override
  Widget build(BuildContext context) {
    final ok = quality?.ok == true;
    return KioskStatusBanner(
      message: quality?.message ?? 'Align your palm with the outline',
      tone: ok ? KioskBannerTone.success : KioskBannerTone.info,
      icon: ok ? Icons.check_circle_outline : Icons.back_hand_outlined,
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

  @override
  Widget build(BuildContext context) {
    final showKeyboard = focus == 0 || focus == 1;
    final showDate = focus == 2;
    final showTime = focus == 3 && !timeUnknown;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 8),
            child: Row(
              children: [
                if (palmPreview != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.memory(palmPreview!, width: 140, height: 180, fit: BoxFit.cover),
                    ),
                  ),
                Expanded(
                  child: ListView(
                    children: [
                      KioskTextTapField(
                        label: 'Name',
                        hint: 'Your name',
                        value: nameController.text,
                        focused: focus == 0,
                        onTap: () => onFocus(0),
                      ),
                      const SizedBox(height: 10),
                      KioskTextTapField(
                        label: 'Place of birth',
                        hint: 'City, State',
                        value: placeController.text,
                        focused: focus == 1,
                        onTap: () => onFocus(1),
                      ),
                      const SizedBox(height: 14),
                      Text('Gender', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (final option in const [
                            ('female', 'Female'),
                            ('male', 'Male'),
                            ('other', 'Other'),
                          ]) ...[
                            Expanded(
                              child: _ChoiceTile(
                                label: option.$2,
                                selected: gender == option.$1,
                                onTap: () => onGender(option.$1),
                              ),
                            ),
                            if (option.$1 != 'other') const SizedBox(width: 8),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      KioskTextTapField(
                        label: 'Date of birth',
                        value: dob.toIso8601String().split('T').first,
                        focused: focus == 2,
                        onTap: () => onFocus(2),
                      ),
                      const SizedBox(height: 10),
                      _ChoiceTile(
                        label: 'I do not know the birth time',
                        selected: timeUnknown,
                        onTap: () => onTimeUnknown(!timeUnknown),
                      ),
                      if (!timeUnknown) ...[
                        const SizedBox(height: 10),
                        KioskTextTapField(
                          label: 'Birth time',
                          value:
                              '${birthTime.hour.toString().padLeft(2, '0')}:${birthTime.minute.toString().padLeft(2, '0')}',
                          focused: focus == 3,
                          onTap: () => onFocus(3),
                        ),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        KioskStatusBanner(
                          message: error!,
                          tone: KioskBannerTone.danger,
                          icon: Icons.error_outline,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showKeyboard)
          SizedBox(
            height: 220,
            child: KioskKeyboard(onKey: onKey, onBackspace: onBackspace),
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

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
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
      color: selected ? SkpColors.accent.withValues(alpha: 0.28) : SkpColors.raised,
      borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
        child: Container(
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
            border: Border.all(color: selected ? SkpColors.accentBright : SkpColors.line),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? SkpColors.accentBright : SkpColors.text,
                ),
          ),
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({super.key, required this.reading});

  final AstrologyReading reading;

  @override
  Widget build(BuildContext context) {
    final chartBits = [
      if (reading.chart.lagna != null) 'Lagna ${reading.chart.lagna}',
      if (reading.chart.sunSign != null) 'Sun ${reading.chart.sunSign}',
      if (reading.chart.moonSign != null) 'Moon ${reading.chart.moonSign}',
      if (reading.chart.nakshatra != null) 'Nakshatra ${reading.chart.nakshatra}',
      if (reading.chart.currentDasha != null) 'Dasha ${reading.chart.currentDasha}',
    ];

    final sections = <(String, String)>[
      ('Overview', reading.sections.overview),
      ('Palm', reading.palm.summary),
      ('Life line', reading.palm.lifeLine),
      ('Heart line', reading.palm.heartLine),
      ('Head line', reading.palm.headLine),
      ('Fate line', reading.palm.fateLine),
      ('Personality', reading.sections.personality),
      ('Career', reading.sections.career),
      ('Health', reading.sections.health),
      ('Relationships', reading.sections.relationships),
      ('This period', reading.sections.period),
    ].where((item) => item.$2.trim().isNotEmpty).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(32, 12, 32, 16),
          children: [
            Text(
              reading.name.isEmpty ? 'Your reading' : '${reading.name}\'s reading',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              reading.disclaimer,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (chartBits.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final bit in chartBits)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: SkpColors.raised,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: SkpColors.line),
                      ),
                      child: Text(bit, style: Theme.of(context).textTheme.titleSmall),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            for (var i = 0; i < sections.length; i++)
              _SectionCard(index: i + 1, title: sections[i].$1, body: sections[i].$2),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.index, required this.title, required this.body});

  final int index;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SkpColors.panel,
        borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
        border: Border.all(color: SkpColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SkpColors.accent.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$index',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: SkpColors.accentBright,
                      ),
                ),
              ),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 10),
          Text(body, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
