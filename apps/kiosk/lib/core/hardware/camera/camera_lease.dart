import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';

enum CameraHolder { none, palm, surveillance }

class CameraLeaseTimeout implements Exception {
  const CameraLeaseTimeout(this.requestedBy);

  final CameraHolder requestedBy;

  @override
  String toString() => 'CameraLeaseTimeout($requestedBy)';
}

class CameraLeaseState {
  const CameraLeaseState({this.holder = CameraHolder.none});

  final CameraHolder holder;
}

class CameraLease extends Notifier<CameraLeaseState> {
  static const acquireTimeout = Duration(seconds: 8);

  /// Increment 2 wires this to pause surveillance and [release] it.
  void Function()? onPreemptRequested;

  Completer<void>? _released;

  @override
  CameraLeaseState build() => const CameraLeaseState();

  Future<void> acquire(
    CameraHolder holder, {
    Duration timeout = acquireTimeout,
  }) async {
    if (holder == CameraHolder.none) {
      throw ArgumentError.value(holder, 'holder');
    }
    if (state.holder == holder) {
      return;
    }
    if (state.holder != CameraHolder.none) {
      AppLogger.info(
        'CAMERA_LEASE_PREEMPT holder=${state.holder.name} requestedBy=${holder.name}',
      );
      try {
        onPreemptRequested?.call();
      } catch (error) {
        AppLogger.error('CAMERA_LEASE_PREEMPT callback failed', error);
      }
      await _waitUntilFree(holder, timeout);
      if (state.holder == holder) {
        return;
      }
    }
    _grant(holder);
  }

  void release(CameraHolder holder) {
    if (state.holder != holder) {
      return;
    }
    state = const CameraLeaseState();
    AppLogger.info('CAMERA_LEASE_RELEASED holder=${holder.name}');
    final waiting = _released;
    _released = null;
    if (waiting != null && !waiting.isCompleted) {
      waiting.complete();
    }
  }

  Future<void> _waitUntilFree(CameraHolder requestedBy, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (state.holder != CameraHolder.none && state.holder != requestedBy) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw CameraLeaseTimeout(requestedBy);
      }
      _released ??= Completer<void>();
      try {
        await _released!.future.timeout(remaining);
      } on TimeoutException {
        throw CameraLeaseTimeout(requestedBy);
      }
    }
  }

  void _grant(CameraHolder holder) {
    state = CameraLeaseState(holder: holder);
    AppLogger.info('CAMERA_LEASE_ACQUIRED holder=${holder.name}');
  }
}

final cameraLeaseProvider =
    NotifierProvider<CameraLease, CameraLeaseState>(CameraLease.new);
