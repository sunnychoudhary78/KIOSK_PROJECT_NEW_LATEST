import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Smart Kiosk brand tokens (aligned with admin / kiosk apps).
abstract final class SkpColors {
  static const Color accent = Color(0xFF0F6A5A);
  static const Color cream = Color(0xFFF3EFE6);
  static const Color creamDeep = Color(0xFFEBE4D7);
  static const Color ink = Color(0xFF1C2430);
  static const Color panel = Color(0xFFFFFDF8);
  static const Color muted = Color(0xFF5B6573);
  static const Color line = Color(0xFFD9D1C3);
  static const Color danger = Color(0xFF9B1C1C);
}

class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: SkpColors.accent,
      brightness: Brightness.light,
      primary: SkpColors.accent,
      onPrimary: Colors.white,
      surface: SkpColors.cream,
      onSurface: SkpColors.ink,
      onSurfaceVariant: SkpColors.muted,
      error: SkpColors.danger,
      outline: SkpColors.line,
    );

    final baseText = GoogleFonts.plusJakartaSansTextTheme();
    final textTheme = baseText
        .apply(
          bodyColor: SkpColors.ink,
          displayColor: SkpColors.ink,
        )
        .copyWith(
          displayLarge: baseText.displayLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            color: SkpColors.ink,
          ),
          displayMedium: baseText.displayMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            color: SkpColors.ink,
          ),
          headlineLarge: baseText.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: SkpColors.ink,
          ),
          headlineMedium: baseText.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: SkpColors.ink,
          ),
          headlineSmall: baseText.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: SkpColors.ink,
          ),
          titleLarge: baseText.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: SkpColors.ink,
          ),
          titleMedium: baseText.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: SkpColors.ink,
          ),
          bodyLarge: baseText.bodyLarge?.copyWith(
            height: 1.45,
            color: SkpColors.ink,
          ),
          bodyMedium: baseText.bodyMedium?.copyWith(
            height: 1.45,
            color: SkpColors.ink,
          ),
          bodySmall: baseText.bodySmall?.copyWith(
            height: 1.4,
            color: SkpColors.muted,
          ),
          labelLarge: baseText.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: SkpColors.line),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: SkpColors.cream,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: SkpColors.ink,
        titleTextStyle: textTheme.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: SkpColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: SkpColors.ink,
          side: const BorderSide(color: SkpColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SkpColors.accent,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SkpColors.panel,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: SkpColors.accent, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: SkpColors.danger),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: SkpColors.danger, width: 1.5),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: SkpColors.muted),
        hintStyle: textTheme.bodyMedium?.copyWith(color: SkpColors.muted),
      ),
      cardTheme: CardThemeData(
        color: SkpColors.panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: SkpColors.line),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SkpColors.accent,
      ),
      dividerTheme: const DividerThemeData(
        color: SkpColors.line,
        thickness: 1,
      ),
    );
  }
}
