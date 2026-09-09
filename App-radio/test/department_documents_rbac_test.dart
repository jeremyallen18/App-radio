// La pantalla de documentos por departamento respeta el RBAC en la UI:
// con canManage=false NO aparece el botón de subir; con canManage=true sí.
// (El backend valida lo mismo de forma autoritativa.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/shared/resources/department_documents_screen.dart';

Widget _host(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

void main() {
  testWidgets('canManage=false: sin FAB de subir, con buscador', (tester) async {
    await tester.pumpWidget(_host(const DepartmentDocumentsScreen(
      departmentId: 'd1',
      canManage: false,
    )));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(AppTextField), findsOneWidget); // el buscador siempre está
  });

  testWidgets('canManage=true: aparece el FAB "Subir"', (tester) async {
    await tester.pumpWidget(_host(const DepartmentDocumentsScreen(
      departmentId: 'd1',
      canManage: true,
    )));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Subir'), findsOneWidget);
  });
}
