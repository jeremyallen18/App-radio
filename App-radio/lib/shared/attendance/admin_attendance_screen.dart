import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/attendance.dart';
import 'package:doliv_social/services/attendance_service.dart';
import 'package:doliv_social/shared/attendance/attendance_history_screen.dart';
import 'package:doliv_social/shared/calendar/date_pickers.dart';

/// Panel administrativo de asistencia (director y manager). Muestra SOLO
/// empleados — el director nunca aparece aquí como empleado. El manager ve
/// únicamente a la gente de su departamento (lo aplica el backend).
class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  DateTime _date = DateTime.now();
  List<AdminAttendanceRow> _rows = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await AttendanceApi.adminList(date: _date);
      if (!mounted) return;
      setState(() {
        _rows = rows;
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

  Future<void> _pickDate() async {
    final picked = await pickWorkingDate(
      context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDate: _date,
      helpText: 'Elige el día',
    );
    if (picked == null) return;
    setState(() => _date = picked);
    _load();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year && _date.month == now.month && _date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Asistencia de empleados'),
        actions: [
          IconButton(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Elegir día',
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_loading) return const LoadingState();
          if (_error != null) {
            return ErrorState(message: _error!, onRetry: _load);
          }
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
                Row(
                  children: [
                    const Icon(Icons.event, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _isToday ? 'Hoy' : _fmtDate(_date),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _SummaryStrip(rows: _rows),
                const SizedBox(height: AppSpacing.lg),
                if (_rows.isEmpty)
                  const EmptyState(
                    icon: Icons.groups_outlined,
                    title: 'No hay empleados para mostrar',
                    message: 'Aún no hay empleados asignados a tu ámbito.',
                  )
                else
                  ..._rows.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _EmployeeRowCard(
                          row: r,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AttendanceHistoryScreen(
                                employeeId: r.employeeId,
                                title: r.name,
                              ),
                            ),
                          ),
                        ),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.rows});
  final List<AdminAttendanceRow> rows;

  @override
  Widget build(BuildContext context) {
    int count(bool Function(AdminAttendanceRow) test) => rows.where(test).length;
    final enJornada = count((r) => r.day.state == AttendanceState.enJornada);
    final enComida = count((r) => r.day.state == AttendanceState.enComida);
    final completo = count((r) => r.day.state == AttendanceState.jornadaTerminada);
    final sinEntrada = count((r) => r.day.state == AttendanceState.sinEntrada);
    final tarde = count((r) => r.day.isLate);
    final excedidas = count((r) => r.day.mealExceeded);

    return AppCard(
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.md,
        children: [
          _stat('En jornada', enJornada, AppColors.success),
          _stat('En comida', enComida, AppColors.warning),
          _stat('Completas', completo, AppColors.accent),
          _stat('Sin entrada', sinEntrada, AppColors.error),
          _stat('Llegadas tarde', tarde, AppColors.warning),
          _stat('Comida excedida', excedidas, AppColors.error),
        ],
      ),
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 20),
        ),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }
}

class _EmployeeRowCard extends StatelessWidget {
  const _EmployeeRowCard({required this.row, required this.onTap});
  final AdminAttendanceRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final day = row.day;
    final comida = switch ((day.inicioComida, day.finComida)) {
      (null, _) => '--:-- – --:--',
      (final i?, null) => '$i – …',
      (final i?, final f?) => '$i – $f',
    };
    final (statusText, statusColor) = switch (day.state) {
      AttendanceState.sinEntrada => ('Sin entrada', AppColors.error),
      AttendanceState.enJornada => ('En jornada', AppColors.success),
      AttendanceState.enComida => ('En hora de comida', AppColors.warning),
      AttendanceState.jornadaTerminada => ('Completo', AppColors.accent),
    };

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IdentityAvatar(id: row.name),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if ((row.position ?? '').isNotEmpty)
                      Text(
                        row.position!,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _cell('Entrada', day.entrada ?? '--:--',
                  warn: day.isLate, warnText: day.isLate ? 'tarde' : null),
              _cell('Comida', comida, warn: day.mealExceeded,
                  warnText: day.mealExceeded ? 'excedida' : null),
              _cell('Salida', day.salida ?? '--:--'),
              _cell('Trabajado', day.workedLabel ?? '—'),
            ],
          ),
          if (!row.hasSchedule) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Sin horario asignado',
              style: TextStyle(color: AppColors.warning, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(String label, String value, {bool warn = false, String? warnText}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: warn ? AppColors.warning : AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (warnText != null)
            Text(warnText, style: const TextStyle(color: AppColors.warning, fontSize: 9)),
        ],
      ),
    );
  }
}
