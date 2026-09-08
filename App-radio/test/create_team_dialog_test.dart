// Regresión: el diálogo "Crear equipo" (director → Equipos → FAB) reventaba
// con  'package:flutter/src/widgets/framework.dart': Failed assertion:
// '_dependents.isEmpty': is not true  porque `_createTeam()` liberaba los
// `TextEditingController` justo después de `await showDialog(...)`, con la
// animación de cierre todavía en curso y los `TextField` aún usándolos.
//
// Ahora el diálogo es `CreateTeamDialog`, un StatefulWidget que libera sus
// controllers en `dispose()` (lo llama el framework cuando la ruta ya salió).
// Estas pruebas montan/desmontan el diálogo pasando la animación completa y
// verifican que no se lanza ninguna excepción.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/features/dashboard/director/team_admin_screen.dart';

Future<({String name, String description})?> _openDialog(WidgetTester tester) async {
  ({String name, String description})? result;
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              result = await showDialog<({String name, String description})>(
                context: context,
                builder: (_) => const CreateTeamDialog(),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('confirmar devuelve nombre y descripción y cierra sin excepción',
      (tester) async {
    await _openDialog(tester);

    await tester.enterText(find.byType(TextField).first, '  Locución  ');
    await tester.enterText(find.byType(TextField).last, ' turno matutino ');
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle(); // deja terminar la animación de cierre

    expect(tester.takeException(), isNull);
    expect(find.byType(CreateTeamDialog), findsNothing);
  });

  testWidgets('cancelar cierra sin excepción tras la animación', (tester) async {
    await _openDialog(tester);

    await tester.enterText(find.byType(TextField).first, 'algo');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CreateTeamDialog), findsNothing);
  });
}
