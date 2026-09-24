import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';

class AppTheme {
  static ThemeData kiosk() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: SkpColors.accent,
      onPrimary: Colors.white,
      secondary: SkpColors.accentBright,
      onSecondary: SkpColors.canvas,
      tertiary: SkpColors.gold,
      onTertiary: SkpColors.canvas,
      error: SkpColors.danger,
      onError: Colors.white,
      surface: SkpColors.panel,
      onSurface: SkpColors.text,
      onSurfaceVariant: SkpColors.muted,
      outline: SkpColors.line,
      outlineVariant: SkpColors.line,
      surfaceContainerHighest: SkpColors.raised,
      surfaceContainerHigh: SkpColors.raised,
      surfaceContainer: SkpColors.panel,
      surfaceContainerLow: SkpColors.canvas,
      surfaceContainerLowest: SkpColors.canvas,
    );

    const textTheme = TextTheme(
      displayLarge: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 57,
        letterSpacing: -1.2,
        color: SkpColors.text,
      ),
      displayMedium: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 45,
        letterSpacing: -0.8,
        color: SkpColors.text,
      ),
      displaySmall: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 36,
        letterSpacing: -0.4,
        color: SkpColors.text,
      ),
      headlineLarge: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 32,
        letterSpacing: -0.6,
        color: SkpColors.text,
      ),
      headlineMedium: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 28,
        letterSpacing: -0.4,
        color: SkpColors.text,
      ),
      headlineSmall: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 24,
        color: SkpColors.text,
      ),
      titleLarge: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 22,
        color: SkpColors.text,
      ),
      titleMedium: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 0.15,
        color: SkpColors.text,
      ),
      titleSmall: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        letterSpacing: 0.1,
        color: SkpColors.text,
      ),
      bodyLarge: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w400,
        fontSize: 16,
        height: 1.45,
        color: SkpColors.text,
      ),
      bodyMedium: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w400,
        fontSize: 14,
        height: 1.45,
        color: SkpColors.text,
      ),
      bodySmall: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w400,
        fontSize: 12,
        height: 1.4,
        color: SkpColors.muted,
      ),
      labelLarge: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 0.2,
        color: SkpColors.text,
      ),
      labelMedium: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 0.5,
        color: SkpColors.muted,
      ),
      labelSmall: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 11,
        letterSpacing: 0.5,
        color: SkpColors.muted,
      ),
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
      borderSide: const BorderSide(color: SkpColors.line, width: SkpTokens.hairline),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: SkpFonts.family,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: SkpColors.canvas,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: SkpColors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: SkpColors.text,
        titleTextStyle: textTheme.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(SkpTokens.tapMin, SkpTokens.primaryButtonHeight),
          backgroundColor: SkpColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 18),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(SkpTokens.tapMin, SkpTokens.tapMin),
          foregroundColor: SkpColors.text,
          side: const BorderSide(color: SkpColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SkpColors.accentBright,
          minimumSize: const Size(SkpTokens.tapMin, 48),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SkpColors.raised,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: SkpColors.accentBright, width: 1.5),
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
          borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
          side: const BorderSide(color: SkpColors.line, width: SkpTokens.hairline),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SkpColors.accentBright,
      ),
      dividerTheme: const DividerThemeData(
        color: SkpColors.line,
        thickness: SkpTokens.hairline,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SkpColors.raised,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: SkpColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
        ),
      ),
    );
  }

  /// Kept for older call sites; the public kiosk is dark ATM chrome.
  static ThemeData light() => kiosk();
}
