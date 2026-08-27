import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/ui.dart';
import 'package:skp_mobile/features/nearby_kiosks/application/nearby_kiosks_controller.dart';
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

  void _showKioskSheet(NearbyKiosk kiosk) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SkpColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: SkpColors.line,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  kiosk.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  kiosk.subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: SkpColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  kiosk.distanceLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: SkpColors.accent,
                  ),
                ),
                const SizedBox(height: 20),
                SkpPrimaryButton(
                  label: 'Directions',
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
    if (widget.kiosks.isEmpty) {
      return Scaffold(
        backgroundColor: SkpColors.cream,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
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
                const Spacer(),
                Text(
                  'No kiosks to show on the map.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
              ],
            ),
          ),
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
                      height: 44,
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
                  IconButton(
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
                        '${widget.kiosks.length} kiosk${widget.kiosks.length == 1 ? '' : 's'} on map',
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
