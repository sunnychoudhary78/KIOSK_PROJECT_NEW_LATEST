import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:skp_kiosk/features/astrology/application/palm_jpeg.dart';

void main() {
  test('leaves JPEG bytes unchanged', () {
    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
    expect(toJpegBytes(jpeg), same(jpeg));
  });

  test('encodes PNG camera frames as JPEG', () {
    final image = img.Image(width: 24, height: 24);
    img.fill(image, color: img.ColorRgb8(200, 140, 100));
    final png = Uint8List.fromList(img.encodePng(image));
    expect(png[0], 0x89);
    final jpeg = toJpegBytes(png);
    expect(jpeg[0], 0xFF);
    expect(jpeg[1], 0xD8);
    expect(jpeg[2], 0xFF);
  });

  test('encodes BMP camera frames as JPEG', () {
    final image = img.Image(width: 24, height: 24);
    img.fill(image, color: img.ColorRgb8(200, 140, 100));
    final bmp = Uint8List.fromList(img.encodeBmp(image));
    expect(bmp[0], 0x42);
    expect(bmp[1], 0x4D);
    final jpeg = toJpegBytes(bmp);
    expect(jpeg[0], 0xFF);
    expect(jpeg[1], 0xD8);
    expect(jpeg[2], 0xFF);
  });

  test('encodes a headerless DIB still as JPEG', () {
    final image = img.Image(width: 24, height: 24);
    img.fill(image, color: img.ColorRgb8(200, 140, 100));
    final bmp = Uint8List.fromList(img.encodeBmp(image));
    final dib = Uint8List.sublistView(bmp, 14);
    final jpeg = toJpegBytes(dib);
    expect(jpeg[0], 0xFF);
    expect(jpeg[1], 0xD8);
    expect(jpeg[2], 0xFF);
  });
}
