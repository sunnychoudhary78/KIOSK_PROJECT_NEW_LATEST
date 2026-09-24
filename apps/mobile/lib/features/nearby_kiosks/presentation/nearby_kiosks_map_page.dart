import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/nearby_kiosks/application/nearby_kiosks_controller.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class NearbyKiosksMapPage extends StatefulWidget {
  const NearbyKiosksMapPage({super.key, required this.kiosks});

  final List<NearbyKiosk> kiosks;

  @override
  State<NearbyKiosksMapPage> createState() => _NearbyKiosksMapPageState();
}

class _NearbyKiosksMapPageState extends State<NearbyKiosksMapPage> {
  final _mapController = MapController();

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

  void _showKioskSheet(NearbyKiosk kiosk) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  kiosk.name,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  kiosk.subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: SkpColors.muted,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      kiosk.distanceLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: SkpColors.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SkpStatusChip(label: l10n.statusReady),
                  ],
                ),
                const SizedBox(height: 20),
                SkpPrimaryButton(
                  label: l10n.directions,
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openDirections(kiosk);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  MapOptions _mapOptions() {
    final points = widget.kiosks
        .map((k) => LatLng(k.latitude, k.longitude))
        .toList(growable: false);

    if (points.length == 1) {
      return MapOptions(
        initialCenter: points.first,
        initialZoom: 15,
      );
    }

    return MapOptions(
      initialCameraFit: CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(48, 96, 48, 72),
        maxZoom: 16,
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (widget.kiosks.isEmpty) {
      return SkpScaffold(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: SkpBackButton(),
            ),
            Expanded(
              child: SkpEmptyState(
                icon: Icons.map_outlined,
                title: l10n.noKiosksOnMap,
                message: l10n.noKiosksHelper,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: SkpColors.cream,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: _mapOptions(),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.smartkiosk.skp_mobile',
              ),
              MarkerLayer(
                markers: [
                  for (final kiosk in widget.kiosks)
                    Marker(
                      point: LatLng(kiosk.latitude, kiosk.longitude),
                      width: 44,
                      height: 52,
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        onTap: () => _showKioskSheet(kiosk),
                        child: const Icon(
                          Icons.location_on_rounded,
                          size: 44,
                          color: SkpColors.accent,
                          shadows: [
                            Shadow(
                              color: Color(0x33000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    prependCopyright: true,
                  ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  const SkpBackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: SkpColors.panel.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: SkpColors.line),
                      ),
                      child: Text(
                        l10n.kiosksOnMap(
                          widget.kiosks.length,
                          widget.kiosks.length == 1 ? '' : 's',
                        ),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
