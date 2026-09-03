import 'package:flutter/material.dart';

import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/core/Routes.dart';
import 'package:doliv_social/shared/home/progress.dart';
import 'package:doliv_social/shared/home/tasks.dart';
import 'package:doliv_social/shared/home/teams.dart';
import 'package:doliv_social/shared/attendance/attendance_screen.dart';
import 'package:doliv_social/shared/attendance/admin_attendance_screen.dart';
import 'package:doliv_social/shared/attendance/correction_request_screen.dart';
import 'package:doliv_social/shared/calendar/calendar_screen.dart';
import 'package:doliv_social/shared/leave/my_leave_screen.dart';
import 'package:doliv_social/shared/teams/task_board_screen.dart';
import 'package:doliv_social/shared/directory/colleague_directory_screen.dart';
import 'package:doliv_social/features/dashboard/director/attendance_corrections_screen.dart';
import 'package:doliv_social/features/dashboard/director/attendance_report_screen.dart';
import 'package:doliv_social/features/dashboard/director/admin_location_screen.dart';
import 'package:doliv_social/features/dashboard/director/admin_schedule_screen.dart';
import 'package:doliv_social/features/dashboard/director/leave_calendar_screen.dart';
import 'package:doliv_social/features/dashboard/director/admin_leave_screen.dart';
import 'package:doliv_social/features/dashboard/director/team_admin_screen.dart';
import 'package:doliv_social/features/dashboard/director/site_content/site_content_auth_gate.dart';
import 'package:doliv_social/features/dashboard/director/site_content/site_content_hub.dart';

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

/// Arma las secciones del menú hamburguesa según el rol del usuario.
///
/// Recibe del drawer las dos formas de navegar que necesitan las entradas
/// ([onPushScreen] para pantallas construidas al vuelo, [onPushNamed] para
/// rutas con nombre); el drawer se encarga de cerrar el menú antes de invocar
/// el `onTap`.
List<AppMenuSection> appMenuSectionsForRole(
  UserProfile profile, {
  required void Function(Widget screen) onPushScreen,
  required void Function(String routeName) onPushNamed,
}) {
  switch (profile.role) {
    case AppRole.director:
      return _directorSections(onPushScreen);
    case AppRole.manager:
      return _managerSections(profile, onPushScreen);
    case AppRole.employee:
      return _employeeSections(profile, onPushScreen, onPushNamed);
  }
}

List<AppMenuSection> _employeeSections(
  UserProfile profile,
  void Function(Widget) push,
  void Function(String) pushNamed,
) {
  final department = profile.department;
  return [
    AppMenuSection(
      title: 'Mi asistencia',
      entries: [
        AppMenuEntry(
          icon: Icons.fingerprint,
          title: 'Registrar asistencia',
          subtitle: 'Entrada, hora de comida y salida',
          onTap: () => push(const AttendanceScreen()),
        ),
        AppMenuEntry(
          icon: Icons.rule,
          title: 'Solicitar corrección de un fichaje',
          onTap: () => push(const CorrectionRequestScreen()),
        ),
        AppMenuEntry(
          icon: Icons.beach_access_outlined,
          title: 'Mis permisos',
          subtitle: 'Vacaciones, incapacidades y permisos',
          onTap: () => push(const MyLeaveScreen()),
        ),
        if (department != null)
          AppMenuEntry(
            icon: Icons.checklist_rtl,
            title: 'Tareas de mi departamento',
            subtitle: 'Revísalas y márcalas como completadas',
            onTap: () => push(
              TaskBoardScreen(
                departmentId: department.id,
                departmentName: department.name,
                canManage: false,
                currentUserId: profile.id,
              ),
            ),
          ),
      ],
    ),
    AppMenuSection(
      title: 'Mi calendario',
      entries: [
        AppMenuEntry(
          icon: Icons.calendar_month_outlined,
          title: 'Mi calendario',
          subtitle: 'Tus actividades a entregar y los eventos de la empresa',
          onTap: () => push(const CalendarScreen()),
        ),
      ],
    ),
    AppMenuSection(
      title: 'Mis tareas',
      entries: [
        AppMenuEntry(
          icon: Icons.check_circle_outline,
          title: 'Todas mis tareas',
          onTap: () => push(const TaskContainer()),
        ),
        AppMenuEntry(
          icon: Icons.insights,
          title: 'Mi progreso',
          onTap: () => push(const ProgressChart()),
        ),
      ],
    ),
    AppMenuSection(
      title: 'Equipos',
      entries: [
        AppMenuEntry(
          icon: Icons.person_search_outlined,
          title: 'Buscar compañeros',
          onTap: () => push(ColleagueDirectoryScreen(me: profile)),
        ),
        AppMenuEntry(
          icon: Icons.groups_outlined,
          title: 'Mis equipos',
          onTap: () => push(const TeamPage()),
        ),
        AppMenuEntry(
          icon: Icons.add_circle_outline,
          title: 'Crear equipo',
          onTap: () => pushNamed(MyRoutes.CreateTeamScreen),
        ),
        AppMenuEntry(
          icon: Icons.group_add_outlined,
          title: 'Unirse a un equipo',
          onTap: () => pushNamed(MyRoutes.jointeamRoutes),
        ),
      ],
    ),
    const AppMenuSection(
      title: 'Próximamente',
      entries: [
        AppMenuEntry(
          icon: Icons.folder_shared_outlined,
          title: 'Recursos compartidos',
          enabled: false,
          trailingLabel: 'Próximamente',
        ),
      ],
    ),
  ];
}

