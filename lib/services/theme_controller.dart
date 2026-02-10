import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  static final ValueNotifier<ThemeMode> _mode = ValueNotifier(ThemeMode.light);
  static const String _themeKey = 'theme_mode';

  static ValueListenable<ThemeMode> get listenable => _mode;
  static ThemeMode get mode => _mode.value;

  static bool get isDark => _mode.value == ThemeMode.dark;

  /// Initialize and load saved theme preference
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);
    
    if (savedTheme == 'dark') {
      _mode.value = ThemeMode.dark;
    } else if (savedTheme == 'light') {
      _mode.value = ThemeMode.light;
    }
    // If null, defaults to light (already set)
  }

  static Future<void> toggle() async {
    final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
    _mode.value = newMode;
    
    // Save preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, newMode == ThemeMode.dark ? 'dark' : 'light');
  }
}
