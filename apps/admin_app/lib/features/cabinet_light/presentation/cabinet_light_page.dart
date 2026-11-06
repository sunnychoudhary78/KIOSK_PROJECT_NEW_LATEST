import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_admin/core/theme/app_theme.dart';
import 'package:skp_admin/core/ui/widgets.dart';
import 'package:skp_admin/features/auth/presentation/auth_controller.dart';
import 'package:skp_admin/features/cabinet_light/data/cabinet_light.dart';
import 'package:skp_admin/features/cabinet_light/presentation/cabinet_light_controller.dart';

class CabinetLightPage extends ConsumerStatefulWidget {
  const CabinetLightPage({super.key});

  @override
  ConsumerState<CabinetLightPage> createState() => _CabinetLightPageState();
}

class _CabinetLightPageState extends ConsumerState<CabinetLightPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(cabinetLightProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cabinetLightProvider);
    final canWrite = ref.watch(staffAuthProvider).canWrite;
    final config = state.config;
    final overnight = lightStaysOvernight(config.onTime, config.offTime);

    return Scaffold(
      appBar: AppBar(title: const Text('Cabinet light')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(cabinetLightProvider.notifier).load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (state.loading && state.notice == null && state.error == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            if (state.error != null) ErrorBanner(message: state.error!),
            if (state.notice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(state.notice!, style: const TextStyle(color: AdminColors.success)),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Now', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      cabinetLightStatus(config),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Relay 2 on the kiosk controller.',
                      style: TextStyle(color: AdminColors.muted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Daily schedule', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _TimeRow(
                      label: 'Turn on at',
                      value: config.onTime,
                      onTap: canWrite && !state.saving ? () => _pickTime(on: true) : null,
                    ),
                    const SizedBox(height: 8),
                    _TimeRow(
                      label: 'Turn off at',
                      value: config.offTime,
                      onTap: canWrite && !state.saving ? () => _pickTime(on: false) : null,
                    ),
                    if (overnight) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'The off time is earlier than the on time, so the light stays on through midnight.',
                        style: TextStyle(color: AdminColors.muted),
                      ),
                    ],
                    if (canWrite) ...[
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: state.saving
                            ? null
                            : () => ref.read(cabinetLightProvider.notifier).followSchedule(),
                        child: Text(state.saving ? 'Saving…' : 'Save schedule'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (canWrite)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Switch now', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: state.saving
                            ? null
                            : () => ref.read(cabinetLightProvider.notifier).turnOn(),
                        child: const Text('Turn on now'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: state.saving
                            ? null
                            : () => ref.read(cabinetLightProvider.notifier).turnOff(),
                        child: const Text('Turn off now'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: state.saving || !config.enabled
                            ? null
                            : () => ref.read(cabinetLightProvider.notifier).followSchedule(),
                        child: const Text('Follow schedule'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime({required bool on}) async {
    final config = ref.read(cabinetLightProvider).config;
    final current = on ? config.onTime : config.offTime;
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 18,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    ref.read(cabinetLightProvider.notifier).setTime(
          on: on,
          value: formatClock(picked.hour, picked.minute),
        );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminColors.line),
          ),
          child: Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(color: AdminColors.muted))),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
