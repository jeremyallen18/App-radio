import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/shared/teams/team_detail.dart';

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
          MaterialPageRoute(builder: (context) => TeamDetailView(team: team)),
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

/// Cuerpo de la pestaña "Vista general" del perfil de un director: bloque de
/// acceso, contadores de organización y accesos directos. Los demás roles ven
/// [ProfileAreaCard] en su lugar.
class DirectorOverviewTab extends StatelessWidget {
  const DirectorOverviewTab({
    super.key,
    required this.areasCount,
    required this.collaboratorsCount,
    required this.onOpenAreas,
    required this.onOpenDirectory,
    required this.onOpenReports,
    required this.onOpenSettings,
  });

  final int? areasCount;
  final int? collaboratorsCount;
  final VoidCallback onOpenAreas;
  final VoidCallback onOpenDirectory;
  final VoidCallback onOpenReports;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RoundIcon(icon: Icons.public, filled: true),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Acceso global',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tienes acceso a todas las áreas y colaboradores de Radio Doliv.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(title: 'Organización'),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.apartment_outlined,
                value: areasCount?.toString() ?? '—',
                label: 'Áreas',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatTile(
                icon: Icons.groups_outlined,
                value: collaboratorsCount?.toString() ?? '—',
                label: 'Colaboradores',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(title: 'Acciones rápidas'),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _DirectorActionCard(
                  icon: Icons.apartment_outlined,
                  title: 'Áreas',
                  subtitle: 'Consulta y administra todas las áreas.',
                  onTap: onOpenAreas,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _DirectorActionCard(
                  icon: Icons.groups_outlined,
                  title: 'Colaboradores',
                  subtitle: 'Busca y consulta a cualquier miembro.',
                  onTap: onOpenDirectory,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _DirectorActionCard(
                  icon: Icons.insights_outlined,
                  title: 'Reportes',
                  subtitle: 'Visualiza el progreso general.',
                  onTap: onOpenReports,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _DirectorActionCard(
                  icon: Icons.settings_outlined,
                  title: 'Configuración',
                  subtitle: 'Administración de la organización.',
                  onTap: onOpenSettings,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ícono en círculo: tenue por defecto, o relleno de acento (`filled`) para
/// el bloque destacado.
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, this.filled = false});

  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: filled ? 1 : 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 22,
        color: filled ? AppColors.bgBase : AppColors.accent,
      ),
    );
  }
}

/// Tarjeta de acceso directo (ícono + chevron arriba, título y subtítulo
/// abajo) de la cuadrícula "Acciones rápidas" del director.
class _DirectorActionCard extends StatelessWidget {
  const _DirectorActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RoundIcon(icon: icon),
              const Spacer(),
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
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
