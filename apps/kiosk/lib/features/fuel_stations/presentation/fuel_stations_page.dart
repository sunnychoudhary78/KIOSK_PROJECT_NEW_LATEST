import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/fuel_stations/application/fuel_stations_controller.dart';
import 'package:skp_kiosk/features/fuel_stations/domain/fuel_station.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';

class FuelStationsPage extends ConsumerStatefulWidget {
  const FuelStationsPage({super.key});

  @override
  ConsumerState<FuelStationsPage> createState() => _FuelStationsPageState();
}

class _FuelStationsPageState extends ConsumerState<FuelStationsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(fuelStationsControllerProvider.notifier).load();
    });
  }

  Future<void> _endSession() {
    return ref.read(kioskSessionControllerProvider.notifier).endVisitorSession(attract: false);
  }

  Future<void> _showDirections(FuelStation station) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: SkpColors.panel,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    station.name ?? 'Fuel station',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (station.address != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      station.address!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: SkpColors.muted),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    width: 280,
                    height: 280,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
                    ),
                    child: QrImageView(
                      data: station.directionsUrl,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Scan to open this station in Google Maps, then tap Directions',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: SkpColors.muted),
                  ),
                  const SizedBox(height: 20),
                  KioskPrimaryButton(
                    label: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fuelStationsControllerProvider);
    return VisitorSessionPopScope(
      child: KioskShell(
        title: 'Fuel stations',
        onHome: _endSession,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Stations within about 5 km. Touch one for directions.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: SkpColors.muted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final kind in FuelKind.values)
                    _KindChip(
                      label: kind.label,
                      selected: state.kind == kind,
                      onTap: state.kind == kind
                          ? null
                          : () => ref.read(fuelStationsControllerProvider.notifier).load(kind: kind),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(child: _StationBody(state: state, onOpen: _showDirections)),
              const SizedBox(height: 8),
              Text(
                'Road status is traffic outside the station, not queue length inside.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: SkpColors.muted),
              ),
              const SizedBox(height: 4),
              Text(
                'Map data © OpenStreetMap contributors',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: SkpColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StationBody extends StatelessWidget {
  const _StationBody({required this.state, required this.onOpen});

  final FuelStationsState state;
  final ValueChanged<FuelStation> onOpen;

  @override
  Widget build(BuildContext context) {
    if (state.loading && state.items.isEmpty) {
      return const KioskLoading(message: 'Finding nearby stations…');
    }
    if (state.error != null) {
      return KioskStatusBanner(
        message: state.error!,
        tone: KioskBannerTone.danger,
        icon: Icons.error_outline,
      );
    }
    if (state.items.isEmpty) {
      return const KioskEmpty(
        icon: Icons.local_gas_station_outlined,
        message: 'No stations nearby',
      );
    }
    return ListView.separated(
      itemCount: state.items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final station = state.items[index];
        return _StationTile(station: station, onTap: () => onOpen(station));
      },
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SkpColors.accent : SkpColors.panel,
      borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64, minWidth: 120),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
            border: Border.all(color: selected ? SkpColors.accentBright : SkpColors.line),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? Colors.white : SkpColors.text,
                ),
          ),
        ),
      ),
    );
  }
}

class _StationTile extends StatelessWidget {
  const _StationTile({required this.station, required this.onTap});

  final FuelStation station;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final distance = station.distanceKm < 10
        ? '${station.distanceKm.toStringAsFixed(2)} km'
        : '${station.distanceKm.toStringAsFixed(1)} km';
    return Material(
      color: SkpColors.panel,
      borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
            border: Border.all(color: SkpColors.line),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_gas_station_outlined, color: SkpColors.gold, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name ?? 'Fuel station',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (station.address != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        station.address!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: SkpColors.muted),
                      ),
                    ],
                    if (station.badges.isNotEmpty || station.approachTraffic?.badgeLabel != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final badge in station.badges)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: SkpColors.raised,
                                borderRadius: BorderRadius.circular(SkpTokens.radiusSm),
                              ),
                              child: Text(badge, style: Theme.of(context).textTheme.bodyMedium),
                            ),
                          if (station.approachTraffic?.badgeLabel case final roadLabel?)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: switch (station.approachTraffic!) {
                                  ApproachTraffic.heavy => SkpColors.danger.withValues(alpha: 0.25),
                                  ApproachTraffic.moderate => SkpColors.gold.withValues(alpha: 0.2),
                                  ApproachTraffic.clear => SkpColors.raised,
                                  ApproachTraffic.unknown => SkpColors.raised,
                                },
                                borderRadius: BorderRadius.circular(SkpTokens.radiusSm),
                                border: Border.all(
                                  color: switch (station.approachTraffic!) {
                                    ApproachTraffic.heavy => SkpColors.danger,
                                    ApproachTraffic.moderate => SkpColors.gold,
                                    ApproachTraffic.clear => SkpColors.line,
                                    ApproachTraffic.unknown => SkpColors.line,
                                  },
                                ),
                              ),
                              child: Text(
                                roadLabel,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: switch (station.approachTraffic!) {
                                        ApproachTraffic.heavy => SkpColors.danger,
                                        ApproachTraffic.moderate => SkpColors.gold,
                                        ApproachTraffic.clear => SkpColors.muted,
                                        ApproachTraffic.unknown => SkpColors.muted,
                                      },
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(distance, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Map',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: SkpColors.accentBright),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
