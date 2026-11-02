import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';

/// Astrology-scoped night-reading palette (does not mutate global [SkpColors]).
abstract final class AstrologyColors {
  static const Color canvas = Color(0xFF0B1220);
  static const Color panel = Color(0xCC161F30);
  static const Color panelSolid = Color(0xFF161F30);
  static const Color raised = Color(0xFF1C2638);
  static const Color glassBorder = Color(0x55E8C872);
  static const Color line = Color(0x33E8C872);
  static const Color gold = SkpColors.gold;
  static const Color goldSoft = Color(0xFFF0D9A0);
  static const Color text = Color(0xFFF4F0E6);
  static const Color muted = Color(0xFFA8B0BC);
  static const Color accent = Color(0xFF2EC4A0);
  static const Color danger = SkpColors.danger;

  static const Color kundali = Color(0xFF3D6BFF);
  static const Color palm = Color(0xFFD4894A);
  static const Color matchRose = Color(0xFFE06A8A);
  static const Color matchIndigo = Color(0xFF5C6BC4);
  static const Color today = Color(0xFFC9D4E8);

  static const Color lifeLine = Color(0xFF3DDC97);
  static const Color heartLine = Color(0xFFE06A8A);
  static const Color headLine = Color(0xFF6AA6FF);
  static const Color fateLine = Color(0xFFE8C872);
}
