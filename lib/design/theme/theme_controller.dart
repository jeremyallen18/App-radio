import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../tokens/colors.dart';

/// Controla el modo de tema (claro/oscuro) de toda la app.
///
/// Es un singleton simple (sin paquetes de estado extra) que:
/// - guarda la preferencia del usuario con `shared_preferences`,
/// - mantiene [AppColors] sincronizado con el modo activo (para todo el
///   código que usa `AppColors.xxx` directamente), y
/// - notifica a quien esté escuchando (ver `main.dart`) para forzar un
///   refresco de toda la UI cuando el modo cambia.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'app_theme_is_dark';

  bool _isDark = true;
  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  bool _initialized = false;

  /// Carga la preferencia guardada (si existe). Se llama una vez en
  /// `main()`, antes de `runApp`, para que la primera pantalla ya se
  /// muestre en el modo correcto.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDark = prefs.getBool(_prefsKey) ?? true;
    } catch (_) {
      // Si no hay almacenamiento disponible (p. ej. primer arranque en
      // ciertos entornos de test), se mantiene el modo oscuro por defecto.
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
      // Persistencia best-effort: si falla, el modo igual queda activo
      // para la sesión actual.
    }
  }
}
