import 'package:skp_kiosk/features/astrology/domain/astrology_reading.dart';

class KundaliResult {
  const KundaliResult({
    required this.disclaimer,
    required this.name,
    required this.style,
    required this.chartType,
    required this.svg,
    required this.chart,
  });

  final String disclaimer;
  final String name;
  final String style;
  final String chartType;
  final String svg;
  final AstrologyChartSummary chart;

  factory KundaliResult.fromJson(Map<String, dynamic> json) {
    final subject = json['subject'] as Map<String, dynamic>? ?? const {};
    return KundaliResult(
      disclaimer: json['disclaimer']?.toString() ??
          'For entertainment only. Not medical, legal, or financial advice.',
      name: subject['name']?.toString() ?? '',
      style: json['style']?.toString() ?? 'north',
      chartType: json['chartType']?.toString() ?? 'RasiD1',
      svg: json['svg']?.toString() ?? '',
      chart: AstrologyChartSummary.fromJson(
        json['chart'] as Map<String, dynamic>?,
      ),
    );
  }
}
