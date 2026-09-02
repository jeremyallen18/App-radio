import 'package:flutter/material.dart';
import 'app_card.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';

/// Tarjeta compacta para una métrica (usada en resúmenes/dashboards):
/// ícono, valor y etiqueta.
class StatTile extends StatelessWidget {
  StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.accentColor,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final resolvedAccent = accentColor ?? AppColors.accent;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: resolvedAccent, size: 22),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
