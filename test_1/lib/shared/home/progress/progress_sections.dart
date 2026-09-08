import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/dept_task.dart';
import 'package:doliv_social/shared/home/progress/progress_stats.dart';
import 'package:doliv_social/shared/home/progress_widgets.dart';

/// Leyenda de tres estados bajo el medidor.
class StatusLegend extends StatelessWidget {
  const StatusLegend({
    super.key,
    required this.done,
    required this.inProgress,
    required this.pending,
  });

  final int done;
  final int inProgress;
  final int pending;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      children: [
        ProgressLegendDot(color: AppColors.success, label: '$done hechas'),
        ProgressLegendDot(color: AppColors.accent, label: '$inProgress en curso'),
        ProgressLegendDot(color: AppColors.warning, label: '$pending pendientes'),
      ],
    );
  }
}

/// Encabezado de tarjeta: título a la izquierda, dato a la derecha.
class CardTitle extends StatelessWidget {
  const CardTitle({super.key, required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

/// Tres tiles: A tiempo · Con retardo · Vencidas.
class PunctualityRow extends StatelessWidget {
  const PunctualityRow({super.key, required this.stats});

  final ProgressStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatTile(
            icon: Icons.task_alt_rounded,
            value: '${stats.onTime}',
            label: 'A tiempo',
            accentColor: AppColors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: StatTile(
            icon: Icons.history_toggle_off_rounded,
            value: '${stats.late}',
            label: 'Con retardo',
            accentColor: AppColors.warning,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: StatTile(
            icon: Icons.event_busy_rounded,
            value: '${stats.overdue}',
            label: 'Vencidas',
            accentColor: stats.overdue > 0 ? AppColors.error : AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// Lista corta de próximas entregas con chip de cuenta atrás.
class UpcomingList extends StatelessWidget {
  const UpcomingList({super.key, required this.tasks});

  final List<DeptTask> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Text(
        'Nada con fecha límite por delante.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < tasks.length; i++) ...[
          if (i > 0) const Divider(height: AppSpacing.md),
          _UpcomingTile(task: tasks[i]),
        ],
      ],
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.task});

  final DeptTask task;

  @override
  Widget build(BuildContext context) {
    final due = task.dueDate!;
    final days = ProgressStats.daysUntil(due);
    final variant = days <= 0
        ? AppBadgeVariant.error
        : days <= 2
            ? AppBadgeVariant.warning
            : AppBadgeVariant.info;
    return Row(
      children: [
        Icon(
          task.status == DeptTaskStatus.enProgreso
              ? Icons.play_circle_outline_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 18,
          color: task.status == DeptTaskStatus.enProgreso ? AppColors.accent : AppColors.textMuted,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            task.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        AppBadge(label: ProgressStats.dueLabel(due), variant: variant),
      ],
    );
  }
}
