import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_admin/core/theme/app_theme.dart';
import 'package:skp_admin/core/ui/widgets.dart';
import 'package:skp_admin/features/auth/presentation/auth_controller.dart';
import 'package:skp_admin/features/fleet/presentation/fleet_controller.dart';
import 'package:skp_admin/features/print_jobs/presentation/print_jobs_page.dart';
import 'package:skp_admin/features/printer/data/printer_display.dart';
import 'package:skp_admin/features/printer/data/printer_health.dart';
import 'package:skp_admin/features/printer/presentation/printer_controller.dart';

class PrinterPage extends ConsumerStatefulWidget {
  const PrinterPage({super.key, required this.deviceId});

  final String deviceId;

  @override
  ConsumerState<PrinterPage> createState() => _PrinterPageState();
}

class _PrinterPageState extends ConsumerState<PrinterPage> {
  final _trayInput = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(printerActionsProvider.notifier).reset());
  }

  @override
  void dispose() {
    ref.read(printerActionsProvider.notifier).reset();
    _trayInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(fleetProvider.select((state) => state.byId(widget.deviceId)));
    final actions = ref.watch(printerActionsProvider);
    final canWrite = ref.watch(staffAuthProvider).canWrite;

    if (device == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Printer')),
        body: const Center(child: Text('This kiosk is no longer in the list.')),
      );
    }

    final maintenance = resolvePrinterMaintenance(device.printerHealth);
    final errors = resolvePrinterErrorHistory(device.printerHealth);
    final status = resolvePrinterStatus(device.printerHealth);
    final stale = maintenance is MaintenanceShown && maintenance.stale ||
        errors is ErrorHistoryShown && errors.stale;
    final staleTitle = maintenance is MaintenanceShown
        ? maintenance.title
        : errors is ErrorHistoryShown
        ? errors.title
        : null;
    final usbTotal = usbPagesTotal(device.printerHealth);
    final paused = device.printingPausedReason;

    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: [
          IconButton(
            tooltip: 'Print jobs',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PrintJobsPage(deviceId: device.id, deviceName: device.name),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              const Text('Status', style: TextStyle(color: AdminColors.muted)),
              const SizedBox(width: 8),
              ToneText(
                label: status.label,
                tone: status.fault
                    ? (device.printerHealth?.snmpOk == false
                          ? PrinterRowTone.amber
                          : PrinterRowTone.alert)
                    : status.kind == PrinterStatusKind.ready ||
                          status.kind == PrinterStatusKind.printing
                    ? PrinterRowTone.ok
                    : PrinterRowTone.muted,
              ),
              if (stale) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: staleTitle ?? 'The last USB reading is stale',
                  child: const Text(
                    'Stale',
                    style: TextStyle(color: AdminColors.warning, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
          if (actions.refreshNote != null) ...[
            const SizedBox(height: 8),
            Text(actions.refreshNote!, style: const TextStyle(color: AdminColors.danger)),
          ],
          if (actions.actionError != null) ...[
            const SizedBox(height: 8),
            Text(actions.actionError!, style: const TextStyle(color: AdminColors.danger)),
          ],
          const SizedBox(height: 16),
          _Section(
            title: 'Toner',
            child: maintenance is! MaintenanceShown
                ? const Text('Unavailable', style: TextStyle(color: AdminColors.muted))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Metric(label: 'Black', value: maintenance.lines.black),
                      _Metric(label: 'Cyan', value: maintenance.lines.cyan),
                      _Metric(label: 'Magenta', value: maintenance.lines.magenta),
                      _Metric(label: 'Yellow', value: maintenance.lines.yellow),
                    ],
                  ),
          ),
          _Section(
            title: 'Pages',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: 'Total',
                        value: maintenance is MaintenanceShown ? maintenance.lines.total : '—',
                        large: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Metric(
                        label: 'Pages left',
                        value: device.pagesLeft?.toString() ?? '—',
                        large: true,
                      ),
                    ),
                  ],
                ),
                if (maintenance is MaintenanceShown) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Color ${maintenance.lines.color} · Black and white ${maintenance.lines.blackAndWhite}',
                    style: const TextStyle(color: AdminColors.muted),
                  ),
                ],
                if (canWrite) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Add keeps the leftover. Replace starts the tray over.',
                    style: TextStyle(color: AdminColors.muted),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _trayInput,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Pages to load'),
                    onChanged: (_) => ref.read(printerActionsProvider.notifier).clearTrayError(),
                  ),
                  if (usbTotal == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'The printer page total is not available yet.',
                        style: TextStyle(color: AdminColors.muted),
                      ),
                    ),
                  if (actions.trayError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(actions.trayError!, style: const TextStyle(color: AdminColors.danger)),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: actions.traySaving || usbTotal == null
                            ? null
                            : () async {
                                final saved = await ref
                                    .read(printerActionsProvider.notifier)
                                    .saveTray(device.id, 'add', _trayInput.text);
                                if (!mounted || !saved) return;
                                _trayInput.clear();
                              },
                        child: const Text('Add to current'),
                      ),
                      OutlinedButton(
                        onPressed: actions.traySaving || usbTotal == null
                            ? null
                            : () async {
                                final saved = await ref
                                    .read(printerActionsProvider.notifier)
                                    .saveTray(device.id, 'replace', _trayInput.text);
                                if (!mounted || !saved) return;
                                _trayInput.clear();
                              },
                        child: const Text('Replace tray'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          _Section(
            title: 'Parts',
            child: maintenance is! MaintenanceShown
                ? const Text('Unavailable', style: TextStyle(color: AdminColors.muted))
                : Text('Belt ${maintenance.lines.belt} · Fuser ${maintenance.lines.fuser}'),
          ),
          _Section(
            title: 'Errors',
            child: switch (errors) {
              ErrorHistoryUnavailable() => const Text(
                'Unavailable',
                style: TextStyle(color: AdminColors.muted),
              ),
              ErrorHistoryEmpty() => const Text(
                'No recorded errors',
                style: TextStyle(color: AdminColors.muted),
              ),
              ErrorHistoryShown(:final entries) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(entry.description),
                    ),
                ],
              ),
            },
          ),
          if (paused != null && paused.isNotEmpty) ...[
            const Text(
              'Printing paused',
              style: TextStyle(color: AdminColors.danger, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              device.printerHealth?.reportsPaperOut == true
                  ? 'The latest report still says out of paper.'
                  : 'The latest report says paper is back.',
              style: const TextStyle(color: AdminColors.muted),
            ),
            if (canWrite) ...[
              const SizedBox(height: 8),
              FilledButton(
                onPressed: actions.enabling
                    ? null
                    : () => ref.read(printerActionsProvider.notifier).enablePrinting(device.id),
                child: Text(actions.enabling ? 'Enabling…' : 'Enable printing'),
              ),
            ],
            const SizedBox(height: 12),
          ],
          OutlinedButton(
            onPressed: actions.refreshing
                ? null
                : () => ref.read(printerActionsProvider.notifier).refresh(device.id),
            child: Text(actions.refreshing ? 'Refreshing…' : 'Refresh'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.large = false});

  final String label;
  final String value;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.paper,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AdminColors.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: large ? 22 : 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
