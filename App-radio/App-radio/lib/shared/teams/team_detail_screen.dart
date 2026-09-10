import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/services/team_service.dart';
import 'package:doliv_social/shared/directory/colleague_profile_screen.dart';
import 'package:doliv_social/shared/teams/task_board_screen.dart';
import 'package:doliv_social/shared/teams/user_picker_sheet.dart';

/// Detalle de un equipo (departamento) para el director: asignar/cambiar
/// manager, agregar y quitar miembros, y abrir el tablero de tareas.
class TeamDetailScreen extends StatefulWidget {
  const TeamDetailScreen({super.key, required this.department});
  final DepartmentInfo department;

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  late DepartmentInfo _dept;
  List<UserProfile> _members = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dept = widget.department;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        TeamApi.listDepartments(),
        TeamApi.members(_dept.id),
      ]);
      if (!mounted) return;
      final fresh = (results[0] as List<DepartmentInfo>)
          .cast<DepartmentInfo?>()
          .firstWhere((d) => d?.id == _dept.id, orElse: () => null);
      setState(() {
        if (fresh != null) _dept = fresh;
        _members = results[1] as List<UserProfile>;
        _loading = false;
      });
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _run(Future<void> Function() op, String ok) async {
    setState(() => _busy = true);
    try {
      await op();
      await _load();
      if (mounted) {
        setState(() => _busy = false);
        _snack(ok);
      }
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.message);
    }
  }

  Future<void> _assignManager() async {
    final u = await pickPerson(context, title: 'Elegir manager del equipo');
    if (u == null) return;
    await _run(
      () => TeamApi.assignManager(_dept.id, email: u.email),
      'Manager asignado.',
    );
  }

  Future<void> _addEmployee() async {
    final u = await pickPerson(context, title: 'Agregar empleado al equipo');
    if (u == null) return;
    await _run(
      () => TeamApi.addEmployee(_dept.id, email: u.email),
      'Empleado agregado.',
    );
  }

  Future<void> _removeEmployee(UserProfile u) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Quitar del equipo',
      message: '¿Quitar a ${u.name} de este equipo?',
      confirmLabel: 'Quitar',
      danger: true,
    );
    if (ok != true) return;
    await _run(
      () => TeamApi.removeEmployee(_dept.id, email: u.email),
      'Empleado removido.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final managerEmail = _dept.managerEmail ?? '';
    final employees =
        _members.where((u) => u.role == AppRole.employee).toList();

    return AppScaffold(
      appBar: AppBar(leading: const BackButton(), title: Text(_dept.name)),
      body: Builder(
        builder: (context) {
          if (_loading) return const LoadingState();
          if (_error != null) {
            return ErrorState(message: _error!, onRetry: _load);
          }
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
                if ((_dept.description ?? '').isNotEmpty) ...[
                  Text(_dept.description!,
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  const SizedBox(height: AppSpacing.lg),
                ],
                const SectionHeader(title: 'Manager'),
                AppCard(
                  child: Row(
                    children: [
                      Icon(Icons.badge_outlined, color: AppColors.accent),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          managerEmail.isEmpty
                              ? 'Sin manager asignado'
                              : managerEmail,
                          style: TextStyle(
                            color: managerEmail.isEmpty
                                ? AppColors.warning
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _assignManager,
                        child:
                            Text(managerEmail.isEmpty ? 'Asignar' : 'Cambiar'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'Miembros (${employees.length})',
                  action: TextButton.icon(
                    onPressed: _busy ? null : _addEmployee,
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Agregar'),
                  ),
                ),
                if (employees.isEmpty)
                  const EmptyState(
                    icon: Icons.groups_outlined,
                    title: 'Aún no hay empleados en este equipo',
                  )
                else
                  ...employees.map((u) => AppCard(
                        // Abre la ficha del compañero (donde el director edita
                        // el número de control).
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ColleagueProfileScreen(
                                colleagueId: u.id,
                                preview: u,
                                viewerIsDirector: true,
                              ),
                            ),
                          );
                          _load();
                        },
                        child: Row(
                          children: [
                            IdentityAvatar(id: u.name),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(u.name,
                                      style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600)),
                                  Text(u.headline,
                                      style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12)),
                                  Text(u.controlNumberLabel,
                                      style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed:
                                  _busy ? null : () => _removeEmployee(u),
                              icon: Icon(Icons.person_remove_alt_1,
                                  color: AppColors.error),
                              tooltip: 'Quitar del equipo',
                            ),
                          ],
                        ),
                      )),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'VER TAREAS DEL EQUIPO',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TaskBoardScreen(
                        departmentId: _dept.id,
                        departmentName: _dept.name,
                        canManage: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
