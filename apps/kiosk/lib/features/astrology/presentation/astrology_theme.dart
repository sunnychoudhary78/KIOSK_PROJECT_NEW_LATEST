import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';

/// Astrology palette aligned with the global light kiosk theme.
/// Feature accents stay distinct; surfaces match [SkpColors].
abstract final class AstrologyColors {
  static const Color canvas = SkpColors.canvas;
  static const Color panel = SkpColors.panel;
  static const Color panelSolid = SkpColors.panel;
  static const Color raised = SkpColors.raised;
  static const Color glassBorder = SkpColors.line;
  static const Color line = SkpColors.line;
  static const Color gold = SkpColors.gold;
  static const Color goldSoft = Color(0xFFF0D9A0);
  static const Color text = SkpColors.text;
  static const Color muted = SkpColors.muted;
  static const Color accent = SkpColors.accentBright;
  static const Color danger = SkpColors.danger;

  static const Color kundali = Color(0xFF3D6BFF);
  static const Color palm = Color(0xFFD4894A);
  static const Color matchRose = Color(0xFFE06A8A);
  static const Color matchIndigo = Color(0xFF5C6BC4);
  /// Darker slate so it remains readable as text/accent on light surfaces.
  static const Color today = Color(0xFF4A6FA5);

  static const Color lifeLine = Color(0xFF3DDC97);
  static const Color heartLine = Color(0xFFE06A8A);
  static const Color headLine = Color(0xFF6AA6FF);
  static const Color fateLine = Color(0xFFE8C872);
}
