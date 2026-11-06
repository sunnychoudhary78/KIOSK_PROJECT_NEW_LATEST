import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/local_services/application/local_services_controller.dart';
import 'package:skp_kiosk/features/local_services/domain/local_service.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';

class LocalServicesPage extends ConsumerStatefulWidget {
  const LocalServicesPage({super.key});

  @override
  ConsumerState<LocalServicesPage> createState() => _LocalServicesPageState();
}

class _LocalServicesPageState extends ConsumerState<LocalServicesPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(localServicesControllerProvider.notifier).load();
    });
  }

  Future<void> _endSession() {
    return ref
        .read(kioskSessionControllerProvider.notifier)
        .endVisitorSession(attract: false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localServicesControllerProvider);
    final colors = context.athenaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveCategories = _resolveCategories(state.categories);

    return VisitorSessionPopScope(
      child: KioskShell(
        title: 'Find a Service',
        titleIcon: Icons.handyman_outlined,
        onHome: _endSession,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                                text: 'Choose a ',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: colors.textPrimary,
                                ),
                              ),
                              TextSpan(
                                text: 'Service',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: colors.accentMagenta,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 48,
                          height: 3.5,
                          decoration: BoxDecoration(
                            color: colors.accentMagenta,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Select a service to find nearby professionals.',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).maybePop(),
                      borderRadius: BorderRadius.circular(26),
                      child: Ink(
                        height: 44,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C143F) : Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF7445BD)
                                : const Color(0xFFD0D5DD),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? const Color(0x2E8B35FF)
                                  : Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_back_rounded,
                              size: 18,
                              color: colors.textPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Back',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Expanded(
                child: _TradeGrid(
                  categories: effectiveCategories,
                  isLoading: state.loading && state.categories.isEmpty,
                  error: state.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<LocalServiceCategory> _resolveCategories(
      List<LocalServiceCategory> apiList) {
    return apiList;
  }
}

class _TradeGrid extends StatelessWidget {
  const _TradeGrid({
    required this.categories,
    required this.isLoading,
    this.error,
  });

  final List<LocalServiceCategory> categories;
  final bool isLoading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const KioskLoading(message: 'Loading services…');
    }

    if (error != null && categories.isEmpty) {
      return Center(
        child: KioskStatusBanner(
          message: error!,
          tone: KioskBannerTone.danger,
          icon: Icons.error_outline,
        ),
      );
    }

    if (categories.isEmpty) {
      return const Center(child: Text('No services available.'));
    }

    const columns = 4;
    const gap = 12.0;
    final rowCount = (categories.length / columns).ceil();

    Widget rowAt(int row) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var col = 0; col < columns; col++) ...[
            if (col > 0) const SizedBox(width: gap),
            Expanded(
              child: Builder(
                builder: (ctx) {
                  final idx = row * columns + col;
                  if (idx >= categories.length) {
                    return const SizedBox.expand();
                  }
                  final cat = categories[idx];
                  return _TradeCard(
                    category: cat,
                    count: cat.contacts.length,
                    onTap: () => Navigator.of(ctx).pushNamed(
                      AppRoutes.localServiceContacts,
                      arguments: cat,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      children: [
        for (var row = 0; row < rowCount; row++) ...[
          if (row > 0) const SizedBox(height: gap),
          Expanded(child: rowAt(row)),
        ],
      ],
    );
  }
}

class _TradeCard extends StatelessWidget {
  const _TradeCard({
    required this.category,
    required this.count,
    required this.onTap,
  });

  final LocalServiceCategory category;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meta = _metaFor(category.slug);

    // Clean card styling: white in light mode, dark purple in dark mode.
    // Thin uniform border (NO rainbow border!).
    final cardDecoration = BoxDecoration(
      color: isDark ? const Color(0xFF1C143F) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark ? const Color(0xFF7445BD) : const Color(0xFFE2EBF5),
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark ? const Color(0x2E8B35FF) : const Color(0x0A1B2B4F),
          blurRadius: isDark ? 16 : 10,
          offset: const Offset(0, 2),
        ),
      ],
    );

    final arrowBorderColor =
        isDark ? const Color(0xFF7445BD) : const Color(0xFFD6C8F0);
    final arrowBg = isDark ? const Color(0xFF1C143F) : Colors.white;
    final arrowIconColor = isDark ? Colors.white : const Color(0xFF7445BD);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: (isDark ? const Color(0xFF7445BD) : meta.accent)
            .withValues(alpha: 0.12),
        child: Ink(
          decoration: cardDecoration,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // 3D icon image (52x52 container)
                SizedBox(
                  width: 52,
                  height: 52,
                  child: _TradeIcon(meta: meta),
                ),
                const SizedBox(width: 12),

                // Title & contact count
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                          height: 1.2,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        count == 1 ? '1 number' : '$count numbers',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Accent-colored circular arrow button (Images 2 & 3)
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: arrowBg,
                    border: Border.all(
                      color: arrowBorderColor,
                      width: 1.4,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: arrowIconColor,
                    ),
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

/// Renders either asset 3D PNG or fallback Material icon.
class _TradeIcon extends StatelessWidget {
  const _TradeIcon({required this.meta});

  final _TradeMetaInfo meta;

  @override
  Widget build(BuildContext context) {
    if (meta.assetPath != null) {
      return Image.asset(
        meta.assetPath!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            meta.icon ?? Icons.handyman_rounded,
            size: 28,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF7445BD),
          );
        },
      );
    }
    return Icon(
      meta.icon ?? Icons.handyman_rounded,
      size: 28,
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : const Color(0xFF7445BD),
    );
  }
}

class _TradeMetaInfo {
  const _TradeMetaInfo({
    this.icon,
    this.assetPath,
    required this.accent,
  }) : assert(
          icon != null || assetPath != null,
          'Either icon or assetPath must be provided',
        );

  final IconData? icon;
  final String? assetPath;
  final Color accent;
}

_TradeMetaInfo _metaFor(String slug) {
  switch (slug) {
    case 'appliance-repair':
      return const _TradeMetaInfo(
        assetPath: 'assets/new_theme_icons/appliance_repair.png',
        accent: Color(0xFF0288D1),
      );
    case 'scrap-dealer':
      return const _TradeMetaInfo(
        assetPath: 'assets/new_theme_icons/scrap_dealer.png',
        accent: Color(0xFF2E7D32),
      );
    case 'two-wheeler-mechanic':
      return const _TradeMetaInfo(
        assetPath: 'assets/new_theme_icons/two_wheeler_mechanic.png',
        accent: Color(0xFF6A1B9A),
      );
    case 'tailor':
      return const _TradeMetaInfo(
        assetPath: 'assets/new_theme_icons/tailor.png',
        accent: Color(0xFFC2185B),
      );
    case 'carpenter':
      return const _TradeMetaInfo(
        assetPath: 'assets/new_theme_icons/carpenter.png',
        accent: Color(0xFFE65100),
      );
    case 'gas-stove-repair':
      return const _TradeMetaInfo(
        assetPath: 'assets/new_theme_icons/06_gas_stove_repair.png',
        accent: Color(0xFF00838F),
      );
    case 'electrician':
      return const _TradeMetaInfo(
        assetPath: 'assets/new_theme_icons/electrician.png',
        accent: Color(0xFFF57F17),
      );
    case 'pigeon-net':
      return const _TradeMetaInfo(
        assetPath: 'assets/new_theme_icons/pigeon_net.png',
        accent: Color(0xFF283593),
      );
    case 'puncture':
      return const _TradeMetaInfo(
        assetPath: 'assets/new_theme_icons/09_puncture.png',
        accent: Color(0xFF37474F),
      );
    case 'painter':
      return const _TradeMetaInfo(
        assetPath: 'assets/new_theme_icons/10_painter.png',
        accent: Color(0xFFAD1457),
      );
    case 'mason':
      return const _TradeMetaInfo(
        assetPath: 'assets/new_theme_icons/11_mason.png',
        accent: Color(0xFFD84315),
      );
    case 'interior':
      return const _TradeMetaInfo(
        assetPath: 'assets/new_theme_icons/12_interior.png',
        accent: Color(0xFF00695C),
      );
    case 'car-mechanic':
      return const _TradeMetaInfo(
        assetPath: 'assets/new_theme_icons/13_car_mechanic.png',
        accent: Color(0xFF1565C0),
      );
    case 'key-maker':
      return const _TradeMetaInfo(
        assetPath: 'assets/new_theme_icons/14_key_maker.png',
        accent: Color(0xFFFBC02D),
      );
    case 'fabricator':
      return const _TradeMetaInfo(
        assetPath: 'assets/new_theme_icons/15_fabricator.png',
        accent: Color(0xFF1A237E),
      );
    case 'plumber':
      return const _TradeMetaInfo(
        assetPath: 'assets/new_theme_icons/16_plumber.png',
        accent: Color(0xFF0091EA),
      );
    default:
      return const _TradeMetaInfo(
        assetPath: 'assets/new_theme_icons/handyman.png',
        icon: Icons.handyman_rounded,
        accent: Color(0xFF4527A0),
      );
  }
}
