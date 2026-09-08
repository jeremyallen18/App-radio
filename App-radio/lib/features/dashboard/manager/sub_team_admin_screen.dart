import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/dept_task.dart' show TaskUserRef;
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/models/sub_team.dart';
import 'package:doliv_social/services/sub_team_service.dart';
import 'package:doliv_social/services/team_service.dart';
import 'package:doliv_social/shared/teams/task_board_screen.dart';
import 'package:doliv_social/shared/teams/user_picker_sheet.dart';

/// Sub-equipos de un departamento (migración 030).
///
/// - `leadScope == false` (manager del área / director): crear, renombrar,
///   borrar sub-equipos, fijar el sub-líder y administrar miembros.
/// - `leadScope == true` (sub-líder): solo ve los sub-equipos que lidera;
///   administra sus miembros y abre su tablero de tareas. No crea ni borra.
class SubTeamAdminScreen extends StatefulWidget {
  const SubTeamAdminScreen({
    super.key,
    required this.departmentId,
    required this.departmentName,
    required this.currentUserId,
    this.leadScope = false,
  });

  final String departmentId;
  final String departmentName;
  final String currentUserId;
  final bool leadScope;

  @override
  State<SubTeamAdminScreen> createState() => _SubTeamAdminScreenState();
}

class _SubTeamAdminScreenState extends State<SubTeamAdminScreen> {
  List<SubTeam> _subTeams = const [];
  List<UserProfile> _deptEmployees = const [];
  bool _loading = true;
  bool _busy = false;
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
    try {
      final results = await Future.wait([
        SubTeamApi.list(widget.departmentId),
        TeamApi.members(widget.departmentId),
      ]);
      if (!mounted) return;
      var subTeams = results[0] as List<SubTeam>;
      if (widget.leadScope) {
        subTeams = subTeams
            .where((s) => s.isLeadUser(widget.currentUserId))
            .toList();
      }
      setState(() {
        _subTeams = subTeams;
        _deptEmployees = (results[1] as List<UserProfile>)
            .where((u) => u.role == AppRole.employee)
            .toList();
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

  Future<void> _run(Future<void> Function() action, [String? okMsg]) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      if (mounted && okMsg != null) _snack(okMsg);
    } on TeamException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final data = await _nameDescDialog(title: 'Crear sub-equipo');
    if (data == null) return;
    await _run(
      () => SubTeamApi.create(
        departmentId: widget.departmentId,
        name: data.$1,
        description: data.$2,
      ),
      'Sub-equipo creado.',
    );
  }

  Future<void> _rename(SubTeam s) async {
    final data = await _nameDescDialog(
      title: 'Editar sub-equipo',
      name: s.name,
      description: s.description ?? '',
    );
    if (data == null) return;
    await _run(
      () => SubTeamApi.update(s.id, name: data.$1, description: data.$2),
      'Sub-equipo actualizado.',
    );
  }

  Future<void> _delete(SubTeam s) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Eliminar sub-equipo',
      message: '¿Eliminar "${s.name}"? Sus tareas quedarán como tareas de área.',
      confirmLabel: 'Eliminar',
      danger: true,
    );
    if (ok != true) return;
    await _run(() => SubTeamApi.delete(s.id), 'Sub-equipo eliminado.');
  }

  Future<void> _setLead(SubTeam s) async {
    final u = await pickPerson(
      context,
      title: 'Elegir sub-líder',
      people: _deptEmployees,
    );
    if (u == null) return;
    await _run(() => SubTeamApi.setLead(s.id, u.id), 'Sub-líder asignado.');
  }

  Future<void> _clearLead(SubTeam s) async {
    await _run(() => SubTeamApi.setLead(s.id, ''), 'Sub-líder quitado.');
  }

  Future<void> _addMember(SubTeam s) async {
    final inTeam = s.members.map((m) => m.id).toSet();
    final options =
        _deptEmployees.where((u) => !inTeam.contains(u.id)).toList();
    if (options.isEmpty) {
      _snack('Ya están todos los empleados del área en este sub-equipo.');
      return;
    }
    final u = await pickPerson(
      context,
      title: 'Agregar a ${s.name}',
      people: options,
    );
    if (u == null) return;
    await _run(() => SubTeamApi.addMember(s.id, u.id), 'Miembro agregado.');
  }

  Future<void> _removeMember(SubTeam s, TaskUserRef m) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Quitar del sub-equipo',
      message: '¿Quitar a ${m.name} de "${s.name}"?',
      confirmLabel: 'Quitar',
      danger: true,
    );
    if (ok != true) return;
    await _run(() => SubTeamApi.removeMember(s.id, m.id), 'Miembro quitado.');
  }

  void _openBoard(SubTeam s) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskBoardScreen(
          departmentId: widget.departmentId,
          departmentName: '${widget.departmentName} · ${s.name}',
          canManage: true,
          currentUserId: widget.currentUserId,
          subTeamId: s.id,
          subTeamName: s.name,
        ),
      ),
    );
  }

  Future<(String, String)?> _nameDescDialog({
    required String title,
    String name = '',
    String description = '',
  }) {
    final nameCtrl = TextEditingController(text: name);
    final descCtrl = TextEditingController(text: description);
    return showDialog<(String, String)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(controller: nameCtrl, hintText: 'Nombre del sub-equipo'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: descCtrl,
              hintText: 'Descripción (opcional)',
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final n = nameCtrl.text.trim();
              if (n.isEmpty) return;
              Navigator.pop(ctx, (n, descCtrl.text.trim()));
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ).whenComplete(() {
      nameCtrl.dispose();
      descCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(widget.leadScope
            ? 'Mis sub-equipos'
            : 'Sub-equipos · ${widget.departmentName}'),
      ),
      floatingActionButton: widget.leadScope
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : _create,
              icon: const Icon(Icons.add),
              label: const Text('Crear sub-equipo'),
            ),
      body: Builder(
        builder: (context) {
          if (_loading) return const LoadingState();
          if (_error != null) {
            return ErrorState(message: _error!, onRetry: _load);
          }
          if (_subTeams.isEmpty) {
            return EmptyState(
              icon: Icons.workspaces_outline,
              title: widget.leadScope
                  ? 'No lideras ningún sub-equipo'
                  : 'Todavía no hay sub-equipos',
              message: widget.leadScope
                  ? 'Cuando tu manager te ponga al frente de un sub-equipo, aparecerá aquí.'
                  : 'Divide tu área en sub-equipos (p. ej. Frontend, Backend) y '
                      'ponles un responsable.',
            );
          }
          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
              itemCount: _subTeams.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, i) => _SubTeamCard(
                subTeam: _subTeams[i],
                leadScope: widget.leadScope,
                busy: _busy,
                onRename: () => _rename(_subTeams[i]),
                onDelete: () => _delete(_subTeams[i]),
                onSetLead: () => _setLead(_subTeams[i]),
                onClearLead: () => _clearLead(_subTeams[i]),
                onAddMember: () => _addMember(_subTeams[i]),
                onRemoveMember: (m) => _removeMember(_subTeams[i], m),
                onOpenBoard: () => _openBoard(_subTeams[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SubTeamCard extends StatelessWidget {
  const _SubTeamCard({
    required this.subTeam,
    required this.leadScope,
    required this.busy,
    required this.onRename,
    required this.onDelete,
    required this.onSetLead,
    required this.onClearLead,
    required this.onAddMember,
    required this.onRemoveMember,
    required this.onOpenBoard,
  });

  final SubTeam subTeam;
  final bool leadScope;
  final bool busy;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onSetLead;
  final VoidCallback onClearLead;
  final VoidCallback onAddMember;
  final ValueChanged<TaskUserRef> onRemoveMember;
  final VoidCallback onOpenBoard;

  @override
  Widget build(BuildContext context) {
    final s = subTeam;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              if (!leadScope)
                PopupMenuButton<String>(
                  enabled: !busy,
                  onSelected: (v) {
                    switch (v) {
                      case 'rename':
                        onRename();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
            ],
          ),
          if ((s.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(s.description!,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
          const SizedBox(height: AppSpacing.md),

          // Sub-líder
          Row(
            children: [
              const Icon(Icons.star_border_rounded,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  s.lead == null ? 'Sin sub-líder' : 'Sub-líder: ${s.lead!.name}',
                  style: TextStyle(
                    color: s.lead == null
                        ? AppColors.warning
                        : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!leadScope) ...[
                TextButton(
                  onPressed: busy ? null : onSetLead,
                  child: Text(s.lead == null ? 'Asignar' : 'Cambiar'),
                ),
                if (s.lead != null)
                  IconButton(
                    tooltip: 'Quitar sub-líder',
                    onPressed: busy ? null : onClearLead,
                    icon: const Icon(Icons.close, size: 18),
                  ),
              ],
            ],
          ),
          const Divider(color: AppColors.surfaceBorder, height: AppSpacing.xl),

          // Miembros
          Row(
            children: [
              Expanded(
                child: Text(
                  'Miembros (${s.members.length})',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: busy ? null : onAddMember,
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Agregar'),
              ),
            ],
          ),
          if (s.members.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text('Aún no hay miembros.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            )
          else
            for (final m in s.members)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 16, color: AppColors.textMuted),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(m.name,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 13)),
                    ),
                    IconButton(
                      tooltip: 'Quitar',
                      visualDensity: VisualDensity.compact,
                      onPressed: busy ? null : () => onRemoveMember(m),
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                    ),
                  ],
                ),
              ),

          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onOpenBoard,
              icon: const Icon(Icons.checklist_rtl, size: 18),
              label: const Text('Tablero del sub-equipo'),
            ),
          ),
        ],
      ),
    );
  }
}
