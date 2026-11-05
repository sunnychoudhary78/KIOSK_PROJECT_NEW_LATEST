import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';

class AppTheme {
  static ThemeData kiosk() => light();

  /// Light theme matching Athena Wave Kiosk UI (Images 1 & 2)
  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AthenaColors.magenta,
      onPrimary: Colors.white,
      secondary: AthenaColors.cyan,
      onSecondary: Colors.white,
      tertiary: SkpColors.gold,
      onTertiary: SkpColors.text,
      error: SkpColors.danger,
      onError: Colors.white,
      surface: AthenaColors.lightSurfaceCard,
      onSurface: AthenaColors.lightTextPrimary,
      onSurfaceVariant: AthenaColors.lightTextSecondary,
      outline: AthenaColors.lightCardBorder,
      outlineVariant: AthenaColors.lightCardBorder,
      surfaceContainerHighest: Color(0xFFF0F4FA),
      surfaceContainerHigh: Color(0xFFF5F8FC),
      surfaceContainer: AthenaColors.lightSurfaceCard,
      surfaceContainerLow: AthenaColors.lightCanvas,
      surfaceContainerLowest: Colors.white,
    );

    const textTheme = TextTheme(
      displayLarge: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 57,
        letterSpacing: -1.2,
        color: Color(0xFF1B2234),
      ),
      displayMedium: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 45,
        letterSpacing: -0.8,
        color: Color(0xFF1B2234),
      ),
      displaySmall: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 36,
        letterSpacing: -0.4,
        color: Color(0xFF1B2234),
      ),
      headlineLarge: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 32,
        letterSpacing: -0.6,
        color: Color(0xFF1B2234),
      ),
      headlineMedium: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 28,
        letterSpacing: -0.4,
        color: Color(0xFF1B2234),
      ),
      headlineSmall: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 24,
        color: Color(0xFF1B2234),
      ),
      titleLarge: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 22,
        color: Color(0xFF1B2234),
      ),
      titleMedium: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 0.15,
        color: Color(0xFF1B2234),
      ),
      titleSmall: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        letterSpacing: 0.1,
        color: Color(0xFF1B2234),
      ),
      bodyLarge: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w400,
        fontSize: 16,
        height: 1.45,
        color: Color(0xFF1B2234),
      ),
      bodyMedium: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w400,
        fontSize: 14,
        height: 1.45,
        color: Color(0xFF1B2234),
      ),
      bodySmall: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w400,
        fontSize: 12,
        height: 1.4,
        color: Color(0xFF5A6578),
      ),
      labelLarge: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 0.2,
        color: Color(0xFF1B2234),
      ),
      labelMedium: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 0.5,
        color: Color(0xFF5A6578),
      ),
      labelSmall: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 11,
        letterSpacing: 0.5,
        color: Color(0xFF5A6578),
      ),
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
      borderSide: const BorderSide(color: Color(0xFFE4EDF7), width: SkpTokens.hairline),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: SkpFonts.family,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AthenaColors.lightCanvas,
      textTheme: textTheme,
      extensions: const [AthenaColors.light],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AthenaColors.lightTextPrimary,
        titleTextStyle: textTheme.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(SkpTokens.tapMin, SkpTokens.primaryButtonHeight),
          backgroundColor: AthenaColors.magenta,
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
          foregroundColor: AthenaColors.lightTextPrimary,
          side: const BorderSide(color: Color(0xFFE4EDF7)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AthenaColors.magenta,
          minimumSize: const Size(SkpTokens.tapMin, 48),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AthenaColors.magenta, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: SkpColors.danger),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: SkpColors.danger, width: 1.5),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: const Color(0xFF5A6578)),
        hintStyle: textTheme.bodyMedium?.copyWith(color: const Color(0xFF8D99AE)),
      ),
      cardTheme: CardThemeData(
        color: AthenaColors.lightSurfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
          side: const BorderSide(color: Color(0xFFE4EDF7), width: SkpTokens.hairline),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE4EDF7),
        thickness: SkpTokens.hairline,
      ),
    );
  }

  /// Dark theme matching Athena Cyber Wave Kiosk UI (Image 3)
  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AthenaColors.neonPink,
      onPrimary: Colors.white,
      secondary: AthenaColors.neonCyan,
      onSecondary: Colors.black,
      tertiary: AthenaColors.neonPurple,
      onTertiary: Colors.white,
      error: Color(0xFFFF5252),
      onError: Colors.white,
      surface: AthenaColors.darkSurfaceCard,
      onSurface: Colors.white,
      onSurfaceVariant: Color(0xFFA0A6BD),
      outline: AthenaColors.darkCardBorder,
      outlineVariant: Color(0x447445BD),
      surfaceContainerHighest: Color(0xFF2B1F5A),
      surfaceContainerHigh: Color(0xFF251A4F),
      surfaceContainer: AthenaColors.darkSurfaceCard,
      surfaceContainerLow: Color(0xFF130E2E),
      surfaceContainerLowest: AthenaColors.darkCanvas,
    );

    const textTheme = TextTheme(
      displayLarge: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 57,
        letterSpacing: -1.2,
        color: Colors.white,
      ),
      displayMedium: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 45,
        letterSpacing: -0.8,
        color: Colors.white,
      ),
      displaySmall: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 36,
        letterSpacing: -0.4,
        color: Colors.white,
      ),
      headlineLarge: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 32,
        letterSpacing: -0.6,
        color: Colors.white,
      ),
      headlineMedium: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 28,
        letterSpacing: -0.4,
        color: Colors.white,
      ),
      headlineSmall: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w700,
        fontSize: 24,
        color: Colors.white,
      ),
      titleLarge: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 22,
        color: Colors.white,
      ),
      titleMedium: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 0.15,
        color: Colors.white,
      ),
      titleSmall: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        letterSpacing: 0.1,
        color: Colors.white,
      ),
      bodyLarge: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w400,
        fontSize: 16,
        height: 1.45,
        color: Colors.white,
      ),
      bodyMedium: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w400,
        fontSize: 14,
        height: 1.45,
        color: Color(0xFFCBD2E1),
      ),
      bodySmall: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w400,
        fontSize: 12,
        height: 1.4,
        color: Color(0xFFA0A6BD),
      ),
      labelLarge: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 0.2,
        color: Colors.white,
      ),
      labelMedium: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 0.5,
        color: Color(0xFFA0A6BD),
      ),
      labelSmall: TextStyle(
        fontFamily: SkpFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 11,
        letterSpacing: 0.5,
        color: Color(0xFFA0A6BD),
      ),
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
      borderSide: const BorderSide(color: Color(0x667928CA), width: SkpTokens.hairline),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: SkpFonts.family,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AthenaColors.darkCanvas,
      textTheme: textTheme,
      extensions: const [AthenaColors.dark],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        titleTextStyle: textTheme.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(SkpTokens.tapMin, SkpTokens.primaryButtonHeight),
          backgroundColor: AthenaColors.neonPink,
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
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0x667928CA)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AthenaColors.neonPink,
          minimumSize: const Size(SkpTokens.tapMin, 48),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x66161234),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AthenaColors.neonPink, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: Color(0xFFFF5252)),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: const Color(0xFFA0A6BD)),
        hintStyle: textTheme.bodyMedium?.copyWith(color: const Color(0xFF6E7590)),
      ),
      cardTheme: CardThemeData(
        color: AthenaColors.darkSurfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SkpTokens.radiusLg),
          side: const BorderSide(color: Color(0xFF7445BD), width: SkpTokens.hairline),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x337445BD),
        thickness: SkpTokens.hairline,
      ),
    );
  }
}
