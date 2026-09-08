// Formulario de tarea: el director elige departamento (la tarea le cae al
// manager); el manager elige responsable entre su gente.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/shared/teams/task_form_screen.dart';

Widget host(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

final depts = [
  DepartmentInfo(id: 'd1', companyId: 'c', name: 'Noticias', managerEmail: 'ana@doliv.test', employeeCount: 3),
  DepartmentInfo(id: 'd2', companyId: 'c', name: 'Ventas', managerEmail: null, employeeCount: 0),
];

void main() {
  testWidgets('director: elige departamento y ve a quién le llega', (tester) async {
    await tester.pumpWidget(host(TaskFormScreen(asDirector: true, departments: depts)));
    await tester.pumpAndSettle();

    expect(find.text('Departamento'), findsOneWidget);
    expect(find.text('Responsable'), findsNothing);
    expect(find.text('Noticias'), findsOneWidget);

    await tester.tap(find.text('Noticias'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Le llegará a ana@doliv.test'), findsOneWidget);

    await tester.tap(find.text('Ventas'));
    await tester.pumpAndSettle();
    expect(find.textContaining('aún no tiene manager'), findsOneWidget);
  });

  testWidgets('director sin departamento elegido no puede guardar', (tester) async {
    await tester.pumpWidget(host(TaskFormScreen(asDirector: true, departments: depts)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Cobertura');
    await tester.tap(find.text('Crear tarea'));
    await tester.pumpAndSettle();
    expect(find.text('Elige el departamento que hará la tarea.'), findsOneWidget);
  });

  testWidgets('director viene del tablero de un departamento: ya preseleccionado', (tester) async {
    await tester.pumpWidget(host(TaskFormScreen(departmentId: 'd1', asDirector: true, departments: depts)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Le llegará a ana@doliv.test'), findsOneWidget);
  });

  testWidgets('manager (o director en subtarea): elige responsable', (tester) async {
    await tester.pumpWidget(host(const TaskFormScreen(departmentId: 'd1')));
    await tester.pumpAndSettle();
    expect(find.text('Responsable'), findsOneWidget);
    expect(find.text('Departamento'), findsNothing);

    await tester.pumpWidget(host(TaskFormScreen(departmentId: 'd1', parentId: 'p', asDirector: true, departments: depts)));
    await tester.pumpAndSettle();
    expect(find.text('Responsable'), findsOneWidget);
    expect(find.text('Crear subtarea'), findsOneWidget);
  });
}
