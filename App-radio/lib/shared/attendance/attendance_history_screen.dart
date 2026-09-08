import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/attendance.dart';
import 'package:doliv_social/services/attendance_service.dart';
import 'package:doliv_social/shared/attendance/correction_request_screen.dart';
import 'package:doliv_social/shared/calendar/date_pickers.dart';

/// Historial de asistencia del empleado. Los registros son inmutables: un
/// cambio de horario posterior no altera lo ya registrado (el backend usa el
/// snapshot del horario congelado ese día).
class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key, this.employeeId, this.title});

  /// Si se pasa, se consulta el historial de ese empleado por la vía
  /// administrativa (director / manager). Si es `null`, el del usuario actual.
  final String? employeeId;
  final String? title;

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  late DateTime _from;
  late DateTime _to;
  List<AttendanceDay> _days = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _to = DateTime.now();
    _from = _to.subtract(const Duration(days: 30));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final days = widget.employeeId != null
          ? await AttendanceApi.adminEmployeeHistory(
              widget.employeeId!,
              from: _from,
              to: _to,
            )
          : await AttendanceApi.history(from: _from, to: _to);
      if (!mounted) return;
      setState(() {
        _days = days;
        _loading = false;
      });
    } on AttendanceException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _pickRange() async {
    final picked = await pickWorkingDateRange(
      context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      helpText: 'Elige el rango de fechas',
      saveText: 'Aplicar',
    );
    if (picked == null) return;
    setState(() {
      _from = picked.start;
      _to = picked.end;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(widget.title ?? 'Historial de asistencia'),
        actions: [
          IconButton(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range),
            tooltip: 'Elegir fechas',
          ),
        ],
      ),
      // Solo cuando el empleado mira SU propio historial.
      floatingActionButton: widget.employeeId != null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CorrectionRequestScreen(),
                ));
                _load();
              },
              icon: const Icon(Icons.rule),
              label: const Text('Corrección'),
            ),
      body: Builder(
        builder: (context) {
          if (_loading) return const LoadingState();
          if (_error != null) {
            return ErrorState(message: _error!, onRetry: _load);
          }
          if (_days.isEmpty) {
            return const EmptyState(
              icon: Icons.event_note_outlined,
              title: 'Sin registros en este rango',
              message: 'Prueba con otras fechas.',
            );
          }
          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              itemCount: _days.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, i) => _HistoryDayCard(day: _days[i]),
            ),
          );
        },
      ),
    );
  }
}

class _HistoryDayCard extends StatelessWidget {
  const _HistoryDayCard({required this.day});
  final AttendanceDay day;

  @override
  Widget build(BuildContext context) {
    final comida = switch ((day.inicioComida, day.finComida)) {
      (null, _) => '—',
      (final i?, null) => '$i — sin cierre',
      (final i?, final f?) => '$i — $f',
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                day.workDateLabel,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              AppBadge(label: day.stateLabel),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _line('Entrada', day.entrada ?? '—',
              trailing: day.isLate ? 'tarde ${day.lateMinutes} min' : null,
              trailingColor: AppColors.warning),
          _line('Comida', comida,
              trailing: day.mealMinutesLabel),
          _line('Salida', day.salida ?? '—'),
          _line('Tiempo trabajado', day.workedLabel ?? '—', emphasize: true),
          if (day.mealExceeded) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 14, color: AppColors.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Hora de comida excedida por ${_fmtMin(day.mealExcessMinutes)}',
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _fmtMin(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '$h h $m min';
    if (h > 0) return '$h h';
    return '$m min';
  }

  Widget _line(
    String label,
    String value, {
    String? trailing,
    Color? trailingColor,
    bool emphasize = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                fontSize: emphasize ? 15 : 13,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: TextStyle(
                color: trailingColor ?? AppColors.textMuted,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}
