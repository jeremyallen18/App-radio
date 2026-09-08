import 'dart:async';

import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/attendance.dart';
import 'package:doliv_social/models/calendar_event.dart';
import 'package:doliv_social/services/attendance_service.dart';
import 'package:doliv_social/core/location/attendance_location.dart';
import 'package:doliv_social/shared/attendance/attendance_format.dart';
import 'package:doliv_social/shared/attendance/attendance_history_screen.dart';
import 'package:doliv_social/shared/attendance/attendance_status_cards.dart';
import 'package:doliv_social/shared/attendance/attendance_time_cards.dart';

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
      case AttendanceAction.saltarComida:
        return 'Confirmas que hoy no tomarás hora de comida. '
            'Esto NO registra tu salida: tu jornada sigue abierta y podrás '
            'registrar tu salida cuando termines.';
    }
  }

  String _successMessage(AttendanceAction action, AttendanceDay day) {
    if (action == AttendanceAction.finComida && day.mealExceeded) {
      return 'Hora de comida terminada. Excediste el límite por '
          '${attendanceMinutesLabel(day.mealExcessMinutes)}.';
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
      case AttendanceAction.saltarComida:
        return 'Registrado: hoy no tomarás hora de comida. Tu jornada sigue '
            'abierta.';
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: const BackButton(),
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
            color: AppColors.accent,
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
                  AttendanceAbsenceCard(absence: _absence!),
                  const SizedBox(height: AppSpacing.lg),
                ],
                AttendanceStateHeader(day: day),
                const SizedBox(height: AppSpacing.lg),
                if (_absence == null) ...[
                  if (_entryOverride != null)
                    AttendanceEventEntryCard(event: _entryOverride!)
                  else
                    AttendancePlaceCard(place: _place),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (day.state == AttendanceState.enComida)
                  MealTimerCard(day: day, elapsed: _mealElapsed),
                if (day.state == AttendanceState.enComida)
                  const SizedBox(height: AppSpacing.lg),
                if (day.mealExceeded) ...[
                  MealExceededBanner(day: day),
                  const SizedBox(height: AppSpacing.lg),
                ],
                AttendanceTimesCard(day: day),
                const SizedBox(height: AppSpacing.lg),
                AttendanceScheduleCard(day: day),
                const SizedBox(height: AppSpacing.xl),
                if (_absence == null) ...[
                  AttendancePrimaryAction(
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
