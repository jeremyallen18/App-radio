import 'dart:async';

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

/// Filtro de estado sobre la lista ya cargada (client-side, sin llamada nueva).
enum _StatusFilter { todos, sinEntrada, enJornada, enComida, completo }

extension on _StatusFilter {
  String get label => switch (this) {
        _StatusFilter.todos => 'Todos',
        _StatusFilter.sinEntrada => 'Sin entrada',
        _StatusFilter.enJornada => 'En jornada',
        _StatusFilter.enComida => 'En comida',
        _StatusFilter.completo => 'Completo',
      };

  bool matches(AttendanceState state) => switch (this) {
        _StatusFilter.todos => true,
        _StatusFilter.sinEntrada => state == AttendanceState.sinEntrada,
        _StatusFilter.enJornada => state == AttendanceState.enJornada,
        _StatusFilter.enComida => state == AttendanceState.enComida,
        _StatusFilter.completo => state == AttendanceState.jornadaTerminada,
      };
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  DateTime _date = DateTime.now();
  List<AdminAttendanceRow> _rows = const [];
  bool _loading = true;
  String? _error;

  final _searchController = TextEditingController();
  String _query = '';
  _StatusFilter _filter = _StatusFilter.todos;

  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _searchController.dispose();
    super.dispose();
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

  void _shiftDate(int days) {
    final next = _date.add(Duration(days: days));
    if (next.isAfter(DateTime.now())) return;
    setState(() => _date = next);
    _load();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
  }

  List<AdminAttendanceRow> get _visibleRows {
    return _rows.where((r) {
      if (!_filter.matches(r.day.state)) return false;
      if (_query.isEmpty) return true;
      return r.name.toLowerCase().contains(_query) ||
          (r.position ?? '').toLowerCase().contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Asistencia de empleados'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
          ),
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
          final visible = _visibleRows;
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
                _DateStrip(
                  date: _date,
                  isToday: _isToday,
                  now: _now,
                  onPrev: () => _shiftDate(-1),
                  onNext: _isToday ? null : () => _shiftDate(1),
                ),
                const SizedBox(height: AppSpacing.md),
                _SummaryStrip(rows: _rows),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _searchController,
                  hintText: 'Buscar por nombre o puesto',
                  prefixIcon: const Icon(Icons.search),
                ),
                const SizedBox(height: AppSpacing.md),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in _StatusFilter.values) ...[
                        AppFilterChip(
                          label: f.label,
                          selected: _filter == f,
                          onTap: () => setState(() => _filter = f),
                          count: f == _StatusFilter.todos
                              ? _rows.length
                              : _rows.where((r) => f.matches(r.day.state)).length,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (visible.isEmpty)
                  EmptyState(
                    icon: Icons.groups_outlined,
                    title: _rows.isEmpty
                        ? 'No hay empleados para mostrar'
                        : 'Nadie coincide con la búsqueda',
                    message: _rows.isEmpty
                        ? 'Aún no hay empleados asignados a tu ámbito.'
                        : 'Prueba con otro nombre, puesto o filtro.',
                  )
                else
                  ...visible.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _EmployeeRowCard(
                          row: r,
                          onDetails: () => Navigator.of(context).push(
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
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({
    required this.date,
    required this.isToday,
    required this.now,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime date;
  final bool isToday;
  final DateTime now;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _fmtClock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left),
          color: AppColors.textMuted,
          tooltip: 'Día anterior',
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event, size: 16, color: AppColors.textMuted),
              const SizedBox(width: AppSpacing.sm),
              Text(
                isToday ? 'Hoy · ${_fmtDate(date)}' : _fmtDate(date),
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          color: onNext == null
              ? AppColors.textMuted.withValues(alpha: 0.3)
              : AppColors.textMuted,
          tooltip: 'Día siguiente',
        ),
        const SizedBox(width: AppSpacing.sm),
        Row(
          children: [
            Icon(Icons.schedule, size: 14, color: AppColors.accent),
            const SizedBox(width: 4),
            Text(
              _fmtClock(now),
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.rows});
  final List<AdminAttendanceRow> rows;

  @override
  Widget build(BuildContext context) {
    int count(bool Function(AdminAttendanceRow) test) =>
        rows.where(test).length;
    final enJornada = count((r) => r.day.state == AttendanceState.enJornada);
    final enComida = count((r) => r.day.state == AttendanceState.enComida);
    final completo =
        count((r) => r.day.state == AttendanceState.jornadaTerminada);
    final sinEntrada = count((r) => r.day.state == AttendanceState.sinEntrada);
    final tarde = count((r) => r.day.isLate);
    final excedidas = count((r) => r.day.mealExceeded);

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              _stat('En jornada', enJornada, AppColors.success),
              _stat('En comida', enComida, AppColors.warning),
              _stat('Completas', completo, AppColors.accent),
              _stat('Sin entrada', sinEntrada, AppColors.error),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _stat('Llegadas tarde', tarde, AppColors.warning),
              _stat('Comida excedida', excedidas, AppColors.error),
              const Spacer(),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 20),
          ),
          Text(label,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _EmployeeRowCard extends StatelessWidget {
  const _EmployeeRowCard({required this.row, required this.onDetails});
  final AdminAttendanceRow row;
  final VoidCallback onDetails;

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
    final schedule = day.schedule;
    final scheduleLabel = schedule != null
        ? 'Horario: ${schedule.entryTime} – ${schedule.exitTime}'
        : null;

    return AppCard(
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
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      [
                        'ID: ${row.employeeId}',
                        if ((row.position ?? '').isNotEmpty) row.position!,
                      ].join(' · '),
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              _cell('Comida', comida,
                  warn: day.mealExceeded,
                  warnText: day.mealExceeded ? 'excedida' : null),
              _cell('Salida', day.salida ?? '--:--'),
              _cell('Trabajado', day.workedLabel ?? '—'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  row.hasSchedule
                      ? (scheduleLabel ?? '')
                      : 'Sin horario asignado',
                  style: TextStyle(
                    color: row.hasSchedule
                        ? AppColors.textMuted
                        : AppColors.warning,
                    fontSize: 11,
                  ),
                ),
              ),
              TextButton(
                onPressed: onDetails,
                child: const Text('Detalles'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(String label, String value,
      {bool warn = false, String? warnText}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
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
            Text(warnText,
                style: TextStyle(color: AppColors.warning, fontSize: 9)),
        ],
      ),
    );
  }
}
