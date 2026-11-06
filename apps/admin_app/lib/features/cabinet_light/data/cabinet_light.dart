class CabinetLightConfig {
  const CabinetLightConfig({
    required this.enabled,
    required this.mode,
    required this.onTime,
    required this.offTime,
  });

  final bool enabled;
  final String mode;
  final String onTime;
  final String offTime;

  static const defaults = CabinetLightConfig(
    enabled: false,
    mode: 'schedule',
    onTime: '18:00',
    offTime: '06:00',
  );

  factory CabinetLightConfig.fromJson(Map<String, dynamic> json) {
    final mode = json['mode']?.toString();
    return CabinetLightConfig(
      enabled: json['enabled'] == true,
      mode: mode == 'on' || mode == 'off' ? mode! : 'schedule',
      onTime: _clock(json['onTime'], defaults.onTime),
      offTime: _clock(json['offTime'], defaults.offTime),
    );
  }

  CabinetLightConfig copyWith({
    bool? enabled,
    String? mode,
    String? onTime,
    String? offTime,
  }) {
    return CabinetLightConfig(
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      onTime: onTime ?? this.onTime,
      offTime: offTime ?? this.offTime,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'mode': mode,
        'onTime': onTime,
        'offTime': offTime,
      };
}

String cabinetLightStatus(CabinetLightConfig config) {
  if (config.mode == 'on') return 'Forced on';
  if (config.mode == 'off') return 'Forced off';
  if (config.enabled) {
    return 'Following schedule ${config.onTime}–${config.offTime}';
  }
  return 'Schedule is off';
}

bool lightStaysOvernight(String onTime, String offTime) {
  final on = _minutes(onTime);
  final off = _minutes(offTime);
  if (on == null || off == null) return false;
  return off < on;
}

String formatClock(int hour, int minute) {
  final hh = hour.clamp(0, 23).toString().padLeft(2, '0');
  final mm = minute.clamp(0, 59).toString().padLeft(2, '0');
  return '$hh:$mm';
}

String _clock(Object? raw, String fallback) {
  final value = raw?.toString() ?? '';
  return _minutes(value) == null ? fallback : value;
}

int? _minutes(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}
