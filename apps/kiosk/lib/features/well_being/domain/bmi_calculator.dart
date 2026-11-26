/// BMI wellness calculator (metric). Not a medical diagnosis.
enum BmiCategory {
  underweight,
  normal,
  overweight,
  obese,
}

class BmiResult {
  const BmiResult({
    required this.bmi,
    required this.category,
    required this.heightCm,
    required this.weightKg,
    required this.title,
    required this.summary,
    required this.advice,
    required this.categoryRangeLabel,
    required this.idealWeightMinKg,
    required this.idealWeightMaxKg,
  });

  final double bmi;
  final BmiCategory category;
  final double heightCm;
  final double weightKg;
  final String title;
  final String summary;
  final String advice;
  final String categoryRangeLabel;
  final double idealWeightMinKg;
  final double idealWeightMaxKg;

  String get bmiLabel => bmi.toStringAsFixed(1);

  String get categoryLabel => switch (category) {
        BmiCategory.underweight => 'Underweight',
        BmiCategory.normal => 'Normal',
        BmiCategory.overweight => 'Overweight',
        BmiCategory.obese => 'Obese',
      };

  String get categoryApi => switch (category) {
        BmiCategory.underweight => 'underweight',
        BmiCategory.normal => 'normal',
        BmiCategory.overweight => 'overweight',
        BmiCategory.obese => 'obese',
      };

  String get idealWeightLabel =>
      '${idealWeightMinKg.round()} – ${idealWeightMaxKg.round()} kg';

  /// 0–1 position on a visual scale spanning BMI 12–40.
  double get scalePosition {
    const min = 12.0;
    const max = 40.0;
    return ((bmi - min) / (max - min)).clamp(0.0, 1.0);
  }
}

abstract final class BmiCalculator {
  static const minHeightCm = 100.0;
  static const maxHeightCm = 230.0;
  static const minWeightKg = 25.0;
  static const maxWeightKg = 250.0;

  static String? validateHeightCm(double? cm) {
    if (cm == null) return 'Enter height in cm';
    if (cm < minHeightCm || cm > maxHeightCm) {
      return 'Height should be between ${minHeightCm.toInt()} and ${maxHeightCm.toInt()} cm';
    }
    return null;
  }

  static String? validateWeightKg(double? kg) {
    if (kg == null) return 'Enter weight in kg';
    if (kg < minWeightKg || kg > maxWeightKg) {
      return 'Weight should be between ${minWeightKg.toInt()} and ${maxWeightKg.toInt()} kg';
    }
    return null;
  }

  static String categoryRangeLabel(BmiCategory category) => switch (category) {
        BmiCategory.underweight => 'Below 18.5',
        BmiCategory.normal => '18.5 – 24.9',
        BmiCategory.overweight => '25.0 – 29.9',
        BmiCategory.obese => '30.0 and above',
      };

  static BmiResult calculate({
    required double heightCm,
    required double weightKg,
  }) {
    final meters = heightCm / 100.0;
    final bmi = weightKg / (meters * meters);
    final category = categorize(bmi);
    final idealMin = 18.5 * meters * meters;
    final idealMax = 24.9 * meters * meters;
    return BmiResult(
      bmi: bmi,
      category: category,
      heightCm: heightCm,
      weightKg: weightKg,
      categoryRangeLabel: categoryRangeLabel(category),
      idealWeightMinKg: idealMin,
      idealWeightMaxKg: idealMax,
      title: switch (category) {
        BmiCategory.underweight => 'BMI suggests underweight',
        BmiCategory.normal => 'BMI in normal range',
        BmiCategory.overweight => 'BMI suggests overweight',
        BmiCategory.obese => 'BMI suggests obesity range',
      },
      summary: switch (category) {
        BmiCategory.underweight =>
          'Your BMI is ${bmi.toStringAsFixed(1)} (underweight). '
          'A typical healthy weight for ${heightCm.round()} cm is about '
          '${idealMin.round()}–${idealMax.round()} kg.',
        BmiCategory.normal =>
          'Your BMI is ${bmi.toStringAsFixed(1)}, within the common adult healthy range '
          '(18.5–24.9).',
        BmiCategory.overweight =>
          'Your BMI is ${bmi.toStringAsFixed(1)} (overweight). '
          'A typical healthy weight for ${heightCm.round()} cm is about '
          '${idealMin.round()}–${idealMax.round()} kg.',
        BmiCategory.obese =>
          'Your BMI is ${bmi.toStringAsFixed(1)} (obesity range). '
          'A typical healthy weight for ${heightCm.round()} cm is about '
          '${idealMin.round()}–${idealMax.round()} kg.',
      },
      advice:
          'BMI is a screening estimate only — it does not diagnose health conditions. '
          'Muscle mass, age, sex, and medical history matter. '
          'Speak with a qualified clinician for personal advice.',
    );
  }

  static BmiCategory categorize(double bmi) {
    if (bmi < 18.5) return BmiCategory.underweight;
    if (bmi < 25.0) return BmiCategory.normal;
    if (bmi < 30.0) return BmiCategory.overweight;
    return BmiCategory.obese;
  }
}
