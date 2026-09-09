import 'package:flutter/material.dart';
import 'app_badge.dart';
import 'app_card.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';

/// Tarjeta de tarea: descripción, contexto (equipo · área), estado y fecha
/// límite. La fecha llega como texto libre desde el backend (`dd-MM-yyyy`,
/// sin validación de formato) — [deadlineText] se intenta parsear solo para
/// mostrar una insignia de urgencia; si no se puede, se muestra tal cual.
///
/// No hay campo de prioridad en el modelo de datos actual (`tasks` no lo
/// tiene) — este widget no lo inventa.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.description,
    required this.context_,
    required this.deadlineText,
    required this.done,
    this.busy = false,
    this.onComplete,
  });

  final String description;
  final String context_;
  final String deadlineText;
  final bool done;
  final bool busy;
  final VoidCallback? onComplete;

  DateTime? get _parsedDeadline {
    final parts = deadlineText.split('-');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  /// Una tarea pendiente cuya fecha límite ya pasó se considera "no
  /// realizada" en vez de simplemente "pendiente".
  bool get _isOverdue {
    if (done || deadlineText.isEmpty) return false;
    final deadline = _parsedDeadline;
    if (deadline == null) return false;
    final today = DateTime.now();
    final daysLeft = DateTime(deadline.year, deadline.month, deadline.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    return daysLeft < 0;
  }

  ({String label, AppBadgeVariant variant})? get _urgency {
    if (done || deadlineText.isEmpty) return null;
    final deadline = _parsedDeadline;
    if (deadline == null) return null;
    final today = DateTime.now();
    final daysLeft = DateTime(deadline.year, deadline.month, deadline.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    // Si ya venció, el badge principal ya dice "Tarea no realizada"; no
    // hace falta repetirlo aquí con un segundo badge de "Vencida".
    if (daysLeft < 0) return null;
    if (daysLeft == 0) return (label: 'Vence hoy', variant: AppBadgeVariant.warning);
    if (daysLeft <= 2) return (label: 'Vence pronto', variant: AppBadgeVariant.warning);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final urgency = _urgency;
    final bool overdue = _isOverdue;
    // Una tarea vencida ya no se puede entregar, ni siquiera con retraso:
    // se ignora cualquier callback que nos hayan pasado desde afuera.
    final VoidCallback? effectiveOnComplete = overdue ? null : onComplete;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        description,
                        style: TextStyle(
                          color: done
                              ? AppColors.textMuted
                              : (overdue ? AppColors.error : AppColors.textPrimary),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          decoration: (done || overdue) ? TextDecoration.lineThrough : TextDecoration.none,
                          decorationColor: overdue ? AppColors.error : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppBadge(
                      label: done
                          ? 'Completada'
                          : (_isOverdue ? 'Tarea no realizada' : 'Pendiente'),
                      variant: done
                          ? AppBadgeVariant.success
                          : (_isOverdue ? AppBadgeVariant.error : AppBadgeVariant.neutral),
                    ),
                  ],
                ),
                if (context_.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(context_, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
                if (deadlineText.isNotEmpty || urgency != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: 4,
                    children: [
                      if (deadlineText.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(deadlineText, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      if (urgency != null) AppBadge(label: urgency.label, variant: urgency.variant),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (done)
            Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.check_circle, color: AppColors.success, size: 26),
            )
          else if (overdue)
            // Ya no se puede entregar (ni con retraso): se muestra un
            // tache rojo en vez del botón de completar.
            Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.cancel, color: AppColors.error, size: 26),
            )
          else if (busy)
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
            )
          else if (effectiveOnComplete != null)
            IconButton(
              tooltip: 'Completar tarea',
              onPressed: effectiveOnComplete,
              icon: Icon(Icons.radio_button_unchecked, color: AppColors.accent, size: 26),
            ),
        ],
      ),
    );
  }
}
