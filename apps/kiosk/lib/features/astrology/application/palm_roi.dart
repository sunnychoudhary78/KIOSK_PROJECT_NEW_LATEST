/// Normalized palm outline on the live preview and on still frames.
///
/// Matches [PalmOverlayPainter]: centered at (0.50, 0.52) with size 50% × 64%.
class PalmRoi {
  const PalmRoi._();

  static const centerX = 0.50;
  static const centerY = 0.52;
  static const width = 0.50;
  static const height = 0.64;

  static const left = centerX - width / 2;
  static const top = centerY - height / 2;

  static ({int left, int top, int width, int height}) crop(int imageWidth, int imageHeight) {
    final leftPx = (imageWidth * left).round().clamp(0, imageWidth - 8);
    final topPx = (imageHeight * top).round().clamp(0, imageHeight - 8);
    final widthPx = (imageWidth * width).round().clamp(8, imageWidth - leftPx);
    final heightPx = (imageHeight * height).round().clamp(8, imageHeight - topPx);
    return (left: leftPx, top: topPx, width: widthPx, height: heightPx);
  }
}
