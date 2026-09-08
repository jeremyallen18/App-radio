import 'package:flutter/material.dart';

import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/core/Routes.dart';
import 'package:doliv_social/shared/home/tasks.dart';
import 'package:doliv_social/shared/home/teams.dart';
import 'package:doliv_social/shared/home/progress.dart';
import 'package:doliv_social/shared/teams/task_board_screen.dart';
import 'package:doliv_social/shared/directory/colleague_directory_screen.dart';

/// Una entrada navegable del menú hamburguesa.
class AppMenuEntry {
  const AppMenuEntry({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.enabled = true,
    this.trailingLabel,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Se ejecuta después de cerrar el drawer. Dejar en `null` (con [enabled]
  /// en `false`) para entradas de "Próximamente".
  final VoidCallback? onTap;
  final bool enabled;

  /// Texto corto a la derecha (p. ej. "Próximamente"). Si es `null` se
  /// muestra un chevron cuando la entrada está habilitada.
  final String? trailingLabel;
}

/// Un grupo de entradas del menú bajo un título.
class AppMenuSection {
  const AppMenuSection({required this.title, required this.entries});

  final String title;
  final List<AppMenuEntry> entries;
}

/// Arma las secciones del menú hamburguesa.
///
/// Este clon recortado expone solo Directorio, Tareas/Equipos y las
/// funciones marcadas como "Próximamente"; las secciones son iguales para
/// todos los roles.
List<AppMenuSection> appMenuSectionsForRole(
  UserProfile profile, {
  required void Function(Widget screen) onPushScreen,
  required void Function(String routeName) onPushNamed,
}) {
  final department = profile.department;

  return [
    AppMenuSection(
      title: 'Compañeros',
      entries: [
        AppMenuEntry(
          icon: Icons.person_search_outlined,
          title: 'Buscar compañeros',
          subtitle: 'Directorio con búsqueda por área',
          onTap: () => onPushScreen(ColleagueDirectoryScreen(me: profile)),
        ),
      ],
    ),
    AppMenuSection(
      title: 'Mis tareas',
      entries: [
        AppMenuEntry(
          icon: Icons.check_circle_outline,
          title: 'Todas mis tareas',
          onTap: () => onPushScreen(const TaskContainer()),
        ),
        AppMenuEntry(
          icon: Icons.insights,
          title: 'Mi progreso',
          subtitle: 'Gráficas de avance y ritmo de la semana',
          onTap: () => onPushScreen(const ProgressChart()),
        ),
        if (department != null)
          AppMenuEntry(
            icon: Icons.checklist_rtl,
            title: 'Tareas de mi departamento',
            subtitle: 'Revísalas y márcalas como completadas',
            onTap: () => onPushScreen(
              TaskBoardScreen(
                departmentId: department.id,
                departmentName: department.name,
                canManage: profile.role != AppRole.employee,
                currentUserId: profile.id,
              ),
            ),
          ),
      ],
    ),
    AppMenuSection(
      title: 'Equipos',
      entries: [
        AppMenuEntry(
          icon: Icons.groups_outlined,
          title: 'Mis equipos',
          onTap: () => onPushScreen(const TeamPage()),
        ),
        AppMenuEntry(
          icon: Icons.add_circle_outline,
          title: 'Crear equipo',
          onTap: () => onPushNamed(MyRoutes.CreateTeamScreen),
        ),
        AppMenuEntry(
          icon: Icons.group_add_outlined,
          title: 'Unirse a un equipo',
          onTap: () => onPushNamed(MyRoutes.jointeamRoutes),
        ),
      ],
    ),
    const AppMenuSection(
      title: 'Próximamente',
      entries: [
        AppMenuEntry(
          icon: Icons.fingerprint,
          title: 'Registro de entrada y salida',
          enabled: false,
          trailingLabel: 'Próximamente',
        ),
        AppMenuEntry(
          icon: Icons.language_outlined,
          title: 'Edición de la página web',
          enabled: false,
          trailingLabel: 'Próximamente',
        ),
        AppMenuEntry(
          icon: Icons.radio_outlined,
          title: 'Sintonización "En vivo"',
          enabled: false,
          trailingLabel: 'Próximamente',
        ),
      ],
    ),
  ];
}
