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
import 'package:skp_kiosk/features/home/application/service_catalog_controller.dart';
import 'package:skp_kiosk/features/home/domain/kiosk_home_service.dart';
import 'package:skp_kiosk/features/home/presentation/stopped_kiosk_page.dart';
import 'package:skp_kiosk/features/home/presentation/under_maintenance_page.dart';
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
      ref.read(serviceCatalogControllerProvider.notifier).startWatching();
    } else if (!authenticated && _adsStarted) {
      _adsStarted = false;
      ref.read(adsControllerProvider.notifier).stopWatching();
      ref.read(weatherControllerProvider.notifier).stopWatching();
      ref.read(serviceCatalogControllerProvider.notifier).stopWatching();
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
      body = StoppedKioskPage(deviceName: auth.deviceName);
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
  Future<void> _openService(
    BuildContext context,
    KioskHomeService service,
    String route,
  ) async {
    await ref.read(serviceCatalogControllerProvider.notifier).refresh();
    if (!context.mounted) {
      return;
    }
    final catalog = ref.read(serviceCatalogControllerProvider);
    if (!catalog.isHomeServiceEnabled(service)) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => UnderMaintenancePage(serviceTitle: service.displayName),
        ),
      );
      return;
    }
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final playlist = ref.watch(adsControllerProvider).playlist;
    // Rebuild when enablement/status changes so taps use the latest map.
    final catalog = ref.watch(serviceCatalogControllerProvider);
    final showHorizontal = playlist.homeBanners.isNotEmpty;
    final showVertical = playlist.homeSideBanners.isNotEmpty;
    final layout = _HomeLayout.of(MediaQuery.sizeOf(context));

    ({String? label, bool blocked}) tileStatus(KioskHomeService service) {
      if (catalog.isHomeServiceEnabled(service)) {
        return (label: null, blocked: false);
      }
      return (label: 'Under maintenance', blocked: true);
    }

    final printStatus = tileStatus(KioskHomeService.printDocuments);
    final localStatus = tileStatus(KioskHomeService.localServices);
    final wellBeingStatus = tileStatus(KioskHomeService.wellBeing);
    final chargingStatus = tileStatus(KioskHomeService.phoneCharging);
    final astrologyStatus = tileStatus(KioskHomeService.astrology);
    final fuelStatus = tileStatus(KioskHomeService.fuelStations);

    // 6 Signature Service Tiles with pastel organic waves
    final tiles = [
      KioskServiceTile(
        icon: Icons.print_rounded,
        title: 'Print Documents',
        subtitle: 'Phone, OTP, or DigiLocker',
        accent: const Color(0xFF0077B6),
        waveColor: const Color(0xFFE0F2FE),
        gradientColors: const [Color(0xFF38BDF8), Color(0xFF0284C7)],
        statusLabel: printStatus.label,
        statusBlocked: printStatus.blocked,
        onTap: () => _openService(
          context,
          KioskHomeService.printDocuments,
          AppRoutes.print,
        ),
      ),
      KioskServiceTile(
        icon: Icons.handyman_rounded,
        title: 'Find Services',
        subtitle: 'Mechanics, tailors, carpenters, and more',
        accent: const Color(0xFF059669),
        waveColor: const Color(0xFFD1FAE5),
        gradientColors: const [Color(0xFF34D399), Color(0xFF059669)],
        statusLabel: localStatus.label,
        statusBlocked: localStatus.blocked,
        onTap: () => _openService(
          context,
          KioskHomeService.localServices,
          AppRoutes.localServices,
        ),
      ),
      KioskServiceTile(
        icon: Icons.favorite_rounded,
        title: 'Well Being',
        subtitle: 'Heart rate, blood oxygen, and temperature',
        accent: const Color(0xFFE11D48),
        waveColor: const Color(0xFFFFE4E6),
        gradientColors: const [Color(0xFFFB7185), Color(0xFFE11D48)],
        statusLabel: wellBeingStatus.label,
        statusBlocked: wellBeingStatus.blocked,
        onTap: () => _openService(
          context,
          KioskHomeService.wellBeing,
          AppRoutes.wellBeing,
        ),
      ),
      KioskServiceTile(
        icon: Icons.battery_charging_full_rounded,
        title: 'Phone Charging',
        subtitle: 'Watch a short message, then charge your phone',
        accent: const Color(0xFFD97706),
        waveColor: const Color(0xFFFEF3C7),
        gradientColors: const [Color(0xFFFBBF24), Color(0xFFD97706)],
        statusLabel: chargingStatus.label,
        statusBlocked: chargingStatus.blocked,
        onTap: () => _openService(
          context,
          KioskHomeService.phoneCharging,
          AppRoutes.charging,
        ),
      ),
      KioskServiceTile(
        icon: Icons.auto_awesome_rounded,
        title: 'Astrology',
        subtitle: 'Kundali · Palm · Match · Today',
        accent: const Color(0xFF7C3AED),
        waveColor: const Color(0xFFEDE9FE),
        gradientColors: const [Color(0xFFA855F7), Color(0xFF7C3AED)],
        statusLabel: astrologyStatus.label,
        statusBlocked: astrologyStatus.blocked,
        onTap: () => _openService(
          context,
          KioskHomeService.astrology,
          AppRoutes.astrology,
        ),
      ),
      KioskServiceTile(
        icon: Icons.local_gas_station_rounded,
        title: 'Fuel Stations',
        subtitle: 'Petrol, diesel, CNG, and EV stations nearby',
        accent: const Color(0xFFEA580C),
        waveColor: const Color(0xFFFFEDD5),
        gradientColors: const [Color(0xFFFB923C), Color(0xFFEA580C)],
        statusLabel: fuelStatus.label,
        statusBlocked: fuelStatus.blocked,
        onTap: () => _openService(
          context,
          KioskHomeService.fuelStations,
          AppRoutes.fuelStations,
        ),
      ),
    ];

    final gap = layout.gridGap;
    const rows = 3;

    final serviceGrid = Column(
      children: [
        for (var row = 0; row < rows; row++) ...[
          if (row > 0) SizedBox(height: gap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[row * 2]),
                SizedBox(width: gap),
                Expanded(child: tiles[row * 2 + 1]),
              ],
            ),
          ),
        ],
      ],
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!layout.compactHero)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: layout.s(12),
              vertical: layout.s(4),
            ),
            margin: EdgeInsets.only(bottom: layout.s(6)),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2E1C48) : const Color(0xFFFDF2F8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF6B21A8) : const Color(0xFFFBCFE8),
                width: 1.1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: layout.s(15),
                  color: const Color(0xFFEC4899),
                ),
                SizedBox(width: layout.s(6)),
                Text(
                  'Athena Smart Kiosk',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: layout.s(13),
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF472B6) : const Color(0xFFBE185D),
                  ),
                ),
              ],
            ),
          ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select a ',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: layout.headlineSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: colors.textPrimary,
                ),
              ),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFE11D48), Color(0xFF9333EA)],
                ).createShader(bounds),
                child: Text(
                  'Service',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: layout.headlineSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: layout.s(6)),
              Text('✨', style: TextStyle(fontSize: layout.s(24))),
            ],
          ),
        ),
        SizedBox(height: layout.s(4)),
        Container(
          width: layout.s(56),
          height: layout.s(4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE11D48), Color(0xFF9333EA)],
            ),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE11D48).withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        if (!layout.compactHero) ...[
          SizedBox(height: layout.s(6)),
          Row(
            children: [
              Icon(
                Icons.touch_app_outlined,
                size: layout.s(16),
                color: colors.textSecondary.withValues(alpha: 0.8),
              ),
              SizedBox(width: layout.s(6)),
              Flexible(
                child: Text(
                  'Touch any card below to start your service',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: layout.subtitleSize,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    final actionChips = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HomeActionChip(
          height: layout.actionHeight,
          horizontalPadding: layout.s(layout.compactHero ? 12 : 16),
          iconSize: layout.s(20),
          fontSize: layout.s(layout.compactHero ? 13 : 15),
          label: 'Emergency',
          icon: Icons.sos_rounded,
          colors: const [Color(0xFFF43F5E), Color(0xFFE11D48)],
          shadowColor: const Color(0xFFE11D48),
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.emergency),
        ),
        SizedBox(width: layout.s(8)),
        _HomeActionChip(
          height: layout.actionHeight,
          horizontalPadding: layout.s(layout.compactHero ? 12 : 16),
          iconSize: layout.s(20),
          fontSize: layout.s(layout.compactHero ? 13 : 15),
          label: 'Support',
          icon: Icons.support_agent_rounded,
          colors: const [Color(0xFF38BDF8), Color(0xFF0284C7)],
          shadowColor: const Color(0xFF0284C7),
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.support),
        ),
        if (layout.showMachine) ...[
          SizedBox(width: layout.s(10)),
          Image.asset(
            'assets/new_theme_icons/machine_image.png',
            height: layout.machineSize,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                KioskTerminalGraphic(size: layout.machineSize),
          ),
        ],
      ],
    );

    final hero = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: titleBlock),
        SizedBox(width: layout.s(layout.compactHero ? 8 : 10)),
        Flexible(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: actionChips,
            ),
          ),
        ),
      ],
    );

    final contentArea = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        hero,
        SizedBox(height: layout.s(layout.compactHero ? 8 : 10)),
        Expanded(child: serviceGrid),
      ],
    );

    final centerColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHorizontal) ...[
          HomeBannerStrip(height: layout.bannerHeight),
          ColoredBox(
            color: colors.cardBorder,
            child: const SizedBox(height: SkpTokens.hairline),
          ),
        ],
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              showVertical ? layout.contentPadTight : layout.contentPadWide,
              showHorizontal ? layout.s(8) : layout.s(6),
              showVertical ? layout.contentPadTight : layout.contentPadWide,
              0,
            ),
            child: contentArea,
          ),
        ),
        if (showHorizontal) ...[
          ColoredBox(
            color: colors.cardBorder,
            child: const SizedBox(height: SkpTokens.hairline),
          ),
          HomeBannerStrip(height: layout.bannerHeight),
        ],
      ],
    );

    final mainBody = showVertical
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HomeBannerStrip(
                axis: HomeBannerAxis.vertical,
                width: layout.bannerSideWidth,
              ),
              ColoredBox(
                color: colors.cardBorder,
                child: const SizedBox(width: SkpTokens.hairline),
              ),
              Expanded(child: centerColumn),
              ColoredBox(
                color: colors.cardBorder,
                child: const SizedBox(width: SkpTokens.hairline),
              ),
              HomeBannerStrip(
                axis: HomeBannerAxis.vertical,
                width: layout.bannerSideWidth,
              ),
            ],
          )
        : centerColumn;

    return KioskScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: layout.headerHeight,
            padding: EdgeInsets.symmetric(horizontal: layout.s(20)),
            child: Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/new_theme_icons/athena_new_logo.png',
                      height: layout.logoSize,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        width: layout.logoSize - 6,
                        height: layout.logoSize - 6,
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
                              fontSize: layout.s(18),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Flexible(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          WeatherHeaderStrip(
                            locationLabel: (widget.auth.deviceName != null &&
                                    widget.auth.deviceName!.isNotEmpty)
                                ? widget.auth.deviceName!
                                : 'Kiosk 6',
                          ),
                          SizedBox(width: layout.s(10)),
                          const KioskClock(showDate: true),
                        ],
                      ),
                    ),
                  ),
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

