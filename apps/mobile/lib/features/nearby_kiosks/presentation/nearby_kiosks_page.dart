import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/nearby_kiosks/application/nearby_kiosks_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class NearbyKiosksPage extends ConsumerStatefulWidget {
  const NearbyKiosksPage({super.key});

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
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${kiosk.latitude},${kiosk.longitude}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Maps')),
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

    return SkpScaffold(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: IconButton.styleFrom(
                backgroundColor: SkpColors.panel,
                side: const BorderSide(color: SkpColors.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Nearest kiosks',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sorted by distance from your current location.',
            style: theme.textTheme.bodyMedium?.copyWith(color: SkpColors.muted),
          ),
          if (!state.loading &&
              state.error == null &&
              state.items.isNotEmpty) ...[
            const SizedBox(height: 16),
            SkpSecondaryButton(
              label: 'View on map',
              onPressed: () => _openMap(state.items),
            ),
          ],
          const SizedBox(height: 20),
          if (state.loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SkpPrimaryButton(
                      label: state.permissionDenied ? 'Try again' : 'Retry',
                      onPressed: () =>
                          ref.read(nearbyKiosksProvider.notifier).load(),
                    ),
                  ],
                ),
              ),
            )
          else if (state.items.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No active kiosks with a location yet.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Register devices with latitude and longitude in admin, then activate them.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: SkpColors.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SkpSecondaryButton(
                      label: 'Refresh',
                      onPressed: () =>
                          ref.read(nearbyKiosksProvider.notifier).load(),
                    ),
                  ],
                ),
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
                    return Material(
                      color: SkpColors.panel,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: SkpColors.line),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _openDirections(kiosk),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color:
                                      SkpColors.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.near_me_rounded,
                                  color: SkpColors.accent,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      kiosk.name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      kiosk.subtitle,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
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
                                    style:
                                        theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: SkpColors.accent,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Directions',
                                    style:
                                        theme.textTheme.bodySmall?.copyWith(
                                      color: SkpColors.muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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
