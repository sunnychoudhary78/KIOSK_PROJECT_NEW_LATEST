import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:skp_kiosk/features/ads/application/ads_controller.dart';
import 'package:skp_kiosk/features/ads/data/ads_media_cache.dart';
import 'package:skp_kiosk/features/ads/data/ads_media_sniff.dart';
import 'package:skp_kiosk/features/ads/data/ads_repository.dart';

enum _IdleRenderMode { loading, video, image }

class _Slot {
  _Slot(this.player)
      : controller = VideoController(
          player,
          configuration: const VideoControllerConfiguration(hwdec: 'auto-safe'),
        );

  final Player player;
  final VideoController controller;
  StreamSubscription<bool>? completedSub;
  StreamSubscription<String>? errorSub;

  Future<void> dispose() async {
    await completedSub?.cancel();
    await errorSub?.cancel();
    await player.dispose();
  }
}

/// Full-screen idle ads. Any pointer interaction dismisses back to home.
class IdleAdPlayer extends ConsumerStatefulWidget {
  const IdleAdPlayer({super.key});

  @override
  ConsumerState<IdleAdPlayer> createState() => _IdleAdPlayerState();
}

class _IdleAdPlayerState extends ConsumerState<IdleAdPlayer> {
  static const _photoDwell = Duration(seconds: 6);
  static const _videoReadyTimeout = Duration(seconds: 3);

  late final List<_Slot> _slots;
  int _visibleSlot = 0;

  int _index = 0;
  int _assetIndex = 0;
  File? _imageFile;
  _IdleRenderMode _mode = _IdleRenderMode.loading;
  int _playGeneration = 0;
  int _prepareEpoch = 0;
  Future<void>? _prepareFuture;
  bool _hiddenReady = false;
  int? _hiddenReadyForIndex;
  bool _handlingComplete = false;

  AdsMediaCache get _cache => ref.read(adsMediaCacheProvider);

  @override
  void initState() {
    super.initState();
    _slots = [_Slot(Player()), _Slot(Player())];
    for (var i = 0; i < _slots.length; i++) {
      final slot = i;
      _slots[i].completedSub = _slots[i].player.stream.completed.listen((done) {
        if (done) {
          unawaited(_onSlotCompleted(slot));
        }
      });
      _slots[i].errorSub = _slots[i].player.stream.error.listen((message) {
        debugPrint('IdleAdPlayer media_kit error (slot $slot): $message');
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_playCurrent());
    });
  }

  @override
  void dispose() {
    _playGeneration += 1;
    _prepareEpoch += 1;
    for (final slot in _slots) {
      unawaited(slot.dispose());
    }
    super.dispose();
  }

  List<AdPlaylistItem> get _idle =>
      ref.read(adsControllerProvider).playlist.idle;

  bool _declaredVideo(AdPlaylistItem ad) {
    return ad.type == 'video' ||
        (ad.mimeType ?? '').toLowerCase().startsWith('video/');
  }

