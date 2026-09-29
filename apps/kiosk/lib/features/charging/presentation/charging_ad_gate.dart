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

enum _GateMode { loading, video, image }

/// Plays exactly one idle creative, then calls [onCompleted].
///
/// If the idle playlist is empty, waits briefly then still completes so
/// charging is not blocked when ads are unavailable.
class ChargingAdGate extends ConsumerStatefulWidget {
  const ChargingAdGate({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  static const emptyPlaylistFallback = Duration(seconds: 3);
  static const photoDwell = Duration(seconds: 6);

  @override
  ConsumerState<ChargingAdGate> createState() => _ChargingAdGateState();
}

class _ChargingAdGateState extends ConsumerState<ChargingAdGate> {
  static const _videoReadyTimeout = Duration(seconds: 3);

  Player? _player;
  VideoController? _controller;
  StreamSubscription<bool>? _completedSub;
  Timer? _fallbackTimer;
  Timer? _imageTimer;

  File? _imageFile;
  _GateMode _mode = _GateMode.loading;
  int _generation = 0;
  bool _finished = false;
  bool _handlingComplete = false;

  AdsMediaCache get _cache => ref.read(adsMediaCacheProvider);

  List<AdPlaylistItem> get _idle =>
      ref.read(adsControllerProvider).playlist.idle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_start());
    });
  }

  @override
  void dispose() {
    _generation += 1;
    _fallbackTimer?.cancel();
    _imageTimer?.cancel();
    unawaited(_completedSub?.cancel());
    final player = _player;
    _player = null;
    _controller = null;
    if (player != null) {
      unawaited(player.dispose());
    }
    super.dispose();
  }

  Future<void> _start() async {
    final generation = ++_generation;
    final idle = _idle;
    if (idle.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() => _mode = _GateMode.loading);
      _fallbackTimer?.cancel();
      _fallbackTimer = Timer(ChargingAdGate.emptyPlaylistFallback, () {
        _complete();
      });
      return;
    }
    await _playAd(idle.first, generation);
  }

  bool _declaredVideo(AdPlaylistItem ad) {
    return ad.type == 'video' ||
        (ad.mimeType ?? '').toLowerCase().startsWith('video/');
  }

  Future<void> _playAd(AdPlaylistItem ad, int generation) async {
    try {
      if (_declaredVideo(ad)) {
        if (ad.mediaUrl == null) {
          _complete();
          return;
        }
        final cached = await _cache.ensure(
          id: ad.id,
          mediaUrl: ad.mediaUrl!,
          mimeType: ad.mimeType,
          creativeType: ad.type,
        );
        if (!mounted || generation != _generation) {
          return;
        }
        final isVideo = looksLikeVideo(
          bytes: cached.bytes,
          mimeType: ad.mimeType,
          creativeType: ad.type,
        );
        if (!isVideo) {
          await _showImage(cached.file, ad, generation);
          return;
        }
        final shown = await _showVideo(cached.file, generation);
        if (!mounted || generation != _generation) {
          return;
        }
        if (!shown) {
          _complete();
          return;
        }
        await _report(ad, 'impression');
        await _report(ad, 'play_start');
        return;
      }

      if (ad.mediaUrl == null) {
        _complete();
        return;
      }
      final cached = await _cache.ensure(
        id: ad.id,
        mediaUrl: ad.mediaUrl!,
        mimeType: ad.mimeType,
        creativeType: ad.type,
      );
      if (!mounted || generation != _generation) {
        return;
      }
      if (cached.sniff.isVideo) {
        final shown = await _showVideo(cached.file, generation);
        if (!shown) {
          _complete();
          return;
        }
        await _report(ad, 'impression');
        await _report(ad, 'play_start');
        return;
      }
      await _showImage(cached.file, ad, generation);
    } catch (error, stack) {
      debugPrint('ChargingAdGate failed for ${ad.id}: $error');
      debugPrint('$stack');
      _complete();
    }
  }

  Future<void> _showImage(
    File file,
    AdPlaylistItem ad,
    int generation,
  ) async {
    if (!mounted || generation != _generation) {
      return;
    }
    setState(() {
      _imageFile = file;
      _mode = _GateMode.image;
    });
    await _report(ad, 'impression');
    await _report(ad, 'play_start');
    final dwell = Duration(seconds: ad.durationSec ?? ChargingAdGate.photoDwell.inSeconds);
    _imageTimer?.cancel();
    _imageTimer = Timer(dwell, () {
      unawaited(() async {
        await _report(ad, 'play_complete');
        _complete();
      }());
    });
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
      final player = _player ?? Player();
      _player ??= player;
      _controller ??= VideoController(
        player,
        configuration: const VideoControllerConfiguration(hwdec: 'auto-safe'),
      );
      await _completedSub?.cancel();
      _completedSub = player.stream.completed.listen((done) {
        if (done) {
          unawaited(_onVideoCompleted());
        }
      });
      await player.setVolume(0);
      await player.stop();
      await player.open(Media(file.path), play: false);
      final ready = await _waitForVideoReady(
        player,
        isCurrent: () => mounted && generation == _generation,
      );
      if (!ready || !mounted || generation != _generation) {
        return false;
      }
      await player.play();
      if (mounted && generation == _generation) {
        setState(() {
          _imageFile = null;
          _mode = _GateMode.video;
        });
      }
      return mounted && generation == _generation;
    } catch (error, stack) {
      debugPrint('ChargingAdGate open video failed: $error');
      debugPrint('$stack');
      return false;
    }
  }

  Future<void> _onVideoCompleted() async {
    if (_handlingComplete || _mode != _GateMode.video) {
      return;
    }
    _handlingComplete = true;
    try {
      final idle = _idle;
      if (idle.isNotEmpty) {
        await _report(idle.first, 'play_complete');
      }
      _complete();
    } finally {
      _handlingComplete = false;
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

  void _complete() {
    if (_finished || !mounted) {
      return;
    }
    _finished = true;
    _fallbackTimer?.cancel();
    _imageTimer?.cancel();
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Watch to unlock charging',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _idle.isEmpty
              ? 'Sponsored message unavailable — unlocking shortly…'
              : 'Please watch this message. Charging starts when it finishes.',
          style: theme.textTheme.bodyLarge?.copyWith(color: SkpColors.muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: SkpColors.raised,
              borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
              border: Border.all(color: SkpColors.line),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
              child: switch (_mode) {
                _GateMode.loading => const KioskLoading(
                    message: 'Loading message…',
                  ),
                _GateMode.image => _imageFile == null
                    ? const KioskLoading(message: 'Loading message…')
                    : Image.file(_imageFile!, fit: BoxFit.contain),
                _GateMode.video => _controller == null
                    ? const KioskLoading(message: 'Loading message…')
                    : Video(
                        controller: _controller!,
                        controls: NoVideoControls,
                        fit: BoxFit.contain,
                      ),
              },
            ),
          ),
        ),
      ],
    );
  }
}
