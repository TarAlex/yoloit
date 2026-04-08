import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yoloit/core/theme/app_theme.dart';

class ThemeManager extends ChangeNotifier {
  ThemeManager._();

  static final ThemeManager instance = ThemeManager._();

  AppThemePreset _current = AppThemePreset.neonPurple;

  AppThemePreset get current => _current;
  ThemeData get theme => _current.theme;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('theme_preset') ?? AppThemePreset.neonPurple.name;
    _current = AppThemePreset.values.firstWhere(
      (t) => t.name == name,
      orElse: () => AppThemePreset.neonPurple,
    );
    notifyListeners();
  }

  Future<void> setTheme(AppThemePreset preset) async {
    _current = preset;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_preset', preset.name);
  }
}
