import 'package:flutter/material.dart';

/// Paleta de la app, anclada a los colores de marca extraídos de
/// `assets/logo/logo.png` (azul marino #00356F, azul medio #004691, blanco
/// #F2F2F2) y verificada contra WCAG sobre el fondo oscuro `bgBase`.
///
/// Regla de uso: [brandNavy] y [brandBlue] solo sirven como RELLENO (fondos,
/// botones sólidos) — su contraste como texto/ícono sobre [bgBase] es de
/// 1.48:1 y 1.94:1, muy por debajo del mínimo AA (4.5:1). Para texto, íconos,
/// enlaces y bordes sobre fondo oscuro usar [accent] o [accentStrong].
class AppColors {
  AppColors._();

  // Fondo y superficies
  static const Color bgBase = Color(0xFF0A1730);
  static const Color surface = Color(0xFF122240);
  static const Color surfaceBorder = Color(0xFF1E3355);

  // Marca (solo relleno — ver regla de uso arriba)
  static const Color brandNavy = Color(0xFF00356F);
  static const Color brandBlue = Color(0xFF004691);

  // Acento (texto, íconos, enlaces, bordes — AA/AAA verificado)
  static const Color accent = Color(0xFF4D93E8); // 5.65:1 AA
  static const Color accentStrong = Color(0xFF6FA9EE); // 7.29:1 AAA

  // Texto
  static const Color textPrimary = Color(0xFFF2F2F2); // 15.92:1 AAA
  static const Color textMuted = Color(0xFF9FB0CC); // 8.11:1 AAA

  // Semánticos (mismo criterio de contraste sobre bgBase)
  static const Color success = Color(0xFF52C77E); // 8.34:1 AAA
  static const Color warning = Color(0xFFE8B84D); // 9.67:1 AAA
  static const Color error = Color(0xFFEF6B6B); // 5.93:1 AA
  static const Color info = accent;

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [brandBlue, brandNavy],
  );
}
