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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
                      color: SkpColors.qrSurface,
                      borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
                      border: Border.all(color: SkpColors.line),
                    ),
                    child: QrImageView(
                      data: station.directionsUrl,
                      backgroundColor: SkpColors.qrSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Scan with your phone to open Google Maps, then tap Directions',
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
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nearby stations · ~5 km · tap for directions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              _KindFilterBar(
                selected: state.kind,
                onSelected: (kind) =>
                    ref.read(fuelStationsControllerProvider.notifier).load(kind: kind),
              ),
              const SizedBox(height: 10),
              Expanded(child: _StationBody(state: state, onOpen: _showDirections)),
              const SizedBox(height: 6),
              Text(
                'Bar = traffic on the drive; wait chip = congestion near the station. © OpenStreetMap',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SkpColors.muted),
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

    return Stack(
      children: [
        ListView.separated(
          itemCount: state.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final station = state.items[index];
            return _StationTile(station: station, onTap: () => onOpen(station));
          },
        ),
        if (state.loading)
          Positioned.fill(
            child: ColoredBox(
              color: SkpColors.canvas.withValues(alpha: 0.55),
              child: const Center(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(strokeWidth: 3.5),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _KindFilterBar extends StatelessWidget {
  const _KindFilterBar({
    required this.selected,
    required this.onSelected,
  });

  final FuelKind selected;
  final ValueChanged<FuelKind> onSelected;

  static const double _height = 56;

  @override
  Widget build(BuildContext context) {
    final kinds = FuelKind.values;
    return SizedBox(
      height: _height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SkpColors.panel,
          borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
          border: Border.all(color: SkpColors.line),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(SkpTokens.radiusMd - 0.5),
          child: Row(
            children: [
              for (var i = 0; i < kinds.length; i++) ...[
                if (i > 0)
                  Container(width: SkpTokens.hairline, color: SkpColors.line),
                Expanded(
                  child: _KindSegment(
                    label: kinds[i].label,
                    selected: selected == kinds[i],
                    onTap: selected == kinds[i] ? null : () => onSelected(kinds[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _KindSegment extends StatelessWidget {
  const _KindSegment({
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
      color: selected ? SkpColors.accent : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? Colors.white : SkpColors.text,
                  fontWeight: FontWeight.w700,
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

  IconData get _leadingIcon {
    if (station.ev && !station.petrol && !station.diesel && !station.cng) {
      return Icons.ev_station_outlined;
    }
    if (station.cng && !station.petrol && !station.diesel && !station.ev) {
      return Icons.propane_tank_outlined;
    }
    return Icons.local_gas_station_outlined;
  }

  Color get _iconColor {
    if (station.ev && !station.petrol && !station.diesel && !station.cng) {
      return SkpColors.accentBright;
    }
    if (station.cng && !station.petrol && !station.diesel && !station.ev) {
      return SkpColors.gold;
    }
    return SkpColors.accent;
  }

  String _formatKm(double km) {
    return km < 10 ? '${km.toStringAsFixed(2)} km' : '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final driveKm = station.driveDistanceKm;
    final distanceLabel = driveKm != null ? _formatKm(driveKm) : _formatKm(station.distanceKm);
    final durationMin = station.driveDurationMin;

    return Material(
      color: SkpColors.panel,
      borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
            border: Border.all(color: SkpColors.line),
            boxShadow: [
              BoxShadow(
                color: SkpColors.text.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_leadingIcon, color: _iconColor, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name ?? 'Fuel station',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (station.address != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        station.address!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(color: SkpColors.muted),
                      ),
                    ],
                    if (station.routeTrafficSegments.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _RouteTrafficBar(segments: station.routeTrafficSegments),
                    ],
                    if (station.badges.isNotEmpty || station.approachTraffic?.badgeLabel != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final badge in station.badges)
                            _FuelBadge(label: badge),
                          if (station.approachTraffic?.badgeLabel case final roadLabel?)
                            _TrafficBadge(
                              label: roadLabel,
                              traffic: station.approachTraffic!,
                              waitMin: station.approachWaitMin,
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
                  Text(
                    distanceLabel,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (durationMin != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '~$durationMin min',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: SkpColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: SkpColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(SkpTokens.radiusSm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_outlined, size: 18, color: SkpColors.accent),
                        const SizedBox(width: 6),
                        Text(
                          'Directions',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: SkpColors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
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

class _RouteTrafficBar extends StatelessWidget {
  const _RouteTrafficBar({required this.segments});

  final List<RouteTrafficSegment> segments;

  Color _colorFor(RouteTrafficSpeed speed) {
    return switch (speed) {
      RouteTrafficSpeed.normal => SkpColors.accentBright,
      RouteTrafficSpeed.slow => SkpColors.gold,
      RouteTrafficSpeed.trafficJam => SkpColors.danger,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            for (final segment in segments)
              Expanded(
                flex: (segment.fraction * 1000).round().clamp(1, 100000),
                child: ColoredBox(color: _colorFor(segment.speed)),
              ),
          ],
        ),
      ),
    );
  }
}

class _FuelBadge extends StatelessWidget {
  const _FuelBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: SkpColors.raised,
        borderRadius: BorderRadius.circular(SkpTokens.radiusSm),
        border: Border.all(color: SkpColors.line),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: SkpColors.text,
            ),
      ),
    );
  }
}

class _TrafficBadge extends StatelessWidget {
  const _TrafficBadge({
    required this.label,
    required this.traffic,
    required this.waitMin,
  });

  final String label;
  final ApproachTraffic traffic;
  final int? waitMin;

  @override
  Widget build(BuildContext context) {
    final (Color fill, Color border, Color text) = switch (traffic) {
      ApproachTraffic.heavy => (
          SkpColors.danger.withValues(alpha: 0.1),
          SkpColors.danger.withValues(alpha: 0.45),
          SkpColors.danger,
        ),
      ApproachTraffic.moderate => (
          SkpColors.gold.withValues(alpha: 0.22),
          SkpColors.gold,
          SkpColors.text,
        ),
      ApproachTraffic.clear => (
          SkpColors.accentBright.withValues(alpha: 0.12),
          SkpColors.accentBright.withValues(alpha: 0.45),
          SkpColors.accent,
        ),
      ApproachTraffic.unknown => (
          SkpColors.raised,
          SkpColors.line,
          SkpColors.muted,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(SkpTokens.radiusSm),
        border: Border.all(color: border),
      ),
      child: Text.rich(
        TextSpan(
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: text,
                fontWeight: FontWeight.w600,
              ),
          children: [
            TextSpan(text: label),
            if (waitMin != null)
              TextSpan(
                text: ' · +$waitMin min',
                style: TextStyle(
                  color: traffic == ApproachTraffic.heavy ? SkpColors.danger : text,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
