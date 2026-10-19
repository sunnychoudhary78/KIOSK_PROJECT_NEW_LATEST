import 'package:skp_kiosk/features/astrology/domain/astrology_reading.dart';

class KundaliChartEntry {
  const KundaliChartEntry({
    required this.svg,
    required this.title,
    required this.subtitle,
  });

  final String svg;
  final String title;
  final String subtitle;

  factory KundaliChartEntry.fromJson(Map<String, dynamic> json) {
    return KundaliChartEntry(
      svg: json['svg']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
    );
  }
}

class KundaliResult {
  const KundaliResult({
    required this.disclaimer,
    required this.name,
    required this.style,
    required this.chartType,
    required this.svg,
    required this.chart,
    required this.charts,
  });

  final String disclaimer;
  final String name;
  final String style;
  final String chartType;
  final String svg;
  final AstrologyChartSummary chart;
  final Map<String, KundaliChartEntry> charts;

  /// Stable tab order for the result UI.
  static const tabKeys = ['RasiD1', 'NavamshaD9', 'DashamamshaD10'];

  List<MapEntry<String, KundaliChartEntry>> get availableTabs {
    return tabKeys
        .where((key) => charts[key]?.svg.trim().isNotEmpty == true)
        .map((key) => MapEntry(key, charts[key]!))
        .toList();
  }

  factory KundaliResult.fromJson(Map<String, dynamic> json) {
    final subject = json['subject'] as Map<String, dynamic>? ?? const {};
    final chartsRaw = json['charts'] as Map<String, dynamic>? ?? const {};
    final charts = <String, KundaliChartEntry>{};
    for (final entry in chartsRaw.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        final parsed = KundaliChartEntry.fromJson(value);
        if (parsed.svg.trim().isNotEmpty) {
          charts[entry.key] = parsed;
        }
      }
    }

    final fallbackSvg = json['svg']?.toString() ?? '';
    if (charts['RasiD1'] == null && fallbackSvg.trim().isNotEmpty) {
      charts['RasiD1'] = KundaliChartEntry(
        svg: fallbackSvg,
        title: 'Birth',
        subtitle: 'Rasi',
      );
    }

    return KundaliResult(
      disclaimer: json['disclaimer']?.toString() ??
          'For entertainment only. Not medical, legal, or financial advice.',
      name: subject['name']?.toString() ?? '',
      style: json['style']?.toString() ?? 'north',
      chartType: json['chartType']?.toString() ?? 'RasiD1',
      svg: charts['RasiD1']?.svg ?? fallbackSvg,
      chart: AstrologyChartSummary.fromJson(
        json['chart'] as Map<String, dynamic>?,
      ),
      charts: charts,
    );
  }
}
