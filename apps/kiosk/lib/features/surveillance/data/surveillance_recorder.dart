class SurveillanceStartConfig {
  const SurveillanceStartConfig({
    required this.deviceId,
    required this.segmentSeconds,
    required this.width,
    required this.height,
    required this.fps,
    required this.bitrate,
    required this.maxCacheBytes,
  });

  final String deviceId;
  final int segmentSeconds;
  final int width;
  final int height;
  final int fps;
  final int bitrate;
  final int maxCacheBytes;

  Map<String, Object> toMap() => {
        'deviceId': deviceId,
        'segmentSeconds': segmentSeconds,
        'width': width,
        'height': height,
        'fps': fps,
        'bitrate': bitrate,
        'maxCacheBytes': maxCacheBytes,
      };
}

class SurveillanceNativeEvent {
  const SurveillanceNativeEvent(this.type, [this.data = const {}]);

  final String type;
  final Map<String, dynamic> data;
}

abstract class SurveillanceRecorder {
  Future<void> start(SurveillanceStartConfig config);
  Future<void> stop();
  Future<void> pauseForPalm();
  Future<void> resume();
  Future<String?> getRootDir(String deviceId);
  Stream<SurveillanceNativeEvent> get events;
}
