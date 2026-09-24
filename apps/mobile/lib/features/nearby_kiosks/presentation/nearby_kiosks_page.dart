import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/nearby_kiosks/application/nearby_kiosks_controller.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class NearbyKiosksPage extends ConsumerStatefulWidget {
  const NearbyKiosksPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<NearbyKiosksPage> createState() => _NearbyKiosksPageState();
}

class _NearbyKiosksPageState extends ConsumerState<NearbyKiosksPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(nearbyKiosksProvider.notifier).load();
    });
  }

  Future<void> _openDirections(NearbyKiosk kiosk) async {
    final l10n = AppLocalizations.of(context);
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${kiosk.latitude},${kiosk.longitude}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.couldNotOpenMaps)),
      );
    }
  }

  void _openMap(List<NearbyKiosk> items) {
    Navigator.of(context).pushNamed(
      AppRoutes.nearbyKiosksMap,
      arguments: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nearbyKiosksProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SkpScaffold(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkpPageHeader(
            title: l10n.nearestKiosks,
            subtitle: l10n.nearestHelper,
            showBack: !widget.embedded,
            trailing: !state.loading &&
                    state.error == null &&
                    state.items.isNotEmpty
                ? IconButton(
                    tooltip: l10n.viewOnMap,
                    onPressed: () => _openMap(state.items),
                    icon: const Icon(Icons.map_outlined),
                  )
                : null,
          ),
          const SizedBox(height: 20),
          if (state.loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.error != null)
            Expanded(
              child: SkpEmptyState(
                icon: Icons.location_off_outlined,
                title: state.permissionDenied
                    ? l10n.locationRequired
                    : state.error!,
                message: l10n.nearestHelper,
                actionLabel: state.permissionDenied ? l10n.tryAgain : l10n.retry,
                onAction: () => ref.read(nearbyKiosksProvider.notifier).load(),
              ),
            )
          else if (state.items.isEmpty)
            Expanded(
              child: SkpEmptyState(
                icon: Icons.store_mall_directory_outlined,
                title: l10n.noKiosks,
                message: l10n.noKiosksHelper,
                actionLabel: l10n.refresh,
                secondary: true,
                onAction: () => ref.read(nearbyKiosksProvider.notifier).load(),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(nearbyKiosksProvider.notifier).load(),
                child: ListView.separated(
                  itemCount: state.items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final kiosk = state.items[index];
                    return SkpPanelCard(
                      onTap: () => _openDirections(kiosk),
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          const SkpIconWell(
                            icon: Icons.near_me_rounded,
                            size: 48,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  kiosk.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  kiosk.subtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: SkpColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                kiosk.distanceLabel,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: SkpColors.accent,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SkpStatusChip(label: l10n.statusReady),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
