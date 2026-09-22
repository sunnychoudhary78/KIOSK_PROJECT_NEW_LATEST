import 'dart:async';

import 'package:flutter/services.dart';
import 'package:skp_kiosk/core/logging/app_logger.dart';
import 'package:skp_kiosk/features/surveillance/data/surveillance_recorder.dart';

const surveillanceMethodChannel = MethodChannel('skp/surveillance');
const surveillanceEventChannel = EventChannel('skp/surveillance/events');

class MethodChannelSurveillanceRecorder implements SurveillanceRecorder {
  MethodChannelSurveillanceRecorder({
    MethodChannel? methods,
    EventChannel? events,
  })  : _methods = methods ?? surveillanceMethodChannel,
        _events = (events ?? surveillanceEventChannel).receiveBroadcastStream().map(_decode);

  final MethodChannel _methods;
  final Stream<SurveillanceNativeEvent> _events;

  @override
  Stream<SurveillanceNativeEvent> get events => _events;

  @override
  Future<void> start(SurveillanceStartConfig config) {
    return _invoke('start', config.toMap());
  }

  @override
  Future<void> stop() => _invoke('stop');

  @override
  Future<void> pauseForPalm() => _invoke('pauseForPalm');

  @override
  Future<void> resume() => _invoke('resume');

  @override
  Future<String?> getRootDir(String deviceId) async {
    try {
      final result = await _methods.invokeMethod<String>(
        'getRootDir',
        {'deviceId': deviceId},
      );
      if (result == null || result.isEmpty) {
        return null;
      }
      return result;
    } on MissingPluginException {
      AppLogger.error('SURVEILLANCE native plugin missing for getRootDir');
      return null;
    }
  }

  Future<void> _invoke(String method, [Map<String, Object>? args]) async {
    try {
      await _methods.invokeMethod<void>(method, args);
    } on MissingPluginException {
      AppLogger.error('SURVEILLANCE native plugin missing for $method');
      rethrow;
    }
  }

  static SurveillanceNativeEvent _decode(dynamic raw) {
    if (raw is Map) {
      final type = raw['type']?.toString() ?? 'UNKNOWN';
      final data = <String, dynamic>{};
      raw.forEach((key, value) {
        if (key != 'type') {
          data[key.toString()] = value;
        }
      });
      return SurveillanceNativeEvent(type, data);
    }
    return SurveillanceNativeEvent(raw.toString());
  }
}
