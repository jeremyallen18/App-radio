import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../design/design.dart';
import '../models/appbar.dart';
import '../models/models.dart';
import '../utils/api_config.dart';
import '../utils/session.dart';
import 'chat.dart';
import 'login.dart';

/// Dashboard para usuarios con rol [AppRole.manager]: resumen del
/// departamento propio (`UserProfile.department`, ya viene en `/user/me`).
///
/// "Empleados del departamento" (listado), "Recursos" y "Anuncios" del
/// departamento dependen de módulos que otras áreas todavía están
/// construyendo — se muestran como "Próximamente" mientras tanto (ver
/// `actualizaciones/README.md`).
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

    Future<int?> count(String path, String field) async {
      try {
        final response = await http.get(
          Uri.parse('$kBaseUrl/$path'),
          headers: <String, String>{'Authorization': token ?? ''},
        );
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
        _hasError = true;
        _loading = false;
      });
    }
  }

  void _openChat() {
    final name = _profile?.email ?? '';
    Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(name)));
  }

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
                message: 'No se pudo cargar el panel del manager.',
                onRetry: _load,
              );
            }

            final department = _profile?.department;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                Text(
                  'Hola, ${_profile?.name ?? ''}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 6),
                AppBadge(
                  label: _profile?.role.label ?? AppRole.manager.label,
                  variant: AppBadgeVariant.info,
                ),
                const SizedBox(height: AppSpacing.xl),

                const SectionHeader(title: 'Mi departamento'),
                if (department == null)
                  const EmptyState(
                    icon: Icons.apartment_outlined,
                    title: 'Aún no tienes un departamento asignado',
                    message: 'Pide al director que te asigne a un departamento.',
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
                            fontSize: 16,
                          ),
                        ),
                        if ((department.description ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            department.description!,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        StatTile(
                          icon: Icons.groups_outlined,
                          value: '${department.employeeCount}',
                          label: 'Empleados en el departamento',
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),

                const SectionHeader(title: 'Empleados del departamento'),
                const ComingSoonCard(
                  icon: Icons.groups_outlined,
                  message:
                      'El listado detallado de empleados llegará con el módulo de gestión de departamentos.',
                ),
                const SizedBox(height: AppSpacing.xl),

                SectionHeader(
                  title: 'Tareas',
                  action: const AppBadge(label: 'Vista personal'),
                ),
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
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'El desglose de tareas de todo el departamento llegará con el '
                  'flujo jerárquico de tareas.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.xl),

                const SectionHeader(title: 'Recursos del departamento'),
                const ComingSoonCard(
                  icon: Icons.folder_shared_outlined,
                  message: 'Estará disponible junto con el módulo de recursos por departamento.',
                ),
                const SizedBox(height: AppSpacing.xl),

                const SectionHeader(title: 'Anuncios del departamento'),
                const ComingSoonCard(
                  icon: Icons.campaign_outlined,
                  message: 'Estará disponible junto con el módulo de anuncios.',
                ),
                const SizedBox(height: AppSpacing.xl),

                const SectionHeader(title: 'Chat'),
                AppCard(
                  onTap: _openChat,
                  child: Row(
                    children: [
                      const Icon(Icons.chat_outlined, color: AppColors.accent),
                      const SizedBox(width: AppSpacing.md),
                      const Expanded(
                        child: Text(
                          'Abrir chat de la empresa',
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Por ahora es el chat general de la empresa; el chat por '
                  'departamento llega con su módulo correspondiente.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
