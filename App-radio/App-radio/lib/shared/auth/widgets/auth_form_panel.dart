import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';

/// Panel translúcido que agrupa los campos de un formulario de autenticación.
class AuthFormPanel extends StatelessWidget {
  const AuthFormPanel({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: AppRadius.card + 4,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// Etiqueta encima del campo (el placeholder desaparece al escribir; la
/// etiqueta no).
class AuthField extends StatelessWidget {
  const AuthField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Enlace de pie de pantalla: "¿No tienes cuenta? Regístrate".
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onTap,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$prompt ',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              TextSpan(
                text: action,
                style: TextStyle(
                  color: AppColors.accentStrong,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón de ojo para mostrar/ocultar contraseña.
class PasswordVisibilityToggle extends StatelessWidget {
  const PasswordVisibilityToggle({
    super.key,
    required this.obscured,
    required this.onToggle,
  });

  final bool obscured;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscured ? 'Mostrar contraseña' : 'Ocultar contraseña',
      icon: Icon(
        obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: AppColors.textMuted,
      ),
      onPressed: onToggle,
    );
  }
}

/// Validadores compartidos por las pantallas de autenticación.
class AuthValidators {
  AuthValidators._();

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa tu correo';
    if (!_email.hasMatch(v)) return 'Correo inválido';
    return null;
  }

  static String? password(String? value) {
    if ((value ?? '').length < 6) return 'Mínimo 6 caracteres';
    return null;
  }
}
