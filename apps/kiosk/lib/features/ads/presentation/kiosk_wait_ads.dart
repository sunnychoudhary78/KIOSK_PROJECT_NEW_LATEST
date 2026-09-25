import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/kiosk_status.dart';
import 'package:skp_kiosk/features/ads/application/ads_controller.dart';
import 'package:skp_kiosk/features/ads/data/ads_media_cache.dart';
import 'package:skp_kiosk/features/ads/data/ads_media_sniff.dart';
import 'package:skp_kiosk/features/ads/data/ads_repository.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_hold.dart';

/// In-service wait body: idle creatives after a short spinner, or [KioskLoading].
class KioskWaitAds extends ConsumerStatefulWidget {
  const KioskWaitAds({super.key, required this.message});

  final String message;

  static const revealDelay = Duration(milliseconds: 1200);
  static const surfaceKey = Key('kiosk-wait-ads-surface');

  @override
  ConsumerState<KioskWaitAds> createState() => _KioskWaitAdsState();
}

class _KioskWaitAdsState extends ConsumerState<KioskWaitAds> {
  Timer? _revealTimer;
  bool _reveal = false;
  KioskSessionHoldController? _hold;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _hold = ref.read(kioskSessionHoldProvider.notifier);
      _hold!.set(waiting: true);
    });
    _revealTimer = Timer(KioskWaitAds.revealDelay, () {
      if (mounted) {
        setState(() => _reveal = true);
      }
    });
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _hold?.set(waiting: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idle = ref.watch(adsControllerProvider).playlist.idle;
    if (idle.isEmpty || !_reveal) {
      return KioskLoading(message: widget.message);
    }
    return _WaitAdSurface(message: widget.message);
  }
}

enum _WaitRenderMode { loading, video, image }

class _WaitAdSurface extends ConsumerStatefulWidget {
  const _WaitAdSurface({required this.message});

  final String message;

  @override
  ConsumerState<_WaitAdSurface> createState() => _WaitAdSurfaceState();
}

class _WaitAdSurfaceState extends ConsumerState<_WaitAdSurface> {
  static const _photoDwell = Duration(seconds: 6);
  static const _videoReadyTimeout = Duration(seconds: 3);

  Player? _player;
  VideoController? _controller;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<String>? _errorSub;

  int _index = 0;
  int _assetIndex = 0;
  File? _imageFile;
  _WaitRenderMode _mode = _WaitRenderMode.loading;
  int _playGeneration = 0;
  bool _handlingComplete = false;
  int _cycleErrors = 0;

