import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_provider.dart';
import 'package:skp_kiosk/core/hardware/serial/serial_state.dart';

/// Temporary developer screen for USB serial bring-up (debug builds).
class SerialDebugPage extends ConsumerWidget {
  const SerialDebugPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serialControllerProvider);
    final controller = ref.read(serialControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Serial Debug'),
        actions: [
          IconButton(
            tooltip: 'Clear incoming data',
            onPressed: controller.clearIncoming,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Available Ports',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                FilledButton.tonal(
                  onPressed: state.scanning ? null : controller.refreshPorts,
                  child: Text(state.scanning ? 'Scanning…' : 'Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: state.ports.isEmpty
                    ? const Center(
                        child: Text('No serial ports found. Plug in the device and Refresh.'),
                      )
                    : ListView.separated(
                        itemCount: state.ports.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final port = state.ports[index];
                          final selected = port.name == state.selectedPortName;
                          return ListTile(
                            selected: selected,
                            title: Text(port.name),
                            subtitle: Text(port.displayLabel),
                            trailing: selected ? const Icon(Icons.check) : null,
                            onTap: () => controller.selectPort(port.name),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton(
                  onPressed: state.status == SerialConnectionStatus.connecting ||
                          state.status == SerialConnectionStatus.reconnecting
                      ? null
                      : () => controller.connect(),
                  child: const Text('Connect'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: state.isConnected ? controller.disconnect : null,
                  child: const Text('Disconnect'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: state.status == SerialConnectionStatus.connecting ||
                          state.status ==
                              SerialConnectionStatus.reconnecting ||
                          (state.selectedPortName == null &&
                              !state.isConnected)
                      ? null
                      : controller.reconnect,
                  child: const Text('Reconnect'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Status : ${state.statusLabel}'
              '${state.selectedPortName == null ? '' : ' · ${state.selectedPortName}'}'
              '${state.isConnected ? ' · ${state.baudRate} baud' : ''}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (state.lastError != null) ...[
              const SizedBox(height: 8),
              Text(
                state.lastError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Incoming Data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: state.incomingLines.isEmpty
                      ? const Center(
                          child: Text('Waiting for raw serial data…'),
                        )
                      : SingleChildScrollView(
                          reverse: true,
                          child: SelectableText(
                            state.incomingLines.join('\n'),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontFamily: 'Consolas',
                                  fontFamilyFallback: const [
                                    'Courier New',
                                    'monospace',
                                  ],
                                ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
