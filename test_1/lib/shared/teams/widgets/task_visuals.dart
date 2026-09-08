import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/dept_task.dart';
import 'package:doliv_social/shared/home/progress/progress_stats.dart';

/// El "tono" de una tarea resume en un color lo que hay que saber de ella:
/// hecha, en curso, por revisar, devuelta, vencida o simplemente pendiente.
/// Lo usan el riel lateral, el chip de estado y la cabecera del detalle.
enum TaskTone {
  pending(AppColors.textMuted, 'Pendiente'),
  inProgress(AppColors.accent, 'En progreso'),
  done(AppColors.success, 'Completada'),
  toReview(AppColors.warning, 'Por revisar'),
  returned(AppColors.error, 'Devuelta'),
  overdue(AppColors.error, 'Vencida');

  const TaskTone(this.color, this.label);
  final Color color;
  final String label;

  static TaskTone of(DeptTask t, {DateTime? now}) {
    if (t.isDone) return t.awaitingReview ? TaskTone.toReview : TaskTone.done;
    if (t.wasRejected) return TaskTone.returned;
    final due = t.dueDate;
    if (due != null && ProgressStats.daysUntil(due, now: now) < 0) {
      return TaskTone.overdue;
    }
    return t.status == DeptTaskStatus.enProgreso ? TaskTone.inProgress : TaskTone.pending;
  }
}

/// Riel vertical de color a la izquierda de cada tarea.
class StatusRail extends StatelessWidget {
  const StatusRail({super.key, required this.color, this.width = 4});

  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(width),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 6)],
      ),
    );
  }
}

/// Cuenta atrás de la fecha límite con color por urgencia. Para tareas ya
/// completadas solo muestra la fecha, en gris.
class DueChip extends StatelessWidget {
  const DueChip({super.key, required this.task, this.now});

  final DeptTask task;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final due = task.dueDate;
    if (due == null) return const SizedBox.shrink();
    final days = ProgressStats.daysUntil(due, now: now);
    final Color color;
    final String text;
    if (task.isDone) {
      color = AppColors.textMuted;
      text = task.dueLabel!;
    } else if (days < 0) {
      color = AppColors.error;
      text = ProgressStats.dueLabel(due, now: now);
    } else if (days <= 1) {
      color = AppColors.error;
      text = ProgressStats.dueLabel(due, now: now);
    } else if (days <= 3) {
      color = AppColors.warning;
      text = ProgressStats.dueLabel(due, now: now);
    } else {
      color = AppColors.textMuted;
      text = task.dueLabel!;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule_rounded, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: color == AppColors.textMuted ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Mini barra de subtareas: "▰▰▰▱ 3/4".
class SubtaskProgress extends StatelessWidget {
  const SubtaskProgress({super.key, required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    final ratio = done / total;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: AppColors.surfaceBorder,
                valueColor: AlwaysStoppedAnimation(
                  ratio >= 1 ? AppColors.success : AppColors.accent,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$done/$total subtareas',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

/// Persona asignada: avatar pequeño + nombre.
class AssigneeChip extends StatelessWidget {
  const AssigneeChip({super.key, required this.person});

  final TaskUserRef person;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IdentityAvatar(id: person.email, label: person.name, radius: 8),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            person.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

/// Ícono pequeño con tooltip para los atributos secundarios (evidencia,
/// repetición, retardo, aprobada): no compiten con el título.
class TaskFlagIcon extends StatelessWidget {
  const TaskFlagIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    this.color = AppColors.textMuted,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Tooltip(
      message: tooltip,
      child: Icon(icon, size: 15, color: color),
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(padding: const EdgeInsets.all(2), child: child),
    );
  }
}

/// Íconos de atributos secundarios de una tarea, en orden fijo.
class TaskFlags extends StatelessWidget {
  const TaskFlags({super.key, required this.task, this.onViewEvidence});

  final DeptTask task;
  final VoidCallback? onViewEvidence;

  @override
  Widget build(BuildContext context) {
    final flags = <Widget>[
      if (task.completedLate)
        const TaskFlagIcon(icon: Icons.timer_off_outlined, tooltip: 'Entregada con retardo', color: AppColors.error),
      if (task.reviewStatus == DeptTaskReviewStatus.aprobada)
        const TaskFlagIcon(icon: Icons.verified_rounded, tooltip: 'Aprobada por el manager', color: AppColors.success),
      if (task.isRecurring)
        TaskFlagIcon(icon: Icons.repeat_rounded, tooltip: 'Se repite: ${task.recurrence.label}'),
      if (task.hasEvidence)
        TaskFlagIcon(
          icon: Icons.photo_outlined,
          tooltip: 'Ver evidencia',
          color: AppColors.accent,
          onTap: onViewEvidence,
        )
      else if (task.requiresEvidence)
        const TaskFlagIcon(icon: Icons.attach_file_rounded, tooltip: 'Requiere evidencia al completar'),
    ];
    if (flags.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < flags.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          flags[i],
        ],
      ],
    );
  }
}

/// Chip de estado (tocable para el manager: cicla el estado).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.tone, this.onTap, this.compact = false});

  final TaskTone tone;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(
        color: tone.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: tone.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: tone.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            tone.label,
            style: TextStyle(color: tone.color, fontSize: compact ? 10.5 : 11, fontWeight: FontWeight.w700),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 2),
            Icon(Icons.unfold_more_rounded, size: 12, color: tone.color),
          ],
        ],
      ),
    );
    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: chip,
    );
  }
}
