import 'dart:math';

import 'package:flutter/material.dart';

/// One screening plate in the Well Being color vision test.
///
/// Plates are original screening designs inspired by pseudoisochromatic
/// methodology — not copyrighted Ishihara reproductions.
class ColorVisionPlate {
  const ColorVisionPlate({
    required this.id,
    required this.figure,
    required this.options,
    required this.normalAnswer,
    required this.cvdAnswer,
    required this.figureColors,
    required this.groundColors,
    this.nothingIsCvd = false,
  });

  final String id;
  /// Figure drawn in the plate (e.g. `12`, `8`), empty when absent.
  final String figure;
  final List<String> options;
  final String normalAnswer;
  /// Typical answer for red-green deficiency (may be `Nothing`).
  final String cvdAnswer;
  final List<Color> figureColors;
  final List<Color> groundColors;
  final bool nothingIsCvd;

  ColorVisionPlate withShuffledOptions([Random? random]) {
    final next = List<String>.of(options)..shuffle(random ?? Random());
    return ColorVisionPlate(
      id: id,
      figure: figure,
      options: List<String>.unmodifiable(next),
      normalAnswer: normalAnswer,
      cvdAnswer: cvdAnswer,
      figureColors: figureColors,
      groundColors: groundColors,
      nothingIsCvd: nothingIsCvd,
    );
  }
}

enum ColorVisionOutcome {
  normal,
  possibleDeficiency,
  inconclusive,
}

class ColorVisionResult {
  const ColorVisionResult({
    required this.outcome,
    required this.correctCount,
    required this.cvdPatternCount,
    required this.totalPlates,
    required this.title,
    required this.summary,
    required this.advice,
  });

  final ColorVisionOutcome outcome;
  final int correctCount;
  final int cvdPatternCount;
  final int totalPlates;
  final String title;
  final String summary;
  final String advice;

  String get scoreLabel => '$correctCount / $totalPlates correct';
}

