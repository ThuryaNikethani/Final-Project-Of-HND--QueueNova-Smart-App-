import 'package:flutter/material.dart';

/// App-wide display preferences for the officer web dashboard — theme and
/// font scale. Language uses easy_localization's own `context.setLocale()`
/// directly (same mechanism the citizen app's `LanguageProvider` wraps),
/// so it doesn't need a slot here.
class WebPreferencesProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  double _fontScale = 1.0;

  ThemeMode get themeMode => _themeMode;
  double get fontScale => _fontScale;

  static const Map<String, ThemeMode> themeModeByName = {
    'Light': ThemeMode.light,
    'Dark': ThemeMode.dark,
    'System Default': ThemeMode.system,
  };

  static const Map<String, double> fontScaleByName = {
    'Small': 0.9,
    'Medium': 1.0,
    'Large': 1.15,
  };

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void setThemeModeByName(String name) {
    final mode = themeModeByName[name];
    if (mode != null) setThemeMode(mode);
  }

  void setFontScale(double scale) {
    if (_fontScale == scale) return;
    _fontScale = scale;
    notifyListeners();
  }

  void setFontScaleByName(String name) {
    final scale = fontScaleByName[name];
    if (scale != null) setFontScale(scale);
  }
}
