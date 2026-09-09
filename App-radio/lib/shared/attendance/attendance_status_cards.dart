import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/attendance.dart';
import 'package:doliv_social/models/calendar_event.dart';
import 'package:doliv_social/shared/attendance/attendance_format.dart';

/// Cabecera con el estado actual del trabajador (sin entrada / en jornada /
/// en comida / jornada terminada) y el aviso de llegada tarde.
class AttendanceStateHeader extends StatelessWidget {
  const AttendanceStateHeader({super.key, required this.day});
  final AttendanceDay day;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (day.state) {
      AttendanceState.sinEntrada => (AppColors.textMuted, Icons.schedule),
      AttendanceState.enJornada => (AppColors.success, Icons.work_outline),
      AttendanceState.enComida => (AppColors.warning, Icons.restaurant),
      AttendanceState.jornadaTerminada => (
          AppColors.accent,
          Icons.check_circle_outline
        ),
    };
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado actual',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  day.stateLabel.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                if (day.isLate) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Llegada tarde: ${attendanceMinutesLabel(day.lateMinutes)}',
                    style: TextStyle(color: AppColors.warning, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso "asistencia no requerida hoy" por una ausencia autorizada.
class AttendanceAbsenceCard extends StatelessWidget {
  const AttendanceAbsenceCard({super.key, required this.absence});
  final AttendanceAbsence absence;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_available, color: AppColors.success),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asistencia no requerida hoy',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tienes una ausencia autorizada: ${absence.typeLabel}'
                  '${absence.rangeLabel.isNotEmpty ? ' (${absence.rangeLabel})' : ''}. '
                  'No necesitas registrar entrada, hora de comida ni salida.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta del lugar de asistencia configurado por el director (o el aviso de
/// que todavía no lo ha configurado).
class AttendancePlaceCard extends StatelessWidget {
  const AttendancePlaceCard({super.key, required this.place});
  final AttendanceLocationConfig? place;

  @override
  Widget build(BuildContext context) {
    if (place == null) {
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.location_off_outlined,
                color: AppColors.warning, size: 18),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'El director aún no ha configurado el lugar de asistencia. No '
                'podrás registrar entrada ni terminar la hora de comida hasta '
                'que lo haga.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    final p = place!;
    return AppCard(
      child: Row(
        children: [
          Icon(Icons.place_outlined, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (p.label ?? '').isNotEmpty ? p.label! : 'Lugar de asistencia',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Debes estar a menos de ${p.radiusM} m para registrar tu '
                  'entrada y para terminar tu hora de comida.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reemplaza a [AttendancePlaceCard] cuando hoy hay un evento con ubicación que
/// cubre al trabajador: la entrada se registra en el lugar y a la hora del
/// evento.
class AttendanceEventEntryCard extends StatelessWidget {
  const AttendanceEventEntryCard({super.key, required this.event});
  final EntryOverrideEvent event;

  @override
  Widget build(BuildContext context) {
    final place =
        (event.label ?? '').isNotEmpty ? event.label! : 'el lugar del evento';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hoy entras por el evento «${event.title}»',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tu entrada de hoy se registra en $place '
                  '(a menos de ${event.radiusM} m)'
                  '${event.entryTime != null ? ', con hora de entrada ${event.entryTime}' : ''}. '
                  'La hora de comida y la salida no cambian.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
