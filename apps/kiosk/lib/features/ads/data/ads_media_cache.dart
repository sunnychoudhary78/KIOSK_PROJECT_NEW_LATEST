import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/features/ads/data/ads_media_sniff.dart';
import 'package:skp_kiosk/features/ads/data/ads_repository.dart';

final adsMediaCacheProvider = Provider<AdsMediaCache>((ref) {
  final api = ref.watch(apiClientProvider);
  return AdsMediaCache(fetchBytes: api.getBytes);
});

class CachedAdMedia {
  const CachedAdMedia({
    required this.file,
    required this.sniff,
    required this.bytes,
  });

  final File file;
  final AdMediaSniff sniff;

  /// Full bytes on a cache miss; a prefix on a hit (enough to sniff).
  final Uint8List bytes;
}

/// Disk cache for idle ad creatives under `%TEMP%/skp_ads/{id}{ext}`.
class AdsMediaCache {
  AdsMediaCache({
    required Future<Uint8List> Function(String url) fetchBytes,
    Directory? directory,
  })  : _fetchBytes = fetchBytes,
        directory = directory ??
            Directory(p.join(Directory.systemTemp.path, 'skp_ads'));

  static const prefetchCap = 10;
  static const sniffPrefixLength = 64 * 1024;

  final Future<Uint8List> Function(String url) _fetchBytes;
  final Directory directory;
  final Map<String, Future<CachedAdMedia>> _inflight = {};

  static Set<String> idsInIdle(List<AdPlaylistItem> idle) {
    final ids = <String>{};
    for (final item in idle) {
      ids.add(item.id);
      for (final asset in item.assets) {
        ids.add(asset.id);
      }
    }
    return ids;
  }

  Future<CachedAdMedia> ensure({
    required String id,
    required String mediaUrl,
    String? mimeType,
    String? creativeType,
  }) {
    final existing = _inflight[id];
    if (existing != null) {
      return existing;
    }
    final future = _ensureUntracked(
      id: id,
      mediaUrl: mediaUrl,
      mimeType: mimeType,
      creativeType: creativeType,
    );
    _inflight[id] = future;
    return future.whenComplete(() {
      _inflight.remove(id);
    });
  }

  Future<void> prefetchIdle(
    List<AdPlaylistItem> idle, {
    int cap = prefetchCap,
  }) async {
    var n = 0;
    for (final item in idle) {
      if (n >= cap) {
        break;
      }
      if (item.type == 'carousel' && item.assets.isNotEmpty) {
        for (final asset in item.assets) {
          if (n >= cap) {
            break;
          }
          if (asset.mediaUrl == null) {
            continue;
          }
          try {
            await ensure(
              id: asset.id,
              mediaUrl: asset.mediaUrl!,
              mimeType: asset.mimeType,
              creativeType: item.type,
            );
            n += 1;
          } catch (_) {}
        }
        continue;
      }
      if (item.mediaUrl == null) {
        continue;
      }
      try {
        await ensure(
          id: item.id,
          mediaUrl: item.mediaUrl!,
          mimeType: item.mimeType,
          creativeType: item.type,
        );
        n += 1;
      } catch (_) {}
    }
  }

  Future<void> pruneKeepIds(Set<String> keepIds) async {
    if (!await directory.exists()) {
      return;
    }
    await for (final entity in directory.list()) {
      if (entity is! File) {
        continue;
      }
      final stem = p.basenameWithoutExtension(entity.path);
      if (!keepIds.contains(stem)) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  Future<CachedAdMedia> _ensureUntracked({
    required String id,
    required String mediaUrl,
    String? mimeType,
    String? creativeType,
  }) async {
    await directory.create(recursive: true);
    final hit = await _existingFile(id);
    if (hit != null) {
      final prefix = await _readPrefix(hit);
      final sniff = sniffAdMedia(
        bytes: prefix,
        mimeType: mimeType,
        creativeType: creativeType,
      );
      return CachedAdMedia(file: hit, sniff: sniff, bytes: prefix);
    }

    final bytes = await _fetchBytes(mediaUrl);
    final sniff = sniffAdMedia(
      bytes: bytes,
      mimeType: mimeType,
      creativeType: creativeType,
    );
    await _deleteStaleVariants(id);
    final file = File(p.join(directory.path, '$id${sniff.extension}'));
    await file.writeAsBytes(bytes, flush: true);
    return CachedAdMedia(file: file, sniff: sniff, bytes: bytes);
  }

  Future<File?> _existingFile(String id) async {
    if (!await directory.exists()) {
      return null;
    }
    await for (final entity in directory.list()) {
      if (entity is! File) {
        continue;
      }
      if (p.basenameWithoutExtension(entity.path) != id) {
        continue;
      }
      final length = await entity.length();
      if (length > 0) {
        return entity;
      }
    }
    return null;
  }

  Future<void> _deleteStaleVariants(String id) async {
    if (!await directory.exists()) {
      return;
    }
    await for (final entity in directory.list()) {
      if (entity is! File) {
        continue;
      }
      if (p.basenameWithoutExtension(entity.path) == id) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  Future<Uint8List> _readPrefix(File file) async {
    final length = await file.length();
    final take = length < sniffPrefixLength ? length : sniffPrefixLength;
    final raf = await file.open();
    try {
      return Uint8List.fromList(await raf.read(take));
    } finally {
      await raf.close();
    }
  }
}
