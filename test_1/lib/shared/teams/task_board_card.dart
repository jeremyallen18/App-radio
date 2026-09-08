import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/dept_task.dart';
import 'package:doliv_social/shared/teams/widgets/task_visuals.dart';

/// Tarjeta de una tarea (o subtarea, con `dense`) de la escaleta del equipo.
///
/// Riel de color a la izquierda con el tono de la tarea, casilla de
/// completada, título, y una línea de meta (responsable · fecha · íconos).
/// Es puramente de presentación: recibe callbacks para cada acción y no habla
/// con la API. La lógica de permisos vive en [TaskBoardBody].
class TaskBoardCard extends StatelessWidget {
  const TaskBoardCard({
    super.key,
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

  @override
  Widget build(BuildContext context) {
    final tone = TaskTone.of(task);
    final showReview = canManage && task.awaitingReview;
    final rejectNote = task.wasRejected && (task.reviewNote ?? '').isNotEmpty;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          padding: EdgeInsets.fromLTRB(AppSpacing.md, dense ? AppSpacing.sm : AppSpacing.md, AppSpacing.sm, dense ? AppSpacing.sm : AppSpacing.md),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StatusRail(color: tone.color),
                const SizedBox(width: AppSpacing.sm),
                _Checkbox(
                  done: task.isDone,
                  enabled: !busy && canComplete,
                  tooltip: canComplete
                      ? (task.isDone ? 'Reabrir' : 'Marcar como completada')
                      : (task.assignedTo == null
                          ? 'Sin responsable: solo un manager puede completarla'
                          : 'Solo puede completarla la persona asignada'),
                  onTap: onToggleDone,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          color: task.isDone ? AppColors.textMuted : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: dense ? 14 : 15,
                          decoration: task.isDone ? TextDecoration.lineThrough : null,
                          decorationColor: AppColors.textMuted,
                        ),
                      ),
                      if (!dense && (task.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          task.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusChip(
                            tone: tone,
                            compact: dense,
                            onTap: canManage && !busy ? onCycleStatus : null,
                          ),
                          if (task.assignedTo != null) AssigneeChip(person: task.assignedTo!),
                          DueChip(task: task),
                          TaskFlags(task: task, onViewEvidence: onViewEvidence),
                        ],
                      ),
                      if (!dense && task.subtaskCount > 0) ...[
                        const SizedBox(height: AppSpacing.sm),
                        SubtaskProgress(done: task.subtaskDoneCount, total: task.subtaskCount),
                      ],
                      if (rejectNote) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _RejectNote(note: task.reviewNote!),
                      ],
                      if (showReview) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _ReviewActions(busy: busy, onApprove: onApprove, onReject: onReject),
                      ],
                    ],
                  ),
                ),
                if (canManage)
                  PopupMenuButton<String>(
                    enabled: !busy,
                    tooltip: 'Más acciones',
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 20),
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
                      const PopupMenuItem(value: 'edit', child: ListTile(dense: true, leading: Icon(Icons.edit_outlined), title: Text('Editar'))),
                      if (onAddSubtask != null)
                        const PopupMenuItem(value: 'sub', child: ListTile(dense: true, leading: Icon(Icons.subdirectory_arrow_right_rounded), title: Text('Agregar subtarea'))),
                      const PopupMenuItem(value: 'del', child: ListTile(dense: true, leading: Icon(Icons.delete_outline, color: AppColors.error), title: Text('Eliminar', style: TextStyle(color: AppColors.error)))),
                    ],
                  )
                else
                  const SizedBox(width: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.done, required this.enabled, required this.tooltip, required this.onTap});

  final bool done;
  final bool enabled;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.success
        : enabled
            ? AppColors.textMuted
            : AppColors.surfaceBorder;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.success : Colors.transparent,
                border: Border.all(color: color, width: 2),
              ),
              child: done
                  ? const Icon(Icons.check_rounded, size: 16, color: AppColors.bgBase)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _RejectNote extends StatelessWidget {
  const _RejectNote({required this.note});
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.undo_rounded, size: 14, color: AppColors.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Devuelta: $note',
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewActions extends StatelessWidget {
  const _ReviewActions({required this.busy, required this.onApprove, required this.onReject});
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy ? null : onReject,
            icon: const Icon(Icons.undo_rounded, size: 16),
            label: const Text('Devolver'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: FilledButton.icon(
            onPressed: busy ? null : onApprove,
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Aprobar'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.bgBase,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }
}

/// Conector "└" que cuelga una subtarea del riel de su tarea principal.
class SubtaskConnector extends StatelessWidget {
  const SubtaskConnector({super.key, required this.child, required this.isLast});

  final Widget child;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: CustomPaint(painter: _ConnectorPainter(isLast: isLast)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({required this.isLast});
  final bool isLast;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.surfaceBorder
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const x = 14.0;
    final midY = size.height / 2;
    canvas.drawLine(const Offset(x, 0), Offset(x, isLast ? midY : size.height), paint);
    final path = Path()
      ..moveTo(x, midY - 6)
      ..quadraticBezierTo(x, midY, x + 6, midY)
      ..lineTo(size.width, midY);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) => old.isLast != isLast;
}
