import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../design/design.dart';
import '../models/models.dart';
import '../screens/login.dart'; // globals `secureStorage` / `key` (accessToken)
import '../utils/api_config.dart';
import '../utils/session.dart';
import 'dashboard_widgets.dart';

/// Dashboard del Director: vista de la empresa completa.
///
/// Consume `GET /company/info` y `GET /department/list`, que ya existen.
/// Empleados, tareas activas a nivel empresa, desempeño, aprobaciones de
/// permisos, anuncios y reportes dependen de módulos que otras áreas
/// todavía están construyendo (ver `actualizaciones/README.md`) — mientras
/// no exista el endpoint correspondiente se muestra "Próximamente" en vez
/// de bloquear esta pantalla.
class DirectorDashboard extends StatefulWidget {
  const DirectorDashboard({super.key});

  @override
  State<DirectorDashboard> createState() => _DirectorDashboardState();
}

class _DirectorDashboardState extends State<DirectorDashboard> {
  UserProfile? _profile;
  Map<String, dynamic>? _company;
  List<DepartmentInfo> _departments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = await secureStorage.readSecureData(key);
    final headers = <String, String>{'Authorization': token ?? ''};

    Future<Map<String, dynamic>?> company() async {
      try {
        final response = await http.get(Uri.parse('$kBaseUrl/company/info'), headers: headers);
        if (response.statusCode != 200) return null;
        return jsonDecode(response.body)['company'] as Map<String, dynamic>?;
      } catch (_) {
        return null;
      }
    }

    Future<List<DepartmentInfo>> departments() async {
      try {
        final response = await http.get(Uri.parse('$kBaseUrl/department/list'), headers: headers);
        if (response.statusCode != 200) return [];
        final List<dynamic> list = jsonDecode(response.body)['departments'] ?? [];
        return list
            .map((d) => DepartmentInfo.fromJson(Map<String, dynamic>.from(d as Map)))
            .toList();
      } catch (_) {
        return [];
      }
    }

    try {
      final results = await Future.wait([
        Session.fetchCurrentUser(token ?? ''),
        company(),
        departments(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as UserProfile?;
        _company = results[1] as Map<String, dynamic>?;
        _departments = results[2] as List<DepartmentInfo>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el dashboard.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
        children: [
          DashboardHeader(
            title: _profile != null ? 'Hola, ${_profile!.name}' : 'Panel del Director',
            roleLabel: _profile?.role.label,
          ),

          const SectionHeader(title: 'Acciones rápidas'),
          const QuickTeamActions(),
          const SizedBox(height: AppSpacing.xl),

          const SectionHeader(title: 'Resumen de la empresa'),
          if (_company == null)
            const AppCard(
              child: EmptyState(
                icon: Icons.apartment_outlined,
                title: 'La empresa aún no ha sido creada',
              ),
            )
          else
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (_company!['name'] ?? '').toString(),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  if ((_company!['description'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _company!['description'].toString(),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(title: 'Departamentos (${_departments.length})'),
          if (_departments.isEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.corporate_fare_outlined,
                title: 'Todavía no hay departamentos',
              ),
            )
          else
            ..._departments.map(
              (dept) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dept.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            if ((dept.managerEmail ?? '').isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Manager: ${dept.managerEmail}',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      AppBadge(label: '${dept.employeeCount} empleados'),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),

          const ComingSoonSection(
            title: 'Empleados',
            message: 'La lista de empleados de la empresa estará disponible próximamente.',
          ),
          const ComingSoonSection(
            title: 'Tareas activas',
            message: 'El resumen de tareas a nivel empresa estará disponible próximamente.',
          ),
          const ComingSoonSection(
            title: 'Desempeño',
            message: 'Las gráficas de desempeño estarán disponibles próximamente.',
          ),
          const ComingSoonSection(
            title: 'Aprobaciones de permisos pendientes',
            message: 'Las aprobaciones de permisos estarán disponibles próximamente.',
          ),
          const ComingSoonSection(
            title: 'Anuncios de la empresa',
            message: 'Los anuncios de empresa estarán disponibles próximamente.',
          ),
          const ComingSoonSection(
            title: 'Reportes',
            message: 'Los reportes estarán disponibles próximamente.',
          ),
        ],
      ),
    );
  }
}
