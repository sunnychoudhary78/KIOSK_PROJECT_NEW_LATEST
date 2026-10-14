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
}
