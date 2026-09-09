import 'package:flutter/material.dart';
import 'package:doliv_social/design/components/app_badge.dart';
import 'package:doliv_social/design/components/app_card.dart';
import 'package:doliv_social/design/motion/app_motion.dart';
import 'package:doliv_social/design/tokens/colors.dart';
import 'package:doliv_social/design/tokens/spacing.dart';

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

  ({String label, AppBadgeVariant variant})? get _urgency {
    if (done || deadlineText.isEmpty) return null;
    final deadline = _parsedDeadline;
    if (deadline == null) return null;
    final today = DateTime.now();
    final daysLeft = DateTime(deadline.year, deadline.month, deadline.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    if (daysLeft < 0) {
      return (label: 'Vencida', variant: AppBadgeVariant.error);
    }
    if (daysLeft == 0) {
      return (label: 'Vence hoy', variant: AppBadgeVariant.warning);
    }
    if (daysLeft <= 2) {
      return (label: 'Vence pronto', variant: AppBadgeVariant.warning);
    }
    return null;
  }

  Widget _buildTrailing() {
    if (done) {
      return Padding(
        key: ValueKey('done'),
        padding: EdgeInsets.only(top: 2),
        child: Icon(Icons.check_circle, color: AppColors.success, size: 26),
      );
    }
    if (busy) {
      return SizedBox(
        key: ValueKey('busy'),
        width: 26,
        height: 26,
        child:
            CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
      );
    }
    if (onComplete != null) {
      return IconButton(
        key: const ValueKey('todo'),
        tooltip: 'Completar tarea',
        onPressed: onComplete,
        icon: Icon(Icons.radio_button_unchecked,
            color: AppColors.accent, size: 26),
      );
    }
    return const SizedBox(key: ValueKey('none'), width: 0, height: 26);
  }

  @override
  Widget build(BuildContext context) {
    final urgency = _urgency;

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
                      child: AnimatedDefaultTextStyle(
                        duration: AppDurations.short,
                        curve: AppCurves.standard,
                        style: TextStyle(
                          color: done
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          decoration: done
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: AppColors.textMuted,
                        ),
                        child: Text(description),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppBadge(
                      label: done ? 'Completada' : 'Pendiente',
                      variant: done
                          ? AppBadgeVariant.success
                          : AppBadgeVariant.neutral,
                    ),
                  ],
                ),
                if (context_.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(context_,
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
                            Icon(Icons.event,
                                size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(deadlineText,
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      if (urgency != null)
                        AppBadge(
                            label: urgency.label, variant: urgency.variant),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AnimatedSwitcher(
            duration: AppDurations.short,
            switchInCurve: AppCurves.emphasized,
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: _buildTrailing(),
          ),
        ],
      ),
    );
  }
}
