import 'package:flutter/material.dart';

import '../database/database_helper.dart';

/// Persists [ThemeMode] (dark / light) in SQLite via [DatabaseHelper].
class ThemeService {
  /// Creates a service backed by [helper].
  ThemeService({DatabaseHelper? helper}) : _db = helper ?? DatabaseHelper();

  final DatabaseHelper _db;

  /// Stored value for [ThemeMode.light]; anything else resolves to dark.
  static const preferenceKey = 'theme_mode';
  static const _valueLight = 'light';
  static const _valueDark = 'dark';

  /// Loads saved mode; defaults to [ThemeMode.dark].
  Future<ThemeMode> loadThemeMode() async {
    final raw = await _db.getAppPreference(preferenceKey);
    if (raw == _valueLight) return ThemeMode.light;
    return ThemeMode.dark;
  }

  /// Persists [mode] (only light and dark are stored).
  Future<void> saveThemeMode(ThemeMode mode) async {
    final v = mode == ThemeMode.light ? _valueLight : _valueDark;
    await _db.setAppPreference(preferenceKey, v);
  }
}
