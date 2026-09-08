// Tarjeta de tarea rediseñada, filtros del tablero y humo del detalle.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/dept_task.dart';
import 'package:doliv_social/shared/teams/task_board_card.dart';
import 'package:doliv_social/shared/teams/widgets/board_summary.dart';
import 'package:doliv_social/shared/teams/widgets/task_visuals.dart';

DeptTask task({
  String id = 't1',
  String title = 'Cobertura',
  String status = 'pendiente',
  String? assignedId,
  DateTime? due,
  String? review,
  bool late = false,
  String? note,
  int subs = 0,
  int subsDone = 0,
}) =>
    DeptTask.fromJson({
      'id': id,
      'title': title,
      'status': status,
      if (assignedId != null) 'assignedTo': {'id': assignedId, 'name': 'Ana', 'email': 'ana@x'},
      if (due != null) 'dueDate': due.toIso8601String(),
      if (review != null) 'reviewStatus': review,
      if (note != null) 'reviewNote': note,
      'completedLate': late,
      'subtaskCount': subs,
      'subtaskDoneCount': subsDone,
    });

Widget host(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

Widget card(
  DeptTask t, {
  bool canManage = true,
  bool canComplete = true,
  VoidCallback? onToggle,
  VoidCallback? onApprove,
}) =>
    TaskBoardCard(
      task: t,
      canManage: canManage,
      canComplete: canComplete,
      busy: false,
      onToggleDone: onToggle ?? () {},
      onCycleStatus: () {},
      onEdit: () {},
      onAddSubtask: () {},
      onDelete: () {},
      onOpen: () {},
      onApprove: onApprove ?? () {},
      onReject: () {},
    );

void main() {
  group('TaskTone', () {
    final now = DateTime(2026, 9, 4);
    test('prioriza revisión, devolución y vencimiento sobre el estado', () {
      expect(TaskTone.of(task(status: 'completada', review: 'pendiente_revision'), now: now), TaskTone.toReview);
      expect(TaskTone.of(task(status: 'completada'), now: now), TaskTone.done);
      expect(TaskTone.of(task(review: 'rechazada'), now: now), TaskTone.returned);
      expect(TaskTone.of(task(due: DateTime(2026, 9, 1)), now: now), TaskTone.overdue);
      expect(TaskTone.of(task(status: 'en_progreso', due: DateTime(2026, 9, 10)), now: now), TaskTone.inProgress);
      expect(TaskTone.of(task(), now: now), TaskTone.pending);
    });
  });

  group('TaskBoardCard', () {
    testWidgets('muestra título, responsable, cuenta atrás y barra de subtareas', (tester) async {
      final t = task(assignedId: 'u1', due: DateTime.now().add(const Duration(days: 1)), subs: 4, subsDone: 3);
      await tester.pumpWidget(host(card(t)));
      await tester.pumpAndSettle();
      expect(find.text('Cobertura'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Mañana'), findsOneWidget);
      expect(find.text('3/4 subtareas'), findsOneWidget);
      expect(find.byType(StatusRail), findsOneWidget);
    });

    testWidgets('la casilla no responde si no se puede completar', (tester) async {
      var toggled = 0;
      await tester.pumpWidget(host(card(task(), canComplete: false, canManage: false, onToggle: () => toggled++)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sin responsable: solo un manager puede completarla'));
      await tester.pumpAndSettle();
      expect(toggled, 0);
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    });

    testWidgets('el manager ve Aprobar/Devolver solo cuando está por revisar', (tester) async {
      var approved = 0;
      await tester.pumpWidget(host(card(task(status: 'completada', review: 'pendiente_revision'), onApprove: () => approved++)));
      await tester.pumpAndSettle();
      expect(find.text('Por revisar'), findsOneWidget);
      await tester.tap(find.text('Aprobar'));
      expect(approved, 1);

      await tester.pumpWidget(host(card(task(status: 'completada', review: 'pendiente_revision'), canManage: false)));
      await tester.pumpAndSettle();
      expect(find.text('Aprobar'), findsNothing);
    });

    testWidgets('muestra la nota de devolución', (tester) async {
      await tester.pumpWidget(host(card(task(review: 'rechazada', note: 'Falta el audio'))));
      await tester.pumpAndSettle();
      expect(find.text('Devuelta: Falta el audio'), findsOneWidget);
      expect(find.text('Devuelta'), findsOneWidget); // chip de tono
    });
  });

  group('BoardFilter', () {
    final tasks = [
      task(id: 'a', assignedId: 'me'),
      task(id: 'b', status: 'completada', review: 'pendiente_revision'),
      task(id: 'c', due: DateTime(2020, 1, 1)),
      task(id: 'd', status: 'completada'),
    ];
    test('filtra en el cliente', () {
      List<String> ids(BoardFilter f) =>
          tasks.where((t) => f.matches(t, currentUserId: 'me')).map((t) => t.id).toList();
      expect(ids(BoardFilter.all), ['a', 'b', 'c', 'd']);
      expect(ids(BoardFilter.mine), ['a']);
      expect(ids(BoardFilter.open), ['a', 'c']);
      expect(ids(BoardFilter.toReview), ['b']);
      expect(ids(BoardFilter.overdue), ['c']);
    });

    testWidgets('el resumen muestra conteos y chips con número', (tester) async {
      BoardFilter? picked;
      await tester.pumpWidget(host(BoardSummary(
        tasks: tasks,
        selected: BoardFilter.all,
        onSelect: (f) => picked = f,
        currentUserId: 'me',
        showMine: true,
      )));
      await tester.pumpAndSettle();
      expect(find.text('pendientes'), findsOneWidget);
      expect(find.text('hechas'), findsOneWidget);
      expect(find.text('Por revisar'), findsOneWidget);
      expect(find.text('Vencidas'), findsOneWidget);
      await tester.tap(find.text('Mías'));
      expect(picked, BoardFilter.mine);
    });
  });
}
