import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/features/ads/application/ads_controller.dart';
import 'package:skp_kiosk/features/ads/data/ads_media_sniff.dart';
import 'package:skp_kiosk/features/ads/data/ads_repository.dart';

enum _IdleRenderMode { loading, video, image }

/// Full-screen idle ads. Any pointer interaction dismisses back to home.
class IdleAdPlayer extends ConsumerStatefulWidget {
  const IdleAdPlayer({super.key});

  @override
  ConsumerState<IdleAdPlayer> createState() => _IdleAdPlayerState();
}

class _IdleAdPlayerState extends ConsumerState<IdleAdPlayer> {
  static const _photoDwell = Duration(seconds: 6);
  static const _videoReadyTimeout = Duration(seconds: 3);

  late final Player _player = Player();
  late final VideoController _videoController = VideoController(
    _player,
    configuration: const VideoControllerConfiguration(
      hwdec: 'auto-safe',
    ),
  );

  int _index = 0;
  int _assetIndex = 0;
  File? _tempFile;
  _IdleRenderMode _mode = _IdleRenderMode.loading;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<String>? _errorSub;
  int _playGeneration = 0;

  @override
  void initState() {
    super.initState();
    _completedSub = _player.stream.completed.listen((done) {
      if (done && _mode == _IdleRenderMode.video) {
        unawaited(_onVideoCompleted());
      }
    });
    _errorSub = _player.stream.error.listen((message) {
      debugPrint('IdleAdPlayer media_kit error: $message');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_playCurrent());
    });
  }

  @override
  void dispose() {
    _playGeneration += 1;
    unawaited(_completedSub?.cancel());
    unawaited(_errorSub?.cancel());
    unawaited(_player.dispose());
    final file = _tempFile;
    if (file != null) {
      unawaited(() async {
        try {
          await file.delete();
        } catch (_) {}
      }());
    }
    super.dispose();
  }

  List<AdPlaylistItem> get _idle =>
      ref.read(adsControllerProvider).playlist.idle;

  Future<({File file, AdMediaSniff sniff, Uint8List bytes})> _downloadToTemp({
    required String id,
    required String mediaUrl,
    required String? mimeType,
    required String? creativeType,
  }) async {
    final api = ref.read(apiClientProvider);
    final bytes = await api.getBytes(mediaUrl);
    final sniff = sniffAdMedia(
      bytes: bytes,
      mimeType: mimeType,
      creativeType: creativeType,
    );
    final dir = Directory(p.join(Directory.systemTemp.path, 'skp_ads'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, '$id${sniff.extension}'));
    await file.writeAsBytes(bytes, flush: true);
    return (file: file, sniff: sniff, bytes: bytes);
  }

  Future<bool> _waitForVideoReady(int generation) async {
    final deadline = DateTime.now().add(_videoReadyTimeout);
    while (mounted && generation == _playGeneration) {
      final width = _player.state.width;
      final height = _player.state.height;
      final playing = _player.state.playing;
      final buffering = _player.state.buffering;
      if ((width != null && width > 0 && height != null && height > 0) ||
          (playing && !buffering && (_player.state.duration > Duration.zero))) {
        return true;
      }
      if (DateTime.now().isAfter(deadline)) {
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  Future<bool> _openVideo(File file, {required bool softwareDecode}) async {
    try {
      if (softwareDecode) {
        // NativePlayer.setProperty — not on PlatformPlayer interface.
        final native = _player.platform;
        if (native != null) {
          await (native as dynamic).setProperty('hwdec', 'no');
        }
        debugPrint('IdleAdPlayer: retrying with hwdec=no');
      }
      await _player.stop();
      await _player.open(Media(file.path), play: true);
      return true;
    } catch (error, stack) {
      debugPrint('IdleAdPlayer open failed (software=$softwareDecode): $error');
      debugPrint('$stack');
      return false;
    }
  }

  Future<void> _playCurrent() async {
    final generation = ++_playGeneration;
    if (mounted) {
      setState(() {
        _mode = _IdleRenderMode.loading;
        _tempFile = null;
      });
    }

    final items = _idle;
    if (items.isEmpty) {
      ref.read(adsControllerProvider.notifier).dismissIdle();
      return;
    }
    if (_index >= items.length) {
      _index = 0;
    }
    final ad = items[_index];

    try {
      // Prefer playlist type/mime, then refine with magic after download.
      final declaredVideo =
          ad.type == 'video' || (ad.mimeType ?? '').toLowerCase().startsWith('video/');

      if (declaredVideo) {
        if (ad.mediaUrl == null) {
          await _advancePlaylistItem();
          return;
        }
        final downloaded = await _downloadToTemp(
          id: ad.id,
          mediaUrl: ad.mediaUrl!,
          mimeType: ad.mimeType,
          creativeType: ad.type,
        );
        if (!mounted || generation != _playGeneration) {
          return;
        }

        final isVideo = looksLikeVideo(
          bytes: downloaded.bytes,
          mimeType: ad.mimeType,
          creativeType: ad.type,
        );
        if (!isVideo) {
          // Declared video but bytes look like an image — show as image.
          _tempFile = downloaded.file;
          if (mounted) {
            setState(() => _mode = _IdleRenderMode.image);
          }
          await ref.read(adsControllerProvider.notifier).reportEvent(
                campaignId: ad.campaignId,
                creativeId: ad.id,
                eventType: 'play_start',
              );
          await Future<void>.delayed(
            Duration(seconds: ad.durationSec ?? _photoDwell.inSeconds),
          );
          if (!mounted || generation != _playGeneration) {
            return;
          }
          await ref.read(adsControllerProvider.notifier).reportEvent(
                campaignId: ad.campaignId,
                creativeId: ad.id,
                eventType: 'play_complete',
              );
          await _advancePlaylistItem();
          return;
        }

        _tempFile = downloaded.file;
        if (mounted) {
          setState(() => _mode = _IdleRenderMode.video);
        }

        await ref.read(adsControllerProvider.notifier).reportEvent(
              campaignId: ad.campaignId,
              creativeId: ad.id,
              eventType: 'play_start',
            );

        var opened = await _openVideo(downloaded.file, softwareDecode: false);
        if (!opened || generation != _playGeneration) {
          if (generation == _playGeneration) {
            await _advancePlaylistItem();
          }
          return;
        }

        var ready = await _waitForVideoReady(generation);
        if (!ready && generation == _playGeneration) {
          opened = await _openVideo(downloaded.file, softwareDecode: true);
          if (opened) {
            ready = await _waitForVideoReady(generation);
          }
        }

        if (!ready) {
          debugPrint(
            'IdleAdPlayer: video never produced frames for ${ad.id} '
            '(${downloaded.sniff.extension}, mime=${ad.mimeType})',
          );
          if (generation == _playGeneration) {
            await _advancePlaylistItem();
          }
        }
        return;
      }

      // Image or carousel: cycle photo URLs every 6s.
      final photoUrls = <({String id, String url, String? mime})>[];
      if (ad.type == 'carousel' && ad.assets.isNotEmpty) {
        for (final asset in ad.assets) {
          if (asset.mediaUrl != null) {
            photoUrls.add((id: asset.id, url: asset.mediaUrl!, mime: asset.mimeType));
          }
        }
      } else if (ad.mediaUrl != null) {
        photoUrls.add((id: ad.id, url: ad.mediaUrl!, mime: ad.mimeType));
      }

      if (photoUrls.isEmpty) {
        await _advancePlaylistItem();
        return;
      }

      if (_assetIndex >= photoUrls.length) {
        _assetIndex = 0;
      }

      await ref.read(adsControllerProvider.notifier).reportEvent(
            campaignId: ad.campaignId,
            creativeId: ad.id,
            eventType: 'play_start',
          );

      while (mounted && generation == _playGeneration) {
        final photo = photoUrls[_assetIndex];
        final downloaded = await _downloadToTemp(
          id: photo.id,
          mediaUrl: photo.url,
          mimeType: photo.mime,
          creativeType: ad.type,
        );
        if (!mounted || generation != _playGeneration) {
          return;
        }

        // If a "photo" slot is actually video bytes, play via media_kit.
        if (downloaded.sniff.isVideo) {
          _tempFile = downloaded.file;
          if (mounted) {
            setState(() => _mode = _IdleRenderMode.video);
          }
          var opened = await _openVideo(downloaded.file, softwareDecode: false);
          var ready = opened && await _waitForVideoReady(generation);
          if (!ready && generation == _playGeneration) {
            opened = await _openVideo(downloaded.file, softwareDecode: true);
            ready = opened && await _waitForVideoReady(generation);
          }
          if (!ready) {
            await _advancePlaylistItem();
          }
          // Video completion handler advances playlist.
          return;
        }

        _tempFile = downloaded.file;
        if (mounted) {
          setState(() => _mode = _IdleRenderMode.image);
        }

        final dwell = Duration(seconds: ad.durationSec ?? _photoDwell.inSeconds);
        await Future<void>.delayed(dwell);
        if (!mounted || generation != _playGeneration) {
          return;
        }

        if (_assetIndex >= photoUrls.length - 1) {
          await ref.read(adsControllerProvider.notifier).reportEvent(
                campaignId: ad.campaignId,
                creativeId: ad.id,
                eventType: 'play_complete',
              );
          await _advancePlaylistItem();
          return;
        }
        _assetIndex += 1;
      }
    } catch (error, stack) {
      debugPrint('IdleAdPlayer failed for ${ad.id} (${ad.mediaUrl}): $error');
      debugPrint('$stack');
      if (generation == _playGeneration) {
        await _advancePlaylistItem();
      }
    }
  }

  Future<void> _onVideoCompleted() async {
    final items = _idle;
    if (items.isEmpty) {
      return;
    }
    final current = items[_index % items.length];
    await ref.read(adsControllerProvider.notifier).reportEvent(
          campaignId: current.campaignId,
          creativeId: current.id,
          eventType: 'play_complete',
        );
    await _advancePlaylistItem();
  }

  Future<void> _advancePlaylistItem() async {
    _assetIndex = 0;
    _index = (_index + 1) % (_idle.isEmpty ? 1 : _idle.length);
    await _playCurrent();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(adsControllerProvider.notifier).dismissIdle(),
        onPanDown: (_) => ref.read(adsControllerProvider.notifier).dismissIdle(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_mode == _IdleRenderMode.video)
              Video(controller: _videoController, fit: BoxFit.contain)
            else if (_mode == _IdleRenderMode.image && _tempFile != null)
              Image.file(_tempFile!, fit: BoxFit.contain)
            else
              const Center(child: CircularProgressIndicator(color: Colors.white)),
            Positioned(
              left: 16,
              bottom: 16,
              child: Text(
                'Tap anywhere to continue',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
