import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/otp_print/application/otp_print_controller.dart';

class OtpPrintPage extends ConsumerStatefulWidget {
  const OtpPrintPage({super.key});

  @override
  ConsumerState<OtpPrintPage> createState() => _OtpPrintPageState();
}

class _OtpPrintPageState extends ConsumerState<OtpPrintPage> {
  final _label = TextEditingController();
  final List<File> _files = [];

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: true,
      withData: false,
    );
    if (result == null) return;
    setState(() {
      _files
        ..clear()
        ..addAll(
          result.paths.whereType<String>().map(File.new),
        );
    });
  }

  Future<void> _upload() async {
    await ref.read(otpPrintControllerProvider.notifier).createChallenge(
          files: List<File>.from(_files),
          documentLabel: _label.text.trim(),
        );
    if (!mounted) return;
    final state = ref.read(otpPrintControllerProvider);
    if (state.hasValue && state.value != null) {
      setState(() {
        _files.clear();
        _label.clear();
      });
      final challenge = state.value!;
      if (challenge.paymentRequired && !challenge.otpSent) {
        await Navigator.of(context).pushNamed(AppRoutes.otpPrintPayment);
      } else {
        await Navigator.of(context).pushNamed(AppRoutes.otpPrintSuccess);
      }
    }
  }

  String _fileName(File file) => file.path.split(RegExp(r'[\\/]')).last;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(otpPrintControllerProvider);
    final theme = Theme.of(context);
    final loading = state.isLoading;

    return SkpScaffold(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      safeAreaBottom: false,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.hasError) ...[
            Text(
              state.error.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (loading) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 12),
          ],
          SkpPrimaryButton(
            label: loading ? 'Uploading…' : 'Upload & continue',
            loading: loading,
            onPressed: loading || _files.isEmpty ? null : _upload,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: loading ? null : () => Navigator.of(context).maybePop(),
              style: IconButton.styleFrom(
                backgroundColor: SkpColors.panel,
                side: const BorderSide(color: SkpColors.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Upload documents',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'After upload, free sessions get an OTP by SMS. Extra pages require payment first, then the OTP is sent.',
            style: theme.textTheme.bodyMedium?.copyWith(color: SkpColors.muted),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _label,
            enabled: !loading,
            decoration: const InputDecoration(
              labelText: 'Label (optional)',
              hintText: 'e.g. School certificates',
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: SkpColors.panel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: loading ? null : _pickFiles,
              child: CustomPaint(
                painter: _DashedBorderPainter(
                  color: SkpColors.accent.withValues(alpha: 0.35),
                  radius: 18,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: SkpColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.upload_file_rounded,
                          color: SkpColors.accent,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _files.isEmpty
                            ? 'Tap to add PDF documents'
                            : '${_files.length} PDF(s) selected — tap to replace',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PDF only · page limits enforced by server',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: SkpColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_files.isNotEmpty)
            Expanded(
              child: ListView.separated(
                itemCount: _files.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final file = _files[index];
                  return Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                    decoration: BoxDecoration(
                      color: SkpColors.panel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: SkpColors.line),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: SkpColors.accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _fileName(file),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: loading
                              ? null
                              : () => setState(() => _files.removeAt(index)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            Expanded(
              child: Center(
                child: Text(
                  'Add one or more PDFs to continue.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: SkpColors.muted,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.7, 0.7, size.width - 1.4, size.height - 1.4),
          Radius.circular(radius),
        ),
      );
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
