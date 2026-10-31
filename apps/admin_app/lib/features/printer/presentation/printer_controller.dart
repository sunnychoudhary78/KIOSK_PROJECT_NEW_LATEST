import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_admin/core/network/api_client.dart';
import 'package:skp_admin/features/fleet/data/device.dart';
import 'package:skp_admin/features/fleet/presentation/fleet_controller.dart';
import 'package:skp_admin/features/printer/data/printer_display.dart';

class PrinterActionState {
  const PrinterActionState({
    this.refreshing = false,
    this.refreshNote,
    this.traySaving = false,
    this.trayError,
    this.enabling = false,
    this.actionError,
  });

  final bool refreshing;
  final String? refreshNote;
  final bool traySaving;
  final String? trayError;
  final bool enabling;
  final String? actionError;

  PrinterActionState copyWith({
    bool? refreshing,
    String? refreshNote,
    bool clearRefreshNote = false,
    bool? traySaving,
    String? trayError,
    bool clearTrayError = false,
    bool? enabling,
    String? actionError,
    bool clearActionError = false,
  }) {
    return PrinterActionState(
      refreshing: refreshing ?? this.refreshing,
      refreshNote: clearRefreshNote ? null : refreshNote ?? this.refreshNote,
      traySaving: traySaving ?? this.traySaving,
      trayError: clearTrayError ? null : trayError ?? this.trayError,
      enabling: enabling ?? this.enabling,
      actionError: clearActionError ? null : actionError ?? this.actionError,
    );
  }
}

class PrinterActionsNotifier extends Notifier<PrinterActionState> {
  int _generation = 0;

  @override
  PrinterActionState build() => const PrinterActionState();

  void reset() {
    _generation++;
    state = const PrinterActionState();
  }

  void clearTrayError() {
    if (state.trayError != null) {
      state = state.copyWith(clearTrayError: true);
    }
  }

  Future<void> refresh(String deviceId) async {
    if (state.refreshing) return;
    final generation = ++_generation;
    state = state.copyWith(refreshing: true, clearRefreshNote: true, clearActionError: true);
    try {
      final requestedAt = await ref.read(devicesRepositoryProvider).requestPrinterRefresh(deviceId);
      final deadline = DateTime.now().add(const Duration(seconds: 8));
      while (DateTime.now().isBefore(deadline)) {
        if (generation != _generation) return;
        final devices = await ref.read(devicesRepositoryProvider).list();
        if (generation != _generation) return;
        ref.read(fleetProvider.notifier).replaceAll(devices);
        KioskDevice? device;
        for (final item in devices) {
          if (item.id == deviceId) {
            device = item;
            break;
          }
        }
        if (device != null &&
            printerRefreshSettled(
              printerHealthAt: device.printerHealthAtIso,
              printerRefreshRequestedAt: device.printerRefreshRequestedAtIso,
              requestedAt: requestedAt,
            )) {
          if (generation == _generation) {
            state = state.copyWith(refreshing: false, clearRefreshNote: true);
          }
          return;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      if (generation == _generation) {
        state = state.copyWith(
          refreshing: false,
          refreshNote: 'The kiosk did not answer. Showing the last report.',
        );
      }
    } catch (error) {
      if (generation == _generation) {
        state = state.copyWith(
          refreshing: false,
          refreshNote: error is ApiException
              ? error.message
              : 'The kiosk did not answer. Showing the last report.',
        );
      }
    }
  }

  Future<bool> saveTray(String deviceId, String mode, String input) async {
    final error = validateTrayPages(input);
    if (error != null) {
      state = state.copyWith(trayError: error);
      return false;
    }
    state = state.copyWith(traySaving: true, clearTrayError: true, clearActionError: true);
    try {
      final updated = await ref.read(devicesRepositoryProvider).setTray(
        deviceId,
        mode: mode,
        pages: int.parse(input.trim()),
      );
      ref.read(fleetProvider.notifier).upsert(updated);
      state = state.copyWith(traySaving: false, clearTrayError: true);
      return true;
    } catch (error) {
      state = state.copyWith(traySaving: false, trayError: '$error');
      return false;
    }
  }

  Future<void> enablePrinting(String deviceId) async {
    state = state.copyWith(enabling: true, clearActionError: true);
    try {
      final updated = await ref.read(devicesRepositoryProvider).enablePrinting(deviceId);
      ref.read(fleetProvider.notifier).upsert(updated);
      state = state.copyWith(enabling: false);
    } catch (error) {
      state = state.copyWith(enabling: false, actionError: '$error');
    }
  }
}

final printerActionsProvider = NotifierProvider<PrinterActionsNotifier, PrinterActionState>(
  PrinterActionsNotifier.new,
);
