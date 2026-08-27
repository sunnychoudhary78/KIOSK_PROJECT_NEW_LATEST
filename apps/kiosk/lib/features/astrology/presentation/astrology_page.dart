import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/features/astrology/application/astrology_controller.dart';
import 'package:skp_kiosk/features/astrology/application/palm_jpeg.dart';
import 'package:skp_kiosk/features/astrology/application/palm_quality_checker.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_phase.dart';
import 'package:skp_kiosk/features/astrology/domain/astrology_reading.dart';
import 'package:skp_kiosk/features/astrology/presentation/palm_overlay.dart';

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
  Timer? _sampleTimer;

  final _name = TextEditingController();
  final _place = TextEditingController();
  DateTime? _dob;
  TimeOfDay _birthTime = const TimeOfDay(hour: 12, minute: 0);
  bool _timeUnknown = false;
  String _gender = 'female';

  @override
  void initState() {
    super.initState();
    Future.microtask(_openCamera);
  }

  @override
  void dispose() {
    _sampleTimer?.cancel();
    _name.dispose();
    _place.dispose();
    unawaited(_camera?.dispose());
    super.dispose();
  }

  Future<void> _openCamera() async {
    setState(() {
      _cameraError = null;
      _cameraReady = false;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'No camera found. Connect the USB camera and retry.');
        return;
      }
      final camera = cameras.first;
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await _camera?.dispose();
      _camera = controller;
      setState(() => _cameraReady = true);
      _startSampling();
    } catch (error) {
      setState(() => _cameraError = 'Could not open the camera. Check Windows camera privacy settings.');
    }
  }

  void _startSampling() {
    _sampleTimer?.cancel();
    _sampleTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      unawaited(_sampleFrame());
    });
  }

  Future<void> _sampleFrame() async {
    final controller = _camera;
    final phase = ref.read(astrologyControllerProvider).phase;
    if (!mounted ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _sampling ||
        phase != AstrologyPhase.capture) {
      return;
    }
    _sampling = true;
    try {
      final shot = await controller.takePicture();
      final bytes = await _jpegFromShot(shot);
      if (!mounted) {
        return;
      }
      ref.read(astrologyControllerProvider.notifier).evaluateFrame(bytes);
      if (ref.read(astrologyControllerProvider).phase == AstrologyPhase.form) {
        _sampleTimer?.cancel();
      }
    } catch (_) {
      // Preview can fail a frame on USB cameras; keep sampling.
    } finally {
      _sampling = false;
    }
  }

  Future<void> _captureNow() async {
    final controller = _camera;
    if (controller == null || !controller.value.isInitialized || _sampling) {
      return;
    }
    _sampling = true;
    try {
      final shot = await controller.takePicture();
      final bytes = await _jpegFromShot(shot);
      if (!mounted) {
        return;
      }
      ref.read(astrologyControllerProvider.notifier).acceptPalm(bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not capture. Try again.')),
        );
      }
    } finally {
      _sampling = false;
    }
  }

  Future<Uint8List> _jpegFromShot(XFile shot) async {
    final raw = await File(shot.path).readAsBytes();
    try {
      await File(shot.path).delete();
    } catch (_) {}
    return toJpegBytes(raw);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _dob = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _birthTime);
    if (picked != null) {
      setState(() => _birthTime = picked);
    }
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
    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select date of birth')),
      );
      return;
    }
    ref.read(astrologyControllerProvider.notifier).submit(
          name: _name.text,
          gender: _gender,
          dateOfBirth: _formatDob(_dob!),
          birthTime: _formatTime(_birthTime),
          birthPlace: _place.text,
          birthTimeUnknown: _timeUnknown,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(astrologyControllerProvider);
    ref.listen(astrologyControllerProvider, (previous, next) {
      if (previous?.phase == AstrologyPhase.capture && next.phase != AstrologyPhase.capture) {
        _sampleTimer?.cancel();
        final camera = _camera;
        _camera = null;
        if (camera != null) {
          unawaited(camera.dispose());
        }
        if (mounted) {
          setState(() => _cameraReady = false);
        }
      }
      if (previous?.phase != AstrologyPhase.capture && next.phase == AstrologyPhase.capture) {
        unawaited(_openCamera());
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Astrology'),
        actions: [
          if (state.phase == AstrologyPhase.form)
            TextButton(
              onPressed: () => ref.read(astrologyControllerProvider.notifier).retake(),
              child: const Text('Retake palm'),
            ),
          if (state.phase == AstrologyPhase.result)
            TextButton(
              onPressed: () {
                _name.clear();
                _place.clear();
                setState(() {
                  _dob = null;
                  _timeUnknown = false;
                });
                ref.read(astrologyControllerProvider.notifier).retake();
              },
              child: const Text('New reading'),
            ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: switch (state.phase) {
            AstrologyPhase.capture => _CaptureView(
                key: const ValueKey('capture'),
                camera: _camera,
                cameraReady: _cameraReady,
                cameraError: _cameraError,
                quality: state.quality,
                onRetryCamera: _openCamera,
                onCapture: _captureNow,
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
                onPickDob: _pickDob,
                onPickTime: _pickTime,
                onTimeUnknown: (value) => setState(() => _timeUnknown = value),
                onGender: (value) => setState(() => _gender = value),
                onSubmit: _submit,
              ),
            AstrologyPhase.submitting => const _SubmittingView(key: ValueKey('submitting')),
            AstrologyPhase.result when state.reading != null => _ResultView(
                key: const ValueKey('result'),
                reading: state.reading!,
              ),
            AstrologyPhase.result => const _SubmittingView(key: ValueKey('result-empty')),
          },
        ),
      ),
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
    required this.onCapture,
  });

  final CameraController? camera;
  final bool cameraReady;
  final String? cameraError;
  final PalmQualityResult? quality;
  final VoidCallback onRetryCamera;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Place your open palm inside the outline',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ColoredBox(
                color: Colors.black,
                child: cameraError != null
                    ? _CameraError(message: cameraError!, onRetry: onRetryCamera)
                    : !cameraReady || camera == null
                        ? const Center(child: CircularProgressIndicator())
                        : Stack(
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
          const SizedBox(height: 12),
          _QualityBanner(quality: quality),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: cameraReady ? onCapture : null,
            child: const Text('Capture palm'),
          ),
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
            FilledButton(onPressed: onRetry, child: const Text('Retry camera')),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ok ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        quality?.message ?? 'Align your palm with the outline',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
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
    required this.onPickDob,
    required this.onPickTime,
    required this.onTimeUnknown,
    required this.onGender,
    required this.onSubmit,
  });

  final TextEditingController nameController;
  final TextEditingController placeController;
  final DateTime? dob;
  final TimeOfDay birthTime;
  final bool timeUnknown;
  final String gender;
  final Uint8List? palmPreview;
  final String? error;
  final VoidCallback onPickDob;
  final VoidCallback onPickTime;
  final ValueChanged<bool> onTimeUnknown;
  final ValueChanged<String> onGender;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (palmPreview != null)
              Align(
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.memory(palmPreview!, height: 140, fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Gender', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'female', label: Text('Female')),
                ButtonSegment(value: 'male', label: Text('Male')),
                ButtonSegment(value: 'other', label: Text('Other')),
              ],
              selected: {gender},
              onSelectionChanged: (value) => onGender(value.first),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date of birth'),
              subtitle: Text(dob == null ? 'Tap to select' : dob!.toIso8601String().split('T').first),
              trailing: const Icon(Icons.calendar_today),
              onTap: onPickDob,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('I do not know the birth time'),
              value: timeUnknown,
              onChanged: onTimeUnknown,
            ),
            if (!timeUnknown)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Birth time'),
                subtitle: Text(birthTime.format(context)),
                trailing: const Icon(Icons.schedule),
                onTap: onPickTime,
              ),
            const SizedBox(height: 8),
            TextField(
              controller: placeController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Place of birth',
                hintText: 'City, State',
                border: OutlineInputBorder(),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(onPressed: onSubmit, child: const Text('Get reading')),
          ],
        ),
      ),
    );
  }
}

class _SubmittingView extends StatelessWidget {
  const _SubmittingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Preparing your reading…'),
        ],
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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(24),
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
                    Chip(label: Text(bit)),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _SectionCard(title: 'Overview', body: reading.sections.overview),
            _SectionCard(title: 'Palm', body: reading.palm.summary),
            _SectionCard(title: 'Life line', body: reading.palm.lifeLine),
            _SectionCard(title: 'Heart line', body: reading.palm.heartLine),
            _SectionCard(title: 'Head line', body: reading.palm.headLine),
            _SectionCard(title: 'Fate line', body: reading.palm.fateLine),
            _SectionCard(title: 'Personality', body: reading.sections.personality),
            _SectionCard(title: 'Career', body: reading.sections.career),
            _SectionCard(title: 'Health', body: reading.sections.health),
            _SectionCard(title: 'Relationships', body: reading.sections.relationships),
            _SectionCard(title: 'This period', body: reading.sections.period),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    if (body.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }
}
