import 'dart:async';

import 'package:flutter/material.dart';

import 'package:doliv_social/shared/widgets/appbar.dart';
import 'package:doliv_social/shared/widgets/app_menu_drawer.dart';
import 'package:doliv_social/shared/chat/chat_history.dart';
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/services/team_service.dart';
import 'package:doliv_social/services/chat_service.dart';
import 'package:doliv_social/core/session.dart';
import 'package:doliv_social/shared/auth/login.dart';
import 'package:doliv_social/shared/teams/task_board_screen.dart';
import 'package:doliv_social/shared/teams/task_form_screen.dart';

/// Pestaña "Tablero": muestra el tablero de tareas del flujo jerárquico por
/// departamento (reemplaza la vista anterior de equipos por código).
///
/// - Empleado / manager con departamento: el tablero de su departamento
///   embebido (el manager puede crear/editar/borrar; el empleado solo marca
///   como completadas).
/// - Director: la lista de departamentos; cada uno abre su tablero.
/// - Sin departamento: estado vacío.
class DashbMem extends StatefulWidget {
  /// `true` cuando es la pestaña "Tablero" del `BottomNavBar`: el shell ya
  /// pinta la `MyAppBar` y el menú fijos (no se deslizan al cambiar de
  /// pestaña). Como ruta suelta (`/DashbMem`) sí los trae.
  const DashbMem({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<DashbMem> createState() => DashbMemState();
}

class DashbMemState extends State<DashbMem> {
  UserProfile? _profile;
  List<DepartmentInfo> _departments = const [];
  bool _loading = true;
  String? _error;
  int _unreadMessages = 0;
  Timer? _unreadTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshUnread();
    _unreadTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _refreshUnread());
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshUnread() async {
    final n = await ChatService.unreadTotal();
    if (mounted && n != _unreadMessages) setState(() => _unreadMessages = n);
  }

  /// Director: nueva tarea eligiendo departamento (le cae a su manager).
  Future<void> _newDirectorTask() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(
          asDirector: true,
          departments: _departments,
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tarea enviada al manager del departamento.')),
      );
    }
  }

  void _openMessages() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatScreenfetch()),
    ).then((_) => _refreshUnread());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await secureStorage.readSecureData(key);
      final profile = await Session.fetchCurrentUser((token as String?) ?? '');
      if (profile == null) {
        if (!mounted) return;
        setState(() {
          _error = 'No se pudo cargar tu perfil.';
          _loading = false;
        });
        return;
      }
      List<DepartmentInfo> depts = const [];
      if (profile.role == AppRole.director) {
        depts = await TeamApi.listDepartments();
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _departments = depts;
        _loading = false;
      });
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el tablero.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: widget.embedded ? null : const MyAppBar(),
      drawer: widget.embedded ? null : const AppMenuDrawer(),
      floatingActionButton: _profile == null
          ? null
          : FloatingActionButton(
              tooltip: 'Mensajes',
              onPressed: _openMessages,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.chat),
                  if (_unreadMessages > 0)
                    Positioned(
                      top: -8,
                      right: -10,
                      child: UnreadCountBadge(count: _unreadMessages),
                    ),
                ],
              ),
            ),
      body: AnimatedSwitcher(
        duration: AppDurations.medium,
        child: Builder(
          key: ValueKey(
              _loading ? 'loading' : (_error != null ? 'error' : 'ready')),
          builder: (context) {
            if (_loading) return const LoadingState();
            if (_error != null) {
              return ErrorState(message: _error!, onRetry: _load);
            }

            final profile = _profile!;
            final dept = profile.department;

            // Director: lista de departamentos; cada uno abre su tablero.
            if (profile.role == AppRole.director) {
              return RefreshIndicator(
                color: AppColors.accent,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  children: [
                    SectionHeader(
                      title: 'Tablero de tareas',
                      padding: const EdgeInsets.only(bottom: 4),
                      action: FilledButton.icon(
                        onPressed:
                            _departments.isEmpty ? null : _newDirectorTask,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Nueva tarea'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandBlue,
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md, vertical: 10),
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ),
                    const Text(
                      'Encarga una tarea a un departamento: le llega a su manager, que la reparte. '
                      'O entra a un equipo para ver su tablero.',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_departments.isEmpty)
                      const EmptyState(
                        icon: Icons.groups_2_outlined,
                        title: 'Todavía no hay equipos',
                        message:
                            'Créalos desde "Equipos y departamentos" en Inicio.',
                      )
                    else
                      for (final d in _departments) ...[
                        AppCard(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TaskBoardScreen(
                                departmentId: d.id,
                                departmentName: d.name,
                                canManage: true,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              IdentityAvatar(id: d.name),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  d.name,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              AppBadge(label: '${d.employeeCount} empleados'),
                              const SizedBox(width: AppSpacing.sm),
                              const Icon(Icons.chevron_right,
                                  color: AppColors.textMuted),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                  ],
                ),
              );
            }

            // Sin departamento asignado.
            if (dept == null) {
              return const EmptyState(
                icon: Icons.checklist_rtl_outlined,
                title: 'Aún no perteneces a un equipo',
                message:
                    'Cuando el director te asigne a un departamento verás aquí sus tareas.',
              );
            }

            // Manager / empleado: tablero de su departamento embebido.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Tablero · ${dept.name}',
                        padding: const EdgeInsets.only(bottom: 4),
                      ),
                      Text(
                        profile.role == AppRole.manager
                            ? 'Crea tareas y subtareas para tu equipo y sigue su avance.'
                            : 'Revisa las tareas de tu equipo y márcalas como completadas.',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ),
                ),
                Expanded(
                  child: TaskBoardBody(
                    departmentId: dept.id,
                    canManage: profile.role == AppRole.manager,
                    currentUserId: profile.id,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      96,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
