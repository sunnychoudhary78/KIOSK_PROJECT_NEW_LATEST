import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/features/ads/data/ads_media_cache.dart';
import 'package:skp_kiosk/features/ads/data/ads_repository.dart';

Uint8List _jpegBytes() {
  return Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xE0,
    0, 0, 0, 0,
    0, 0, 0, 0,
    1, 2, 3, 4,
  ]);
}

void main() {
  late Directory dir;
  late Uint8List jpeg;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('skp_ads_test');
    jpeg = _jpegBytes();
  });

  tearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  test('miss writes file and hit skips fetchBytes', () async {
    var fetches = 0;
    final cache = AdsMediaCache(
      fetchBytes: (url) async {
        fetches += 1;
        expect(url, '/ads/media/c1');
        return jpeg;
      },
      directory: dir,
    );

    final first = await cache.ensure(
      id: 'c1',
      mediaUrl: '/ads/media/c1',
      mimeType: 'image/jpeg',
      creativeType: 'image',
    );
    expect(fetches, 1);
    expect(first.file.existsSync(), isTrue);
    expect(first.sniff.extension, '.jpg');
    expect(first.sniff.isVideo, isFalse);
    expect(await first.file.length(), jpeg.length);

    final second = await cache.ensure(
      id: 'c1',
      mediaUrl: '/ads/media/c1',
      mimeType: 'image/jpeg',
      creativeType: 'image',
    );
    expect(fetches, 1);
    expect(second.file.path, first.file.path);
    expect(second.sniff.extension, '.jpg');
  });

  test('missing file is a miss', () async {
    var fetches = 0;
    final cache = AdsMediaCache(
      fetchBytes: (url) async {
        fetches += 1;
        return jpeg;
      },
      directory: dir,
    );

    await cache.ensure(id: 'missing', mediaUrl: '/ads/media/missing');
    expect(fetches, 1);
  });

  test('empty file is treated as a miss', () async {
    File('${dir.path}/empty.jpg').writeAsBytesSync(const []);
    var fetches = 0;
    final cache = AdsMediaCache(
      fetchBytes: (url) async {
        fetches += 1;
        return jpeg;
      },
      directory: dir,
    );

    final cached = await cache.ensure(
      id: 'empty',
      mediaUrl: '/ads/media/empty',
      mimeType: 'image/jpeg',
      creativeType: 'image',
    );
    expect(fetches, 1);
    expect(await cached.file.length(), jpeg.length);
  });

  test('pruneKeepIds deletes files not in the keep set', () async {
    final keepFile = File('${dir.path}/keep.jpg')..writeAsBytesSync(jpeg);
    final dropFile = File('${dir.path}/drop.jpg')..writeAsBytesSync(jpeg);
    final cache = AdsMediaCache(
      fetchBytes: (url) async => jpeg,
      directory: dir,
    );

    await cache.pruneKeepIds({'keep'});
    expect(keepFile.existsSync(), isTrue);
    expect(dropFile.existsSync(), isFalse);
  });

  test('prefetchIdle downloads up to cap and uses carousel assets', () async {
    final urls = <String>[];
    final cache = AdsMediaCache(
      fetchBytes: (url) async {
        urls.add(url);
        return jpeg;
      },
      directory: dir,
    );

    await cache.prefetchIdle(
      [
        const AdPlaylistItem(
          id: 'v1',
          campaignId: 'c',
          title: 'Video',
          type: 'video',
          slot: 'idle_video',
          mediaUrl: '/ads/media/v1',
          mimeType: 'video/mp4',
        ),
        const AdPlaylistItem(
          id: 'car',
          campaignId: 'c',
          title: 'Carousel',
          type: 'carousel',
          slot: 'idle_video',
          assets: [
            AdCreativeAsset(id: 'a1', mediaUrl: '/ads/media/a1'),
            AdCreativeAsset(id: 'a2', mediaUrl: '/ads/media/a2'),
          ],
        ),
        const AdPlaylistItem(
          id: 'img',
          campaignId: 'c',
          title: 'Image',
          type: 'image',
          slot: 'idle_video',
          mediaUrl: '/ads/media/img',
        ),
      ],
      cap: 3,
    );

    expect(urls, ['/ads/media/v1', '/ads/media/a1', '/ads/media/a2']);
  });

  test('idsInIdle includes creative and asset ids', () {
    final ids = AdsMediaCache.idsInIdle([
      const AdPlaylistItem(
        id: 'v1',
        campaignId: 'c',
        title: 'Video',
        type: 'video',
        slot: 'idle_video',
        mediaUrl: '/ads/media/v1',
      ),
      const AdPlaylistItem(
        id: 'car',
        campaignId: 'c',
        title: 'Carousel',
        type: 'carousel',
        slot: 'idle_video',
        assets: [
          AdCreativeAsset(id: 'a1', mediaUrl: '/ads/media/a1'),
        ],
      ),
    ]);
    expect(ids, {'v1', 'car', 'a1'});
  });
}
