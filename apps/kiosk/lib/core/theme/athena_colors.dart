import 'package:flutter/material.dart';

/// Athena Brand & Wave Theme Color Palette for Light and Dark modes.
class AthenaColors extends ThemeExtension<AthenaColors> {
  const AthenaColors({
    required this.canvas,
    required this.surfaceCard,
    required this.cardBorder,
    required this.cardGlow,
    required this.textPrimary,
    required this.textSecondary,
    required this.accentMagenta,
    required this.accentCyan,
    required this.accentPurple,
    required this.topBarPillBg,
    required this.topBarPillBorder,
    required this.waveTopColor1,
    required this.waveTopColor2,
    required this.waveBottomColor1,
    required this.waveBottomColor2,
    required this.dotColor,
    required this.isDark,
  });

  final Color canvas;
  final Color surfaceCard;
  final Color cardBorder;
  final Color cardGlow;
  final Color textPrimary;
  final Color textSecondary;
  final Color accentMagenta;
  final Color accentCyan;
  final Color accentPurple;
  final Color topBarPillBg;
  final Color topBarPillBorder;
  final Color waveTopColor1;
  final Color waveTopColor2;
  final Color waveBottomColor1;
  final Color waveBottomColor2;
  final Color dotColor;
  final bool isDark;

  // Primary Brand Accents
  static const Color magenta = Color(0xFFE6007A);
  static const Color neonPink = Color(0xFFFF1075);
  static const Color cyan = Color(0xFF00B4D8);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color purple = Color(0xFF7928CA);
  static const Color neonPurple = Color(0xFF9D4EDD);

