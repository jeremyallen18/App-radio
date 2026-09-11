import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/services/team_service.dart';
import 'package:doliv_social/shared/home/progress_widgets.dart';

/// Una fila por departamento: nombre, barra apilada (hechas · en progreso ·
/// pendientes) y el % al final. Tocar la fila abre el tablero del área.
class DepartmentStackBars extends StatelessWidget {
  const DepartmentStackBars({
    super.key,
    required this.rows,
    required this.onOpen,
  });

  final List<DepartmentTaskCounts> rows;
  final ValueChanged<DepartmentTaskCounts> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: AppSpacing.lg),
          _Row(counts: rows[i], onTap: () => onOpen(rows[i])),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.counts, required this.onTap});

  final DepartmentTaskCounts counts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasTasks = counts.total > 0;
    final pct = (counts.completionRatio * 100).round();
    final accent = departmentAccent(counts.departmentId);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(color: accent.withValues(alpha: 0.40)),
              ),
              child: Text(
                departmentInitials(counts.departmentName),
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          counts.departmentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        hasTasks
                            ? '${counts.done}/${counts.total}'
                            : 'Sin tareas',
                        style:
                            TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _StackBar(counts: counts),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: 44,
              child: Text(
                hasTasks ? '$pct%' : '—',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: hasTasks ? AppColors.textPrimary : AppColors.textMuted,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _StackBar extends StatelessWidget {
  const _StackBar({required this.counts});

  final DepartmentTaskCounts counts;

  @override
  Widget build(BuildContext context) {
    if (counts.total == 0) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.surfaceBorder,
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            if (counts.done > 0)
              Expanded(
                  flex: counts.done,
                  child: SizedBox.expand(
                      child: ColoredBox(color: AppColors.success))),
            if (counts.inProgress > 0) ...[
              if (counts.done > 0) const SizedBox(width: 2),
              Expanded(
                  flex: counts.inProgress,
                  child: SizedBox.expand(
                      child: ColoredBox(color: AppColors.accent))),
            ],
            if (counts.notStarted > 0) ...[
              if (counts.done > 0 || counts.inProgress > 0)
                const SizedBox(width: 2),
              Expanded(
                  flex: counts.notStarted,
                  child: SizedBox.expand(
                      child: ColoredBox(color: AppColors.warning))),
            ],
          ],
        ),
      ),
    );
  }
}