List<AppMenuSection> _managerSections(
  UserProfile profile,
  void Function(Widget) push,
) {
  final department = profile.department;
  return [
    AppMenuSection(
      title: 'Mi departamento',
      entries: [
        AppMenuEntry(
          icon: Icons.person_search_outlined,
          title: 'Empleados del departamento',
          onTap: () => push(ColleagueDirectoryScreen(me: profile)),
        ),
      ],
    ),
    AppMenuSection(
      title: 'Asistencia',
      entries: [
        AppMenuEntry(
          icon: Icons.fingerprint,
          title: 'Registrar mi asistencia',
          subtitle: 'Entrada, hora de comida y salida',
          onTap: () => push(const AttendanceScreen()),
        ),
        AppMenuEntry(
          icon: Icons.beach_access_outlined,
          title: 'Mis permisos',
          subtitle: 'Solicitar vacaciones, incapacidades y permisos',
          onTap: () => push(const MyLeaveScreen()),
        ),
        AppMenuEntry(
          icon: Icons.how_to_reg_outlined,
          title: 'Asistencia del equipo',
          subtitle: 'Revisa el estado de asistencia de tu departamento',
          onTap: () => push(const AdminAttendanceScreen()),
        ),
        AppMenuEntry(
          icon: Icons.rule,
          title: 'Correcciones del equipo',
          subtitle: 'Solicitudes de corrección de fichajes',
          onTap: () => push(const AttendanceCorrectionsScreen()),
        ),
        AppMenuEntry(
          icon: Icons.summarize_outlined,
          title: 'Reporte mensual',
          subtitle: 'Exportar CSV o PDF',
          onTap: () => push(const AttendanceReportScreen()),
        ),
      ],
    ),
    AppMenuSection(
      title: 'Calendario',
      entries: [
        AppMenuEntry(
          icon: Icons.calendar_month_outlined,
          title: 'Calendario',
          subtitle: 'Alterna entre tu calendario y el de tu departamento',
          onTap: () => push(const CalendarScreen()),
        ),
      ],
    ),
    AppMenuSection(
      title: 'Tareas del departamento',
      entries: [
        if (department != null)
          AppMenuEntry(
            icon: Icons.checklist_rtl,
            title: 'Tablero de tareas',
            subtitle: 'Crear, asignar y seguir el avance',
            onTap: () => push(
              TaskBoardScreen(
                departmentId: department.id,
                departmentName: department.name,
                canManage: true,
              ),
            ),
          )
        else
          const AppMenuEntry(
            icon: Icons.checklist_rtl,
            title: 'Tablero de tareas',
            subtitle: 'Disponible cuando tengas un departamento asignado',
            enabled: false,
          ),
      ],
    ),
    const AppMenuSection(
      title: 'Próximamente',
      entries: [
        AppMenuEntry(
          icon: Icons.folder_shared_outlined,
          title: 'Recursos del departamento',
          enabled: false,
          trailingLabel: 'Próximamente',
        ),
      ],
    ),
  ];
}

