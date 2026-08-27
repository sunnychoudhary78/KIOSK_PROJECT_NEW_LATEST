/// UI phases for the dual-sensor Well Being flow.
enum WellBeingPhase {
  /// Hub: pick Oxygen or Temperature.
  choose,

  /// Oximeter: waiting for finger after start max30102.
  oxiIdle,

  /// Oximeter: finger detected / recording (~20s).
  oxiMeasuring,

  /// Oximeter: finger removed before a valid result.
  oxiCancelled,

  /// Oximeter: finals available from result line.
  oxiComplete,

  /// Temperature: firmware collecting (~60s).
  tempMeasuring,

  /// Temperature: finals available from result line.
  tempComplete,
}
