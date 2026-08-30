import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/shared/widgets/appbar.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/session.dart';
import 'package:doliv_social/shared/attendance/admin_attendance_screen.dart';
import 'package:doliv_social/features/dashboard/director/admin_location_screen.dart';
import 'package:doliv_social/features/dashboard/director/admin_schedule_screen.dart';
import 'package:doliv_social/features/dashboard/director/attendance_corrections_screen.dart';
import 'package:doliv_social/features/dashboard/director/attendance_report_screen.dart';
import 'package:doliv_social/features/dashboard/director/leave_calendar_screen.dart';
import 'package:doliv_social/shared/calendar/calendar_screen.dart';
import 'package:doliv_social/features/dashboard/director/admin_leave_screen.dart';
import 'package:doliv_social/features/dashboard/director/team_admin_screen.dart';
import 'package:doliv_social/shared/teams/team_detail_screen.dart';
import 'package:doliv_social/shared/auth/login.dart';
import 'package:doliv_social/features/dashboard/director/site_content/site_content_auth_gate.dart';
import 'package:doliv_social/features/dashboard/director/site_content/site_content_hub.dart';

/// Dashboard para usuarios con rol [AppRole.director]: vista general de la
/// empresa completa (todos los departamentos), no solo la propia.
///
/// Varias secciones (tareas activas, desempeño, permisos, anuncios,
/// reportes) dependen de módulos que otras áreas del equipo están
/// construyendo todavía — ver `actualizaciones/README.md`. Mientras esos
/// endpoints no existan, se muestran como "Próximamente" en vez de bloquear
/// esta entrega.
class DirectorDashboard extends StatefulWidget {
  const DirectorDashboard({super.key});

  @override
  State<DirectorDashboard> createState() => _DirectorDashboardState();
}

class _DirectorDashboardState extends State<DirectorDashboard> {
  Map<String, dynamic>? _company;
  bool _companyChecked = false;
  List<DepartmentInfo> _departments = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    final token = await secureStorage.readSecureData(key);

    Future<Map<String, dynamic>?> fetchCompany() async {
      try {
        final response = await http.get(
          Uri.parse('$kBaseUrl/company/info'),
          headers: <String, String>{'Authorization': token ?? ''},
        );
        if (response.statusCode != 200) return null;
        final decoded = jsonDecode(response.body);
        return (decoded['company'] as Map?)?.cast<String, dynamic>();
      } catch (_) {
        return null;
      }
    }

    Future<List<DepartmentInfo>> fetchDepartments() async {
      try {
        final response = await http.get(
          Uri.parse('$kBaseUrl/department/list'),
          headers: <String, String>{'Authorization': token ?? ''},
        );
        if (response.statusCode != 200) return [];
        final decoded = jsonDecode(response.body);
        final List<dynamic> raw = decoded['departments'] ?? [];
        return raw
            .map((d) => DepartmentInfo.fromJson(Map<String, dynamic>.from(d)))
            .toList();
      } catch (_) {
        return [];
      }
    }

