// La pantalla "Configuración" del perfil muestra las opciones correctas por
// rol: el director puede editar el nombre de la empresa; el resto no.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/features/dashboard/settings/account_settings_screen.dart';

UserProfile _profile(AppRole role) => UserProfile(
      id: 'u1',
      name: 'Ana Ruiz',
      email: 'ana@radiodoliv.com',
      role: role,
    );

Widget _host(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

void main() {
  testWidgets('director: ve empresa + nombre + correo + contraseña',
      (tester) async {
    await tester.pumpWidget(
      _host(AccountSettingsScreen(profile: _profile(AppRole.director))),
    );
    await tester.pump();

    expect(find.text('Nombre de la empresa'), findsOneWidget);
    expect(find.text('Nombre de usuario'), findsOneWidget);
    expect(find.text('Correo'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Ana Ruiz'), findsOneWidget);
    expect(find.text('ana@radiodoliv.com'), findsOneWidget);
  });

  testWidgets('empleado: NO ve la fila de nombre de empresa', (tester) async {
    await tester.pumpWidget(
      _host(AccountSettingsScreen(profile: _profile(AppRole.employee))),
    );
    await tester.pump();

    expect(find.text('Nombre de la empresa'), findsNothing);
    expect(find.text('Nombre de usuario'), findsOneWidget);
    expect(find.text('Correo'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
  });

  testWidgets('correo pendiente muestra el aviso y "Cancelar"', (tester) async {
    await tester.pumpWidget(
      _host(AccountSettingsScreen(
        profile: UserProfile(
          id: 'u1',
          name: 'Ana',
          email: 'ana@radiodoliv.com',
          role: AppRole.employee,
          pendingEmail: 'nueva@radiodoliv.com',
        ),
      )),
    );
    await tester.pump();

    expect(find.textContaining('Pendiente de confirmar: nueva@radiodoliv.com'),
        findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });
}
