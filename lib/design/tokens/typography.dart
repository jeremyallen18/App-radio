import 'package:flutter/material.dart';
import 'colors.dart';

/// Escala tipográfica de 6 pasos, mapeada sobre [TextTheme] de Material 3.
/// Pesos tomados de la pantalla ya migrada `login.dart` (w800 títulos,
/// w500 cuerpo).
class AppTypography {
  AppTypography._();

  static const String? fontFamily = null; // fuente del sistema por ahora

  static TextTheme textTheme(Color base, Color muted) {
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: base,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: base,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: base,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: base,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: muted,
      ),
    );
  }

  static final TextTheme dark = textTheme(AppColors.textPrimary, AppColors.textMuted);
}