    try {
      final results = await Future.wait([
        Session.fetchCurrentUser(token ?? ''),
        fetchCompany(),
        fetchDepartments(),
      ]);
      if (!mounted) return;
      setState(() {
        _company = results[1] as Map<String, dynamic>?;
        _companyChecked = true;
        _departments = results[2] as List<DepartmentInfo>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  int get _totalEmployees =>
      _departments.fold(0, (sum, d) => sum + d.employeeCount);

  int get _departmentsWithManager =>
      _departments.where((d) => (d.managerEmail ?? '').isNotEmpty).length;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      appBar: const MyAppBar(),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Builder(
          builder: (context) {
            if (_loading) {
              return const LoadingState();
            }
            if (_hasError) {
              return ErrorState(
                message: 'No se pudo cargar el panel del director.',
                onRetry: _load,
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                if (!_companyChecked)
                  const LoadingState()
                else if (_company == null)
                  const EmptyState(
                    icon: Icons.apartment_outlined,
                    title: 'La empresa aún no ha sido creada',
                    message:
                        'Este paso lo maneja el módulo de gestión de empresa.',
                  )
                else
                  _CompanySummaryCard(
                    company: _company!,
                    departmentCount: _departments.length,
                    employeeCount: _totalEmployees,
                    departmentsWithManager: _departmentsWithManager,
                  ),
                const SizedBox(height: AppSpacing.xl),

                SectionHeader(
                  title: 'Equipos y departamentos',
                  action: TextButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TeamAdminScreen()),
                      );
                      _load();
                    },
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Gestionar'),
                  ),
                ),
                if (_companyChecked && _departments.isEmpty)
                  EmptyState(
                    icon: Icons.groups_2_outlined,
                    title: 'Todavía no hay equipos',
                    message: 'Crea el primero desde "Gestionar".',
                    action: FilledButton(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const TeamAdminScreen()),
                        );
                        _load();
                      },
                      child: const Text('Gestionar equipos'),
                    ),
                  )
                else
                  ResponsiveCardGrid(
                    children: [
                      for (final d in _departments)
                        _DepartmentCard(
                          department: d,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TeamDetailScreen(department: d),
                              ),
                            );
                            _load();
                          },
                        ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.xl),

                const SectionHeader(title: 'Asistencia de empleados'),
                AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminAttendanceScreen()),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.how_to_reg_outlined, color: AppColors.accent),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Estado de hoy, llegadas tarde y horas de comida excedidas',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminScheduleScreen()),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.schedule, color: AppColors.accent),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Asignar y modificar horarios (entrada, salida, comida y límite)',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminLocationScreen()),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.place_outlined, color: AppColors.accent),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Definir el lugar de asistencia (geocerca para entrada y comida)',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AttendanceReportScreen()),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.summarize_outlined, color: AppColors.accent),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Reporte mensual de asistencia para nómina (exportar CSV o PDF)',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const AttendanceCorrectionsScreen()),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.rule, color: AppColors.accent),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Solicitudes de corrección de asistencia (aprobar o devolver)',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminLeaveScreen()),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.fact_check_outlined, color: AppColors.accent),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Gestión de permisos: revisar y aprobar solicitudes de empleados',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LeaveCalendarScreen()),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.calendar_month_outlined, color: AppColors.accent),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Calendario de ausencias del equipo (evitar solapamientos)',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                const SectionHeader(title: 'Contenido del sitio web'),
                AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SiteContentAuthGate(child: SiteContentHubScreen()),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.language_outlined, color: AppColors.accent),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Gestiona anuncios, eventos, patrocinadores, podcasts, '
                          'servicios, equipo y programas de radiodoliv.com',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                const SectionHeader(title: 'Calendario y eventos'),
                AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CalendarScreen()),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.calendar_month_outlined, color: AppColors.accent),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Actividades por departamento y eventos de la empresa. '
                          'Crea eventos generales o por área, con ubicación si aplica.',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                const SectionHeader(title: 'Próximamente'),
                const ComingSoonSection(
                  items: [
                    ComingSoonItem(
                      icon: Icons.task_alt,
                      label: 'Tareas activas',
                      message: 'Resumen por departamento.',
                    ),
                    ComingSoonItem(
                      icon: Icons.insights,
                      label: 'Gráficas de desempeño',
                    ),
                    ComingSoonItem(
                      icon: Icons.campaign_outlined,
                      label: 'Anuncios de empresa',
                    ),
                    ComingSoonItem(
                      icon: Icons.bar_chart,
                      label: 'Reportes',
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CompanySummaryCard extends StatelessWidget {
  const _CompanySummaryCard({
    required this.company,
    required this.departmentCount,
    required this.employeeCount,
    required this.departmentsWithManager,
  });

  final Map<String, dynamic> company;
  final int departmentCount;
  final int employeeCount;
  final int departmentsWithManager;

  @override
  Widget build(BuildContext context) {
    final String description = (company['description'] ?? '').toString();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: const Icon(Icons.apartment_outlined, color: AppColors.accent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resumen de la empresa',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      description.isNotEmpty
                          ? description
                          : (company['name']?.toString() ?? ''),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  icon: Icons.apartment_outlined,
                  value: '$departmentCount',
                  label: 'Departamentos',
                  color: AppColors.accent,
                ),
              ),
              const _SummaryDivider(),
              Expanded(
                child: _SummaryStat(
                  icon: Icons.groups_outlined,
                  value: '$employeeCount',
                  label: 'Empleados',
                  color: AppColors.success,
                ),
              ),
              const _SummaryDivider(),
              Expanded(
                child: _SummaryStat(
                  icon: Icons.badge_outlined,
                  value: '$departmentsWithManager',
                  label: 'Con manager',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 48,
      child: VerticalDivider(color: AppColors.surfaceBorder, width: AppSpacing.lg),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({required this.department, this.onTap});

  final DepartmentInfo department;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool hasManager = (department.managerEmail ?? '').isNotEmpty;
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IdentityAvatar(id: department.name),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  department.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if ((department.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    department.description!,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  hasManager
                      ? 'Manager: ${department.managerEmail}'
                      : 'Sin manager asignado',
                  style: TextStyle(
                    color: hasManager ? AppColors.textMuted : AppColors.warning,
                    fontSize: 12,
                    fontWeight: hasManager ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppBadge(label: '${department.employeeCount} empleados'),
        ],
      ),
    );
  }
}
