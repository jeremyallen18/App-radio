import 'package:flutter/material.dart';
import 'app_card.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';

/// Un módulo pendiente dentro de [ComingSoonSection].
class ComingSoonItem {
  const ComingSoonItem({required this.icon, required this.label, this.message});

  final IconData icon;
  final String label;
  final String? message;
}

/// Agrupa varios módulos "próximamente" en una sola tarjeta compacta, en vez
/// de una [AppCard] grande por cada uno. Así el dashboard prioriza visualmente
/// lo que ya funciona hoy y deja lo pendiente como una referencia rápida al
/// final, sin obligar a hacer scroll entre bloques inertes.
class ComingSoonSection extends StatelessWidget {
  const ComingSoonSection({super.key, required this.items});

  final List<ComingSoonItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.lg),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.surfaceBorder),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(items[i].icon, size: 18, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].label,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (items[i].message != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            items[i].message!,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const _SoonBadge(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SoonBadge extends StatelessWidget {
  const _SoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceBorder,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: const Text(
        'Pronto',
        style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
