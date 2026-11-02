import 'package:flutter/material.dart';

abstract final class AdminColors {
  static const Color accent = Color(0xFF0F6A5A);
  static const Color accentSoft = Color(0x140F6A5A);
  static const Color ink = Color(0xFF1C2430);
  static const Color muted = Color(0xFF5B6573);
  static const Color paper = Color(0xFFF6F4EF);
  static const Color card = Color(0xFFFFFDF8);
  static const Color line = Color(0xFFD9D1C3);
  static const Color danger = Color(0xFF9B1C1C);
  static const Color warning = Color(0xFF8A5A00);
  static const Color success = Color(0xFF1B7A4A);
}

abstract final class AdminFonts {
  static const String family = 'PlusJakartaSans';
}

class AppTheme {
  static ThemeData light() {
    const textTheme = TextTheme(
      headlineMedium: TextStyle(
        fontFamily: AdminFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 28,
        letterSpacing: -0.6,
        color: AdminColors.ink,
      ),
      titleLarge: TextStyle(
        fontFamily: AdminFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 20,
        letterSpacing: -0.3,
        color: AdminColors.ink,
      ),
      titleMedium: TextStyle(
        fontFamily: AdminFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: AdminColors.ink,
      ),
      titleSmall: TextStyle(
        fontFamily: AdminFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: AdminColors.ink,
      ),
      bodyLarge: TextStyle(
        fontFamily: AdminFonts.family,
        fontSize: 16,
        height: 1.45,
        color: AdminColors.ink,
      ),
      bodyMedium: TextStyle(
        fontFamily: AdminFonts.family,
        fontSize: 14,
        height: 1.45,
        color: AdminColors.ink,
      ),
      bodySmall: TextStyle(
        fontFamily: AdminFonts.family,
        fontSize: 12,
        height: 1.4,
        color: AdminColors.muted,
      ),
      labelLarge: TextStyle(
        fontFamily: AdminFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        letterSpacing: 0.1,
        color: AdminColors.ink,
      ),
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AdminColors.line),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AdminFonts.family,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AdminColors.accent,
        primary: AdminColors.accent,
        onPrimary: Colors.white,
        surface: AdminColors.paper,
        onSurface: AdminColors.ink,
        onSurfaceVariant: AdminColors.muted,
        error: AdminColors.danger,
        outline: AdminColors.line,
      ),
      scaffoldBackgroundColor: AdminColors.paper,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AdminColors.paper,
        foregroundColor: AdminColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: AdminColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AdminColors.line),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        height: 68,
        indicatorColor: AdminColors.accent.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: AdminFonts.family,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AdminColors.accent : AdminColors.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? AdminColors.accent : AdminColors.muted);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AdminColors.accent, width: 1.5),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AdminColors.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: AdminColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16, color: Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminColors.ink,
          side: const BorderSide(color: AdminColors.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AdminColors.accent),
    );
  }
}
