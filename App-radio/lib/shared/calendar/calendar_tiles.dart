import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/calendar_event.dart';

/// Tarjeta de un evento del día en el calendario: título, horario, descripción
/// y las insignias de alcance / ubicación / hora de entrada.
class CalendarEventTile extends StatelessWidget {
  const CalendarEventTile({super.key, required this.event});
  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final timeLabel = [
      if (event.startTime != null) event.startTime!,
      if (event.endTime != null) '– ${event.endTime!}',
    ].join(' ');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event, color: AppColors.accent, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  event.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (event.hasLocation)
                const AppBadge(label: 'Con ubicación', variant: AppBadgeVariant.info),
            ],
          ),
          if (timeLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(timeLabel, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
          if ((event.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(event.description!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 4,
            children: [
              AppBadge(label: event.isGeneral ? 'General' : 'Áreas'),
              if (!event.isGeneral && event.areaNames.isNotEmpty)
                AppBadge(label: event.areaNames),
              if (event.hasLocation && event.entryTime != null)
                AppBadge(
                  label: 'Entrada ${event.entryTime}'
                      '${(event.locationLabel ?? '').isNotEmpty ? ' · ${event.locationLabel}' : ''}',
                  variant: AppBadgeVariant.warning,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de una actividad a entregar (tarea con fecha límite) del día en el
/// calendario, con su equipo/área, responsable y estado de entrega.
class CalendarActivityTile extends StatelessWidget {
  const CalendarActivityTile({super.key, required this.activity});
  final CalendarActivity activity;

  @override
  Widget build(BuildContext context) {
    final sub = [
      if ((activity.teamName ?? '').isNotEmpty) activity.teamName!,
      if ((activity.domainName ?? '').isNotEmpty) activity.domainName!,
    ].join(' · ');
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            activity.completed ? Icons.check_circle : Icons.assignment_outlined,
            color: activity.completed ? AppColors.success : AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.description,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    decoration: activity.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
                if ((activity.assignedTo).isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    activity.assignedTo,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppBadge(
            label: activity.completed ? 'Entregada' : 'A entregar',
            variant: activity.completed ? AppBadgeVariant.success : AppBadgeVariant.warning,
          ),
        ],
      ),
    );
  }
}
