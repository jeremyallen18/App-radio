import 'package:flutter_test/flutter_test.dart';

import 'package:doliv_social/models/dept_task.dart';
import 'package:doliv_social/shared/home/progress/progress_stats.dart';

DeptTask task({
  String status = 'pendiente',
  String? due,
  String? completedAt,
  bool late = false,
  String title = 't',
}) =>
    DeptTask.fromJson({
      'id': title,
      'title': title,
      'status': status,
      if (due != null) 'dueDate': due,
      if (completedAt != null) 'completedAt': completedAt,
      'completedLate': late,
    });

void main() {
  final now = DateTime(2026, 9, 4, 15, 30); // viernes

  test('reparte los tres estados y la puntualidad', () {
    final s = ProgressStats.fromTasks([
      task(status: 'completada', completedAt: '2026-09-04 10:00:00'),
      task(status: 'completada', completedAt: '2026-09-02 10:00:00', late: true),
      task(status: 'en_progreso', due: '2026-09-10'),
      task(status: 'pendiente', due: '2026-09-01'), // vencida
      task(status: 'pendiente'),
    ], now: now);

    expect(s.done, 2);
    expect(s.inProgress, 1);
    expect(s.pending, 2);
    expect(s.total, 5);
    expect(s.onTime, 1);
    expect(s.late, 1);
    expect(s.overdue, 1);
    expect(s.completionPct, 40);
  });

  test('la semana son 7 días que terminan hoy, con hechas a tiempo y tarde', () {
    final s = ProgressStats.fromTasks([
      task(status: 'completada', completedAt: '2026-09-04 09:00:00'),
      task(status: 'completada', completedAt: '2026-09-04 18:00:00', late: true),
      task(status: 'completada', completedAt: '2026-08-29 09:00:00'), // primer día
      task(status: 'completada', completedAt: '2026-08-28 09:00:00'), // fuera
      task(status: 'completada'), // sin fecha: cuenta en done, no en semana
    ], now: now);

    expect(s.week.length, 7);
    expect(s.week.first.day, DateTime(2026, 8, 29));
    expect(s.week.last.day, DateTime(2026, 9, 4));
    expect(s.week.last.onTime, 1);
    expect(s.week.last.late, 1);
    expect(s.week.first.total, 1);
    expect(s.weekTotal, 3);
    expect(s.done, 5);
  });

  test('próximas: sin completar, hoy o después, ordenadas, máximo 3', () {
    final s = ProgressStats.fromTasks([
      task(title: 'c', due: '2026-09-09'),
      task(title: 'a', due: '2026-09-04', status: 'en_progreso'),
      task(title: 'b', due: '2026-09-06'),
      task(title: 'd', due: '2026-09-20'),
      task(title: 'x', due: '2026-09-01'), // vencida, no sale
      task(title: 'y', due: '2026-09-05', status: 'completada'),
    ], now: now);

    expect(s.upcoming.map((t) => t.title), ['a', 'b', 'c']);
  });

  test('etiquetas de vencimiento', () {
    expect(ProgressStats.dueLabel(DateTime(2026, 9, 4), now: now), 'Vence hoy');
    expect(ProgressStats.dueLabel(DateTime(2026, 9, 5), now: now), 'Mañana');
    expect(ProgressStats.dueLabel(DateTime(2026, 9, 7), now: now), 'En 3 días');
    expect(ProgressStats.dueLabel(DateTime(2026, 9, 2), now: now), 'Hace 2 días');
  });

  test('sin tareas', () {
    final s = ProgressStats.fromTasks(const [], now: now);
    expect(s.isEmpty, isTrue);
    expect(s.completionRatio, 0);
    expect(s.week.length, 7);
  });
}