  // Static Light Tokens (matching exact spec: #abd5fd, #cfe3fc, #ebf1fd)
  static const Color lightCanvas = Color(0xFFEBF1FD);
  static const Color lightSurfaceCard = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFE2EBF5);
  static const Color lightCardGlow = Color(0x0C1B2B4F);
  static const Color lightTextPrimary = Color(0xFF1B2234);
  static const Color lightTextSecondary = Color(0xFF5A6578);
  static const Color lightTopBarPillBg = Color(0xFFFFFFFF);
  static const Color lightTopBarPillBorder = Color(0xFFD8E4F2);
  static const Color lightWaveTop1 = Color(0xFFCFE3FC);
  static const Color lightWaveTop2 = Color(0xFFEBF1FD);
  static const Color lightWaveBottom1 = Color(0xFFCFE3FC);
  static const Color lightWaveBottom2 = Color(0xFFE8DDF8);
  static const Color lightDotColor = Color(0x65ABD5FD);

  // Static Dark Tokens (matching exact spec: #050925, #211747, #7445bd)
  static const Color darkCanvas = Color(0xFF050925);
  static const Color darkSurfaceCard = Color(0xFF211747);
  static const Color darkCardBorder = Color(0xFF7445BD);
  static const Color darkCardGlow = Color(0x2E8B35FF); // rgba(139, 53, 255, 0.18)
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFA0A6BD);
  static const Color darkTopBarPillBg = Color(0xFF1C143F);
  static const Color darkTopBarPillBorder = Color(0xFF7445BD);
  static const Color darkWaveTop1 = Color(0x3500E5FF);
  static const Color darkWaveTop2 = Color(0x357928CA);
  static const Color darkWaveBottom1 = Color(0x50FF007F);
  static const Color darkWaveBottom2 = Color(0x3532104F);
  static const Color darkDotColor = Color(0x3000E5FF);

  /// Light Mode Palette (Images 1 & 2)
  static const light = AthenaColors(
    canvas: lightCanvas,
    surfaceCard: lightSurfaceCard,
    cardBorder: lightCardBorder,
    cardGlow: lightCardGlow,
    textPrimary: lightTextPrimary,
    textSecondary: lightTextSecondary,
    accentMagenta: magenta,
    accentCyan: cyan,
    accentPurple: purple,
    topBarPillBg: lightTopBarPillBg,
    topBarPillBorder: lightTopBarPillBorder,
    waveTopColor1: lightWaveTop1,
    waveTopColor2: lightWaveTop2,
    waveBottomColor1: lightWaveBottom1,
    waveBottomColor2: lightWaveBottom2,
    dotColor: lightDotColor,
    isDark: false,
  );

  /// Dark Mode Palette (Image 3)
  static const dark = AthenaColors(
    canvas: darkCanvas,
    surfaceCard: darkSurfaceCard,
    cardBorder: darkCardBorder,
    cardGlow: darkCardGlow,
    textPrimary: darkTextPrimary,
    textSecondary: darkTextSecondary,
    accentMagenta: neonPink,
    accentCyan: neonCyan,
    accentPurple: neonPurple,
    topBarPillBg: darkTopBarPillBg,
    topBarPillBorder: darkTopBarPillBorder,
    waveTopColor1: darkWaveTop1,
    waveTopColor2: darkWaveTop2,
    waveBottomColor1: darkWaveBottom1,
    waveBottomColor2: darkWaveBottom2,
    dotColor: darkDotColor,
    isDark: true,
  );

  @override
  AthenaColors copyWith({
    Color? canvas,
    Color? surfaceCard,
    Color? cardBorder,
    Color? cardGlow,
    Color? textPrimary,
    Color? textSecondary,
    Color? accentMagenta,
    Color? accentCyan,
    Color? accentPurple,
    Color? topBarPillBg,
    Color? topBarPillBorder,
    Color? waveTopColor1,
    Color? waveTopColor2,
    Color? waveBottomColor1,
    Color? waveBottomColor2,
    Color? dotColor,
    bool? isDark,
  }) {
    return AthenaColors(
      canvas: canvas ?? this.canvas,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      cardBorder: cardBorder ?? this.cardBorder,
      cardGlow: cardGlow ?? this.cardGlow,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accentMagenta: accentMagenta ?? this.accentMagenta,
      accentCyan: accentCyan ?? this.accentCyan,
      accentPurple: accentPurple ?? this.accentPurple,
      topBarPillBg: topBarPillBg ?? this.topBarPillBg,
      topBarPillBorder: topBarPillBorder ?? this.topBarPillBorder,
      waveTopColor1: waveTopColor1 ?? this.waveTopColor1,
      waveTopColor2: waveTopColor2 ?? this.waveTopColor2,
      waveBottomColor1: waveBottomColor1 ?? this.waveBottomColor1,
      waveBottomColor2: waveBottomColor2 ?? this.waveBottomColor2,
      dotColor: dotColor ?? this.dotColor,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  AthenaColors lerp(ThemeExtension<AthenaColors>? other, double t) {
    if (other is! AthenaColors) return this;
    return AthenaColors(
      canvas: Color.lerp(canvas, other.canvas, t) ?? canvas,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t) ?? surfaceCard,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t) ?? cardBorder,
      cardGlow: Color.lerp(cardGlow, other.cardGlow, t) ?? cardGlow,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      accentMagenta: Color.lerp(accentMagenta, other.accentMagenta, t) ?? accentMagenta,
      accentCyan: Color.lerp(accentCyan, other.accentCyan, t) ?? accentCyan,
      accentPurple: Color.lerp(accentPurple, other.accentPurple, t) ?? accentPurple,
      topBarPillBg: Color.lerp(topBarPillBg, other.topBarPillBg, t) ?? topBarPillBg,
      topBarPillBorder: Color.lerp(topBarPillBorder, other.topBarPillBorder, t) ?? topBarPillBorder,
      waveTopColor1: Color.lerp(waveTopColor1, other.waveTopColor1, t) ?? waveTopColor1,
      waveTopColor2: Color.lerp(waveTopColor2, other.waveTopColor2, t) ?? waveTopColor2,
      waveBottomColor1: Color.lerp(waveBottomColor1, other.waveBottomColor1, t) ?? waveBottomColor1,
      waveBottomColor2: Color.lerp(waveBottomColor2, other.waveBottomColor2, t) ?? waveBottomColor2,
      dotColor: Color.lerp(dotColor, other.dotColor, t) ?? dotColor,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension AthenaColorsContext on BuildContext {
  AthenaColors get athenaColors =>
      Theme.of(this).extension<AthenaColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AthenaColors.dark
          : AthenaColors.light);
}
