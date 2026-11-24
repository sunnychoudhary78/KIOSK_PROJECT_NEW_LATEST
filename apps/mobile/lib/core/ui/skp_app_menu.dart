import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
import 'package:skp_mobile/core/format.dart';
import 'package:skp_mobile/core/navigation/nav_tab.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';

/// Opens a left side drawer menu (replaces bottom navbar destinations).
Future<void> showSkpAppMenu(BuildContext context, WidgetRef ref) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: MediaQuery.sizeOf(dialogContext).width * 0.82,
            height: MediaQuery.sizeOf(dialogContext).height,
            child: _SkpAppDrawer(
              onClose: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

class SkpAppMenuButton extends ConsumerWidget {
  const SkpAppMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Menu',
      onPressed: () => showSkpAppMenu(context, ref),
      style: IconButton.styleFrom(
        backgroundColor: SkpColors.panel,
        foregroundColor: SkpColors.accent,
        side: const BorderSide(color: SkpColors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      icon: const Icon(Icons.menu_rounded),
    );
  }
}

class _SkpAppDrawer extends ConsumerWidget {
  const _SkpAppDrawer({required this.onClose});

  final VoidCallback onClose;

  void _goTab(WidgetRef ref, int tab) {
    onClose();
    ref.read(navTabProvider.notifier).select(tab);
  }

  void _goRoute(BuildContext context, String route) {
    onClose();
    Navigator.of(context).pushNamed(route);
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    onClose();
    await ref.read(citizenAuthProvider.notifier).logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final auth = ref.watch(citizenAuthProvider);
    final phone = maskPhone(auth.phone);
    final phoneChip = phone.isEmpty ? l10n.citizenAccount : phone;

    return SafeArea(
      right: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 8, 0, 8),
        decoration: BoxDecoration(
          color: SkpColors.atmosphere,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(4, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: _ProfileHeaderCard(
                title: l10n.citizenAccount,
                subtitle: l10n.brandName,
                phoneChip: phoneChip,
                viewProfileLabel: l10n.tabProfile,
                onViewProfile: () => _goTab(ref, NavTabs.profile),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                children: [
                  _MenuGroupCard(
                    children: [
                      _DrawerMenuTile(
                        icon: Icons.home_outlined,
                        label: l10n.tabHome,
                        onTap: () => _goTab(ref, NavTabs.home),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MenuGroupCard(
                    children: [
                      _DrawerMenuTile(
                        icon: Icons.receipt_long_outlined,
                        label: l10n.tabHistory,
                        onTap: () => _goTab(ref, NavTabs.history),
                      ),
                      _DrawerMenuTile(
                        icon: Icons.location_on_outlined,
                        label: l10n.tabNearby,
                        onTap: () => _goTab(ref, NavTabs.nearby),
                      ),
                      _DrawerMenuTile(
                        icon: Icons.print_outlined,
                        label: l10n.uploadTileTitle,
                        onTap: () => _goRoute(context, AppRoutes.otpPrint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MenuGroupCard(
                    children: [
                      _DrawerMenuTile(
                        icon: Icons.handyman_outlined,
                        label: l10n.findServicesTileTitle,
                        onTap: () => _goRoute(context, AppRoutes.findServices),
                      ),
                      _DrawerMenuTile(
                        icon: Icons.local_gas_station_outlined,
                        label: l10n.fuelStationsTileTitle,
                        onTap: () => _goRoute(context, AppRoutes.fuelStations),
                      ),
                      _DrawerMenuTile(
                        icon: Icons.auto_awesome_outlined,
                        label: l10n.astrologyPanditTileTitle,
                        onTap: () =>
                            _goRoute(context, AppRoutes.astrologyPandit),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Material(
                color: SkpColors.panel,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _logout(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: SkpColors.danger.withValues(alpha: 0.55),
                        width: 1.4,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          color: SkpColors.danger,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          l10n.signOut,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: SkpColors.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.title,
    required this.subtitle,
    required this.phoneChip,
    required this.viewProfileLabel,
    required this.onViewProfile,
  });

  final String title;
  final String subtitle;
  final String phoneChip;
  final String viewProfileLabel;
  final VoidCallback onViewProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F6A5A),
            Color(0xFF1A8F78),
            Color(0xFF2EC4A0),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: SkpColors.accent.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: Color(0xFF7DD3FC),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.phone_iphone_rounded,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              phoneChip,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onViewProfile,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      viewProfileLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuGroupCard extends StatelessWidget {
  const _MenuGroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SkpColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SkpColors.line.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 54,
                color: SkpColors.line.withValues(alpha: 0.7),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _DrawerMenuTile extends StatelessWidget {
  const _DrawerMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: SkpColors.muted),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: SkpColors.ink,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: SkpColors.muted.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}
