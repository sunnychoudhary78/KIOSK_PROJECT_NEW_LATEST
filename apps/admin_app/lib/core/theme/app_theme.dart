import 'package:flutter/material.dart';

abstract final class AdminColors {
  static const Color accent = Color(0xFF0F6A5A);
  static const Color ink = Color(0xFF1C2430);
  static const Color muted = Color(0xFF5B6573);
  static const Color paper = Color(0xFFF6F4EF);
  static const Color card = Color(0xFFFFFDF8);
  static const Color line = Color(0xFFD9D1C3);
  static const Color danger = Color(0xFF9B1C1C);
  static const Color warning = Color(0xFF8A5A00);
  static const Color success = Color(0xFF1B7A4A);
}

class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AdminColors.accent,
      primary: AdminColors.accent,
      onPrimary: Colors.white,
      surface: AdminColors.paper,
      onSurface: AdminColors.ink,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AdminColors.paper,
      appBarTheme: const AppBarTheme(
        backgroundColor: AdminColors.paper,
        foregroundColor: AdminColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AdminColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AdminColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
