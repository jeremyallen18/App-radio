import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';

enum PasswordStrength {
  empty,
  weak,
  medium,
  strong;

  /// Regla simple y explicable: menos de 6 caracteres siempre es débil (es el
  /// mínimo que exige el backend). A partir de ahí suma puntos por longitud,
  /// dígitos, mezcla de mayúsculas/minúsculas y símbolos.
  static PasswordStrength evaluate(String password) {
    if (password.isEmpty) return PasswordStrength.empty;
    if (password.length < 6) return PasswordStrength.weak;
    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'\d').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password) && RegExp(r'[A-Z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
    if (score <= 1) return PasswordStrength.weak;
    if (score <= 3) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  String get label {
    switch (this) {
      case PasswordStrength.empty:
        return '';
      case PasswordStrength.weak:
        return 'Débil';
      case PasswordStrength.medium:
        return 'Aceptable';
      case PasswordStrength.strong:
        return 'Fuerte';
    }
  }

  Color get color {
    switch (this) {
      case PasswordStrength.empty:
        return AppColors.surfaceBorder;
      case PasswordStrength.weak:
        return AppColors.error;
      case PasswordStrength.medium:
        return AppColors.warning;
      case PasswordStrength.strong:
        return AppColors.success;
    }
  }

  /// Barras encendidas de 3.
  int get bars => index; // empty=0, weak=1, medium=2, strong=3
}

/// Tres barras + etiqueta bajo el campo de contraseña. Con la contraseña
/// vacía se muestra apagado (sin texto) para no regañar antes de escribir.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final strength = PasswordStrength.evaluate(password);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, left: AppSpacing.xs, right: AppSpacing.xs),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 4,
                decoration: BoxDecoration(
                  color: i < strength.bars ? strength.color : AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i < 2) const SizedBox(width: AppSpacing.xs),
          ],
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 64,
            child: Text(
              strength.label,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: strength == PasswordStrength.empty ? AppColors.textMuted : strength.color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