/// Fixed screening battery (10 plates).
abstract final class ColorVisionBattery {
  static const plates = <ColorVisionPlate>[
    ColorVisionPlate(
      id: 'p1',
      figure: '12',
      options: ['12', '8', 'Nothing', 'Unclear'],
      normalAnswer: '12',
      cvdAnswer: 'Nothing',
      nothingIsCvd: true,
      figureColors: [Color(0xFFE11D48), Color(0xFFF43F5E), Color(0xFFBE123C)],
      groundColors: [Color(0xFF86EFAC), Color(0xFF4ADE80), Color(0xFF22C55E)],
    ),
    ColorVisionPlate(
      id: 'p2',
      figure: '8',
      options: ['3', '8', 'Nothing', 'Unclear'],
      normalAnswer: '8',
      cvdAnswer: '3',
      figureColors: [Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFFF87171)],
      groundColors: [Color(0xFFA3E635), Color(0xFF84CC16), Color(0xFF65A30D)],
    ),
    ColorVisionPlate(
      id: 'p3',
      figure: '6',
      options: ['5', '6', 'Nothing', 'Unclear'],
      normalAnswer: '6',
      cvdAnswer: '5',
      figureColors: [Color(0xFFB91C1C), Color(0xFFDC2626), Color(0xFFF87171)],
      groundColors: [Color(0xFFD9F99D), Color(0xFFBEF264), Color(0xFFA3E635)],
    ),
    ColorVisionPlate(
      id: 'p4',
      figure: '29',
      options: ['29', '70', 'Nothing', 'Unclear'],
      normalAnswer: '29',
      cvdAnswer: '70',
      figureColors: [Color(0xFF9F1239), Color(0xFFE11D48), Color(0xFFFB7185)],
      groundColors: [Color(0xFFBBF7D0), Color(0xFF86EFAC), Color(0xFF4ADE80)],
    ),
    ColorVisionPlate(
      id: 'p5',
      figure: '57',
      options: ['57', '35', 'Nothing', 'Unclear'],
      normalAnswer: '57',
      cvdAnswer: '35',
      figureColors: [Color(0xFFC2410C), Color(0xFFEA580C), Color(0xFFFB923C)],
      groundColors: [Color(0xFF86EFAC), Color(0xFF34D399), Color(0xFF10B981)],
    ),
    ColorVisionPlate(
      id: 'p6',
      figure: '5',
      options: ['2', '5', 'Nothing', 'Unclear'],
      normalAnswer: '5',
      cvdAnswer: '2',
      figureColors: [Color(0xFFBE123C), Color(0xFFE11D48), Color(0xFFF43F5E)],
      groundColors: [Color(0xFFFDE68A), Color(0xFFFBBF24), Color(0xFFF59E0B)],
    ),
    ColorVisionPlate(
      id: 'p7',
      figure: '3',
      options: ['3', '5', 'Nothing', 'Unclear'],
      normalAnswer: '3',
      cvdAnswer: '5',
      figureColors: [Color(0xFF9A3412), Color(0xFFC2410C), Color(0xFFEA580C)],
      groundColors: [Color(0xFFA7F3D0), Color(0xFF6EE7B7), Color(0xFF34D399)],
    ),
    ColorVisionPlate(
      id: 'p8',
      figure: '15',
      options: ['15', '17', 'Nothing', 'Unclear'],
      normalAnswer: '15',
      cvdAnswer: '17',
      figureColors: [Color(0xFFDC2626), Color(0xFFF43F5E), Color(0xFFFB7185)],
      groundColors: [Color(0xFFD9F99D), Color(0xFFA3E635), Color(0xFF84CC16)],
    ),
    ColorVisionPlate(
      id: 'p9',
      figure: '74',
      options: ['74', '21', 'Nothing', 'Unclear'],
      normalAnswer: '74',
      cvdAnswer: '21',
      figureColors: [Color(0xFFB91C1C), Color(0xFFEF4444), Color(0xFFFCA5A5)],
      groundColors: [Color(0xFFBBF7D0), Color(0xFF4ADE80), Color(0xFF22C55E)],
    ),
    ColorVisionPlate(
      id: 'p10',
      figure: '2',
      options: ['2', 'Nothing', '7', 'Unclear'],
      normalAnswer: '2',
      cvdAnswer: 'Nothing',
      nothingIsCvd: true,
      figureColors: [Color(0xFFE11D48), Color(0xFFBE123C), Color(0xFF9F1239)],
      groundColors: [Color(0xFF86EFAC), Color(0xFF22C55E), Color(0xFF16A34A)],
    ),
  ];

  /// New random plate order + shuffled answer buttons for one kiosk run.
  static List<ColorVisionPlate> startSession([Random? random]) {
    final rng = random ?? Random();
    final session = plates.map((p) => p.withShuffledOptions(rng)).toList()
      ..shuffle(rng);
    return List<ColorVisionPlate>.unmodifiable(session);
  }

  static ColorVisionResult score(
    List<String?> answers, {
    List<ColorVisionPlate>? sessionPlates,
  }) {
    final ordered = sessionPlates ?? plates;
    final total = ordered.length;
    var correct = 0;
    var cvdHits = 0;
    for (var i = 0; i < total; i++) {
      final plate = ordered[i];
      final answer = i < answers.length ? answers[i] : null;
      if (answer == null || answer.isEmpty) continue;
      if (answer == plate.normalAnswer) {
        correct += 1;
      } else if (answer == plate.cvdAnswer ||
          (plate.nothingIsCvd && answer == 'Nothing')) {
        cvdHits += 1;
      }
    }

    if (correct >= 8) {
      return ColorVisionResult(
        outcome: ColorVisionOutcome.normal,
        correctCount: correct,
        cvdPatternCount: cvdHits,
        totalPlates: total,
        title: 'Normal screening result',
        summary:
            'You correctly identified most plates in this screening test.',
        advice:
            'This is a wellness screening only — not a medical diagnosis. '
            'If you have vision concerns, consult an eye-care professional.',
      );
    }
    if (cvdHits >= 4 || (correct <= 5 && cvdHits >= 3)) {
      return ColorVisionResult(
        outcome: ColorVisionOutcome.possibleDeficiency,
        correctCount: correct,
        cvdPatternCount: cvdHits,
        totalPlates: total,
        title: 'Possible color vision deficiency',
        summary:
            'Your answers followed a pattern often seen with red–green color vision difficulty.',
        advice:
            'This screening suggests you may benefit from a clinical color vision exam. '
            'Please consult an optometrist or ophthalmologist for confirmation.',
      );
    }
    return ColorVisionResult(
      outcome: ColorVisionOutcome.inconclusive,
      correctCount: correct,
      cvdPatternCount: cvdHits,
      totalPlates: total,
      title: 'Inconclusive screening',
      summary:
          'The result was mixed or incomplete, so a clear screening outcome could not be determined.',
      advice:
          'Try again in good lighting, or see an eye-care professional for a full assessment. '
          'This kiosk test is not a medical diagnosis.',
    );
  }
}
