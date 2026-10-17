import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's appearance preference across app restarts.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier({ThemeMode initialMode = ThemeMode.light})
    : super(initialMode);

  static const _storageKey = 'mechx_theme_mode';

  Future<void> toggleTheme() =>
      setThemeMode(state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);

  Future<void> setThemeMode(ThemeMode mode) async {
    // Update the UI immediately; the saved preference is written right after.
    state = mode;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _storageKey,
        mode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {
      // Storage failure should not prevent changing theme for this session.
    }
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);
