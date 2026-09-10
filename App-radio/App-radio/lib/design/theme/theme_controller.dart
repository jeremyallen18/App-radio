import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:doliv_social/design/tokens/colors.dart';

/// Singleton del modo de tema (claro/oscuro): persiste la preferencia, mantiene
/// [AppColors] sincronizado y notifica para refrescar la UI.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'app_theme_is_dark';

  bool _isDark = true;
  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  bool _initialized = false;

  /// Carga la preferencia guardada. Se llama una vez en `main()`, antes de
  /// `runApp`, para evitar parpadeo.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDark = prefs.getBool(_prefsKey) ?? true;
    } catch (_) {
      // Sin almacenamiento: se queda en oscuro por defecto.
    }
    AppColors.setDark(_isDark);
  }

  Future<void> toggle() => setDark(!_isDark);

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    AppColors.setDark(_isDark);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, _isDark);
    } catch (_) {
      // Persistencia best-effort; el modo igual queda activo esta sesión.
    }
  }
}
