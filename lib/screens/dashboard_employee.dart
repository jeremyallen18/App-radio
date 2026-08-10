import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../design/design.dart';
import '../home_page/progress.dart';
import '../home_page/tasks.dart';
import '../home_page/teams.dart';
import '../models/appbar.dart';
import '../models/models.dart';
import '../utils/Routes.dart';
import '../utils/api_config.dart';
import '../utils/session.dart';
import 'chat.dart';
import 'login.dart';

/// Dashboard para usuarios con rol [AppRole.employee] (o cuando el rol no
/// se pudo determinar — ver `RoleDashboardRouter`). Reutiliza los widgets ya
/// existentes en `lib/home_page/*` (tareas, progreso, equipos) en vez de
/// duplicar su lógica de red.
///
/// "Mi calendario", "Mis anuncios", "Recursos compartidos" y "Solicitudes
/// de permiso" (por departamento) dependen de módulos que otras áreas
/// todavía están construyendo — se muestran como "Próximamente" mientras
/// tanto (ver `actualizaciones/README.md`).
class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
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

  double get _completionRatio {
    final pending = _pendingCount ?? 0;
    final completed = _completedCount ?? 0;
    final total = pending + completed;
    return total == 0 ? 0 : completed / total;
  }

  void _openTasks() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const TaskContainer()));
  }

  void _openProgress() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const ProgressChart()));
  }

  void _openTeams() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const TeamPage()));
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
                message: 'No se pudo cargar tu panel.',
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
                Text(
                  'Hola, ${_profile?.name ?? ''}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    AppBadge(
                      label: _profile?.role.label ?? AppRole.employee.label,
                      variant: AppBadgeVariant.info,
                    ),
                    if (_profile?.department != null)
                      AppBadge(label: _profile!.department!.name),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                SectionHeader(
                  title: 'Mis tareas',
                  action: TextButton(
                    onPressed: _openTasks,
                    child: const Text('Ver todas'),
                  ),
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
                const SizedBox(height: AppSpacing.xl),

                SectionHeader(
                  title: 'Mi progreso',
                  action: TextButton(
                    onPressed: _openProgress,
                    child: const Text('Ver gráfica'),
                  ),
                ),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                        child: LinearProgressIndicator(
                          value: (_pendingCount == null && _completedCount == null)
                              ? null
                              : _completionRatio,
                          minHeight: 8,
                          backgroundColor: AppColors.surfaceBorder,
                          valueColor: const AlwaysStoppedAnimation(AppColors.success),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${(_completionRatio * 100).round()}% de tus tareas completadas',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                const SectionHeader(title: 'Mi calendario'),
                const ComingSoonCard(
                  icon: Icons.calendar_month_outlined,
                  message: 'El calendario de tareas y turnos estará disponible próximamente.',
                ),
                const SizedBox(height: AppSpacing.xl),

                const SectionHeader(title: 'Mis anuncios'),
                const ComingSoonCard(
                  icon: Icons.campaign_outlined,
                  message: 'Estará disponible junto con el módulo de anuncios.',
                ),
                const SizedBox(height: AppSpacing.xl),

                const SectionHeader(title: 'Chat del departamento'),
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
                const SizedBox(height: AppSpacing.xl),

                const SectionHeader(title: 'Recursos compartidos'),
                const ComingSoonCard(
                  icon: Icons.folder_shared_outlined,
                  message: 'Estará disponible junto con el módulo de recursos por departamento.',
                ),
                const SizedBox(height: AppSpacing.xl),

                const SectionHeader(title: 'Solicitudes de permiso'),
                const ComingSoonCard(
                  icon: Icons.event_busy_outlined,
                  message:
                      'Estará disponible junto con el módulo de permisos jerárquicos. Mientras '
                      'tanto, puedes solicitarlo desde el detalle de tu equipo.',
                ),
                const SizedBox(height: AppSpacing.xl),

                const SectionHeader(title: 'Acciones rápidas'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    QuickActionChip(
                      icon: Icons.groups_outlined,
                      label: 'Mis equipos',
                      onTap: _openTeams,
                    ),
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
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
