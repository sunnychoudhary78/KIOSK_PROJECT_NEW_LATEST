import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/hardware/camera/kiosk_camera.dart';

CameraDescription _cam(String name, CameraLensDirection lens) {
  return CameraDescription(
    name: name,
    lensDirection: lens,
    sensorOrientation: 0,
  );
}

void main() {
  test('prefers an external USB camera over built-in webcams', () {
    final front = _cam('front', CameraLensDirection.front);
    final usb = _cam('usb', CameraLensDirection.external);
    expect(pickKioskCamera([front, usb]), same(usb));
  });

  test('falls back to a back camera then the first camera', () {
    final front = _cam('front', CameraLensDirection.front);
    final back = _cam('back', CameraLensDirection.back);
    expect(pickKioskCamera([front, back]), same(back));
    expect(pickKioskCamera([front]), same(front));
  });

  test('when every camera is front, prefers a USB name over integrated or IR', () {
    final integrated = _cam('Integrated Webcam', CameraLensDirection.front);
    final ir = _cam('IR Camera', CameraLensDirection.front);
    final usb = _cam('USB Camera', CameraLensDirection.front);
    expect(pickKioskCamera([integrated, ir, usb]), same(usb));
    expect(pickKioskCamera([usb, integrated, ir]), same(usb));
  });

  test('keeps enumeration order when name scores tie', () {
    final first = _cam('Camera A', CameraLensDirection.front);
    final second = _cam('Camera B', CameraLensDirection.front);
    expect(pickKioskCamera([first, second]), same(first));
  });

  test('empty list throws', () {
    expect(() => pickKioskCamera(const []), throwsStateError);
  });
}
