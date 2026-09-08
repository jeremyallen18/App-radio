import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/dept_task.dart';
import 'package:doliv_social/shared/teams/widgets/task_visuals.dart';

/// Filtros de la escaleta. Todos se aplican en el cliente sobre el listado
/// ya cargado (no hay que volver a pedir nada al cambiar de filtro).
enum BoardFilter {
  all('Todas'),
  mine('Mías'),
  open('Abiertas'),
  toReview('Por revisar'),
  overdue('Vencidas');

  const BoardFilter(this.label);
  final String label;

  bool matches(DeptTask t, {String? currentUserId}) => switch (this) {
        BoardFilter.all => true,
        BoardFilter.mine => t.assignedTo != null && t.assignedTo!.id == currentUserId,
        BoardFilter.open => !t.isDone,
        BoardFilter.toReview => t.awaitingReview,
        BoardFilter.overdue => TaskTone.of(t) == TaskTone.overdue,
      };
}

/// Conteos + chips de filtro en la cabecera del tablero.
class BoardSummary extends StatelessWidget {
  const BoardSummary({
    super.key,
    required this.tasks,
    required this.selected,
    required this.onSelect,
    required this.currentUserId,
    required this.showMine,
    this.trailing,
  });

  final List<DeptTask> tasks;
  final BoardFilter selected;
  final ValueChanged<BoardFilter> onSelect;
  final String? currentUserId;

  /// El chip "Mías" solo tiene sentido si se sabe quién es el usuario.
  final bool showMine;

  /// Acción a la derecha de los conteos (p. ej. "+ Nueva" para el manager).
  /// Va en esa fila y no en la de chips, para que los filtros tengan todo el
  /// ancho.
  final Widget? trailing;

  int _count(BoardFilter f) =>
      tasks.where((t) => f.matches(t, currentUserId: currentUserId)).length;

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => t.isDone).length;
    final inProgress = tasks.where((t) => t.status == DeptTaskStatus.enProgreso).length;
    final pending = tasks.length - done - inProgress;
    final toReview = _count(BoardFilter.toReview);
    final overdue = _count(BoardFilter.overdue);

    final filters = [
      BoardFilter.all,
      if (showMine) BoardFilter.mine,
      BoardFilter.open,
      if (toReview > 0 || selected == BoardFilter.toReview) BoardFilter.toReview,
      if (overdue > 0 || selected == BoardFilter.overdue) BoardFilter.overdue,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Wrap(
                spacing: AppSpacing.lg,
                runSpacing: 4,
                children: [
                  _Count(color: TaskTone.pending.color, n: pending, label: 'pendientes'),
                  _Count(color: TaskTone.inProgress.color, n: inProgress, label: 'en curso'),
                  _Count(color: TaskTone.done.color, n: done, label: 'hechas'),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < filters.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                AppFilterChip(
                  label: filters[i].label,
                  selected: selected == filters[i],
                  count: switch (filters[i]) {
                    BoardFilter.toReview => toReview,
                    BoardFilter.overdue => overdue,
                    _ => null,
                  },
                  onTap: () => onSelect(filters[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.color, required this.n, required this.label});
  final Color color;
  final int n;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(
          '$n ',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800),
        ),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ],
    );
  }
}
