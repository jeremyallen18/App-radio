import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../design/design.dart';
import '../models/appbar.dart';
import '../models/models.dart';
import '../utils/api_config.dart';
import '../utils/session.dart';
import 'login.dart';

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
  UserProfile? _profile;
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
        _profile = results[0] as UserProfile?;
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
                _Header(profile: _profile),
                const SizedBox(height: AppSpacing.xl),

                const SectionHeader(title: 'Resumen de la empresa'),
                if (!_companyChecked)
                  const LoadingState()
                else if (_company == null)
                  const EmptyState(
                    icon: Icons.apartment_outlined,
                    title: 'La empresa aún no ha sido creada',
                    message:
                        'Este paso lo maneja el módulo de gestión de empresa.',
                  )
                else ...[
                  Text(
                    _company!['name']?.toString() ?? '',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  if ((_company!['description'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _company!['description'].toString(),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          icon: Icons.apartment_outlined,
                          value: '${_departments.length}',
                          label: 'Departamentos',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: StatTile(
                          icon: Icons.groups_outlined,
                          value: '$_totalEmployees',
                          label: 'Empleados',
                          accentColor: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: StatTile(
                          icon: Icons.badge_outlined,
                          value: '$_departmentsWithManager',
                          label: 'Con manager',
                          accentColor: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),

                const SectionHeader(title: 'Departamentos'),
                if (_companyChecked && _departments.isEmpty)
                  const EmptyState(
                    icon: Icons.apartment_outlined,
                    title: 'Todavía no hay departamentos',
                    message: 'Créalos desde el módulo de gestión de departamentos.',
                  )
                else
                  ResponsiveCardGrid(
                    children: [
                      for (final d in _departments) _DepartmentCard(department: d),
                    ],
                  ),
                const SizedBox(height: AppSpacing.xl),

                const SectionHeader(title: 'Tareas activas'),
                const ComingSoonCard(
                  icon: Icons.task_alt,
                  message:
                      'El resumen de tareas por departamento llegará con el flujo jerárquico de tareas.',
                ),
                const SizedBox(height: AppSpacing.lg),

                const SectionHeader(title: 'Gráficas de desempeño'),
                const ComingSoonCard(
                  icon: Icons.insights,
                  message: 'Estará disponible junto con el módulo de reportes y analítica.',
                ),
                const SizedBox(height: AppSpacing.lg),

                const SectionHeader(title: 'Aprobaciones de permisos pendientes'),
                const ComingSoonCard(
                  icon: Icons.fact_check_outlined,
                  message: 'Estará disponible junto con el módulo de permisos jerárquicos.',
                ),
                const SizedBox(height: AppSpacing.lg),

                const SectionHeader(title: 'Anuncios de empresa'),
                const ComingSoonCard(
                  icon: Icons.campaign_outlined,
                  message: 'Estará disponible junto con el módulo de anuncios.',
                ),
                const SizedBox(height: AppSpacing.lg),

                const SectionHeader(title: 'Reportes'),
                const ComingSoonCard(
                  icon: Icons.bar_chart,
                  message: 'Estará disponible junto con el módulo de reportes y analítica.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola, ${profile?.name ?? ''}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 6),
              AppBadge(
                label: profile?.role.label ?? AppRole.director.label,
                variant: AppBadgeVariant.info,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({required this.department});

  final DepartmentInfo department;

  @override
  Widget build(BuildContext context) {
    final bool hasManager = (department.managerEmail ?? '').isNotEmpty;
    return AppCard(
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
