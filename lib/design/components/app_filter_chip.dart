import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';

/// Chip de filtro con estado: a diferencia de [QuickActionChip], que dispara
/// una acción, este representa una opción que está activa o no (el área que
/// se está viendo en el directorio, por ejemplo).
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Número opcional al lado de la etiqueta (cuántas personas hay en esa área).
  final int? count;

  @override
  Widget build(BuildContext context) {
    final Color border = selected ? AppColors.accent : AppColors.surfaceBorder;
    final Color text = selected ? AppColors.textPrimary : AppColors.textMuted;

    return Material(
      color: selected ? AppColors.brandNavy : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: text,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? AppColors.accentStrong : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
