// Humo de las vistas de Progreso rediseñadas: montan con datos, muestran el
// medidor, el ritmo semanal y las próximas entregas; y el vacío sigue ahí.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/dept_task.dart';
import 'package:doliv_social/services/team_service.dart';
import 'package:doliv_social/shared/home/director_performance_view.dart';
import 'package:doliv_social/shared/home/personal_progress_view.dart';
import 'package:doliv_social/shared/home/progress/completion_gauge.dart';
import 'package:doliv_social/shared/home/progress/department_stack_bars.dart';
import 'package:doliv_social/shared/home/progress/progress_stats.dart';
import 'package:doliv_social/shared/home/progress/weekly_rhythm_chart.dart';

Widget host(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

DeptTask task(String title, {String status = 'pendiente', DateTime? due, DateTime? done, bool late = false}) =>
    DeptTask.fromJson({
      'id': title,
      'title': title,
      'status': status,
      if (due != null) 'dueDate': due.toIso8601String(),
      if (done != null) 'completedAt': done.toIso8601String(),
      'completedLate': late,
    });

void main() {
  testWidgets('vista personal: medidor, ritmo, puntualidad y próximas', (tester) async {
    final now = DateTime.now();
    final stats = ProgressStats.fromTasks([
      task('Editar promo', status: 'completada', done: now),
      task('Guion matutino', status: 'completada', done: now.subtract(const Duration(days: 1)), late: true),
      task('Entrevista', status: 'en_progreso', due: now.add(const Duration(days: 1))),
      task('Cortinillas', due: now.add(const Duration(days: 4))),
    ]);
    await tester.pumpWidget(host(PersonalProgressView(stats: stats)));
    await tester.pumpAndSettle();

    expect(find.byType(CompletionGauge), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.byType(WeeklyRhythmChart), findsOneWidget);
    expect(find.text('A tiempo'), findsOneWidget);
    expect(find.text('Con retardo'), findsOneWidget);
    expect(find.text('Vencidas'), findsOneWidget);
    expect(find.text('Entrevista'), findsOneWidget);
    expect(find.text('Mañana'), findsOneWidget);
    expect(find.text('En 4 días'), findsOneWidget);
  });

  testWidgets('vista personal vacía', (tester) async {
    await tester.pumpWidget(host(PersonalProgressView(stats: ProgressStats.fromTasks(const []))));
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay tareas asignadas'), findsOneWidget);
    expect(find.byType(CompletionGauge), findsNothing);
  });

  testWidgets('vista del director: medidor + barras por departamento ordenadas por avance',
      (tester) async {
    const data = DeptTasksByDepartment(
      departments: [
        DepartmentTaskCounts(departmentId: '1', departmentName: 'Noticias', pending: 4, inProgress: 1, done: 2, total: 6),
        DepartmentTaskCounts(departmentId: '2', departmentName: 'Producción', pending: 1, inProgress: 0, done: 5, total: 6),
        DepartmentTaskCounts(departmentId: '3', departmentName: 'Ventas', pending: 0, inProgress: 0, done: 0, total: 0),
      ],
      totalPending: 5,
      totalInProgress: 1,
      totalDone: 7,
      total: 12,
    );
    await tester.pumpWidget(host(const DirectorPerformanceView(data: data)));
    await tester.pumpAndSettle();

    expect(find.byType(CompletionGauge), findsOneWidget);
    expect(find.text('58%'), findsOneWidget); // 7/12
    expect(find.byType(DepartmentStackBars), findsOneWidget);
    expect(find.text('2 de 3 con tareas'), findsOneWidget);
    // Producción (83 %) arriba de Noticias (33 %); Ventas sin tareas al final.
    final yProd = tester.getTopLeft(find.text('Producción')).dy;
    final yNot = tester.getTopLeft(find.text('Noticias')).dy;
    final yVen = tester.getTopLeft(find.text('Ventas')).dy;
    expect(yProd, lessThan(yNot));
    expect(yNot, lessThan(yVen));
    expect(find.text('Sin tareas'), findsOneWidget);
    // Sin listado completo no hay tarjeta de ritmo.
    expect(find.byType(WeeklyRhythmChart), findsNothing);
  });
}
