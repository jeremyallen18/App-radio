import 'package:flutter/material.dart';

/// Paleta de la app: **azul, blanco y negro** como únicos colores de marca /
/// superficie / texto. En modo oscuro domina el **azul marino** (fondos y
/// bordes son azul, no negro); el negro puro casi no se usa. En modo claro
/// domina el blanco con acentos en azul y texto casi negro.
/// success/warning/error se conservan en verde/ámbar/rojo porque codifican
/// estados funcionales (aprobado/pendiente/rechazado, prioridad, validación)
/// en ~60 pantallas y perder ese código de color degradaría la lectura rápida.
/// Los tokens son getters que resuelven según [isDark], así toda la UI cambia
/// de modo sin tocar cada pantalla. [brandNavy]/[brandBlue] son el relleno
/// sólido de marca (dos tonos de azul); para texto/íconos usar
/// [accent]/[accentStrong].
class AppColors {
  AppColors._();

  // Modo actual (lo actualiza [ThemeController]); oscuro por defecto.
  static bool _isDark = true;
  static bool get isDark => _isDark;
  static void setDark(bool value) => _isDark = value;

  // paleta oscura — azul marino dominante (el negro queda solo como matiz de
  // profundidad, no como fondo real; ver feedback del usuario 2026-09-10).
  static const Color _darkBgBase = Color(0xFF0A1428);
  static const Color _darkSurface = Color(0xFF122347);
  static const Color _darkSurfaceBorder = Color(0xFF2A4374);

  static const Color _darkAccent =
      Color(0xFF60A5FA); // blue-400, ~6.6:1 AA sobre _darkBgBase
  static const Color _darkAccentStrong = Color(0xFF93C5FD); // blue-300, ~9:1

  static const Color _darkTextPrimary = Color(0xFFF5F7FA); // blanco, ~17:1
  static const Color _darkTextMuted = Color(0xFF9FB3D9); // azul-gris claro, ~8:1

  static const Color _darkSuccess =
      Color(0xFF10B981); // emerald-500 "en vivo"/éxito, ~6.8:1 sobre bg
  static const Color _darkWarning = Color(0xFFFBBF24); // amber-400, ~11:1
  static const Color _darkError = Color(0xFFFB7185); // rose-400, ~7:1

  // paleta clara — blanco / azul-gris muy pálido
  static const Color _lightBgBase = Color(0xFFF3F6FB);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceBorder = Color(0xFFD7E1EF);

  static const Color _lightAccent =
      Color(0xFF1D4ED8); // blue-700, ~8.6:1 sobre blanco
  static const Color _lightAccentStrong =
      Color(0xFF1E3A8A); // blue-900, ~12:1

  static const Color _lightTextPrimary =
      Color(0xFF05070B); // negro azulado, ~19:1 sobre blanco
  static const Color _lightTextMuted = Color(0xFF48566B); // azul-gris, ~8:1

  static const Color _lightSuccess =
      Color(0xFF047857); // emerald-700, ~5.2:1 sobre blanco AA
  static const Color _lightWarning = Color(0xFFB45309); // amber-700, ~5.1:1
  static const Color _lightError = Color(0xFFBE123C); // rose-700, ~6.4:1

  // tokens públicos (dinámicos según el modo activo)
  static Color get bgBase => _isDark ? _darkBgBase : _lightBgBase;
  static Color get surface => _isDark ? _darkSurface : _lightSurface;
  static Color get surfaceBorder =>
      _isDark ? _darkSurfaceBorder : _lightSurfaceBorder;

  // Marca / relleno sólido (no depende del modo). Dos tonos de azul puro:
  // [brandBlue] = blue-600 (primario), [brandNavy] = blue-900 (fin del
  // degradado / hover, casi negro-azulado).
  static const Color brandNavy = Color(0xFF1E3A8A);
  static const Color brandBlue = Color(0xFF2563EB);

  static Color get accent => _isDark ? _darkAccent : _lightAccent;
  static Color get accentStrong =>
      _isDark ? _darkAccentStrong : _lightAccentStrong;

  static Color get textPrimary =>
      _isDark ? _darkTextPrimary : _lightTextPrimary;
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

  // Texto/íconos sobre fondos de marca (azul sólido): fijos en blanco en
  // ambos modos, nunca [textPrimary]/[textMuted].
  static const Color onBrand = Colors.white;
  static const Color onBrandMuted = Colors.white70;
  // Acento que se distingue del blanco puro sobre fondo de marca azul.
  static const Color onBrandAccent = Color(0xFFBFDBFE); // blue-200

  // Paletas "congeladas" (por modo), para que [AppTheme] arme cada `ThemeData`.
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

/// Snapshot inmutable de los tokens de color de un modo, para [AppTheme].
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
