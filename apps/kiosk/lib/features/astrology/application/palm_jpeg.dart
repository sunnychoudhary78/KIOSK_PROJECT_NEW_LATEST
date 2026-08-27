import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Windows `camera_windows` often writes BMP. Always feed JPEG to quality
/// checks and the API.
Uint8List toJpegBytes(Uint8List bytes, {int quality = 85}) {
  if (_isJpeg(bytes)) {
    return bytes;
  }
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return bytes;
  }
  return Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
}

bool _isJpeg(Uint8List bytes) {
  return bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
}
