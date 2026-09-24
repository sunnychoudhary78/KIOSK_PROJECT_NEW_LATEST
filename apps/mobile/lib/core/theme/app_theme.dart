import 'package:flutter/material.dart';

/// Smart Kiosk cream-paper tokens. Inverse of the kiosk ATM-dark palette.
abstract final class SkpColors {
  static const Color accent = Color(0xFF0F6A5A);
  static const Color accentBright = Color(0xFF2EC4A0);
  static const Color cream = Color(0xFFF3EFE6);
  static const Color creamDeep = Color(0xFFEBE4D7);
  static const Color atmosphere = Color(0xFFF7F3EA);
  static const Color ink = Color(0xFF1C2430);
  static const Color panel = Color(0xFFFFFDF8);
  static const Color muted = Color(0xFF5B6573);
  static const Color line = Color(0xFFD9D1C3);
  static const Color gold = Color(0xFFE8C872);
  static const Color danger = Color(0xFF9B1C1C);
  static const Color success = Color(0xFF1B7A4A);
}

abstract final class SkpTokens {
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double hairline = 1;
  static const double buttonHeight = 54;
  static const double pageGutter = 24;
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: pageGutter);
  static const String fontFamily = 'PlusJakartaSans';
}

class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: SkpColors.accent,
      brightness: Brightness.light,
      primary: SkpColors.accent,
      onPrimary: Colors.white,
      secondary: SkpColors.accentBright,
      surface: SkpColors.cream,
      onSurface: SkpColors.ink,
      onSurfaceVariant: SkpColors.muted,
      error: SkpColors.danger,
      outline: SkpColors.line,
    );

    const textTheme = TextTheme(
      displayLarge: TextStyle(
        fontFamily: SkpTokens.fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: 57,
        letterSpacing: -1.2,
        color: SkpColors.ink,
      ),
      displayMedium: TextStyle(
        fontFamily: SkpTokens.fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: 45,
        letterSpacing: -0.8,
        color: SkpColors.ink,
      ),
      displaySmall: TextStyle(
        fontFamily: SkpTokens.fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: 36,
        letterSpacing: -1.0,
        color: SkpColors.ink,
        height: 1.05,
      ),
      headlineLarge: TextStyle(
        fontFamily: SkpTokens.fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: 32,
        letterSpacing: -0.6,
        color: SkpColors.ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: SkpTokens.fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: 28,
        letterSpacing: -0.6,
        color: SkpColors.ink,
      ),
      headlineSmall: TextStyle(
        fontFamily: SkpTokens.fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: 24,
        color: SkpColors.ink,
      ),
      titleLarge: TextStyle(
        fontFamily: SkpTokens.fontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 22,
        color: SkpColors.ink,
      ),
      titleMedium: TextStyle(
        fontFamily: SkpTokens.fontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: SkpColors.ink,
      ),
      titleSmall: TextStyle(
        fontFamily: SkpTokens.fontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: SkpColors.ink,
      ),
      bodyLarge: TextStyle(
        fontFamily: SkpTokens.fontFamily,
        fontSize: 16,
        height: 1.45,
        color: SkpColors.ink,
      ),
      bodyMedium: TextStyle(
        fontFamily: SkpTokens.fontFamily,
        fontSize: 14,
        height: 1.45,
        color: SkpColors.ink,
      ),
      bodySmall: TextStyle(
        fontFamily: SkpTokens.fontFamily,
        fontSize: 12,
        height: 1.4,
        color: SkpColors.muted,
      ),
      labelLarge: TextStyle(
        fontFamily: SkpTokens.fontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        letterSpacing: 0.2,
        color: SkpColors.ink,
      ),
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: SkpColors.line),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: SkpTokens.fontFamily,
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
          minimumSize: const Size.fromHeight(SkpTokens.buttonHeight),
          backgroundColor: SkpColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(SkpTokens.buttonHeight),
          foregroundColor: SkpColors.ink,
          side: const BorderSide(color: SkpColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SkpTokens.radiusMd),
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SkpColors.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SkpTokens.radiusSm),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SkpColors.panel,
        showDragHandle: true,
        dragHandleColor: SkpColors.line,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(SkpTokens.radiusLg)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: SkpColors.panel,
        elevation: 0,
        height: 72,
        indicatorColor: SkpColors.accent.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelLarge?.copyWith(
            fontSize: 12,
            color: states.contains(WidgetState.selected)
                ? SkpColors.accent
                : SkpColors.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? SkpColors.accent
                : SkpColors.muted,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: SkpColors.accent.withValues(alpha: 0.10),
        labelStyle: textTheme.bodySmall?.copyWith(
          color: SkpColors.accent,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
