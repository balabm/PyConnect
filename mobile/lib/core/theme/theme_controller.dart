import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls the app's brightness mode (light/dark/system) with persistence.
/// The user's choice is stored in secure storage (native) or
/// SharedPreferences (web) so it survives app restarts.

enum ThemeModePreference { system, light, dark }

class ThemeController extends StateNotifier<ThemeModePreference> {
  ThemeController(this._storage) : super(ThemeModePreference.system) {
    _load();
  }

  final FlutterSecureStorage _storage;
  static const _key = 'theme_mode';

  Future<void> _load() async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString(_key);
        state = switch (saved) {
          'light' => ThemeModePreference.light,
          'dark' => ThemeModePreference.dark,
          _ => ThemeModePreference.system,
        };
      } catch (_) {}
      return;
    }

    try {
      final saved = await _storage.read(key: _key);
      state = switch (saved) {
        'light' => ThemeModePreference.light,
        'dark' => ThemeModePreference.dark,
        _ => ThemeModePreference.system,
      };
    } catch (_) {}
  }

  Future<void> setMode(ThemeModePreference mode) async {
    state = mode;
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_key, mode.name);
      } catch (_) {}
      return;
    }

    try {
      await _storage.write(key: _key, value: mode.name);
    } catch (_) {}
  }

  ThemeMode toMaterialMode() {
    return switch (state) {
      ThemeModePreference.system => ThemeMode.system,
      ThemeModePreference.light => ThemeMode.light,
      ThemeModePreference.dark => ThemeMode.dark,
    };
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeModePreference>((ref) {
  return ThemeController(const FlutterSecureStorage());
});
