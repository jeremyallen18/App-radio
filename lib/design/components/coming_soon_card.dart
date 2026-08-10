import 'package:flutter/material.dart';
import 'app_card.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';

/// Marcador de sección para módulos que otra área del equipo todavía está
/// construyendo (anuncios, reportes, permisos jerárquicos, recursos por
/// departamento, etc.). Evita bloquear la entrega de un dashboard mientras
/// el endpoint de origen no exista — ver `actualizaciones/README.md`.
class ComingSoonCard extends StatelessWidget {
  const ComingSoonCard({
    super.key,
    this.icon = Icons.hourglass_top_outlined,
    this.message = 'Este módulo estará disponible próximamente.',
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Próximamente',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
