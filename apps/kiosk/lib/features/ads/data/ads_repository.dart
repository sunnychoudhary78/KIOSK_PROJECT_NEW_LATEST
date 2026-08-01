import 'package:skp_kiosk/core/network/api_client.dart';

class AdCreativeAsset {
  const AdCreativeAsset({
    required this.id,
    this.mediaUrl,
    this.mimeType,
    this.sortOrder = 0,
  });

  final String id;
  final String? mediaUrl;
  final String? mimeType;
  final int sortOrder;

  factory AdCreativeAsset.fromJson(Map<String, dynamic> json) {
    return AdCreativeAsset(
      id: json['id'] as String,
      mediaUrl: json['mediaUrl'] as String?,
      mimeType: json['mimeType'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}

class AdPlaylistItem {
  const AdPlaylistItem({
    required this.id,
    required this.campaignId,
    required this.title,
    required this.type,
    required this.slot,
    this.mediaUrl,
    this.mimeType,
    this.durationSec,
    this.assets = const [],
  });

  final String id;
  final String campaignId;
  final String title;
  final String type;
  final String slot;
  final String? mediaUrl;
  final String? mimeType;
  final int? durationSec;
  final List<AdCreativeAsset> assets;

  factory AdPlaylistItem.fromJson(Map<String, dynamic> json) {
    final rawAssets = json['assets'] as List<dynamic>? ?? const [];
    final assets = rawAssets
        .whereType<Map<String, dynamic>>()
        .map(AdCreativeAsset.fromJson)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return AdPlaylistItem(
      id: json['id'] as String,
      campaignId: json['campaignId'] as String? ?? '',
      title: json['title'] as String? ?? 'Ad',
      type: json['type'] as String? ?? 'image',
      slot: json['slot'] as String? ?? '',
      mediaUrl: json['mediaUrl'] as String?,
      mimeType: json['mimeType'] as String?,
      durationSec: json['durationSec'] as int?,
      assets: assets,
    );
  }
}

class AdPlaylist {
  const AdPlaylist({
    required this.idle,
    required this.homeBanners,
    required this.homeCarousels,
  });

  final List<AdPlaylistItem> idle;
  final List<AdPlaylistItem> homeBanners;
  final List<AdPlaylistItem> homeCarousels;

  factory AdPlaylist.fromJson(Map<String, dynamic> json) {
    List<AdPlaylistItem> mapList(String key) {
      final raw = json[key] as List<dynamic>? ?? const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(AdPlaylistItem.fromJson)
          .toList();
    }

    return AdPlaylist(
      idle: mapList('idle'),
      homeBanners: mapList('homeBanners'),
      homeCarousels: mapList('homeCarousels'),
    );
  }
}

class AdsRepository {
  AdsRepository(this._api);

  final ApiClient _api;

  Future<AdPlaylist> fetchPlaylist() async {
    final result = await _api.get('/ads/playlist');
    return AdPlaylist.fromJson(result);
  }

  Future<void> reportEvents(
    List<Map<String, dynamic>> events,
  ) async {
    if (events.isEmpty) {
      return;
    }
    await _api.post('/ads/events', body: {'events': events});
  }
}
