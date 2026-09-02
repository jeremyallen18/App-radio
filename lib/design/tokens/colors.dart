import 'package:flutter/material.dart';

/// Paleta de la app, anclada a los colores de marca extraídos de
/// `assets/logo/logo.png` (azul marino #00356F, azul medio #004691, blanco
/// #F2F2F2).
///
/// La app soporta modo claro y modo oscuro. [AppColors] expone siempre el
/// color correcto para el modo actual a través de getters: en vez de
/// `static const Color bgBase = ...` cada token es ahora
/// `static Color get bgBase => ...`, resuelto según [isDark]. Esto permite
/// que TODA la UI (que ya usa `AppColors.xxx` directamente) cambie de
/// aspecto sin tener que tocar cada pantalla, apenas [ThemeController]
/// actualiza el modo activo.
///
/// Regla de uso: [brandNavy] y [brandBlue] solo sirven como RELLENO (fondos,
/// botones sólidos) — su contraste como texto/ícono es bajo en ambos modos.
/// Para texto, íconos, enlaces y bordes usar [accent] o [accentStrong].
class AppColors {
  AppColors._();

  // Modo actual. Lo actualiza [ThemeController]; por defecto oscuro para
  // no cambiar el comportamiento previo de la app.
  static bool _isDark = true;
  static bool get isDark => _isDark;
  static void setDark(bool value) => _isDark = value;

  // ---------------------------------------------------------------------
  // Paleta oscura (la original de la app)
  // ---------------------------------------------------------------------
  static const Color _darkBgBase = Color(0xFF0A1730);
  static const Color _darkSurface = Color(0xFF122240);
  static const Color _darkSurfaceBorder = Color(0xFF1E3355);

  static const Color _darkAccent = Color(0xFF4D93E8); // 5.65:1 AA sobre _darkBgBase
  static const Color _darkAccentStrong = Color(0xFF6FA9EE); // 7.29:1 AAA

  static const Color _darkTextPrimary = Color(0xFFF2F2F2); // 15.92:1 AAA
  static const Color _darkTextMuted = Color(0xFF9FB0CC); // 8.11:1 AAA

  static const Color _darkSuccess = Color(0xFF52C77E); // 8.34:1 AAA
  static const Color _darkWarning = Color(0xFFE8B84D); // 9.67:1 AAA
  static const Color _darkError = Color(0xFFEF6B6B); // 5.93:1 AA

  // ---------------------------------------------------------------------
  // Paleta clara
  // ---------------------------------------------------------------------
  static const Color _lightBgBase = Color(0xFFF3F5F9);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceBorder = Color(0xFFDCE2ED);

  static const Color _lightAccent = Color(0xFF004691); // brandBlue, ~8.6:1 sobre blanco
  static const Color _lightAccentStrong = Color(0xFF00356F); // brandNavy, ~11.9:1

  static const Color _lightTextPrimary = Color(0xFF0A1730); // ~16.7:1 sobre blanco
  static const Color _lightTextMuted = Color(0xFF4C596E); // ~7.2:1 sobre blanco

  static const Color _lightSuccess = Color(0xFF1E7A45); // ~5.3:1 sobre blanco
  static const Color _lightWarning = Color(0xFF8A6300); // ~5.1:1 sobre blanco
  static const Color _lightError = Color(0xFFC22A2A); // ~5.6:1 sobre blanco

  // ---------------------------------------------------------------------
  // Tokens públicos (dinámicos según el modo activo)
  // ---------------------------------------------------------------------
  static Color get bgBase => _isDark ? _darkBgBase : _lightBgBase;
  static Color get surface => _isDark ? _darkSurface : _lightSurface;
  static Color get surfaceBorder => _isDark ? _darkSurfaceBorder : _lightSurfaceBorder;

  // Marca (solo relleno — ver regla de uso arriba). No dependen del modo.
  static const Color brandNavy = Color(0xFF00356F);
  static const Color brandBlue = Color(0xFF004691);

  static Color get accent => _isDark ? _darkAccent : _lightAccent;
  static Color get accentStrong => _isDark ? _darkAccentStrong : _lightAccentStrong;

  static Color get textPrimary => _isDark ? _darkTextPrimary : _lightTextPrimary;
  static Color get textMuted => _isDark ? _darkTextMuted : _lightTextMuted;

  static Color get success => _isDark ? _darkSuccess : _lightSuccess;
  static Color get warning => _isDark ? _darkWarning : _lightWarning;
  static Color get error => _isDark ? _darkError : _lightError;
  static Color get info => accent;

  static LinearGradient get buttonGradient => const LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [brandBlue, brandNavy],
  );

  // ---------------------------------------------------------------------
  // Paletas "congeladas" (independientes del modo activo). Las usa
  // [AppTheme] para construir `ThemeData` claro y oscuro por separado,
  // sin depender de [_isDark].
  // ---------------------------------------------------------------------
  static const AppPalette darkPalette = AppPalette(
    bgBase: _darkBgBase,
    surface: _darkSurface,
    surfaceBorder: _darkSurfaceBorder,
    accent: _darkAccent,
    accentStrong: _darkAccentStrong,
    textPrimary: _darkTextPrimary,
    textMuted: _darkTextMuted,
    success: _darkSuccess,
    warning: _darkWarning,
    error: _darkError,
  );

  static const AppPalette lightPalette = AppPalette(
    bgBase: _lightBgBase,
    surface: _lightSurface,
    surfaceBorder: _lightSurfaceBorder,
    accent: _lightAccent,
    accentStrong: _lightAccentStrong,
    textPrimary: _lightTextPrimary,
    textMuted: _lightTextMuted,
    success: _lightSuccess,
    warning: _lightWarning,
    error: _lightError,
  );
}

/// Snapshot inmutable de todos los tokens de color para un modo (claro u
/// oscuro). Usado por [AppTheme] para construir cada `ThemeData` sin
/// depender del modo "activo" global de [AppColors].
class AppPalette {
  const AppPalette({
    required this.bgBase,
    required this.surface,
    required this.surfaceBorder,
    required this.accent,
    required this.accentStrong,
    required this.textPrimary,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.error,
  });

  final Color bgBase;
  final Color surface;
  final Color surfaceBorder;
  final Color accent;
  final Color accentStrong;
  final Color textPrimary;
  final Color textMuted;
  final Color success;
  final Color warning;
  final Color error;
}
