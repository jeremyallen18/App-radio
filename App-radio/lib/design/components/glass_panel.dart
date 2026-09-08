import 'package:flutter/material.dart';
import 'package:doliv_social/design/tokens/colors.dart';

/// Panel flotante translúcido de la "cromo" de la app: el header (`MyAppBar`)
/// y la barra inferior. Navy semitransparente sobre el fondo, borde fino y
/// una sombra discreta que lo despega del contenido.
class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child, this.radius = 18});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandNavy.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
