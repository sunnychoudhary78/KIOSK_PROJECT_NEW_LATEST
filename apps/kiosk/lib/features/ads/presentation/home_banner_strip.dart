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
  final Set<String> _impressed = {};

  @override
  Widget build(BuildContext context) {
    final playlist = ref.watch(adsControllerProvider).playlist;
    final banners = widget.axis == HomeBannerAxis.horizontal
        ? playlist.homeBanners
        : playlist.homeSideBanners;
    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    final isHorizontal = widget.axis == HomeBannerAxis.horizontal;

    return SizedBox(
      height: isHorizontal ? widget.height : null,
      width: isHorizontal ? null : widget.width,
      child: PageView.builder(
        scrollDirection: isHorizontal ? Axis.horizontal : Axis.vertical,
        itemCount: banners.length,
        itemBuilder: (context, index) {
          final ad = banners[index];
          unawaited(_ensureLoaded(ad));
          _reportImpression(ad);
          final data = _bytes[ad.id];
          return Padding(
            padding: EdgeInsets.symmetric(
              vertical: isHorizontal ? 4 : 0,
              horizontal: isHorizontal ? 0 : 4,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
              child: data == null
                  ? const ColoredBox(
                      color: SkpColors.raised,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Image.memory(
                      data,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _ensureLoaded(AdPlaylistItem ad) async {
    if (_bytes.containsKey(ad.id) || ad.mediaUrl == null) {
      return;
    }
    try {
      final api = ref.read(apiClientProvider);
      final bytes = await api.getBytes(ad.mediaUrl!);
      if (mounted) {
        setState(() => _bytes[ad.id] = bytes);
      }
    } catch (_) {}
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