/// Responsive home metrics for the 1448×1086 (4:3) kiosk and laptop 16:9 windows.
class _HomeLayout {
  const _HomeLayout._({
    required this.scale,
    required this.compactHero,
    required this.showMachine,
    required this.headerHeight,
    required this.logoSize,
    required this.headlineSize,
    required this.subtitleSize,
    required this.actionHeight,
    required this.machineSize,
    required this.bannerHeight,
    required this.bannerSideWidth,
    required this.gridGap,
    required this.contentPadTight,
    required this.contentPadWide,
  });

  factory _HomeLayout.of(Size size) {
    final width = size.width;
    final height = size.height;
    final aspect = width / (height <= 0 ? 1 : height);

    final widthScale = width / SkpTokens.displayWidth;
    final heightScale = height / SkpTokens.displayHeight;
    // Laptops (16:9) are usually height-limited; kiosk 4:3 is width-limited.
    final scale = (widthScale < heightScale ? widthScale : heightScale)
        .clamp(0.55, 1.15);

    final compact = width < 1180 || height < 820;
    final narrow = width < 980;
    final short = height < 720;
    final wideLaptop = aspect > 1.5;

    double s(double value) => value * scale;

    final sideMax = compact ? 56.0 : (wideLaptop ? 64.0 : 80.0);
    final sideMin = short || narrow ? 40.0 : 48.0;
    final bannerSide = (width * (wideLaptop ? 0.04 : 0.05)).clamp(sideMin, sideMax);

    final bannerH = (height * (short ? 0.05 : 0.066))
        .clamp(short ? 36.0 : 48.0, compact ? 60.0 : 80.0);

    return _HomeLayout._(
      scale: scale,
      compactHero: compact || wideLaptop,
      showMachine: !narrow,
      headerHeight: s(compact ? 58 : 68),
      logoSize: s(compact ? 34 : 40),
      headlineSize: s(compact ? 28 : 34),
      subtitleSize: s(compact ? 14 : 16),
      actionHeight: s(compact ? 42 : 48),
      machineSize: s(compact ? 72 : 96),
      bannerHeight: bannerH,
      bannerSideWidth: bannerSide,
      gridGap: s(compact ? 10 : 12),
      contentPadTight: s(compact ? 12 : 16),
      contentPadWide: s(compact ? 16 : 24),
    );
  }

  final double scale;
  final bool compactHero;
  final bool showMachine;
  final double headerHeight;
  final double logoSize;
  final double headlineSize;
  final double subtitleSize;
  final double actionHeight;
  final double machineSize;
  final double bannerHeight;
  final double bannerSideWidth;
  final double gridGap;
  final double contentPadTight;
  final double contentPadWide;

  double s(double value) => value * scale;
}

class _HomeActionChip extends StatelessWidget {
  const _HomeActionChip({
    required this.height,
    required this.horizontalPadding,
    required this.iconSize,
    required this.fontSize,
    required this.label,
    required this.icon,
    required this.colors,
    required this.shadowColor,
    required this.onTap,
  });

  final double height;
  final double horizontalPadding;
  final double iconSize;
  final double fontSize;
  final String label;
  final IconData icon;
  final List<Color> colors;
  final Color shadowColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.32),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: iconSize, color: Colors.white),
                SizedBox(width: fontSize * 0.45),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
        child: KioskStatusBanner(
          message: error ?? 'Reconnecting to kiosk cloud…',
          tone: KioskBannerTone.info,
          icon: Icons.sync,
        ),
      ),
    );
  }
}
