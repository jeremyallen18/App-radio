import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/dept_task.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/services/team_service.dart';
import 'package:doliv_social/shared/teams/task_detail_sheet.dart';
import 'package:doliv_social/shared/teams/task_form_screen.dart';
import 'package:doliv_social/shared/widgets/evidence_viewer.dart';

/// Tablero de tareas de un departamento/equipo, a pantalla completa.
/// Reutiliza [TaskBoardBody]; la pestaña "Tablero" usa el body directamente.
class TaskBoardScreen extends StatelessWidget {
  const TaskBoardScreen({
    super.key,
    required this.departmentId,
    required this.departmentName,
    required this.canManage,
    this.currentUserId,
  });

  final String departmentId;
  final String departmentName;
  final bool canManage;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('Tareas · $departmentName'),
      ),
      body: TaskBoardBody(
        departmentId: departmentId,
        canManage: canManage,
        currentUserId: currentUserId,
      ),
    );
  }
}

/// Contenido del tablero (sin Scaffold): lista de tareas con sus subtareas,
/// filtros y — para director/manager — creación/edición/borrado.
///
/// - `canManage` (director / manager): crear tareas y subtareas, editar,
///   eliminar y cambiar el estado.
/// - empleado (`canManage == false`): solo marca como completadas las tareas
///   suyas o sin responsable. Puede filtrar "Solo mías".
class TaskBoardBody extends StatefulWidget {
  const TaskBoardBody({
    super.key,
    required this.departmentId,
    required this.canManage,
    this.currentUserId,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl,
    ),
  });

  final String departmentId;
  final bool canManage;

  /// Id del usuario actual. Para el empleado (`!canManage`) determina qué
  /// tareas puede marcar: las suyas o las que no tienen responsable.
  final String? currentUserId;

  final EdgeInsets padding;

  @override
  State<TaskBoardBody> createState() => _TaskBoardBodyState();
}

