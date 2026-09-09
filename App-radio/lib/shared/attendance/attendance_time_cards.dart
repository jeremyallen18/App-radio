import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/attendance.dart';
import 'package:doliv_social/shared/attendance/attendance_format.dart';

/// Cronómetro en vivo de la hora de comida, con el tiempo disponible / excedido.
class MealTimerCard extends StatelessWidget {
  const MealTimerCard({super.key, required this.day, required this.elapsed});
  final AttendanceDay day;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final limit = day.mealLimitMinutes;
    final remaining = limit == null ? null : limit - elapsed.inMinutes;
    final exceeded = remaining != null && remaining < 0;
    return AppCard(
      child: Column(
        children: [
          const Text(
            'HORA DE COMIDA',
            style: TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            attendanceClock(elapsed),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 40,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (remaining != null)
            Text(
              exceeded
                  ? 'Límite excedido por ${attendanceMinutesLabel(-remaining)}'
                  : 'Tiempo disponible: ${attendanceMinutesLabel(remaining)}',
              style: TextStyle(
                color: exceeded ? AppColors.error : AppColors.textMuted,
                fontSize: 13,
                fontWeight: exceeded ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
        ],
      ),
    );
  }
}

/// Banner rojo cuando la hora de comida ya superó el límite.
class MealExceededBanner extends StatelessWidget {
  const MealExceededBanner({super.key, required this.day});
  final AttendanceDay day;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.error),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hora de comida excedida',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Duración: ${day.mealMinutesLabel ?? '—'}   ·   '
                  'Límite: ${attendanceMinutesLabel(day.mealLimitMinutes ?? 0)}   ·   '
                  'Exceso: ${attendanceMinutesLabel(day.mealExcessMinutes)}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Resumen de horas del día: entrada, hora de comida, salida y tiempo trabajado.
class AttendanceTimesCard extends StatelessWidget {
  const AttendanceTimesCard({super.key, required this.day});
  final AttendanceDay day;

  @override
  Widget build(BuildContext context) {
    final comida = switch ((day.inicioComida, day.finComida)) {
      (null, _) => day.mealSkipped ? 'No tomó hora de comida' : '—',
      (final i?, null) => '$i — en curso',
      (final i?, final f?) => '$i — $f',
    };
    return AppCard(
      child: Column(
        children: [
          _row('Entrada', day.entrada ?? '—'),
          const Divider(color: AppColors.surfaceBorder, height: AppSpacing.xl),
          _row('Hora de comida', comida,
              subtitle: day.mealMinutesLabel != null
                  ? 'Duración: ${day.mealMinutesLabel}'
                  : null),
          const Divider(color: AppColors.surfaceBorder, height: AppSpacing.xl),
          _row('Salida', day.salida ?? '—'),
          const Divider(color: AppColors.surfaceBorder, height: AppSpacing.xl),
          _row(
            'Tiempo trabajado',
            day.workedLabel ?? '—',
            subtitle: day.workedInProgress && day.workedLabel != null
                ? 'En curso'
                : null,
            emphasize: true,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {String? subtitle, bool emphasize = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                fontSize: emphasize ? 17 : 15,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
          ],
        ),
      ],
    );
  }
}

/// Horario asignado al trabajador (entrada, salida, comida, límite).
class AttendanceScheduleCard extends StatelessWidget {
  const AttendanceScheduleCard({super.key, required this.day});
  final AttendanceDay day;

  @override
  Widget build(BuildContext context) {
    final s = day.schedule;
    if (s == null) {
      return const AppCard(
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.textMuted, size: 18),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Aún no tienes un horario asignado. Pídeselo al director.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Mi horario',
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppBadge(label: 'Entrada ${s.entryTime}'),
              AppBadge(label: 'Salida ${s.exitTime}'),
              AppBadge(label: 'Comida ${s.mealTime}'),
              AppBadge(label: 'Límite ${s.mealMaxMinutes} min'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Botón principal de la pantalla: su acción la decide el backend
/// (`day.nextAction`). Ofrece además "hoy no tomaré hora de comida" como acción
/// secundaria cuando corresponde.
class AttendancePrimaryAction extends StatelessWidget {
  const AttendancePrimaryAction({
    super.key,
    required this.day,
    required this.submitting,
    required this.onPerform,
  });

  final AttendanceDay day;
  final bool submitting;
  final void Function(AttendanceAction) onPerform;

  @override
  Widget build(BuildContext context) {
    final action = day.nextAction;
    if (action == null) {
      // Jornada terminada: sin acción disponible.
      return Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: const Text(
          'JORNADA TERMINADA',
          style: TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      );
    }

    // En jornada y con la comida aún pendiente: el botón principal inicia la
    // hora de comida. Se ofrece además, como acción SECUNDARIA e independiente,
    // "No tomaré hora de comida": solo deja constancia de esa decisión, NO
    // registra la salida ni cierra la jornada. Tras usarla, el backend deja
    // como siguiente paso `salida`, que el trabajador registra explícitamente
    // cuando de verdad se va.
    final showSkipMeal = day.state == AttendanceState.enJornada &&
        action == AttendanceAction.inicioComida &&
        !day.mealSkipped;

    final hint = _availabilityHint(action, day.schedule);

    return Column(
      children: [
        AppButton(
          label: action.buttonLabel,
          loading: submitting,
          onPressed: submitting ? null : () => onPerform(action),
        ),
        if (hint != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            hint,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
        if (showSkipMeal) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: submitting
                ? null
                : () => onPerform(AttendanceAction.saltarComida),
            child: const Text('Hoy no tomaré hora de comida'),
          ),
          const Text(
            'No registra tu salida. Tu jornada sigue abierta.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  /// Hora ("HH:MM") a partir de la cual el backend acepta el próximo fichaje:
  /// entrada = hora de entrada − 30 min; inicio de comida = hora de comida;
  /// salida = hora de salida. `null` si no hay horario o el paso no aplica.
  String? _availabilityHint(AttendanceAction action, EmployeeSchedule? s) {
    if (s == null) return null;
    switch (action) {
      case AttendanceAction.entrada:
        final t = _minusMinutes(s.entryTime, 30);
        return t == null ? null : 'Disponible desde las $t.';
      case AttendanceAction.inicioComida:
        return 'Disponible desde las ${s.mealTime}.';
      case AttendanceAction.salida:
        return 'Disponible desde las ${s.exitTime}.';
      case AttendanceAction.finComida:
      case AttendanceAction.saltarComida:
        return null;
    }
  }

  /// Resta [minutes] a una hora "HH:MM"; `null` si el formato no es válido.
  String? _minusMinutes(String hhmm, int minutes) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    var total = h * 60 + m - minutes;
    if (total < 0) total += 24 * 60;
    final nh = (total ~/ 60) % 24;
    final nm = total % 60;
    return '${nh.toString().padLeft(2, '0')}:${nm.toString().padLeft(2, '0')}';
  }
}
