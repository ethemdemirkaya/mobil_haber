import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider() {
    _loadFromPrefs();
  }

  ThemeMode _themeMode = ThemeMode.system;
  AppFontScale _fontScale = AppFontScale.medium;
  bool _initialized = false;

  ThemeMode get themeMode => _themeMode;
  AppFontScale get fontScale => _fontScale;
  bool get initialized => _initialized;

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(AppConstants.prefsThemeMode);
    final scaleIndex = prefs.getInt(AppConstants.prefsFontScale);
    if (modeIndex != null && modeIndex >= 0 && modeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[modeIndex];
    }
    if (scaleIndex != null &&
        scaleIndex >= 0 &&
        scaleIndex < AppFontScale.values.length) {
      _fontScale = AppFontScale.values[scaleIndex];
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.prefsThemeMode, mode.index);
  }

  Future<void> setFontScale(AppFontScale scale) async {
    if (_fontScale == scale) return;
    _fontScale = scale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.prefsFontScale, scale.index);
  }
}
