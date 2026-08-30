import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/shared/home/progress.dart';
import 'package:doliv_social/shared/home/tasks.dart';
import 'package:doliv_social/shared/home/teams.dart';
import 'package:doliv_social/shared/widgets/appbar.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/services/team_service.dart';
import 'package:doliv_social/core/Routes.dart';
import 'package:doliv_social/core/session.dart';
import 'package:doliv_social/models/attendance.dart';
import 'package:doliv_social/services/attendance_service.dart';
import 'package:doliv_social/shared/attendance/attendance_screen.dart';
import 'package:doliv_social/shared/attendance/attendance_summary_card.dart';
import 'package:doliv_social/shared/attendance/correction_request_screen.dart';
import 'package:doliv_social/shared/calendar/calendar_screen.dart';
import 'package:doliv_social/shared/leave/my_leave_screen.dart';
import 'package:doliv_social/shared/teams/task_board_screen.dart';
import 'package:doliv_social/shared/chat/chat.dart';
import 'package:doliv_social/shared/directory/colleague_directory_screen.dart';
import 'package:doliv_social/shared/auth/login.dart';

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
  AttendancePeriodSummary? _attendance;
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

    // Conteos de tareas propias desde el flujo por departamento.
    Future<({int pending, int done})?> taskCounts() async {
      try {
        final s = await DeptTaskApi.summary();
        return (pending: s.minePending, done: s.mineDone);
      } catch (_) {
        return null;
      }
    }

    Future<AttendancePeriodSummary?> attendanceSummary() async {
      try {
        return await AttendanceApi.summary();
      } catch (_) {
        return null;
      }
    }

    try {
      final results = await Future.wait([
        Session.fetchCurrentUser(token ?? ''),
        taskCounts(),
        attendanceSummary(),
      ]);
      if (!mounted) return;
      final counts = results[1] as ({int pending, int done})?;
      setState(() {
        _profile = results[0] as UserProfile?;
        _pendingCount = counts?.pending;
        _completedCount = counts?.done;
        _attendance = results[2] as AttendancePeriodSummary?;
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
                if (_profile?.department != null) ...[
                  AppBadge(label: _profile!.department!.name),
                  const SizedBox(height: AppSpacing.xl),
                ],

                const SectionHeader(title: 'Mi asistencia'),
                if (_attendance != null) ...[
                  AttendanceSummaryCard(
                    title: 'Mi resumen del mes',
                    summary: _attendance!,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AttendanceScreen()),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.fingerprint, color: AppColors.accent),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Registrar entrada, hora de comida y salida',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CorrectionRequestScreen()),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.rule, color: AppColors.accent),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Solicitar corrección de un fichaje',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MyLeaveScreen()),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.beach_access_outlined, color: AppColors.accent),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Mis permisos: vacaciones, incapacidades y permisos',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.textMuted),
                    ],
                  ),
                ),
                if (_profile?.department != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TaskBoardScreen(
                          departmentId: _profile!.department!.id,
                          departmentName: _profile!.department!.name,
                          canManage: false,
                          currentUserId: _profile!.id,
                        ),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.checklist_rtl, color: AppColors.accent),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Tareas de mi departamento: revísalas y márcalas como completadas',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),

                const SectionHeader(title: 'Mi calendario'),
                AppCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CalendarScreen()),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.calendar_month_outlined, color: AppColors.accent),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Tus actividades a entregar y los eventos de la empresa',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.textMuted),
                    ],
                  ),
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

                const SectionHeader(title: 'Acciones rápidas'),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    QuickActionChip(
                      icon: Icons.person_search_outlined,
                      label: 'Buscar compañeros',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ColleagueDirectoryScreen(me: _profile),
                        ),
                      ),
                    ),
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

                const SectionHeader(title: 'Próximamente'),
                const ComingSoonSection(
                  items: [
                    ComingSoonItem(
                      icon: Icons.campaign_outlined,
                      label: 'Mis anuncios',
                    ),
                    ComingSoonItem(
                      icon: Icons.folder_shared_outlined,
                      label: 'Recursos compartidos',
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
