import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final languageProvider = StateNotifierProvider<LanguageNotifier, Locale>(
  (ref) => LanguageNotifier(),
);

class LanguageNotifier extends StateNotifier<Locale> {
  LanguageNotifier({Locale initialLocale = const Locale('en')})
    : super(initialLocale);

  static const _key = 'mechx_language';

  Future<void> setLanguage(String code) async {
    final locale = code == 'ur' ? const Locale('ur') : const Locale('en');
    state = locale;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_key, locale.languageCode);
    } catch (_) {
      // The selected language still applies for this session if storage fails.
    }
  }

  Future<void> toggle() =>
      setLanguage(state.languageCode == 'en' ? 'ur' : 'en');
}
