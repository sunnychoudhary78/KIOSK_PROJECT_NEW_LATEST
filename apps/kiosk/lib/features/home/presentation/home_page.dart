import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/features/ads/application/ads_controller.dart';
import 'package:skp_kiosk/features/ads/presentation/home_banner_strip.dart';
import 'package:skp_kiosk/features/ads/presentation/idle_ad_player.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _deviceKeyController = TextEditingController();
  final _deviceSecretController = TextEditingController();
  bool _adsStarted = false;

  @override
  void dispose() {
    if (_adsStarted) {
      ref.read(adsControllerProvider.notifier).stopWatching();
    }
    _deviceKeyController.dispose();
    _deviceSecretController.dispose();
    super.dispose();
  }

  void _syncAdsWatching(bool authenticated) {
    if (authenticated && !_adsStarted) {
      _adsStarted = true;
      ref.read(adsControllerProvider.notifier).startWatching();
    } else if (!authenticated && _adsStarted) {
      _adsStarted = false;
      ref.read(adsControllerProvider.notifier).stopWatching();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(deviceAuthProvider);
    final ads = ref.watch(adsControllerProvider);
    ref.listen(deviceAuthProvider, (previous, next) {
      _syncAdsWatching(next.isAuthenticated);
    });
    if (auth.isAuthenticated && !_adsStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncAdsWatching(true);
        }
      });
    }

    final body = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: auth.bootstrapping || (auth.loading && !auth.isAuthenticated)
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Activating device…'),
                  ],
                )
              : auth.isAuthenticated
                  ? _ServiceCatalog(auth: auth)
                  : _ActivationForm(
                      keyController: _deviceKeyController,
                      secretController: _deviceSecretController,
                      auth: auth,
                      onActivate: () => ref.read(deviceAuthProvider.notifier).authenticate(
                            deviceKey: _deviceKeyController.text,
                            deviceSecret: _deviceSecretController.text,
                          ),
                    ),
        ),
      ),
    );

    return Scaffold(
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          if (auth.isAuthenticated && !ads.idleVisible) {
            ref.read(adsControllerProvider.notifier).resetIdleTimer();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            body,
            if (auth.isAuthenticated && ads.idleVisible) const IdleAdPlayer(),
          ],
        ),
      ),
    );
  }
}

class _ActivationForm extends StatelessWidget {
  const _ActivationForm({
    required this.keyController,
    required this.secretController,
    required this.auth,
    required this.onActivate,
  });

  final TextEditingController keyController;
  final TextEditingController secretController;
  final DeviceAuthState auth;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Smart Kiosk',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Activate this terminal',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Paste the Device key and Device secret from Admin → Kiosks after registering this device.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: keyController,
          decoration: const InputDecoration(
            labelText: 'Device key',
            hintText: 'dk_…',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: secretController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Device secret',
            hintText: 'ds_…',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: auth.loading ? null : onActivate,
          child: Text(auth.loading ? 'Activating…' : 'Activate device'),
        ),
        if (auth.error != null) ...[
          const SizedBox(height: 12),
          Text(
            auth.error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _ServiceCatalog extends ConsumerWidget {
  const _ServiceCatalog({required this.auth});

  final DeviceAuthState auth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Smart Kiosk',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          auth.deviceName == null ? 'Select a service' : auth.deviceName!,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const HomeBannerStrip(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.otpPrint),
          child: const Text('OTP Print'),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.digilockerPrint),
          child: const Text('DigiLocker Print'),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.wellBeing),
          child: const Text('Well Being'),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.astrology),
          child: const Text('Astrology'),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => ref.read(deviceAuthProvider.notifier).deactivate(),
          child: const Text('Deactivate this device'),
        ),
      ],
    );
  }
}
