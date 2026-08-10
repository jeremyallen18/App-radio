import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../design/design.dart';
import '../models/models.dart';
import '../screens/login.dart'; // globals `secureStorage` / `key` (accessToken)
import '../utils/api_config.dart';
import '../utils/session.dart';
import 'dashboard_widgets.dart';

/// Dashboard del Manager: resumen del departamento propio
/// (`UserProfile.department`, ya incluido en `GET /user/me`).
///
/// Empleados del departamento, recursos, anuncios y chat dependen de
/// módulos que otras áreas todavía están construyendo (ver
/// `actualizaciones/README.md`) — mientras tanto se muestran como
/// "Próximamente". Las tareas reutilizan los mismos endpoints de conteo
/// que ya usan `home_page_home.dart`/`profile.dart` (aún no hay un
/// endpoint de tareas agregadas por departamento).
class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  UserProfile? _profile;
  int? _pendingCount;
  int? _completedCount;
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

    Future<int?> count(String path, String field) async {
      try {
        final response = await http.get(Uri.parse('$kBaseUrl/$path'), headers: headers);
        if (response.statusCode != 200) return null;
        final List<dynamic> list = jsonDecode(response.body)[field] ?? [];
        return list.length;
      } catch (_) {
        return null;
      }
    }

    try {
      final results = await Future.wait([
        Session.fetchCurrentUser(token ?? ''),
        count('team/incompleteTasks', 'incompleteTasks'),
        count('team/completedTasks', 'completedTasks'),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as UserProfile?;
        _pendingCount = results[1] as int?;
        _completedCount = results[2] as int?;
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

    final department = _profile?.department;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
        children: [
          DashboardHeader(
            title: _profile != null ? 'Hola, ${_profile!.name}' : 'Panel del Manager',
            roleLabel: _profile?.role.label,
          ),

          const SectionHeader(title: 'Acciones rápidas'),
          const QuickTeamActions(),
          const SizedBox(height: AppSpacing.xl),

          const SectionHeader(title: 'Resumen del departamento'),
          if (department == null)
            const AppCard(
              child: EmptyState(
                icon: Icons.apartment_outlined,
                title: 'Todavía no tienes un departamento asignado',
                message: 'Pide al director que te asigne a uno.',
              ),
            )
          else
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    department.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  if ((department.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      department.description!,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  AppBadge(label: '${department.employeeCount} empleados'),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xl),

          const ComingSoonSection(
            title: 'Empleados del departamento',
            message: 'La lista de empleados del departamento estará disponible próximamente.',
          ),

          const SectionHeader(title: 'Tareas'),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.pending_actions,
                  value: _pendingCount?.toString() ?? '—',
                  label: 'Pendientes',
                  accentColor: AppColors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatTile(
                  icon: Icons.check_circle_outline,
                  value: _completedCount?.toString() ?? '—',
                  label: 'Completadas',
                  accentColor: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          const ComingSoonSection(
            title: 'Recursos del departamento',
            message: 'Los recursos del departamento estarán disponibles próximamente.',
          ),
          const ComingSoonSection(
            title: 'Anuncios del departamento',
            message: 'Los anuncios del departamento estarán disponibles próximamente.',
          ),
          const ComingSoonSection(
            title: 'Chat',
            message: 'El chat del departamento estará disponible próximamente.',
          ),
        ],
      ),
    );
  }
}
