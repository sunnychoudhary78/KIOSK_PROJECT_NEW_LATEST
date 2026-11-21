import 'package:flutter/material.dart';

/// Bright public-kiosk palette: cool off-white surfaces, teal primary.
abstract final class SkpColors {
  static const Color canvas = Color(0xFFF4F7F8);
  static const Color panel = Color(0xFFFFFFFF);
  static const Color raised = Color(0xFFE8EEF0);
  static const Color accent = Color(0xFF0F6A5A);
  static const Color accentBright = Color(0xFF2EC4A0);
  static const Color text = Color(0xFF1A2430);
  static const Color muted = Color(0xFF5C6B76);
  static const Color line = Color(0xFFD0D9DE);
  static const Color gold = Color(0xFFE8C872);
  static const Color danger = Color(0xFFC62828);
  static const Color qrSurface = Color(0xFFFFFFFF);
  static const Color scrim = Color(0xCC1A2430);
}

abstract final class SkpTokens {
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double hairline = 1;
  static const double tapMin = 80;
  static const double tileMinHeight = 140;
  static const double tileMinWidth = 240;
  static const double headerHeight = 72;
  static const double footerHeight = 96;
  static const double primaryButtonHeight = 88;
  static const double keypadKeySize = 80;
  static const double pinSlotSize = 72;
  /// Top/bottom home banners — sized for the 1448×1086 (4:3) kiosk panel.
  static const double bannerHeight = 72;

  /// Left/right home banners — ~5% of 1448px keeps the center catalog usable.
  static const double bannerSideWidth = 72;

  /// Physical kiosk display used as the home layout reference.
  static const double displayWidth = 1448;
  static const double displayHeight = 1086;

  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(32, 16, 32, 16);
}

abstract final class SkpFonts {
  static const String family = 'PlusJakartaSans';
}
