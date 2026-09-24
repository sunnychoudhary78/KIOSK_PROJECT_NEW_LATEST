import 'package:flutter/material.dart';

/// ATM-dark Smart Kiosk palette. Inverse of the cream mobile/admin surfaces.
abstract final class SkpColors {
  static const Color canvas = Color(0xFF0B1419);
  static const Color panel = Color(0xFF132029);
  static const Color raised = Color(0xFF1A2A32);
  static const Color accent = Color(0xFF0F6A5A);
  static const Color accentBright = Color(0xFF2EC4A0);
  static const Color text = Color(0xFFF5F1E8);
  static const Color muted = Color(0xFF9AA3AD);
  static const Color line = Color(0xFF2A3A42);
  static const Color gold = Color(0xFFE8C872);
  static const Color danger = Color(0xFFE85D5D);
}

abstract final class SkpTokens {
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double hairline = 1;
  static const double tapMin = 80;
  static const double tileMinHeight = 200;
  static const double tileMinWidth = 240;
  static const double headerHeight = 72;
  static const double footerHeight = 96;
  static const double primaryButtonHeight = 88;
  static const double keypadKeySize = 80;
  static const double pinSlotSize = 72;
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(32, 16, 32, 16);
}

abstract final class SkpFonts {
  static const String family = 'PlusJakartaSans';
}
