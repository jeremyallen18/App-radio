import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._();

  ThemeController._();

  bool _isLight = false;

  bool get isLight => _isLight;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    _isLight = prefs.getBool('is_light_theme') ?? false;

    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isLight = !_isLight;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      'is_light_theme',
      _isLight,
    );

    notifyListeners();
  }
}