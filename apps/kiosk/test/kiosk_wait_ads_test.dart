import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/ui/kiosk_status.dart';
import 'package:skp_kiosk/features/ads/application/ads_controller.dart';
import 'package:skp_kiosk/features/ads/data/ads_repository.dart';
import 'package:skp_kiosk/features/ads/presentation/kiosk_wait_ads.dart';

class _PlaylistAds extends AdsController {
  _PlaylistAds(this.playlist);

  final AdPlaylist playlist;

  @override
  AdsUiState build() => AdsUiState(playlist: playlist);
}

const _message = 'Preparing your reading…';

AdPlaylist _idlePlaylist() {
  return const AdPlaylist(
    idle: [
      AdPlaylistItem(
        id: 'ad-1',
        campaignId: 'camp-1',
        title: 'Wait',
        type: 'image',
        slot: 'idle_video',
        mediaUrl: '/ads/media/ad-1',
        mimeType: 'image/jpeg',
      ),
    ],
    homeBanners: [],
    homeCarousels: [],
  );
}

void main() {
  testWidgets('empty playlist stays on KioskLoading', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: KioskWaitAds(message: _message)),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(KioskLoading), findsOneWidget);
    expect(find.text(_message), findsOneWidget);
    expect(find.byKey(KioskWaitAds.surfaceKey), findsNothing);

    await tester.pump(KioskWaitAds.revealDelay);
    expect(find.byType(KioskLoading), findsOneWidget);
    expect(find.byKey(KioskWaitAds.surfaceKey), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('non-empty playlist reveals ads surface after delay', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsControllerProvider.overrideWith(() => _PlaylistAds(_idlePlaylist())),
        ],
        child: const MaterialApp(
          home: Scaffold(body: KioskWaitAds(message: _message)),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(KioskLoading), findsOneWidget);
    expect(find.byKey(KioskWaitAds.surfaceKey), findsNothing);

    await tester.pump(KioskWaitAds.revealDelay);
    expect(find.byKey(KioskWaitAds.surfaceKey), findsOneWidget);
    expect(find.text(_message), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
}