class _TaskBoardBodyState extends State<TaskBoardBody> {
  List<DeptTask> _tasks = const [];
  List<UserProfile> _members = const [];
  bool _onlyMine = false;
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
        DeptTaskApi.list(
          departmentId: widget.departmentId,
          mine: !widget.canManage && _onlyMine,
        ),
        if (widget.canManage)
          TeamApi.members(widget.departmentId)
        else
          Future.value(<UserProfile>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _tasks = results[0] as List<DeptTask>;
        _members = (results[1] as List<UserProfile>)
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

  List<DeptTask> get _topLevel => _tasks.where((t) => !t.isSubtask).toList();
  List<DeptTask> _subtasksOf(String id) =>
      _tasks.where((t) => t.parentId == id).toList();

  /// Quién puede marcar una tarea como completada.
  ///
  /// - director / manager (`canManage`): cualquier tarea.
  /// - empleado: SOLO las tareas asignadas específicamente a él. Una tarea
  ///   sin responsable, o de otra persona, no la puede tocar.
  bool _canComplete(DeptTask t) {
    if (widget.canManage) return true;
    final a = t.assignedTo;
    return a != null &&
        widget.currentUserId != null &&
        a.id == widget.currentUserId;
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _toggleDone(DeptTask t) async {
    final bool markingDone = !t.isDone;

    // Desmarcar / reabrir: sin confirmación.
    if (!markingDone) {
      setState(() => _busy = true);
      try {
        await DeptTaskApi.setStatus(t.id, DeptTaskStatus.pendiente);
        await _load();
        if (mounted) setState(() => _busy = false);
      } on TeamException catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        _snack(e.message);
      }
      return;
    }

    // Completar: confirmación (+ evidencia si la tarea la exige).
    final ok = await showAppConfirmDialog(
      context,
      title: 'Completar tarea',
      message: t.requiresEvidence
          ? '"${t.title}" requiere adjuntar evidencia (una foto). ¿Continuar?'
          : '¿Marcar "${t.title}" como completada?',
      confirmLabel: t.requiresEvidence ? 'Elegir foto' : 'Completar',
    );
    if (ok != true) return;

    File? evidence;
    if (t.requiresEvidence) {
      final XFile? picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked == null) return; // canceló el selector
      evidence = File(picked.path);
    }

    setState(() => _busy = true);
    try {
      await DeptTaskApi.complete(t.id, evidence: evidence);
      await _load();
      if (mounted) {
        setState(() => _busy = false);
        if (!widget.canManage) {
          _snack('Tarea enviada. Tu manager la revisará.');
        }
      }
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.message);
    }
  }

  /// Manager/director aprueba o devuelve una tarea pendiente de revisión.
  Future<void> _review(DeptTask t, {required bool approve}) async {
    String? note;
    if (!approve) {
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Devolver tarea'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Motivo (qué falta o corregir)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Devolver', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
      if (ok != true) return;
      note = controller.text.trim();
      if (note.isEmpty) {
        _snack('Indica el motivo del rechazo.');
        return;
      }
    }
    setState(() => _busy = true);
    try {
      await DeptTaskApi.review(t.id, approve: approve, note: note);
      await _load();
      if (mounted) setState(() => _busy = false);
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.message);
    }
  }

  Future<void> _openDetail(DeptTask t) async {
    final canComment = widget.canManage ||
        (t.assignedTo != null && t.assignedTo!.id == widget.currentUserId);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskDetailSheet(task: t, canComment: canComment),
      ),
    );
    if (mounted) _load();
  }

  void _openEvidence(DeptTask t) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EvidenceViewer(
          url: DeptTaskApi.evidenceUrl(t.id),
          title: 'Evidencia · ${t.title}',
        ),
      ),
    );
  }

  Future<void> _openForm({String? parentId, DeptTask? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(
          departmentId: widget.departmentId,
          parentId: parentId,
          existing: existing,
          members: _members,
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(DeptTask t) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Eliminar tarea',
      message: t.subtaskCount > 0
          ? 'Se eliminará la tarea y sus ${t.subtaskCount} subtareas. ¿Continuar?'
          : '¿Eliminar esta tarea?',
      confirmLabel: 'Eliminar',
      danger: true,
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await DeptTaskApi.delete(t.id);
      await _load();
      if (mounted) setState(() => _busy = false);
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.message);
    }
  }

  Future<void> _cycleStatus(DeptTask t) async {
    const order = [DeptTaskStatus.pendiente, DeptTaskStatus.enProgreso, DeptTaskStatus.completada];
    final next = order[(order.indexOf(t.status) + 1) % order.length];
    setState(() => _busy = true);
    try {
      await DeptTaskApi.setStatus(t.id, next);
      await _load();
      if (mounted) setState(() => _busy = false);
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: widget.padding,
        children: [
          if (widget.canManage) ...[
            AppButton(
              label: 'NUEVA TAREA',
              onPressed: _busy ? null : () => _openForm(),
            ),
            const SizedBox(height: AppSpacing.lg),
          ] else ...[
            Row(
              children: [
                const Text('Mostrar:', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(width: AppSpacing.sm),
                AppFilterChip(
                  label: 'Todas',
                  selected: !_onlyMine,
                  onTap: () {
                    setState(() => _onlyMine = false);
                    _load();
                  },
                ),
                const SizedBox(width: AppSpacing.sm),
                AppFilterChip(
                  label: 'Solo mías',
                  selected: _onlyMine,
                  onTap: () {
                    setState(() => _onlyMine = true);
                    _load();
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_topLevel.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xxl),
              child: EmptyState(
                icon: Icons.checklist_rtl_outlined,
                title: 'No hay tareas',
                message: 'Todavía no se han creado tareas para este equipo.',
              ),
            )
          else
            for (final t in _topLevel) ...[
              _TaskCard(
                task: t,
                canManage: widget.canManage,
                canComplete: _canComplete(t),
                busy: _busy,
                onToggleDone: () => _toggleDone(t),
                onCycleStatus: () => _cycleStatus(t),
                onEdit: () => _openForm(existing: t),
                onAddSubtask: () => _openForm(parentId: t.id),
                onDelete: () => _delete(t),
                onOpen: () => _openDetail(t),
                onViewEvidence: t.hasEvidence ? () => _openEvidence(t) : null,
                onApprove: () => _review(t, approve: true),
                onReject: () => _review(t, approve: false),
              ),
              for (final s in _subtasksOf(t.id))
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xl, top: AppSpacing.sm),
                  child: _TaskCard(
                    task: s,
                    canManage: widget.canManage,
                    canComplete: _canComplete(s),
                    busy: _busy,
                    dense: true,
                    onToggleDone: () => _toggleDone(s),
                    onCycleStatus: () => _cycleStatus(s),
                    onEdit: () => _openForm(existing: s),
                    onAddSubtask: null,
                    onDelete: () => _delete(s),
                    onOpen: () => _openDetail(s),
                    onViewEvidence: s.hasEvidence ? () => _openEvidence(s) : null,
                    onApprove: () => _review(s, approve: true),
                    onReject: () => _review(s, approve: false),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.canManage,
    required this.canComplete,
    required this.busy,
    required this.onToggleDone,
    required this.onCycleStatus,
    required this.onEdit,
    required this.onAddSubtask,
    required this.onDelete,
    required this.onOpen,
    required this.onApprove,
    required this.onReject,
    this.onViewEvidence,
    this.dense = false,
  });

  final DeptTask task;
  final bool canManage;
  final bool canComplete;
  final bool busy;
  final VoidCallback onToggleDone;
  final VoidCallback onCycleStatus;
  final VoidCallback onEdit;
  final VoidCallback? onAddSubtask;
  final VoidCallback onDelete;
  final VoidCallback onOpen;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback? onViewEvidence;
  final bool dense;

  Color get _statusColor => switch (task.status) {
        DeptTaskStatus.pendiente => AppColors.textMuted,
        DeptTaskStatus.enProgreso => AppColors.warning,
        DeptTaskStatus.completada => AppColors.success,
      };

  Widget _chip(String text, Color color, {IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 3),
            ],
            Text(text,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  /// Metadato discreto: ícono + texto en gris tenue.
  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 3),
          Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Casilla de completada: para el empleado es su única acción.
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: (busy || !canComplete) ? null : onToggleDone,
                tooltip: canComplete
                    ? null
                    : (task.assignedTo == null
                        ? 'Sin responsable: solo un manager puede completarla'
                        : 'Solo puede completarla la persona asignada'),
                icon: Icon(
                  task.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: task.isDone
                      ? AppColors.success
                      : (canComplete ? AppColors.textMuted : AppColors.surfaceBorder),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: dense ? 14 : 15,
                        decoration: task.isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if ((task.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(task.description!,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: canManage && !busy ? onCycleStatus : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(task.statusLabel,
                                style: TextStyle(color: _statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        if (task.assignedTo != null)
                          _meta(Icons.person_outline, task.assignedTo!.name),
                        if (task.dueLabel != null)
                          _meta(Icons.event_outlined, task.dueLabel!),
                        if (!dense && task.subtaskCount > 0)
                          _meta(Icons.checklist,
                              '${task.subtaskDoneCount}/${task.subtaskCount} subtareas'),
                        if (task.awaitingReview)
                          _chip('Por revisar', AppColors.warning,
                              icon: Icons.hourglass_empty),
                        if (task.reviewStatus == DeptTaskReviewStatus.aprobada)
                          _chip('Aprobada', AppColors.success, icon: Icons.verified_outlined),
                        if (task.isRecurring)
                          _chip(task.recurrence.label, AppColors.accent, icon: Icons.repeat),
                        if (task.requiresEvidence && !task.hasEvidence)
                          _chip('Requiere evidencia', AppColors.textMuted,
                              icon: Icons.attach_file),
                        if (task.hasEvidence)
                          GestureDetector(
                            onTap: onViewEvidence,
                            child: _chip('Ver evidencia', AppColors.accent,
                                icon: Icons.attach_file),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  enabled: !busy,
                  onSelected: (v) {
                    switch (v) {
                      case 'edit':
                        onEdit();
                      case 'sub':
                        onAddSubtask?.call();
                      case 'del':
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    if (onAddSubtask != null)
                      const PopupMenuItem(value: 'sub', child: Text('Agregar subtarea')),
                    const PopupMenuItem(value: 'del', child: Text('Eliminar')),
                  ],
                ),
            ],
          ),

          // Nota de rechazo: la ve sobre todo el empleado asignado.
          if (task.wasRejected && (task.reviewNote ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Text('Devuelta: ${task.reviewNote}',
                  style: const TextStyle(color: AppColors.error, fontSize: 12)),
            ),
          ],

          // Acciones de revisión (solo manager/director, tarea pendiente).
          if (canManage && task.awaitingReview) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onReject,
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Devolver'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onApprove,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Aprobar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
