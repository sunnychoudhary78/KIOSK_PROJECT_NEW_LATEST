import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
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

    final Widget body;
    if (auth.stopped) {
      body = const _StoppedNotice();
    } else if (auth.provisioned && !auth.isAuthenticated) {
      body = _ReconnectNotice(error: auth.error);
    } else if (auth.bootstrapping || auth.loading) {
      body = const KioskLoading(message: 'Activating device…');
    } else if (auth.isAuthenticated) {
      body = _ServiceCatalog(auth: auth);
    } else {
      body = _ActivationForm(
        keyController: _deviceKeyController,
        secretController: _deviceSecretController,
        auth: auth,
        onActivate: () => ref.read(deviceAuthProvider.notifier).authenticate(
              deviceKey: _deviceKeyController.text,
              deviceSecret: _deviceSecretController.text,
            ),
      );
    }

    return Listener(
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
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: KioskShell(
        showHome: false,
        footerTrailing: KioskPrimaryButton(
          label: auth.loading ? 'Activating…' : 'Activate device',
          loading: auth.loading,
          onPressed: auth.loading ? null : onActivate,
        ),
        body: Material(
          color: Colors.transparent,
          child: Center(
          child: SingleChildScrollView(
            padding: SkpTokens.pagePadding,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  Text(
                    'Activate this terminal',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paste the Device key and Device secret from Admin → Kiosks after registering this device.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: SkpColors.muted,
                        ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: keyController,
                    enabled: !auth.loading,
                    enableInteractiveSelection: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Device key',
                      hintText: 'dk_…',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: secretController,
                    enabled: !auth.loading,
                    obscureText: true,
                    enableInteractiveSelection: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (!auth.loading) {
                        onActivate();
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Device secret',
                      hintText: 'ds_…',
                    ),
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: 16),
                    KioskStatusBanner(
                      message: auth.error!,
                      tone: KioskBannerTone.danger,
                      icon: Icons.error_outline,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _ServiceCatalog extends StatelessWidget {
  const _ServiceCatalog({required this.auth});

  final DeviceAuthState auth;

  @override
  Widget build(BuildContext context) {
    return KioskShell(
      showHome: false,
      subtitle: auth.deviceName,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HomeBannerStrip(),
            const SizedBox(height: 8),
            Text(
              'Select a service',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Touch a tile to begin. Your session ends automatically when you leave.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: SkpColors.muted),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 16.0;
                  final tileW = (constraints.maxWidth - gap) / 2;
                  final tileH = (constraints.maxHeight - gap) / 2;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      SizedBox(
                        width: tileW,
                        height: tileH,
                        child: KioskServiceTile(
                          icon: Icons.print_outlined,
                          title: 'OTP Print',
                          subtitle: 'Print documents using the code from the mobile app',
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.otpPrint),
                        ),
                      ),
                      SizedBox(
                        width: tileW,
                        height: tileH,
                        child: KioskServiceTile(
                          icon: Icons.account_balance_outlined,
                          title: 'DigiLocker Print',
                          subtitle: 'Sign in and print government documents',
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.digilockerPrint),
                        ),
                      ),
                      SizedBox(
                        width: tileW,
                        height: tileH,
                        child: KioskServiceTile(
                          icon: Icons.favorite_outline,
                          title: 'Well Being',
                          subtitle: 'Heart rate, blood oxygen, and temperature',
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.wellBeing),
                        ),
                      ),
                      SizedBox(
                        width: tileW,
                        height: tileH,
                        child: KioskServiceTile(
                          icon: Icons.back_hand_outlined,
                          title: 'Astrology',
                          subtitle: 'Palm reading and birth chart',
                          onTap: () => Navigator.of(context).pushNamed(AppRoutes.astrology),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoppedNotice extends StatelessWidget {
  const _StoppedNotice();

  @override
  Widget build(BuildContext context) {
    return KioskShell(
      showHome: false,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: SkpTokens.pagePadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pause_circle_outline, size: 72, color: SkpColors.gold),
                const SizedBox(height: 20),
                Text(
                  'This kiosk has been stopped',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'An operator turned this terminal off from the admin panel. '
                  'It will come back automatically when they start it again.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: SkpColors.muted,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReconnectNotice extends StatelessWidget {
  const _ReconnectNotice({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return KioskShell(
      showHome: false,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: SkpTokens.pagePadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(strokeWidth: 4),
                ),
                const SizedBox(height: 20),
                Text(
                  'Reconnecting to server…',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  KioskStatusBanner(
                    message: error!,
                    tone: KioskBannerTone.warning,
                    icon: Icons.wifi_off,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
