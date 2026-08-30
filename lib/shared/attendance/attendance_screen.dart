import 'dart:async';

import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/attendance.dart';
import 'package:doliv_social/models/calendar_event.dart';
import 'package:doliv_social/services/attendance_service.dart';
import 'package:doliv_social/core/location/attendance_location.dart';
import 'package:doliv_social/shared/attendance/attendance_history_screen.dart';

/// "Mi asistencia": estado actual del trabajador, horas registradas, tiempo
/// trabajado y un único botón principal cuya acción la decide el backend
/// (`day.nextAction`). El trabajador nunca elige libremente el evento.
///
/// La usan empleados y managers (el director nunca). Registrar entrada y
/// terminar la hora de comida piden el GPS: el backend rechaza el registro si
/// no estás dentro del lugar de asistencia definido por el director.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  AttendanceDay? _day;
  AttendanceLocationConfig? _place;
  AttendanceAbsence? _absence;
  EntryOverrideEvent? _entryOverride;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  Timer? _ticker;
  Duration _mealElapsed = Duration.zero;

  /// Eventos que exigen estar físicamente en el lugar de asistencia.
  static const _geofenced = {AttendanceAction.entrada, AttendanceAction.finComida};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await AttendanceApi.today();
      if (!mounted) return;
      setState(() {
        _day = result.day;
        _place = result.location;
        _absence = result.absence;
        _entryOverride = result.entryOverride;
        _loading = false;
      });
      _syncTicker(result.day);
    } on AttendanceException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  /// Arranca o detiene el temporizador de la hora de comida según el estado.
  void _syncTicker(AttendanceDay day) {
    _ticker?.cancel();
    if (day.state == AttendanceState.enComida) {
      _mealElapsed = Duration(minutes: day.mealElapsedMinutes ?? 0);
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _mealElapsed += const Duration(seconds: 1));
      });
    }
  }

  Future<void> _perform(AttendanceAction action) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: action.buttonLabel,
      message: _confirmMessage(action),
      confirmLabel: 'Confirmar',
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);

    // La entrada y el fin de la hora de comida exigen ubicación: se pide el
    // GPS y se manda al backend, que valida contra el lugar de asistencia.
    double? lat;
    double? lng;
    try {
      if (_geofenced.contains(action)) {
        final pos = await AttendanceLocation.current();
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } on AttendanceException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(e.message);
      return;
    }

    try {
      final day = await AttendanceApi.perform(action, latitude: lat, longitude: lng);
      if (!mounted) return;
      setState(() {
        _day = day;
        _submitting = false;
      });
      _syncTicker(day);
      _snack(_successMessage(action, day));
    } on AttendanceException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(e.message);
      // Si el backend indica un permiso aprobado, o el estado cambió, se
      // recarga para reflejar "asistencia no requerida" y no dejar un botón
      // que ya no aplica.
      _load();
    }
  }

  String _confirmMessage(AttendanceAction action) {
    switch (action) {
      case AttendanceAction.entrada:
        return '¿Registrar tu entrada ahora?';
      case AttendanceAction.inicioComida:
        return '¿Iniciar tu hora de comida ahora?';
      case AttendanceAction.finComida:
        return '¿Terminar tu hora de comida ahora?';
      case AttendanceAction.salida:
        return '¿Registrar tu salida ahora? Con esto se cierra tu jornada.';
    }
  }

  String _successMessage(AttendanceAction action, AttendanceDay day) {
    if (action == AttendanceAction.finComida && day.mealExceeded) {
      return 'Hora de comida terminada. Excediste el límite por '
          '${_fmtMin(day.mealExcessMinutes)}.';
    }
    switch (action) {
      case AttendanceAction.entrada:
        return 'Entrada registrada correctamente.';
      case AttendanceAction.inicioComida:
        return 'Hora de comida iniciada.';
      case AttendanceAction.finComida:
        return 'Hora de comida terminada.';
      case AttendanceAction.salida:
        return 'Salida registrada. Jornada terminada.';
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _fmtMin(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '$h h $m min';
    if (h > 0) return '$h h';
    return '$m min';
  }

  static String _fmtClock(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Mi asistencia'),
      ),
      body: Builder(
        builder: (context) {
          if (_loading) return const LoadingState();
          if (_error != null) {
            return ErrorState(message: _error!, onRetry: _load);
          }
          final day = _day!;
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                if (_absence != null) ...[
                  _AbsenceCard(absence: _absence!),
                  const SizedBox(height: AppSpacing.lg),
                ],
                _StateHeader(day: day),
                const SizedBox(height: AppSpacing.lg),
                if (_absence == null) ...[
                  if (_entryOverride != null)
                    _EventEntryCard(event: _entryOverride!)
                  else
                    _PlaceCard(place: _place),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (day.state == AttendanceState.enComida)
                  _MealTimerCard(day: day, elapsed: _mealElapsed),
                if (day.state == AttendanceState.enComida)
                  const SizedBox(height: AppSpacing.lg),
                if (day.mealExceeded) ...[
                  _MealExceededBanner(day: day),
                  const SizedBox(height: AppSpacing.lg),
                ],
                _TimesCard(day: day),
                const SizedBox(height: AppSpacing.lg),
                _ScheduleCard(day: day),
                const SizedBox(height: AppSpacing.xl),
                if (_absence == null) ...[
                  _PrimaryAction(
                    day: day,
                    submitting: _submitting,
                    onPerform: _perform,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AttendanceHistoryScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.history),
                    label: const Text('Ver historial de asistencia'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StateHeader extends StatelessWidget {
  const _StateHeader({required this.day});
  final AttendanceDay day;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (day.state) {
      AttendanceState.sinEntrada => (AppColors.textMuted, Icons.schedule),
      AttendanceState.enJornada => (AppColors.success, Icons.work_outline),
      AttendanceState.enComida => (AppColors.warning, Icons.restaurant),
      AttendanceState.jornadaTerminada => (AppColors.accent, Icons.check_circle_outline),
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
                const Text(
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
                    'Llegada tarde: ${_AttendanceScreenState._fmtMin(day.lateMinutes)}',
                    style: const TextStyle(color: AppColors.warning, fontSize: 12),
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

class _AbsenceCard extends StatelessWidget {
  const _AbsenceCard({required this.absence});
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
          const Icon(Icons.event_available, color: AppColors.success),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Asistencia no requerida hoy',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tienes una ausencia autorizada: ${absence.typeLabel}'
                  '${absence.rangeLabel.isNotEmpty ? ' (${absence.rangeLabel})' : ''}. '
                  'No necesitas registrar entrada, hora de comida ni salida.',
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

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place});
  final AttendanceLocationConfig? place;

  @override
  Widget build(BuildContext context) {
    if (place == null) {
      return const AppCard(
        child: Row(
          children: [
            Icon(Icons.location_off_outlined, color: AppColors.warning, size: 18),
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
          const Icon(Icons.place_outlined, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (p.label ?? '').isNotEmpty ? p.label! : 'Lugar de asistencia',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Debes estar a menos de ${p.radiusM} m para registrar tu '
                  'entrada y para terminar tu hora de comida.',
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

/// Reemplaza a `_PlaceCard` cuando hoy hay un evento con ubicación que cubre al
/// trabajador: la entrada se registra en el lugar y a la hora del evento.
class _EventEntryCard extends StatelessWidget {
  const _EventEntryCard({required this.event});
  final EntryOverrideEvent event;

  @override
  Widget build(BuildContext context) {
    final place = (event.label ?? '').isNotEmpty ? event.label! : 'el lugar del evento';
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
          const Icon(Icons.event, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hoy entras por el evento «${event.title}»',
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tu entrada de hoy se registra en $place '
                  '(a menos de ${event.radiusM} m)'
                  '${event.entryTime != null ? ', con hora de entrada ${event.entryTime}' : ''}. '
                  'La hora de comida y la salida no cambian.',
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

class _MealTimerCard extends StatelessWidget {
  const _MealTimerCard({required this.day, required this.elapsed});
  final AttendanceDay day;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final limit = day.mealLimitMinutes;
    final remaining =
        limit == null ? null : limit - elapsed.inMinutes;
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
            _AttendanceScreenState._fmtClock(elapsed),
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
                  ? 'Límite excedido por ${_AttendanceScreenState._fmtMin(-remaining)}'
                  : 'Tiempo disponible: ${_AttendanceScreenState._fmtMin(remaining)}',
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

class _MealExceededBanner extends StatelessWidget {
  const _MealExceededBanner({required this.day});
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
                  'Límite: ${_AttendanceScreenState._fmtMin(day.mealLimitMinutes ?? 0)}   ·   '
                  'Exceso: ${_AttendanceScreenState._fmtMin(day.mealExcessMinutes)}',
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

class _TimesCard extends StatelessWidget {
  const _TimesCard({required this.day});
  final AttendanceDay day;

  @override
  Widget build(BuildContext context) {
    final comida = switch ((day.inicioComida, day.finComida)) {
      (null, _) => '—',
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

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.day});
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

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
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

    // En jornada y sin comida todavía: el botón principal inicia la comida,
    // pero se ofrece una salida directa para quien no toma hora de comida.
    final showDirectExit = day.state == AttendanceState.enJornada &&
        action == AttendanceAction.inicioComida;

    return Column(
      children: [
        AppButton(
          label: action.buttonLabel,
          loading: submitting,
          onPressed: submitting ? null : () => onPerform(action),
        ),
        if (showDirectExit) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: submitting ? null : () => onPerform(AttendanceAction.salida),
            child: const Text('No tomaré hora de comida · Registrar salida'),
          ),
        ],
      ],
    );
  }
}
