import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localePrefsKey = 'skp_citizen_locale';

class AppLocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    Future.microtask(_restore);
    return const Locale('en');
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_localePrefsKey);
      if (code == 'hi' || code == 'en') {
        state = Locale(code!);
      }
    } catch (_) {
      // Keep English default.
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localePrefsKey, locale.languageCode);
  }
}

final appLocaleProvider =
    NotifierProvider<AppLocaleNotifier, Locale>(AppLocaleNotifier.new);
