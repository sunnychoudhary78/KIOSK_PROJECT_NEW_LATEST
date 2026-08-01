import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/features/ads/application/ads_controller.dart';
import 'package:skp_kiosk/features/ads/data/ads_repository.dart';

class HomeBannerStrip extends ConsumerStatefulWidget {
  const HomeBannerStrip({super.key});

  @override
  ConsumerState<HomeBannerStrip> createState() => _HomeBannerStripState();
}

class _HomeBannerStripState extends ConsumerState<HomeBannerStrip> {
  final Map<String, Uint8List> _bytes = {};
  final Set<String> _impressed = {};

  @override
  Widget build(BuildContext context) {
    final banners = ref.watch(adsControllerProvider).playlist.homeBanners;
    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 120,
      child: PageView.builder(
        itemCount: banners.length,
        itemBuilder: (context, index) {
          final ad = banners[index];
          unawaited(_ensureLoaded(ad));
          _reportImpression(ad);
          final data = _bytes[ad.id];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: data == null
                  ? const ColoredBox(
                      color: Color(0xFFE8E8E8),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Image.memory(data, fit: BoxFit.cover, width: double.infinity),
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