List<AppMenuSection> _directorSections(void Function(Widget) push) {
  return [
    AppMenuSection(
      title: 'Equipos y departamentos',
      entries: [
        AppMenuEntry(
          icon: Icons.settings_outlined,
          title: 'Gestionar equipos y departamentos',
          subtitle: 'Crear departamentos y asignar managers',
          onTap: () => push(const TeamAdminScreen()),
        ),
      ],
    ),
    AppMenuSection(
      title: 'Asistencia de empleados',
      entries: [
        AppMenuEntry(
          icon: Icons.how_to_reg_outlined,
          title: 'Estado de asistencia',
          subtitle: 'Estado de hoy, llegadas tarde y comidas excedidas',
          onTap: () => push(const AdminAttendanceScreen()),
        ),
        AppMenuEntry(
          icon: Icons.schedule,
          title: 'Horarios',
          subtitle: 'Asignar y modificar entrada, salida, comida y límite',
          onTap: () => push(const AdminScheduleScreen()),
        ),
        AppMenuEntry(
          icon: Icons.place_outlined,
          title: 'Lugar de asistencia',
          subtitle: 'Geocerca para entrada y comida',
          onTap: () => push(const AdminLocationScreen()),
        ),
        AppMenuEntry(
          icon: Icons.summarize_outlined,
          title: 'Reporte mensual para nómina',
          subtitle: 'Exportar CSV o PDF',
          onTap: () => push(const AttendanceReportScreen()),
        ),
        AppMenuEntry(
          icon: Icons.rule,
          title: 'Solicitudes de corrección',
          subtitle: 'Aprobar o devolver correcciones de asistencia',
          onTap: () => push(const AttendanceCorrectionsScreen()),
        ),
        AppMenuEntry(
          icon: Icons.fact_check_outlined,
          title: 'Gestión de permisos',
          subtitle: 'Revisar y aprobar solicitudes de empleados',
          onTap: () => push(const AdminLeaveScreen()),
        ),
        AppMenuEntry(
          icon: Icons.calendar_month_outlined,
          title: 'Calendario de ausencias',
          subtitle: 'Evitar solapamientos en el equipo',
          onTap: () => push(const LeaveCalendarScreen()),
        ),
      ],
    ),
    AppMenuSection(
      title: 'Contenido del sitio web',
      entries: [
        AppMenuEntry(
          icon: Icons.language_outlined,
          title: 'Contenido de radiodoliv.com',
          subtitle: 'Anuncios, eventos, patrocinadores, podcasts, servicios, '
              'equipo y programas',
          onTap: () => push(
            const SiteContentAuthGate(child: SiteContentHubScreen()),
          ),
        ),
      ],
    ),
    AppMenuSection(
      title: 'Calendario y eventos',
      entries: [
        AppMenuEntry(
          icon: Icons.calendar_month_outlined,
          title: 'Calendario y eventos',
          subtitle: 'Actividades por departamento y eventos de la empresa',
          onTap: () => push(const CalendarScreen()),
        ),
      ],
    ),
    const AppMenuSection(
      title: 'Próximamente',
      entries: [
        AppMenuEntry(
          icon: Icons.task_alt,
          title: 'Tareas activas',
          subtitle: 'Resumen por departamento',
          enabled: false,
          trailingLabel: 'Próximamente',
        ),
        AppMenuEntry(
          icon: Icons.insights,
          title: 'Gráficas de desempeño',
          enabled: false,
          trailingLabel: 'Próximamente',
        ),
        AppMenuEntry(
          icon: Icons.bar_chart,
          title: 'Reportes',
          enabled: false,
          trailingLabel: 'Próximamente',
        ),
      ],
    ),
  ];
}
