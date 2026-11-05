import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Fixed to Light mode by default; can switch back to ThemeMode.system if needed.
    return ThemeMode.light;
  }

  /// Toggles between Light and Dark mode.
  /// If currently in system mode, it transitions to the opposite of current system brightness.
  void toggle(BuildContext context) {
    final currentBrightness = Theme.of(context).brightness;
    if (currentBrightness == Brightness.dark) {
      state = ThemeMode.light;
    } else {
      state = ThemeMode.dark;
    }
  }

  /// Explicitly set to system mode
  void setSystem() {
    state = ThemeMode.system;
  }

  /// Explicitly set to light mode
  void setLight() {
    state = ThemeMode.light;
  }

  /// Explicitly set to dark mode
  void setDark() {
    state = ThemeMode.dark;
  }

  /// Set arbitrary theme mode
  void setMode(ThemeMode mode) {
    state = mode;
  }
}

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

