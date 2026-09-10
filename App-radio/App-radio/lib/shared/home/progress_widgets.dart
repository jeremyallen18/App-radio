import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';

/// Punto de color + etiqueta para las leyendas de las gráficas de progreso.
class ProgressLegendDot extends StatelessWidget {
  const ProgressLegendDot(
      {super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ],
    );
  }
}
