/// UI phases for the dual-sensor Well Being flow.
enum WellBeingPhase {
  /// Hub: pick Oxygen or Temperature.
  choose,

  /// Oximeter: waiting for finger after start max30102.
  oxiIdle,

  /// Oximeter: finger detected / recording (~15s).
  oxiMeasuring,

  /// Oximeter: finger removed before a valid result.
  oxiCancelled,

  /// Oximeter: finals available from result line.
  oxiComplete,

  /// Temperature: waiting for forehead after start mlx90614.
  tempIdle,

  /// Temperature: forehead detected / recording (~5s).
  tempMeasuring,

  /// Temperature: finals available from result line.
  tempComplete,
}
