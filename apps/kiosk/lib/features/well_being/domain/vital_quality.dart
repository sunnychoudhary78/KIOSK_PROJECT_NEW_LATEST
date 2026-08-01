/// Freshness / readiness of a single vital metric.
enum VitalQuality {
  /// Never received a value for this metric.
  unknown,

  /// Sensor reports no finger / invalid reading.
  waiting,

  /// Valid reading updated recently.
  live,

  /// Had a valid reading, but updates stopped.
  stale,
}
