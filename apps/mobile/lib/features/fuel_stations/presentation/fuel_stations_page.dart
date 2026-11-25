import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/fuel_stations/application/fuel_stations_controller.dart';
import 'package:skp_mobile/features/fuel_stations/domain/fuel_station.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class FuelStationsPage extends ConsumerStatefulWidget {
  const FuelStationsPage({super.key});

  @override
  ConsumerState<FuelStationsPage> createState() => _FuelStationsPageState();
}

class _FuelStationsPageState extends ConsumerState<FuelStationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fuelStationsProvider.notifier).load();
    });
  }

  Future<void> _openDirections(FuelStation station) async {
    final l10n = AppLocalizations.of(context);
    final uri = _directionsUri(station);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.couldNotOpenMaps)),
      );
    }
  }

  Uri _directionsUri(FuelStation station) {
    final destination = '${station.latitude},${station.longitude}';
    final placeId = station.googlePlaceId;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return Uri.https('maps.apple.com', '/', {'daddr': destination});
    }
    if (placeId != null && placeId.isNotEmpty) {
      return Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': destination,
        'query_place_id': placeId,
      });
    }
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
    });
  }

  String _kindLabel(AppLocalizations l10n, FuelKind kind) {
    return switch (kind) {
      FuelKind.all => l10n.fuelKindAll,
      FuelKind.fuel => l10n.fuelKindPetrolDiesel,
      FuelKind.cng => l10n.fuelKindCng,
      FuelKind.ev => l10n.fuelKindEv,
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fuelStationsProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SkpScaffold(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkpPageHeader(
            title: l10n.fuelStationsTitle,
            subtitle: l10n.fuelStationsHelper,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final kind in FuelKind.values) ...[
                  if (kind != FuelKind.all) const SizedBox(width: 8),
                  FilterChip(
                    selected: state.kind == kind,
                    label: Text(_kindLabel(l10n, kind)),
                    onSelected: state.loading
                        ? null
                        : (_) => ref
                            .read(fuelStationsProvider.notifier)
                            .selectKind(kind),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (state.loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.error != null ||
              state.permissionDenied ||
              state.locationServicesDisabled)
            Expanded(
              child: SkpEmptyState(
                icon: Icons.location_off_outlined,
                title: state.locationServicesDisabled
                    ? l10n.locationServicesOff
                    : state.permissionDenied
                        ? l10n.locationRequired
                        : state.error!,
                message: l10n.fuelStationsHelper,
                actionLabel: state.needsSystemSettings
                    ? l10n.openSettings
                    : state.permissionDenied
                        ? l10n.tryAgain
                        : l10n.retry,
                onAction: () {
                  if (state.needsSystemSettings) {
                    ref
                        .read(fuelStationsProvider.notifier)
                        .openLocationRecovery();
                  } else {
                    ref.read(fuelStationsProvider.notifier).load();
                  }
                },
              ),
            )
          else if (state.items.isEmpty)
            Expanded(
              child: SkpEmptyState(
                icon: Icons.local_gas_station_outlined,
                title: l10n.fuelStationsEmpty,
                message: l10n.fuelStationsEmptyHelper,
                actionLabel: l10n.refresh,
                secondary: true,
                onAction: () => ref.read(fuelStationsProvider.notifier).load(),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(fuelStationsProvider.notifier).load(),
                child: ListView.separated(
                  itemCount: state.items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final station = state.items[index];
                    return SkpPanelCard(
                      onTap: () => _openDirections(station),
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SkpIconWell(
                            icon: Icons.local_gas_station_rounded,
                            size: 48,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  station.displayName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  station.displayAddress,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: SkpColors.muted,
                                  ),
                                ),
                                if (station.badges.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      for (final badge in station.badges)
                                        SkpStatusChip(
                                          label: badge,
                                          color: SkpColors.accent,
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                station.distanceLabel,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: SkpColors.accent,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.directions,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: SkpColors.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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
