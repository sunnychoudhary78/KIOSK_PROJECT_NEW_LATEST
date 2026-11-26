/// UI phases for Well Being vitals + wellness screenings.
enum WellBeingPhase {
  /// Hub: pick a check.
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

  /// Color vision: disclaimer / how-to before plates.
  colorVisionIntro,

  /// Color vision: answering pseudoisochromatic plates.
  colorVisionTesting,

  /// Color vision: screening result ready.
  colorVisionComplete,

  /// BMI: height + weight entry.
  bmiInput,

  /// BMI: calculated result ready.
  bmiComplete,
}