  AdsMediaCache get _cache => ref.read(adsMediaCacheProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_playCurrent());
    });
  }

  @override
  void dispose() {
    _playGeneration += 1;
    unawaited(_tearDownPlayer());
    super.dispose();
  }

  List<AdPlaylistItem> get _idle =>
      ref.read(adsControllerProvider).playlist.idle;

  bool _declaredVideo(AdPlaylistItem ad) {
    return ad.type == 'video' ||
        (ad.mimeType ?? '').toLowerCase().startsWith('video/');
  }

  Future<void> _tearDownPlayer() async {
    await _completedSub?.cancel();
    await _errorSub?.cancel();
    _completedSub = null;
    _errorSub = null;
    final player = _player;
    _player = null;
    _controller = null;
    if (player != null) {
      try {
        await player.stop();
      } catch (_) {}
      await player.dispose();
    }
  }

  Future<Player> _ensurePlayer() async {
    final existing = _player;
    if (existing != null) {
      return existing;
    }
    final player = Player();
    _player = player;
    _controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(hwdec: 'auto-safe'),
    );
    _completedSub = player.stream.completed.listen((done) {
      if (done) {
        unawaited(_onVideoCompleted());
      }
    });
    _errorSub = player.stream.error.listen((message) {
      debugPrint('KioskWaitAds media_kit error: $message');
    });
    return player;
  }

  Future<bool> _waitForVideoReady(
    Player player, {
    required bool Function() isCurrent,
  }) async {
    final deadline = DateTime.now().add(_videoReadyTimeout);
    while (mounted && isCurrent()) {
      final width = player.state.width;
      final height = player.state.height;
      final playing = player.state.playing;
      final buffering = player.state.buffering;
      if ((width != null && width > 0 && height != null && height > 0) ||
          (playing && !buffering && (player.state.duration > Duration.zero))) {
        return true;
      }
      if (DateTime.now().isAfter(deadline)) {
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  Future<bool> _showVideo(File file, int generation) async {
    try {
      final player = await _ensurePlayer();
      if (!mounted || generation != _playGeneration) {
        return false;
      }
      await player.setVolume(100);
      await player.stop();
      await player.open(Media(file.path), play: false);
      final ready = await _waitForVideoReady(
        player,
        isCurrent: () => mounted && generation == _playGeneration,
      );
      if (!ready || generation != _playGeneration) {
        return false;
      }
      if (!player.state.playing) {
        await player.play();
      }
      if (mounted && generation == _playGeneration) {
        setState(() {
          _imageFile = null;
          _mode = _WaitRenderMode.video;
        });
      }
      return mounted && generation == _playGeneration;
    } catch (error, stack) {
      debugPrint('KioskWaitAds open failed: $error');
      debugPrint('$stack');
      return false;
    }
  }

  Future<void> _showImage(File file, int generation) async {
    if (!mounted || generation != _playGeneration) {
      return;
    }
    setState(() {
      _imageFile = file;
      _mode = _WaitRenderMode.image;
    });
    final player = _player;
    if (player != null) {
      unawaited(() async {
        try {
          await player.setVolume(0);
          await player.stop();
        } catch (_) {}
      }());
    }
  }

  Future<void> _report(AdPlaylistItem ad, String eventType) async {
    if (ad.campaignId.isEmpty) {
      return;
    }
    await ref.read(adsControllerProvider.notifier).reportEvent(
          campaignId: ad.campaignId,
          creativeId: ad.id,
          eventType: eventType,
        );
  }

  Future<void> _playCurrent() async {
    final generation = ++_playGeneration;
    final items = _idle;
    if (items.isEmpty || !mounted) {
      return;
    }
    if (_index >= items.length) {
      _index = 0;
    }
    final ad = items[_index];

    try {
      if (_declaredVideo(ad)) {
        if (ad.mediaUrl == null) {
          await _advanceAfterError(generation);
          return;
        }
        final cached = await _cache.ensure(
          id: ad.id,
          mediaUrl: ad.mediaUrl!,
          mimeType: ad.mimeType,
          creativeType: ad.type,
        );
        if (!mounted || generation != _playGeneration) {
          return;
        }

        final isVideo = looksLikeVideo(
          bytes: cached.bytes,
          mimeType: ad.mimeType,
          creativeType: ad.type,
        );
        if (!isVideo) {
          _cycleErrors = 0;
          await _showImage(cached.file, generation);
          await _report(ad, 'impression');
          await _report(ad, 'play_start');
          await Future<void>.delayed(
            Duration(seconds: ad.durationSec ?? _photoDwell.inSeconds),
          );
          if (!mounted || generation != _playGeneration) {
            return;
          }
          await _report(ad, 'play_complete');
          await _advancePlaylistItem();
          return;
        }

        final shown = await _showVideo(cached.file, generation);
        if (!mounted || generation != _playGeneration) {
          return;
        }
        if (!shown) {
          await _advanceAfterError(generation);
          return;
        }
        _cycleErrors = 0;
        await _report(ad, 'impression');
        await _report(ad, 'play_start');
        return;
      }

      final photoUrls = <({String id, String url, String? mime})>[];
      if (ad.type == 'carousel' && ad.assets.isNotEmpty) {
        for (final asset in ad.assets) {
          if (asset.mediaUrl != null) {
            photoUrls.add(
              (id: asset.id, url: asset.mediaUrl!, mime: asset.mimeType),
            );
          }
        }
      } else if (ad.mediaUrl != null) {
        photoUrls.add((id: ad.id, url: ad.mediaUrl!, mime: ad.mimeType));
      }

      if (photoUrls.isEmpty) {
        await _advanceAfterError(generation);
        return;
      }
      if (_assetIndex >= photoUrls.length) {
        _assetIndex = 0;
      }

      await _report(ad, 'impression');
      await _report(ad, 'play_start');

      while (mounted && generation == _playGeneration) {
        final photo = photoUrls[_assetIndex];
        final cached = await _cache.ensure(
          id: photo.id,
          mediaUrl: photo.url,
          mimeType: photo.mime,
          creativeType: ad.type,
        );
        if (!mounted || generation != _playGeneration) {
          return;
        }

        if (cached.sniff.isVideo) {
          final shown = await _showVideo(cached.file, generation);
          if (!shown) {
            await _advancePlaylistItem();
            return;
          }
          return;
        }

        _cycleErrors = 0;
        await _showImage(cached.file, generation);

        final dwell = Duration(seconds: ad.durationSec ?? _photoDwell.inSeconds);
        await Future<void>.delayed(dwell);
        if (!mounted || generation != _playGeneration) {
          return;
        }

        if (_assetIndex >= photoUrls.length - 1) {
          await _report(ad, 'play_complete');
          await _advancePlaylistItem();
          return;
        }
        _assetIndex += 1;
      }
    } catch (error, stack) {
      debugPrint('KioskWaitAds failed for ${ad.id} (${ad.mediaUrl}): $error');
      debugPrint('$stack');
      await _advanceAfterError(generation);
    }
  }

  Future<void> _advanceAfterError(int generation) async {
    if (generation != _playGeneration || !mounted) {
      return;
    }
    _cycleErrors += 1;
    final len = _idle.isEmpty ? 1 : _idle.length;
    if (_cycleErrors >= len) {
      _cycleErrors = 0;
      await Future<void>.delayed(const Duration(seconds: 2));
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    if (generation == _playGeneration && mounted) {
      await _advancePlaylistItem();
    }
  }

  Future<void> _onVideoCompleted() async {
    if (_handlingComplete || _mode != _WaitRenderMode.video) {
      return;
    }
    _handlingComplete = true;
    try {
      final items = _idle;
      if (items.isEmpty) {
        return;
      }
      final current = items[_index % items.length];
      await _report(current, 'play_complete');
      await _advancePlaylistItem();
    } finally {
      _handlingComplete = false;
    }
  }

  Future<void> _advancePlaylistItem() async {
    _assetIndex = 0;
    _index = (_index + 1) % (_idle.isEmpty ? 1 : _idle.length);
    await _playCurrent();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return KeyedSubtree(
      key: KioskWaitAds.surfaceKey,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_mode == _WaitRenderMode.video && controller != null)
              Video(
                controller: controller,
                fit: BoxFit.contain,
              )
            else if (_mode == _WaitRenderMode.image && _imageFile != null)
              Image.file(
                _imageFile!,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xCC0B1419),
                      borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
                      border: Border.all(color: SkpColors.line),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: SkpColors.text,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
