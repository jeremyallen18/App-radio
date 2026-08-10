import 'package:flutter/material.dart';

import '../design/design.dart';
import '../utils/Routes.dart';

/// Encabezado de saludo + badge de rol, compartido por los 3 dashboards.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key, required this.title, this.roleLabel});

  final String title;
  final String? roleLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ),
          if (roleLabel != null) AppBadge(label: roleLabel!, variant: AppBadgeVariant.info),
        ],
      ),
    );
  }
}

/// Sección con encabezado + tarjeta "Próximamente", para secciones de
/// dashboard cuyo módulo de origen todavía no existe (ver
/// actualizaciones/README.md para qué área lo está construyendo).
class ComingSoonSection extends StatelessWidget {
  const ComingSoonSection({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.hourglass_top_outlined, color: AppColors.textMuted, size: 20),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Acciones rápidas de equipos (crear/unirse), presentes hoy en
/// `HomeNav` para todos los usuarios. Se repiten aquí para que ningún rol
/// pierda acceso a esta funcionalidad al reemplazar el dashboard único.
class QuickTeamActions extends StatelessWidget {
  const QuickTeamActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        QuickActionChip(
          icon: Icons.add_circle_outline,
          label: 'Crear equipo',
          onTap: () => Navigator.pushNamed(context, MyRoutes.CreateTeamScreen),
        ),
        QuickActionChip(
          icon: Icons.group_add_outlined,
          label: 'Unirse a un equipo',
          onTap: () => Navigator.pushNamed(context, MyRoutes.jointeamRoutes),
        ),
      ],
    );
  }
}
