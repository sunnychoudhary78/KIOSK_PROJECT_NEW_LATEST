/// Cabinet light window from the admin panel.
///
/// `mode` `on` and `off` are the instant switch. `schedule` follows [onTime]
/// and [offTime] (`HH:mm`). A window that crosses midnight stays on overnight.
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

  static const CabinetLightConfig defaults = CabinetLightConfig(
    enabled: false,
    mode: 'schedule',
    onTime: '18:00',
    offTime: '06:00',
  );

  factory CabinetLightConfig.fromJson(Map<String, dynamic> json) {
    return CabinetLightConfig(
      enabled: json['enabled'] == true,
      mode: json['mode']?.toString() ?? 'schedule',
      onTime: json['onTime']?.toString() ?? '18:00',
      offTime: json['offTime']?.toString() ?? '06:00',
    );
  }

  /// Relay 2 should be on for this clock time.
  bool shouldBeOn(DateTime now) {
    if (mode == 'on') return true;
    if (mode == 'off') return false;
    if (!enabled) return false;
    final on = _minutes(onTime);
    final off = _minutes(offTime);
    if (on == null || off == null || on == off) return false;
    final minute = now.hour * 60 + now.minute;
    if (on < off) {
      return minute >= on && minute < off;
    }
    return minute >= on || minute < off;
  }

  static int? _minutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }
}
