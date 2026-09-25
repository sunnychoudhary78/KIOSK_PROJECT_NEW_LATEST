import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
import 'package:skp_mobile/core/format.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/nearby_kiosks/application/nearby_kiosks_controller.dart';
import 'package:skp_mobile/features/otp_print/application/otp_print_controller.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';

class OtpPrintPage extends ConsumerStatefulWidget {
  const OtpPrintPage({super.key});

  @override
  ConsumerState<OtpPrintPage> createState() => _OtpPrintPageState();
}

class _OtpPrintPageState extends ConsumerState<OtpPrintPage> {
  final _label = TextEditingController();
  final List<File> _files = [];
  String _printColorMode = 'bw';
  NearbyKiosk? _kiosk;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(nearbyKiosksProvider.notifier).load();
    });
  }

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
    final kiosk = _kiosk;
    if (kiosk == null) return;
    await ref.read(otpPrintControllerProvider.notifier).createChallenge(
          files: List<File>.from(_files),
          deviceId: kiosk.id,
          documentLabel: _label.text.trim(),
          printColorMode: _printColorMode,
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
    final l10n = AppLocalizations.of(context);
    final loading = state.isLoading;
    final nearby = ref.watch(nearbyKiosksProvider);
    final selected = nearby.items.where((item) => item.id == _kiosk?.id).firstOrNull;

    return SkpScaffold(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      safeAreaBottom: false,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.hasError) ...[
            SkpStatusBanner(
              message: state.error.toString(),
              tone: SkpBannerTone.danger,
            ),
            const SizedBox(height: 8),
          ],
          if (loading) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 12),
          ],
          SkpPrimaryButton(
            label: loading ? l10n.uploading : l10n.uploadContinue,
            loading: loading,
            onPressed: loading || _files.isEmpty || selected == null ? null : _upload,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkpPageHeader(
            title: l10n.uploadTitle,
            subtitle: l10n.uploadHelper,
            showBack: true,
            backEnabled: !loading,
          ),
          const SizedBox(height: 20),
          Text(
            l10n.selectKiosk,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey(nearby.items.map((item) => item.id).join(',')),
            initialValue: selected?.id,
            isExpanded: true,
            hint: Text(l10n.chooseKioskToContinue),
            items: nearby.items
                .map(
                  (kiosk) => DropdownMenuItem(
                    value: kiosk.id,
                    child: Text(
                      '${kiosk.name} · ${kiosk.distanceLabel}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: loading
                ? null
                : (id) {
                    setState(() {
                      _kiosk = nearby.items.where((item) => item.id == id).firstOrNull;
                    });
                  },
          ),
          if (nearby.loading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
          ] else if (nearby.error != null) ...[
            const SizedBox(height: 8),
            Text(
              nearby.error!,
              style: theme.textTheme.bodySmall?.copyWith(color: SkpColors.danger),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _label,
            enabled: !loading,
            decoration: InputDecoration(
              labelText: l10n.labelOptional,
              hintText: l10n.labelHint,
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
                      const SkpIconWell(icon: Icons.upload_file_rounded, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        _files.isEmpty
                            ? l10n.tapToAddPdfs
                            : l10n.pdfsSelected(_files.length),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.pdfOnlyHint,
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
          Text(
            l10n.printColor,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _PrintColorChooser(
            value: _printColorMode,
            enabled: !loading,
            bwLabel: l10n.colorBw,
            colorLabel: l10n.colorColor,
            onChanged: (mode) => setState(() => _printColorMode = mode),
          ),
          const SizedBox(height: 6),
          Text(
            selected == null
                ? (_printColorMode == 'color' ? l10n.colorHelp : l10n.bwHelp)
                : l10n.kioskPrintPricing(
                    _printColorMode == 'color'
                        ? selected.freeColorPagesPerSession
                        : selected.freePagesPerSession,
                    _printColorMode == 'color'
                        ? selected.extraColorPageChargeRupees
                        : selected.extraPageChargeRupees,
                    selected.maxPagesPerSession,
                  ),
            style: theme.textTheme.bodySmall?.copyWith(color: SkpColors.muted),
          ),
          const SizedBox(height: 16),
          if (_files.isNotEmpty)
            Expanded(
              child: ListView.separated(
                itemCount: _files.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final file = _files[index];
                  final bytes = file.existsSync() ? file.lengthSync() : 0;
                  return SkpPanelCard(
                    padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                    radius: 14,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: SkpColors.accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _fileName(file),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (bytes > 0)
                                Text(
                                  formatBytes(bytes),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: SkpColors.muted,
                                  ),
                                ),
                            ],
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
              child: SkpEmptyState(
                icon: Icons.picture_as_pdf_outlined,
                title: l10n.addPdfsToContinue,
                message: l10n.pdfOnlyHint,
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _PrintColorChooser extends StatelessWidget {
  const _PrintColorChooser({
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.bwLabel,
    required this.colorLabel,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final String bwLabel;
  final String colorLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SkpColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SkpColors.line),
      ),
      child: Row(
        children: [
          _option(theme, 'bw', bwLabel, Icons.filter_b_and_w_rounded),
          _option(theme, 'color', colorLabel, Icons.palette_outlined),
        ],
      ),
    );
  }

  Widget _option(ThemeData theme, String mode, String label, IconData icon) {
    final selected = value == mode;
    return Expanded(
      child: Material(
        color: selected ? SkpColors.accent.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: enabled ? () => onChanged(mode) : null,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? SkpColors.accent : SkpColors.muted,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? SkpColors.accent : SkpColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
