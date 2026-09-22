import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Windows `camera_windows` often writes BMP (sometimes a headerless DIB).
/// Always feed JPEG to quality checks and the API.
Uint8List toJpegBytes(Uint8List bytes, {int quality = 85}) {
  if (_isJpeg(bytes)) {
    return bytes;
  }
  final decoded = decodePalmImage(bytes);
  if (decoded == null) {
    return bytes;
  }
  return Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
}

img.Image? decodePalmImage(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded != null) {
    return decoded;
  }
  if (_isBmp(bytes)) {
    return img.decodeBmp(bytes);
  }
  final bmp = _dibToBmp(bytes);
  if (bmp == null) {
    return null;
  }
  return img.decodeBmp(bmp);
}

bool _isJpeg(Uint8List bytes) {
  return bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
}

bool _isBmp(Uint8List bytes) {
  return bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D;
}

/// Media Foundation sometimes emits a BITMAPINFOHEADER DIB without a file header.
Uint8List? _dibToBmp(Uint8List bytes) {
  if (bytes.length < 40) {
    return null;
  }
  final headerSize = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
  if (headerSize != 40 && headerSize != 108 && headerSize != 124) {
    return null;
  }
  final fileSize = 14 + bytes.length;
  final file = Uint8List(fileSize);
  file[0] = 0x42;
  file[1] = 0x4D;
  file[2] = fileSize & 0xFF;
  file[3] = (fileSize >> 8) & 0xFF;
  file[4] = (fileSize >> 16) & 0xFF;
  file[5] = (fileSize >> 24) & 0xFF;
  file[10] = 14 + headerSize;
  file.setRange(14, fileSize, bytes);
  return file;
}
