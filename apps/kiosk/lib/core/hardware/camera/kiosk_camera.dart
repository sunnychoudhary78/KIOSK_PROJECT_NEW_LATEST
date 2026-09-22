import 'package:camera/camera.dart';

/// Prefer the USB kiosk camera over a built-in IR or laptop webcam.
///
/// [camera_windows] reports every device as [CameraLensDirection.front], so
/// when lens direction is unhelpful we score friendly names instead.
CameraDescription pickKioskCamera(List<CameraDescription> cameras) {
  if (cameras.isEmpty) {
    throw StateError('No camera found');
  }
  for (final direction in [
    CameraLensDirection.external,
    CameraLensDirection.back,
  ]) {
    for (final camera in cameras) {
      if (camera.lensDirection == direction) {
        return camera;
      }
    }
  }

  CameraDescription? best;
  var bestScore = -0x7fffffff;
  for (final camera in cameras) {
    final score = _nameScore(camera.name);
    if (score > bestScore) {
      bestScore = score;
      best = camera;
    }
  }
  return best ?? cameras.first;
}

int _nameScore(String name) {
  final n = name.toLowerCase();
  var score = 0;
  if (n.contains('usb')) {
    score += 4;
  }
  if (n.contains('uvc')) {
    score += 4;
  }
  if (n.contains('external')) {
    score += 3;
  }
  if (n.contains('capture')) {
    score += 2;
  }
  if (n.contains('rgb-ir') || n.contains('rgbir') || n.contains('rgb ir')) {
    score -= 5;
  }
  if (n.contains('infrared')) {
    score -= 4;
  }
  if (RegExp(r'(^|[^a-z])ir([^a-z]|$)').hasMatch(n)) {
    score -= 4;
  }
  if (n.contains('hello')) {
    score -= 3;
  }
  if (n.contains('integrated')) {
    score -= 2;
  }
  return score;
}
