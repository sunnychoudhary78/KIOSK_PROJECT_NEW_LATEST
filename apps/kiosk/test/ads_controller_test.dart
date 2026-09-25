import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/features/ads/application/ads_controller.dart';
import 'package:skp_kiosk/features/ads/data/ads_repository.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';

class _AuthedDeviceAuth extends DeviceAuthNotifier {
  @override
  DeviceAuthState build() {
    return const DeviceAuthState(accessToken: 'token', deviceId: 'device-1');
  }
}

AdPlaylist _idlePlaylist() {
  return const AdPlaylist(
    idle: [
      AdPlaylistItem(
        id: 'ad-1',
        campaignId: 'camp-1',
        title: 'Idle',
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
  ProviderContainer containerOf() {
    return ProviderContainer(
      overrides: [
        deviceAuthProvider.overrideWith(_AuthedDeviceAuth.new),
      ],
    );
  }

  test('leaving home cancels attract and hides overlay', () {
    fakeAsync((async) {
      final container = containerOf();
      addTearDown(container.dispose);
      container.listen(adsControllerProvider, (_, _) {});
      container.listen(kioskSessionControllerProvider, (_, _) {});

      final ads = container.read(adsControllerProvider.notifier);
      ads.replacePlaylist(_idlePlaylist());

      async.elapse(AdsController.idleTimeout);
      expect(container.read(adsControllerProvider).idleVisible, isTrue);

      container.read(kioskSessionControllerProvider.notifier).setOnHome(false);
      expect(container.read(adsControllerProvider).idleVisible, isFalse);

      async.elapse(AdsController.idleTimeout);
      expect(container.read(adsControllerProvider).idleVisible, isFalse);
    });
  });

  test('returning home re-arms attract', () {
    fakeAsync((async) {
      final container = containerOf();
      addTearDown(container.dispose);
      container.listen(adsControllerProvider, (_, _) {});
      container.listen(kioskSessionControllerProvider, (_, _) {});

      final ads = container.read(adsControllerProvider.notifier);
      final session = container.read(kioskSessionControllerProvider.notifier);
      ads.replacePlaylist(_idlePlaylist());
      session.setOnHome(false);

      async.elapse(AdsController.idleTimeout);
      expect(container.read(adsControllerProvider).idleVisible, isFalse);

      session.setOnHome(true);
      expect(container.read(adsControllerProvider).idleVisible, isFalse);

      async.elapse(AdsController.idleTimeout);
      expect(container.read(adsControllerProvider).idleVisible, isTrue);
    });
  });

  test('showIdleNow works when on home', () {
    fakeAsync((async) {
      final container = containerOf();
      addTearDown(container.dispose);
      container.listen(adsControllerProvider, (_, _) {});

      final ads = container.read(adsControllerProvider.notifier);
      ads.replacePlaylist(_idlePlaylist());
      ads.showIdleNow();

      expect(container.read(adsControllerProvider).idleVisible, isTrue);
      async.elapse(AdsController.idleTimeout);
      expect(container.read(adsControllerProvider).idleVisible, isTrue);
    });
  });
}
