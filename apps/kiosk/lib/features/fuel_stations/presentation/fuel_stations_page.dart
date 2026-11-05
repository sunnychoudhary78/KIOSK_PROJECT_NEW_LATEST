import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/fuel_stations/application/fuel_stations_controller.dart';
import 'package:skp_kiosk/features/fuel_stations/domain/fuel_station.dart';
import 'package:skp_kiosk/features/fuel_stations/domain/polyline_codec.dart';
import 'package:skp_kiosk/features/service_analytics/application/service_analytics_tracker.dart';
import 'package:skp_kiosk/features/service_analytics/domain/service_event_keys.dart';
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
    return ref
        .read(kioskSessionControllerProvider.notifier)
        .endVisitorSession(attract: false);
  }

  Future<void> _showDirections(FuelStation station) {
    // ignore: discarded_futures
    ref.read(serviceAnalyticsTrackerProvider).track(
          ServiceEventKeys.fuelDirections,
          metadata: {
            if (station.googlePlaceId != null) 'googlePlaceId': station.googlePlaceId,
            'latitude': station.latitude,
            'longitude': station.longitude,
            if (station.name != null) 'name': station.name,
          },
        );
    return showDialog<void>(
      context: context,
      builder: (context) => _StationDirectionsDialog(station: station),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fuelStationsControllerProvider);
    final colors = context.athenaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return VisitorSessionPopScope(
      child: KioskShell(
        title: 'Fuel Stations',
        titleIcon: Icons.local_gas_station_rounded,
        onHome: _endSession,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top Title Row & Blue/Pink Theme ───────────────────────
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
                                text: 'Nearby ',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: colors.textPrimary,
                                ),
                              ),
                              TextSpan(
                                text: 'Fuel Stations',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: colors.accentMagenta,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Signature Athena Magenta Underline Pill
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
                          'Find Petrol, Diesel, CNG, and EV charging points within ~5 km with real-time wait times.',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quick Filter Bar in Blue/Pink styling
                  _KindFilterBar(
                    selected: state.kind,
                    onSelected: (kind) => ref
                        .read(fuelStationsControllerProvider.notifier)
                        .load(kind: kind),
                    colors: colors,
                    isDark: isDark,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Stations List ─────────────────────────────────────────
              Expanded(
                child: _StationBody(
                  state: state,
                  onOpen: _showDirections,
                  colors: colors,
                  isDark: isDark,
                ),
              ),

              const SizedBox(height: 10),

              // ── Bottom Bar: Back Button & Attribution ──────────────────
              Row(
                children: [
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
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Real-time traffic & wait time estimates · © OpenStreetMap',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary.withValues(alpha: 0.8),
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

/// Filter pill segmented bar for Petrol/Diesel / CNG / EV in Blue/Pink styling
class _KindFilterBar extends StatelessWidget {
  const _KindFilterBar({
    required this.selected,
    required this.onSelected,
    required this.colors,
    required this.isDark,
  });

  final FuelKind selected;
  final ValueChanged<FuelKind> onSelected;
  final AthenaColors colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final kinds = FuelKind.values.where((k) => k != FuelKind.all).toList();

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C143F) : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? const Color(0xFF7445BD) : const Color(0xFFE2EBF5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x2E8B35FF) : const Color(0x08101828),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final kind in kinds) ...[
            _KindPillItem(
              label: kind.label,
              icon: _kindIcon(kind),
              selected: selected == kind,
              onTap: () => onSelected(kind),
              colors: colors,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  IconData _kindIcon(FuelKind kind) {
    return switch (kind) {
      FuelKind.all => Icons.apps_rounded,
      FuelKind.fuel => Icons.local_gas_station_rounded,
      FuelKind.cng => Icons.propane_tank_outlined,
      FuelKind.ev => Icons.electric_bolt_rounded,
    };
  }
}

class _KindPillItem extends StatelessWidget {
  const _KindPillItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.colors,
    required this.isDark,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final AthenaColors colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // Signature Blue & Pink active pill
    final activeColor = colors.accentMagenta;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white : colors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StationBody extends StatelessWidget {
  const _StationBody({
    required this.state,
    required this.onOpen,
    required this.colors,
    required this.isDark,
  });

  final FuelStationsState state;
  final ValueChanged<FuelStation> onOpen;
  final AthenaColors colors;
  final bool isDark;

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
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: state.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final station = state.items[index];
            return _StationTile(
              station: station,
              onTap: () => onOpen(station),
              colors: colors,
              isDark: isDark,
            );
          },
        ),
        if (state.loading)
          Positioned.fill(
            child: ColoredBox(
              color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.5),
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

class _StationTile extends StatelessWidget {
  const _StationTile({
    required this.station,
    required this.onTap,
    required this.colors,
    required this.isDark,
  });

  final FuelStation station;
  final VoidCallback onTap;
  final AthenaColors colors;
  final bool isDark;

  IconData get _leadingIcon {
    if (station.ev && !station.petrol && !station.diesel && !station.cng) {
      return Icons.electric_bolt_rounded;
    }
    if (station.cng && !station.petrol && !station.diesel && !station.ev) {
      return Icons.propane_tank_rounded;
    }
    return Icons.local_gas_station_rounded;
  }

  /// Athena Blue & Pink theme accent colors
  Color get _accentColor {
    if (station.ev && !station.petrol && !station.diesel && !station.cng) {
      return const Color(0xFF00B4D8); // Electric cyan blue
    }
    if (station.cng && !station.petrol && !station.diesel && !station.ev) {
      return const Color(0xFF10B981); // Emerald green
    }
    return const Color(0xFF0084FF); // Vibrant Athena royal blue for Petrol/Diesel
  }

  String _formatKm(double km) {
    return km < 10
        ? '${km.toStringAsFixed(1)} km'
        : '${km.toStringAsFixed(0)} km';
  }

  @override
  Widget build(BuildContext context) {
    final driveKm = station.driveDistanceKm;
    final distanceLabel =
        driveKm != null ? _formatKm(driveKm) : _formatKm(station.distanceKm);
    final durationMin = station.driveDurationMin;
    final accent = _accentColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: accent.withValues(alpha: 0.12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C143F) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: station.bestNow
                  ? colors.accentMagenta
                  : (isDark
                      ? const Color(0xFF7445BD)
                      : const Color(0xFFE2EBF5)),
              width: station.bestNow ? 1.8 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0x2E8B35FF)
                    : const Color(0x0C1B2B4F),
                blurRadius: isDark ? 16 : 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // 3D-styled Squircle Icon Container (Blue & Pink tint)
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: isDark ? 0.35 : 0.18),
                      accent.withValues(alpha: isDark ? 0.15 : 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Icon(_leadingIcon, color: accent, size: 28),
                ),
              ),
              const SizedBox(width: 16),

              // Station Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            station.name ?? 'Fuel Station',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        if (station.bestNow) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: colors.accentMagenta,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Best Choice',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (station.address != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              station.address!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (station.displayTrafficSegments.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _RouteTrafficBar(
                          segments: station.displayTrafficSegments),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final badge in station.badges)
                          _FuelBadge(
                            label: badge,
                            isDark: isDark,
                            colors: colors,
                          ),
                        if (station.approachTraffic?.badgeLabel
                            case final roadLabel?)
                          _TrafficBadge(
                            label: roadLabel,
                            traffic: station.approachTraffic!,
                            waitMin: station.approachWaitMin,
                            isDark: isDark,
                            colors: colors,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Distance & Directions Action CTA (Athena Magenta Button)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    distanceLabel,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (durationMin != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.drive_eta_rounded,
                          size: 14,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '~$durationMin min',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),

                  // Pill CTA Button in Magenta with glowing shadow
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.accentMagenta,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: colors.accentMagenta.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_rounded,
                            size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Directions',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
  const _RouteTrafficBar({required this.segments, this.height = 8});

  final List<RouteTrafficSegment> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: ColoredBox(
          color: const Color(0xFFE2EBF5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final segment in segments)
                Expanded(
                  flex: (segment.fraction * 1000).round().clamp(1, 100000),
                  child: ColoredBox(color: _trafficSpeedColor(segment.speed)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _trafficSpeedColor(RouteTrafficSpeed speed) {
  return switch (speed) {
    RouteTrafficSpeed.normal => const Color(0xFF10B981),
    RouteTrafficSpeed.slow => const Color(0xFFF59E0B),
    RouteTrafficSpeed.trafficJam => const Color(0xFFEF4444),
  };
}

class _FuelBadge extends StatelessWidget {
  const _FuelBadge({
    required this.label,
    required this.isDark,
    required this.colors,
  });

  final String label;
  final bool isDark;
  final AthenaColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF261D4E)
            : const Color(0xFF0084FF).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? const Color(0xFF4C307C)
              : const Color(0xFF0084FF).withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : const Color(0xFF0070DF),
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
    required this.isDark,
    required this.colors,
  });

  final String label;
  final ApproachTraffic traffic;
  final int? waitMin;
  final bool isDark;
  final AthenaColors colors;

  @override
  Widget build(BuildContext context) {
    final (Color fill, Color border, Color text) = switch (traffic) {
      ApproachTraffic.heavy => (
          colors.accentMagenta.withValues(alpha: 0.12),
          colors.accentMagenta.withValues(alpha: 0.45),
          colors.accentMagenta,
        ),
      ApproachTraffic.moderate => (
          const Color(0xFF0084FF).withValues(alpha: 0.12),
          const Color(0xFF0084FF).withValues(alpha: 0.45),
          const Color(0xFF0070DF),
        ),
      ApproachTraffic.clear => (
          const Color(0xFF10B981).withValues(alpha: 0.12),
          const Color(0xFF10B981).withValues(alpha: 0.45),
          const Color(0xFF059669),
        ),
      ApproachTraffic.unknown => (
          isDark ? const Color(0xFF261D4E) : const Color(0xFFF1F5F9),
          isDark ? const Color(0xFF4C307C) : const Color(0xFFCBD5E1),
          const Color(0xFF64748B),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: text,
          ),
          children: [
            TextSpan(text: label),
            if (waitMin != null)
              TextSpan(
                text: ' · +$waitMin min wait',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dialog presenting station mini-map and mobile directions QR
class _StationDirectionsDialog extends StatelessWidget {
  const _StationDirectionsDialog({required this.station});

  final FuelStation station;

  String _formatKm(double km) {
    return km < 10
        ? '${km.toStringAsFixed(1)} km'
        : '${km.toStringAsFixed(0)} km';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.athenaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final driveKm = station.driveDistanceKm;
    final distanceLabel =
        driveKm != null ? _formatKm(driveKm) : _formatKm(station.distanceKm);
    final driveMin = station.driveDurationMin;
    final totalEta = station.totalEtaMin;
    final waitMin = station.approachWaitMin;
    final traffic = station.approachTraffic;
    final segments = station.displayTrafficSegments;
    final routePoints = decodePolyline(station.routePolyline ?? '');
    final hasRoute = routePoints.length >= 2;
    const mapRowHeight = 240.0;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF171038) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                station.name ?? 'Fuel Station',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              if (station.address != null) ...[
                const SizedBox(height: 4),
                Text(
                  station.address!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ],
              if (driveMin != null || traffic?.badgeLabel != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (driveMin != null)
                      _DetailStatChip(
                        icon: Icons.directions_car_outlined,
                        label: '~$driveMin min · $distanceLabel',
                        isDark: isDark,
                        colors: colors,
                      ),
                    if (traffic?.badgeLabel case final roadLabel?)
                      _TrafficBadge(
                        label: roadLabel,
                        traffic: traffic!,
                        waitMin: waitMin,
                        isDark: isDark,
                        colors: colors,
                      ),
                    if (totalEta != null && waitMin != null)
                      _DetailStatChip(
                        icon: Icons.schedule_outlined,
                        label: 'Total ~$totalEta min',
                        emphasize: true,
                        isDark: isDark,
                        colors: colors,
                      ),
                  ],
                ),
              ],
              if (segments.isNotEmpty) ...[
                const SizedBox(height: 12),
                _RouteTrafficBar(segments: segments, height: 10),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: mapRowHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: hasRoute
                          ? _RouteMiniMap(
                              points: routePoints,
                              segments: segments,
                              stationLat: station.latitude,
                              stationLng: station.longitude,
                              height: mapRowHeight,
                              isDark: isDark,
                              colors: colors,
                            )
                          : _StationPinMap(
                              latitude: station.latitude,
                              longitude: station.longitude,
                              height: mapRowHeight,
                              isDark: isDark,
                              colors: colors,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF211747)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF7445BD)
                                : const Color(0xFFE2EBF5),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 160,
                                height: 160,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFE2EBF5)),
                                ),
                                child: QrImageView(
                                  data: station.directionsUrl,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Scan for turn-by-turn',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: SizedBox(
                  width: 200,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accentMagenta,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailStatChip extends StatelessWidget {
  const _DetailStatChip({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.colors,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final bool isDark;
  final AthenaColors colors;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final accent = colors.accentMagenta;
    final color = emphasize
        ? accent
        : (isDark ? Colors.white : const Color(0xFF1E293B));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: emphasize
            ? accent.withValues(alpha: 0.12)
            : (isDark ? const Color(0xFF211747) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: emphasize
              ? accent.withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF7445BD) : const Color(0xFFCBD5E1)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

List<Polyline> _coloredRoutePolylines(
  List<LatLng> points,
  List<RouteTrafficSegment> segments,
) {
  if (points.length < 2) return const [];
  if (segments.isEmpty) {
    return [
      Polyline(
        points: points,
        color: const Color(0xFF0084FF),
        strokeWidth: 5,
      ),
    ];
  }

  final polylines = <Polyline>[];
  final lastIndex = points.length - 1;
  var start = 0;
  var used = 0.0;
  for (var i = 0; i < segments.length; i++) {
    final segment = segments[i];
    used += segment.fraction;
    final end = i == segments.length - 1
        ? lastIndex
        : (used * lastIndex).round().clamp(start + 1, lastIndex);
    final slice = points.sublist(start, end + 1);
    if (slice.length >= 2) {
      polylines.add(
        Polyline(
          points: slice,
          color: _trafficSpeedColor(segment.speed),
          strokeWidth: 5,
        ),
      );
    }
    start = end;
  }
  return polylines;
}

class _RouteMiniMap extends StatelessWidget {
  const _RouteMiniMap({
    required this.points,
    required this.segments,
    required this.stationLat,
    required this.stationLng,
    required this.height,
    required this.isDark,
    required this.colors,
  });

  final List<({double lat, double lng})> points;
  final List<RouteTrafficSegment> segments;
  final double stationLat;
  final double stationLng;
  final double height;
  final bool isDark;
  final AthenaColors colors;

  @override
  Widget build(BuildContext context) {
    final latLngs =
        points.map((p) => LatLng(p.lat, p.lng)).toList(growable: false);
    final start = latLngs.first;
    final end = LatLng(stationLat, stationLng);
    final bounds = LatLngBounds.fromPoints([...latLngs, end]);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  isDark ? const Color(0xFF7445BD) : const Color(0xFFE2EBF5),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: FlutterMap(
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(28),
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'skp_kiosk',
              ),
              PolylineLayer(
                  polylines: _coloredRoutePolylines(latLngs, segments)),
              MarkerLayer(
                markers: [
                  Marker(
                    point: start,
                    width: 36,
                    height: 36,
                    child: const _MapPin(
                        color: Color(0xFF0084FF), icon: Icons.my_location),
                  ),
                  Marker(
                    point: end,
                    width: 36,
                    height: 36,
                    child: _MapPin(
                        color: colors.accentMagenta,
                        icon: Icons.local_gas_station_rounded),
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

class _StationPinMap extends StatelessWidget {
  const _StationPinMap({
    required this.latitude,
    required this.longitude,
    required this.height,
    required this.isDark,
    required this.colors,
  });

  final double latitude;
  final double longitude;
  final double height;
  final bool isDark;
  final AthenaColors colors;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  isDark ? const Color(0xFF7445BD) : const Color(0xFFE2EBF5),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'skp_kiosk',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 36,
                    height: 36,
                    child: _MapPin(
                        color: colors.accentMagenta,
                        icon: Icons.local_gas_station_rounded),
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

class _MapPin extends StatelessWidget {
  const _MapPin({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}
