import 'package:flutter/material.dart';

import 'theme_service.dart';

/// Runtime theme mode + DB persistence ([ThemeService]).
class ThemeProvider extends ChangeNotifier {
  /// Creates a provider; call [load] after the database is open.
  ThemeProvider(this._service);

  final ThemeService _service;

  ThemeMode _themeMode = ThemeMode.dark;

  /// Current Material theme mode (dark or light only in UI).
  ThemeMode get themeMode => _themeMode;

  /// Whether the app is using the light palette.
  bool get isLight => _themeMode == ThemeMode.light;

  /// Reads [ThemeService.loadThemeMode] and notifies.
  Future<void> load() async {
    _themeMode = await _service.loadThemeMode();
    notifyListeners();
  }

  /// Updates mode and saves to the database.
  Future<void> setThemeMode(ThemeMode mode) async {
    final next = mode == ThemeMode.light ? ThemeMode.light : ThemeMode.dark;
    if (next == _themeMode) return;
    _themeMode = next;
    notifyListeners();
    await _service.saveThemeMode(next);
  }
}

/// Provides [ThemeProvider] above [MaterialApp] for `context.themeProvider`.
class ThemeProviderScope extends InheritedNotifier<ThemeProvider> {
  /// Wraps [child] with [ThemeProvider] for inherited access.
  const ThemeProviderScope({
    super.key,
    required ThemeProvider notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ThemeProvider of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ThemeProviderScope>();
    assert(scope != null, 'ThemeProviderScope not found');
    return scope!.notifier!;
  }
}

extension ThemeProviderContext on BuildContext {
  /// [ThemeProvider] from [ThemeProviderScope].
  ThemeProvider get themeProvider => ThemeProviderScope.of(this);
}
