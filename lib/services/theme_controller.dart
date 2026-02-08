import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ThemeController {
  static final ValueNotifier<ThemeMode> _mode = ValueNotifier(ThemeMode.light);

  static ValueListenable<ThemeMode> get listenable => _mode;
  static ThemeMode get mode => _mode.value;

  static bool get isDark => _mode.value == ThemeMode.dark;

  static void toggle() {
    _mode.value = isDark ? ThemeMode.light : ThemeMode.dark;
  }
}