  Future<void> _onSlotCompleted(int slot) async {
    if (_mode != _IdleRenderMode.video || slot != _visibleSlot) {
      return;
    }
    await _onVideoCompleted();
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

  Future<bool> _openVideoOnSlot(
    int slot,
    File file, {
    required bool softwareDecode,
    required bool Function() isCurrent,
  }) async {
    final player = _slots[slot].player;
    try {
      if (softwareDecode) {
        final native = player.platform;
        if (native != null) {
          await (native as dynamic).setProperty('hwdec', 'no');
        }
        debugPrint('IdleAdPlayer: retrying slot $slot with hwdec=no');
      }
      await player.setVolume(0);
      await player.stop();
      await player.open(Media(file.path), play: false);
      var ready = await _waitForVideoReady(player, isCurrent: isCurrent);
      if (!ready && isCurrent() && !softwareDecode) {
        return _openVideoOnSlot(
          slot,
          file,
          softwareDecode: true,
          isCurrent: isCurrent,
        );
      }
      return ready && isCurrent();
    } catch (error, stack) {
      debugPrint(
        'IdleAdPlayer open failed slot=$slot software=$softwareDecode: $error',
      );
      debugPrint('$stack');
      return false;
    }
  }

  Future<void> _revealSlot(int slot) async {
    await _slots[slot].player.setVolume(100);
    if (!_slots[slot].player.state.playing) {
      await _slots[slot].player.play();
    }
    if (mounted) {
      setState(() {
        _visibleSlot = slot;
        _mode = _IdleRenderMode.video;
      });
    }
  }

  Future<void> _swapToHidden() async {
    final hidden = 1 - _visibleSlot;
    final old = _visibleSlot;
    await _revealSlot(hidden);
    unawaited(() async {
      try {
        await _slots[old].player.setVolume(0);
        await _slots[old].player.stop();
      } catch (_) {}
    }());
  }

  void _startPrepareNextVideo() {
    _prepareFuture = _prepareNextVideo(_prepareEpoch);
  }

  Future<void> _prepareNextVideo(int epoch) async {
    try {
      final items = _idle;
      if (items.isEmpty) {
        return;
      }
      final nextIndex = (_index + 1) % items.length;
      final next = items[nextIndex];
      if (!_declaredVideo(next) || next.mediaUrl == null) {
        return;
      }
      final cached = await _cache.ensure(
        id: next.id,
        mediaUrl: next.mediaUrl!,
        mimeType: next.mimeType,
        creativeType: next.type,
      );
      if (!mounted || epoch != _prepareEpoch) {
        return;
      }
      if (!looksLikeVideo(
        bytes: cached.bytes,
        mimeType: next.mimeType,
        creativeType: next.type,
      )) {
        return;
      }
      final hidden = 1 - _visibleSlot;
      final opened = await _openVideoOnSlot(
        hidden,
        cached.file,
        softwareDecode: false,
        isCurrent: () => mounted && epoch == _prepareEpoch,
      );
      if (!opened || epoch != _prepareEpoch) {
        return;
      }
      _hiddenReady = true;
      _hiddenReadyForIndex = nextIndex;
    } catch (error, stack) {
      debugPrint('IdleAdPlayer prepare next failed: $error');
      debugPrint('$stack');
    }
  }

  void _prefetchNeighbors() {
    final items = _idle;
    if (items.isEmpty) {
      return;
    }
    unawaited(_prefetchItem(items[(_index + 1) % items.length]));
    final current = items[_index % items.length];
    if (current.type == 'carousel' && current.assets.length > 1) {
      final nextAsset = current.assets[(_assetIndex + 1) % current.assets.length];
      if (nextAsset.mediaUrl != null) {
        unawaited(
          _cache.ensure(
            id: nextAsset.id,
            mediaUrl: nextAsset.mediaUrl!,
            mimeType: nextAsset.mimeType,
            creativeType: current.type,
          ),
        );
      }
    }
  }

  Future<void> _prefetchItem(AdPlaylistItem ad) async {
    try {
      if (ad.type == 'carousel' && ad.assets.isNotEmpty) {
        for (final asset in ad.assets.take(2)) {
          if (asset.mediaUrl != null) {
            await _cache.ensure(
              id: asset.id,
              mediaUrl: asset.mediaUrl!,
              mimeType: asset.mimeType,
              creativeType: ad.type,
            );
          }
        }
        return;
      }
      if (ad.mediaUrl != null) {
        await _cache.ensure(
          id: ad.id,
          mediaUrl: ad.mediaUrl!,
          mimeType: ad.mimeType,
          creativeType: ad.type,
        );
      }
    } catch (_) {}
  }

  Future<bool> _showVideo(File file, int generation) async {
    final target =
        _mode == _IdleRenderMode.video ? 1 - _visibleSlot : _visibleSlot;
    final opened = await _openVideoOnSlot(
      target,
      file,
      softwareDecode: false,
      isCurrent: () => mounted && generation == _playGeneration,
    );
    if (!opened || generation != _playGeneration) {
      return false;
    }
    if (_mode == _IdleRenderMode.video && target != _visibleSlot) {
      await _swapToHidden();
    } else {
      await _revealSlot(target);
    }
    return _mode == _IdleRenderMode.video && generation == _playGeneration;
  }

  Future<void> _showImage(File file, int generation) async {
    if (!mounted || generation != _playGeneration) {
      return;
    }
    setState(() {
      _imageFile = file;
      _mode = _IdleRenderMode.image;
    });
    unawaited(() async {
      try {
        await _slots[_visibleSlot].player.setVolume(0);
        await _slots[_visibleSlot].player.stop();
      } catch (_) {}
    }());
  }

  Future<void> _playCurrent() async {
    _prepareEpoch += 1;
    _hiddenReady = false;
    _hiddenReadyForIndex = null;
    final pending = _prepareFuture;
    if (pending != null) {
      await pending;
    }
    final generation = ++_playGeneration;

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
      if (_declaredVideo(ad)) {
        if (ad.mediaUrl == null) {
          await _advancePlaylistItem();
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
          await _showImage(cached.file, generation);
          await ref.read(adsControllerProvider.notifier).reportEvent(
                campaignId: ad.campaignId,
                creativeId: ad.id,
                eventType: 'play_start',
              );
          _prefetchNeighbors();
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

        final shown = await _showVideo(cached.file, generation);
        if (!mounted || generation != _playGeneration) {
          return;
        }
        if (!shown) {
          debugPrint(
            'IdleAdPlayer: video never produced frames for ${ad.id} '
            '(${cached.sniff.extension}, mime=${ad.mimeType})',
          );
          await _advancePlaylistItem();
          return;
        }

        await ref.read(adsControllerProvider.notifier).reportEvent(
              campaignId: ad.campaignId,
              creativeId: ad.id,
              eventType: 'play_start',
            );
        _prefetchNeighbors();
        _startPrepareNextVideo();
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
          _prefetchNeighbors();
          _startPrepareNextVideo();
          return;
        }

        await _showImage(cached.file, generation);
        _prefetchNeighbors();

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
    if (_handlingComplete) {
      return;
    }
    _handlingComplete = true;
    try {
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
      final nextIndex = (_index + 1) % items.length;
      if (_hiddenReady && _hiddenReadyForIndex == nextIndex) {
        await _swapToHidden();
        _index = nextIndex;
        _assetIndex = 0;
        final next = items[_index];
        await ref.read(adsControllerProvider.notifier).reportEvent(
              campaignId: next.campaignId,
              creativeId: next.id,
              eventType: 'play_start',
            );
        _hiddenReady = false;
        _hiddenReadyForIndex = null;
        _prefetchNeighbors();
        _startPrepareNextVideo();
        return;
      }
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

  List<Widget> _videoLayers() {
    final hidden = 1 - _visibleSlot;
    final visible = _visibleSlot;
    Widget video(int slot) {
      return Video(
        key: ValueKey('idle-ad-slot-$slot'),
        controller: _slots[slot].controller,
        fit: BoxFit.contain,
      );
    }

    return [
      video(hidden),
      if (_mode == _IdleRenderMode.video)
        ColoredBox(color: Colors.black, child: video(visible))
      else
        video(visible),
    ];
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
            const ColoredBox(color: Colors.black),
            ..._videoLayers(),
            if (_mode == _IdleRenderMode.image && _imageFile != null)
              ColoredBox(
                color: Colors.black,
                child: Image.file(
                  _imageFile!,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              )
            else if (_mode == _IdleRenderMode.loading)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            Positioned(
              left: 16,
              bottom: 16,
              child: Text(
                'Tap anywhere to continue',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
