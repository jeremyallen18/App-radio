import 'package:doliv_social/models/dept_task.dart';

/// Tareas completadas en un día concreto (para "Ritmo de la semana").
class DayCompletion {
  const DayCompletion({required this.day, required this.onTime, required this.late});

  /// Fecha a medianoche.
  final DateTime day;
  final int onTime;
  final int late;

  int get total => onTime + late;
}

/// Todo lo que muestra la pantalla de Progreso, calculado en el cliente a
/// partir del listado de tareas (`GET /dept-tasks`). Cálculo puro: no toca
/// red ni widgets, así se prueba con fechas fijas.
class ProgressStats {
  const ProgressStats({
    required this.done,
    required this.inProgress,
    required this.pending,
    required this.onTime,
    required this.late,
    required this.overdue,
    required this.week,
    required this.upcoming,
  });

  final int done;
  final int inProgress;

  /// Solo las que no han empezado (no incluye [inProgress]).
  final int pending;

  /// De las completadas: entregadas dentro del plazo (o sin plazo).
  final int onTime;

  /// De las completadas: entregadas pasado el plazo (`completedLate`).
  final int late;

  /// Sin completar y con la fecha límite ya pasada.
  final int overdue;

  /// Siete días que terminan hoy, en orden cronológico.
  final List<DayCompletion> week;

  /// Sin completar, con fecha límite hoy o después, las más próximas
  /// primero (máximo [maxUpcoming]).
  final List<DeptTask> upcoming;

  static const int maxUpcoming = 3;

  int get total => done + inProgress + pending;
  int get open => inProgress + pending;
  double get completionRatio => total == 0 ? 0 : done / total;
  int get completionPct => (completionRatio * 100).round();
  int get weekTotal => week.fold(0, (n, d) => n + d.total);
  bool get isEmpty => total == 0;

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  /// [now] se inyecta en tests; por defecto es la hora actual.
  factory ProgressStats.fromTasks(List<DeptTask> tasks, {DateTime? now}) {
    final today = _midnight(now ?? DateTime.now());
    final weekStart = today.subtract(const Duration(days: 6));

    var done = 0, inProgress = 0, pending = 0, onTime = 0, late = 0, overdue = 0;
    final byDay = <DateTime, List<int>>{
      for (var i = 0; i < 7; i++) weekStart.add(Duration(days: i)): [0, 0],
    };
    final upcoming = <DeptTask>[];

    for (final t in tasks) {
      switch (t.status) {
        case DeptTaskStatus.completada:
          done++;
          if (t.completedLate) {
            late++;
          } else {
            onTime++;
          }
          final at = t.completedAt;
          if (at != null) {
            final day = _midnight(at);
            final bucket = byDay[day];
            if (bucket != null) bucket[t.completedLate ? 1 : 0]++;
          }
        case DeptTaskStatus.enProgreso:
        case DeptTaskStatus.pendiente:
          if (t.status == DeptTaskStatus.enProgreso) {
            inProgress++;
          } else {
            pending++;
          }
          final due = t.dueDate;
          if (due != null) {
            if (_midnight(due).isBefore(today)) {
              overdue++;
            } else {
              upcoming.add(t);
            }
          }
      }
    }

    upcoming.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    return ProgressStats(
      done: done,
      inProgress: inProgress,
      pending: pending,
      onTime: onTime,
      late: late,
      overdue: overdue,
      week: [
        for (final e in byDay.entries)
          DayCompletion(day: e.key, onTime: e.value[0], late: e.value[1]),
      ],
      upcoming: upcoming.take(maxUpcoming).toList(),
    );
  }

  /// Días que faltan para [due] contando desde hoy (0 = vence hoy).
  static int daysUntil(DateTime due, {DateTime? now}) {
    final today = _midnight(now ?? DateTime.now());
    return _midnight(due).difference(today).inDays;
  }

  /// "Vence hoy", "Mañana", "En 3 días", "Hace 2 días".
  static String dueLabel(DateTime due, {DateTime? now}) {
    final d = daysUntil(due, now: now);
    if (d == 0) return 'Vence hoy';
    if (d == 1) return 'Mañana';
    if (d > 1) return 'En $d días';
    if (d == -1) return 'Ayer';
    return 'Hace ${-d} días';
  }
}
