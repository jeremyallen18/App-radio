import 'package:flutter/material.dart';
import '../tokens/breakpoints.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';

/// Botón primario con el degradado de marca (`brandBlue → brandNavy`).
/// Reemplaza a `widgets/gradient_button.dart`.
///
/// En móvil ocupa todo el ancho disponible; en escritorio se limita a
/// [AppBreakpoints.maxButtonWidth] para que no se estire de borde a borde.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 50,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !loading;
    final bool isDesktop = AppBreakpoints.isDesktop(context);
    return Container(
      height: height,
      width: isDesktop ? AppBreakpoints.maxButtonWidth : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        gradient: AppColors.buttonGradient,
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.brandBlue.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: enabled ? onPressed : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
