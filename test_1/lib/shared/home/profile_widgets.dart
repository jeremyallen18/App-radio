import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/shared/teams/teamDetail.dart';

/// Fila de metadato (ícono + texto en gris tenue) bajo la cabecera del perfil.
class ProfileMetaRow extends StatelessWidget {
  const ProfileMetaRow({
    super.key,
    required this.icon,
    required this.text,
    this.trailing,
  });

  final IconData icon;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing!],
      ],
    );
  }
}

/// Contador (valor grande + etiqueta) de la fila de estadísticas del perfil.
class ProfileStatItem extends StatelessWidget {
  const ProfileStatItem({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
      ],
    );
  }
}

/// Pestaña estilo X: subrayado de acento sobre el texto activo, resto
/// silenciado. Reparte el ancho en partes iguales entre las tres pestañas.
class ProfileTabButton extends StatelessWidget {
  const ProfileTabButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Lista de equipos a los que pertenece el usuario (pestaña "Equipos").
class ProfileTeamsList extends StatelessWidget {
  const ProfileTeamsList({super.key, required this.teams});

  final List<dynamic> teams;

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) {
      return const AppCard(
        child: Text(
          'Todavía no perteneces a ningún equipo.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < teams.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _TeamRow(team: Map<String, dynamic>.from(teams[i])),
        ],
      ],
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.team});

  final Map<String, dynamic> team;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => t_detail(team: team)),
        );
      },
      child: Row(
        children: [
          const Icon(Icons.groups_outlined, size: 20, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              team['teamName']?.toString() ?? 'Equipo',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// Tarjeta del departamento propio y puerta de entrada al directorio. Es el
/// único lugar de la app donde se busca gente, así que la acción va visible
/// en la tarjeta y no escondida en la lista de "Cuenta".
class ProfileAreaCard extends StatelessWidget {
  const ProfileAreaCard({
    super.key,
    required this.department,
    required this.onOpenDirectory,
  });

  final DepartmentInfo? department;
  final VoidCallback onOpenDirectory;

  @override
  Widget build(BuildContext context) {
    final dept = department;
    final String description = dept?.description ?? '';

    return AppCard(
      onTap: onOpenDirectory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.apartment_outlined, size: 20, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  dept?.name ?? 'Sin departamento asignado',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            dept == null
                ? 'Aun así puedes buscar a cualquier persona de Radio Doliv.'
                : description.isNotEmpty
                    ? description
                    : (dept.employeeCount == 1
                        ? '1 persona en el área'
                        : '${dept.employeeCount} personas en el área'),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.person_search_outlined, size: 18, color: AppColors.accentStrong),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  dept == null ? 'Buscar compañeros' : 'Ver y buscar compañeros de mi área',
                  style: const TextStyle(
                    color: AppColors.accentStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
            ],
          ),
        ],
      ),
    );
  }
}
