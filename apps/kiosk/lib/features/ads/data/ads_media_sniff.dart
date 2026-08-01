import 'dart:typed_data';

/// Result of sniffing uploaded / downloaded ad media bytes.
class AdMediaSniff {
  const AdMediaSniff({
    required this.isVideo,
    required this.extension,
    this.detectedMime,
  });

  final bool isVideo;
  final String extension;
  final String? detectedMime;
}

/// Pick a file extension and video/image kind from mime + magic bytes.
AdMediaSniff sniffAdMedia({
  required Uint8List bytes,
  String? mimeType,
  String? creativeType,
}) {
  final mime = (mimeType ?? '').toLowerCase().trim();
  final fromMime = _fromMime(mime);
  if (fromMime != null) {
    return fromMime;
  }

  final fromMagic = _fromMagic(bytes);
  if (fromMagic != null) {
    return fromMagic;
  }

  final type = (creativeType ?? '').toLowerCase();
  if (type == 'video') {
    return const AdMediaSniff(isVideo: true, extension: '.mp4', detectedMime: 'video/mp4');
  }
  if (type == 'image' || type == 'banner' || type == 'carousel') {
    return const AdMediaSniff(isVideo: false, extension: '.bin');
  }

  // Unknown: prefer treating declared video creatives as video elsewhere;
  // default to binary image path for safety.
  return const AdMediaSniff(isVideo: false, extension: '.bin');
}

bool looksLikeVideo({
  required Uint8List bytes,
  String? mimeType,
  String? creativeType,
}) {
  final sniff = sniffAdMedia(
    bytes: bytes,
    mimeType: mimeType,
    creativeType: creativeType,
  );
  if (sniff.isVideo) {
    return true;
  }
  final type = (creativeType ?? '').toLowerCase();
  final mime = (mimeType ?? '').toLowerCase();
  return type == 'video' || mime.startsWith('video/');
}

AdMediaSniff? _fromMime(String mime) {
  if (mime.isEmpty) {
    return null;
  }
  if (mime.startsWith('video/mp4') || mime == 'video/m4v' || mime == 'video/x-m4v') {
    return AdMediaSniff(isVideo: true, extension: '.mp4', detectedMime: mime);
  }
  if (mime == 'video/quicktime') {
    return AdMediaSniff(isVideo: true, extension: '.mov', detectedMime: mime);
  }
  if (mime == 'video/webm') {
    return AdMediaSniff(isVideo: true, extension: '.webm', detectedMime: mime);
  }
  if (mime.contains('matroska') || mime == 'video/x-matroska') {
    return AdMediaSniff(isVideo: true, extension: '.mkv', detectedMime: mime);
  }
  if (mime == 'video/x-msvideo' || mime == 'video/avi') {
    return AdMediaSniff(isVideo: true, extension: '.avi', detectedMime: mime);
  }
  if (mime.startsWith('video/')) {
    return AdMediaSniff(isVideo: true, extension: '.mp4', detectedMime: mime);
  }
  if (mime == 'image/jpeg' || mime == 'image/jpg') {
    return AdMediaSniff(isVideo: false, extension: '.jpg', detectedMime: mime);
  }
  if (mime == 'image/png') {
    return AdMediaSniff(isVideo: false, extension: '.png', detectedMime: mime);
  }
  if (mime == 'image/webp') {
    return AdMediaSniff(isVideo: false, extension: '.webp', detectedMime: mime);
  }
  if (mime == 'image/gif') {
    return AdMediaSniff(isVideo: false, extension: '.gif', detectedMime: mime);
  }
  if (mime.startsWith('image/')) {
    return AdMediaSniff(isVideo: false, extension: '.bin', detectedMime: mime);
  }
  return null;
}

AdMediaSniff? _fromMagic(Uint8List bytes) {
  if (bytes.length < 12) {
    return null;
  }

  // JPEG
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return const AdMediaSniff(isVideo: false, extension: '.jpg', detectedMime: 'image/jpeg');
  }
  // PNG
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return const AdMediaSniff(isVideo: false, extension: '.png', detectedMime: 'image/png');
  }
  // GIF
  if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
    return const AdMediaSniff(isVideo: false, extension: '.gif', detectedMime: 'image/gif');
  }
  // WEBP: RIFF....WEBP
  if (bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return const AdMediaSniff(isVideo: false, extension: '.webp', detectedMime: 'image/webp');
  }

  // EBML (WebM / Matroska)
  if (bytes[0] == 0x1A && bytes[1] == 0x45 && bytes[2] == 0xDF && bytes[3] == 0xA3) {
    return const AdMediaSniff(isVideo: true, extension: '.webm', detectedMime: 'video/webm');
  }

  // AVI: RIFF....AVI
  if (bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x41 &&
      bytes[9] == 0x56 &&
      bytes[10] == 0x49) {
    return const AdMediaSniff(isVideo: true, extension: '.avi', detectedMime: 'video/x-msvideo');
  }

  // ISO BMFF (mp4 / m4v / mov): ....ftyp
  if (bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    if (brand.startsWith('qt')) {
      return const AdMediaSniff(
        isVideo: true,
        extension: '.mov',
        detectedMime: 'video/quicktime',
      );
    }
    return const AdMediaSniff(isVideo: true, extension: '.mp4', detectedMime: 'video/mp4');
  }

  return null;
}
