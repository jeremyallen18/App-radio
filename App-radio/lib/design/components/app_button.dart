import 'package:flutter/material.dart';
import 'package:doliv_social/design/motion/app_motion.dart';
import 'package:doliv_social/design/tokens/colors.dart';
import 'package:doliv_social/design/tokens/spacing.dart';

/// Botón primario con el degradado de marca (`brandBlue → brandNavy`).
/// Reemplaza a `widgets/gradient_button.dart`. Se estira con su contenedor
/// hasta [maxWidth] y queda centrado: en móviles normales se ve casi a todo
/// el ancho, pero en pantallas anchas (tablet, horizontal) no degenera en una
/// cinta. Para un ancho distinto, pasar [maxWidth].
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 50,
    this.loading = false,
    this.maxWidth = 440,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final bool loading;

  /// Ancho máximo del botón. Por debajo de este valor ocupa el ancho que le
  /// dé el padre; por encima, se queda en [maxWidth] y se centra.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !loading;
    return Align(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: AppPressable(
          enabled: enabled,
          child: Container(
            width: double.infinity,
            height: height,
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
          ),
        ),
      ),
    );
  }
}
