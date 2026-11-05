import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/ads/application/ads_controller.dart';
import 'package:skp_kiosk/features/ads/presentation/home_banner_strip.dart';
import 'package:skp_kiosk/features/ads/presentation/idle_ad_player.dart';
import 'package:skp_kiosk/features/home/presentation/widgets/kiosk_terminal_graphic.dart';
import 'package:skp_kiosk/features/weather/application/weather_controller.dart';
import 'package:skp_kiosk/features/weather/presentation/weather_header_strip.dart';

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
      ref.read(weatherControllerProvider.notifier).startWatching();
    } else if (!authenticated && _adsStarted) {
      _adsStarted = false;
      ref.read(adsControllerProvider.notifier).stopWatching();
      ref.read(weatherControllerProvider.notifier).stopWatching();
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
    return KioskScaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: SkpTokens.pagePadding,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Activate Kiosk Device',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the credentials provisioned in the admin dashboard.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: keyController,
                      decoration: const InputDecoration(
                        labelText: 'Device Key',
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: secretController,
                      decoration: const InputDecoration(
                        labelText: 'Device Secret',
                        prefixIcon: Icon(Icons.password_outlined),
                      ),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => onActivate(),
                    ),
                    const SizedBox(height: 24),
                    KioskPrimaryButton(
                      label: 'Activate',
                      loading: auth.loading,
                      onPressed: onActivate,
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

class _ServiceCatalog extends ConsumerStatefulWidget {
  const _ServiceCatalog({required this.auth});

  final DeviceAuthState auth;

  @override
  ConsumerState<_ServiceCatalog> createState() => _ServiceCatalogState();
}

class _ServiceCatalogState extends ConsumerState<_ServiceCatalog> {
  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final playlist = ref.watch(adsControllerProvider).playlist;
    final showHorizontal = playlist.homeBanners.isNotEmpty;
    final showVertical = playlist.homeSideBanners.isNotEmpty;

    // 6 Signature Service Tiles (Image 1)
    final tiles = [
      KioskServiceTile(
        icon: Icons.print_rounded,
        title: 'Print Documents',
        subtitle: 'Phone, OTP, or DigiLocker',
        accent: const Color(0xFF0077B6),
        gradientColors: const [Color(0xFF29B6F6), Color(0xFF0288D1)],
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.print),
      ),
      KioskServiceTile(
        icon: Icons.handyman_rounded,
        title: 'Find Services',
        subtitle: 'Mechanics, tailors, carpenters, and more',
        accent: const Color(0xFF00A878),
        gradientColors: const [Color(0xFF26A69A), Color(0xFF00897B)],
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.localServices),
      ),
      KioskServiceTile(
        icon: Icons.favorite_rounded,
        title: 'Well Being',
        subtitle: 'Heart rate, blood oxygen, and temperature',
        accent: const Color(0xFFE6007A),
        gradientColors: const [Color(0xFFFF4081), Color(0xFFE6007A)],
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.wellBeing),
      ),
      KioskServiceTile(
        icon: Icons.battery_charging_full_rounded,
        title: 'Phone Charging',
        subtitle: 'Watch a short message, then charge your phone',
        accent: const Color(0xFFFB8C00),
        gradientColors: const [Color(0xFFFFB300), Color(0xFFFB8C00)],
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.charging),
      ),
      KioskServiceTile(
        icon: Icons.auto_awesome_rounded,
        title: 'Astrology',
        subtitle: 'Kundali · Palm · Match · Today',
        accent: const Color(0xFF7928CA),
        gradientColors: const [Color(0xFF9C27B0), Color(0xFF673AB7)],
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.astrology),
      ),
      KioskServiceTile(
        icon: Icons.local_gas_station_rounded,
        title: 'Fuel Stations',
        subtitle: 'Petrol, diesel, CNG, and EV stations nearby',
        accent: const Color(0xFFF4511E),
        gradientColors: const [Color(0xFFFF7043), Color(0xFFE64A19)],
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.fuelStations),
      ),
    ];

    const gap = 14.0;
    const rows = 3;

    final serviceGrid = Column(
      children: [
        for (var row = 0; row < rows; row++) ...[
          if (row > 0) const SizedBox(height: gap),
          Expanded(
            child: Row(
              children: [
                Expanded(child: tiles[row * 2]),
                const SizedBox(width: gap),
                Expanded(child: tiles[row * 2 + 1]),
              ],
            ),
          ),
        ],
      ],
    );

    // Main central layout
    final contentArea = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero Header Row: Title + Emergency CTA + Kiosk Graphic
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Select a ',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: colors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: 'Service',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: colors.accentMagenta,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Magenta accent underline
                  Container(
                    width: 54,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.accentMagenta,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Touch a tile to begin',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.emergency),
                icon: const Icon(Icons.sos_outlined, size: 22),
                label: const Text('Emergency'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 56),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Image.asset(
              'assets/new_theme_icons/machine_image.png',
              height: 110,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const KioskTerminalGraphic(size: 110),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(child: serviceGrid),
      ],
    );

    final centerColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHorizontal) ...[
          const HomeBannerStrip(),
          ColoredBox(
            color: colors.cardBorder,
            child: const SizedBox(height: SkpTokens.hairline),
          ),
        ],
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              showVertical ? 20 : 28,
              showHorizontal ? 10 : 8,
              showVertical ? 20 : 28,
              12,
            ),
            child: contentArea,
          ),
        ),
        if (showHorizontal) ...[
          ColoredBox(
            color: colors.cardBorder,
            child: const SizedBox(height: SkpTokens.hairline),
          ),
          const HomeBannerStrip(),
        ],
        // Bottom Footer Bar (Image 1)
        _HomeFooterBar(colors: colors),
      ],
    );

    final mainBody = showVertical
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HomeBannerStrip(axis: HomeBannerAxis.vertical),
              ColoredBox(
                color: colors.cardBorder,
                child: const SizedBox(width: SkpTokens.hairline),
              ),
              Expanded(child: centerColumn),
              ColoredBox(
                color: colors.cardBorder,
                child: const SizedBox(width: SkpTokens.hairline),
              ),
              const HomeBannerStrip(axis: HomeBannerAxis.vertical),
            ],
          )
        : centerColumn;

    return KioskScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Athena Top Navigation Header (Image 1)
          Container(
            height: 76,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Athena Brand Lockup
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/brand/athena_logo.png',
                      height: 44,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.accentMagenta, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            'A',
                            style: TextStyle(
                              color: colors.accentMagenta,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ATHENA',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            letterSpacing: 1.1,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Your Smart Everyday Assistant',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontWeight: FontWeight.w500,
                            fontSize: 10.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Container(
                  width: 1.2,
                  height: 24,
                  color: colors.cardBorder,
                ),
                const SizedBox(width: 12),

                // Smart Service Kiosk Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.accentMagenta.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_rounded, size: 14, color: colors.accentMagenta),
                      const SizedBox(width: 5),
                      Text(
                        'Smart Service Kiosk',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.accentMagenta,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Right header cluster: Weather strip, Theme mode toggle, Clock
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    WeatherHeaderStrip(
                      locationLabel: (widget.auth.deviceName != null && widget.auth.deviceName!.isNotEmpty)
                          ? widget.auth.deviceName!
                          : 'Kiosk 6',
                    ),
                    const SizedBox(width: 12),

                    // Dark/Light Theme Mode Toggle (Sun/Moon capsule)
                    const ThemeModeTogglePill(),
                    const SizedBox(width: 14),

                    // Live Clock & Date
                    const KioskClock(showDate: true),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: mainBody),
        ],
      ),
    );
  }
}

class _HomeFooterBar extends StatelessWidget {
  const _HomeFooterBar({required this.colors});

  final AthenaColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          // Left: Need help?
          Icon(Icons.info_outline_rounded, size: 16, color: colors.textSecondary),
          const SizedBox(width: 6),
          Text(
            'Need help? Please ask the attendant.',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
          const Spacer(),

          // Divider
          Container(
            width: 1,
            height: 18,
            color: colors.cardBorder,
          ),
          const SizedBox(width: 16),

          // Right: Empowering Businesses with Smart IT Solutions
          Icon(Icons.rocket_launch_rounded, size: 16, color: colors.accentMagenta),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Empowering Businesses with ',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
                TextSpan(
                  text: 'Smart IT Solutions',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: colors.accentMagenta,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        child: KioskStatusBanner(
          message: 'This kiosk is temporarily decommissioned.',
          tone: KioskBannerTone.warning,
          icon: Icons.block,
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
        child: KioskStatusBanner(
          message: error ?? 'Reconnecting to kiosk cloud…',
          tone: KioskBannerTone.info,
          icon: Icons.sync,
        ),
      ),
    );
  }
}
