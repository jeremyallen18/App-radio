import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/dept_task.dart';

/// Tarjeta de una tarea (o subtarea, con `dense`) del tablero de equipo.
///
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
