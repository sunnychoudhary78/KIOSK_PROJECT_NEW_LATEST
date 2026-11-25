import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/features/ads/application/ads_controller.dart';
import 'package:skp_kiosk/features/ads/data/ads_repository.dart';

enum HomeBannerAxis { horizontal, vertical }

class HomeBannerStrip extends ConsumerStatefulWidget {
  const HomeBannerStrip({
    super.key,
    this.axis = HomeBannerAxis.horizontal,
    this.height = SkpTokens.bannerHeight,
    this.width = SkpTokens.bannerSideWidth,
  });

  final HomeBannerAxis axis;
  final double height;
  final double width;

  @override
  ConsumerState<HomeBannerStrip> createState() => _HomeBannerStripState();
}

class _HomeBannerStripState extends ConsumerState<HomeBannerStrip> {
  final Map<String, Uint8List> _bytes = {};
  final Set<String> _failed = {};
  final Set<String> _impressed = {};
  final Set<String> _loading = {};

  @override
  Widget build(BuildContext context) {
    final playlist = ref.watch(adsControllerProvider).playlist;
    final banners = widget.axis == HomeBannerAxis.horizontal
        ? playlist.homeBanners
        : playlist.homeSideBanners;
    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    for (final ad in banners) {
      unawaited(_ensureLoaded(ad));
    }

    final visible = banners
        .where((ad) => _bytes.containsKey(ad.id) || !_failed.contains(ad.id))
        .toList();
    // Every creative failed (or had no URL) — hide the strip instead of a stuck spinner.
    if (visible.isEmpty || banners.every((ad) => _failed.contains(ad.id))) {
      return const SizedBox.shrink();
    }

    final ready = banners.where((ad) => _bytes.containsKey(ad.id)).toList();
    final isHorizontal = widget.axis == HomeBannerAxis.horizontal;

    // Still fetching — reserve space quietly (no spinner “loading windows”).
    if (ready.isEmpty) {
      return ColoredBox(
        color: SkpColors.raised.withValues(alpha: 0.35),
        child: SizedBox(
          height: isHorizontal ? widget.height : null,
          width: isHorizontal ? null : widget.width,
        ),
      );
    }

    return ColoredBox(
      color: SkpColors.raised,
      child: SizedBox(
        height: isHorizontal ? widget.height : null,
        width: isHorizontal ? null : widget.width,
        child: PageView.builder(
          scrollDirection: isHorizontal ? Axis.horizontal : Axis.vertical,
          itemCount: ready.length,
          itemBuilder: (context, index) {
            final ad = ready[index];
            _reportImpression(ad);
            final data = _bytes[ad.id]!;
            return Image.memory(
              data,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
            );
          },
        ),
      ),
    );
  }

  Future<void> _ensureLoaded(AdPlaylistItem ad) async {
    if (_bytes.containsKey(ad.id) ||
        _failed.contains(ad.id) ||
        _loading.contains(ad.id)) {
      return;
    }
    final url = ad.mediaUrl;
    if (url == null || url.isEmpty) {
      if (mounted) {
        setState(() => _failed.add(ad.id));
      } else {
        _failed.add(ad.id);
      }
      return;
    }

    _loading.add(ad.id);
    try {
      final api = ref.read(apiClientProvider);
      final bytes = await api.getBytes(url);
      if (!mounted) return;
      setState(() {
        _loading.remove(ad.id);
        if (bytes.isEmpty) {
          _failed.add(ad.id);
        } else {
          _bytes[ad.id] = bytes;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading.remove(ad.id);
        _failed.add(ad.id);
      });
    }
  }

  void _reportImpression(AdPlaylistItem ad) {
    if (_impressed.contains(ad.id) || ad.campaignId.isEmpty) {
      return;
    }
    _impressed.add(ad.id);
    unawaited(
      ref.read(adsControllerProvider.notifier).reportEvent(
            campaignId: ad.campaignId,
            creativeId: ad.id,
            eventType: 'impression',
          ),
    );
  }
}
