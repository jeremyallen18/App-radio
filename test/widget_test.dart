// Pruebas mínimas de la pantalla de login: que renderice y que sus validadores
// bloqueen el envío con datos inválidos. No tocan la red — LoginApi() solo se
// ejecuta si el formulario valida, así que un formulario inválido nunca llega
// a hacer la petición HTTP.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doliv_social/screens/login.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('la pantalla de login muestra sus campos y el botón', (tester) async {
    await tester.pumpWidget(_wrap(const Login()));

    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
  });

  testWidgets('rechaza el envío con los campos vacíos', (tester) async {
    await tester.pumpWidget(_wrap(const Login()));

    await tester.tap(find.text('Iniciar sesión').last);
    await tester.pump();

    expect(find.text('Ingresa tu correo'), findsOneWidget);
    expect(find.text('Mínimo 6 caracteres'), findsOneWidget);
  });

  testWidgets('rechaza un correo con formato inválido', (tester) async {
    await tester.pumpWidget(_wrap(const Login()));

    await tester.enterText(find.byType(TextFormField).first, 'esto-no-es-un-correo');
    await tester.enterText(find.byType(TextFormField).last, 'Secreta123');
    await tester.tap(find.text('Iniciar sesión').last);
    await tester.pump();

    expect(find.text('Correo inválido'), findsOneWidget);
    expect(find.text('Mínimo 6 caracteres'), findsNothing);
  });

  testWidgets('rechaza una contraseña de menos de 6 caracteres', (tester) async {
    await tester.pumpWidget(_wrap(const Login()));

    await tester.enterText(find.byType(TextFormField).first, 'ana@ejemplo.com');
    await tester.enterText(find.byType(TextFormField).last, '123');
    await tester.tap(find.text('Iniciar sesión').last);
    await tester.pump();

    expect(find.text('Mínimo 6 caracteres'), findsOneWidget);
    expect(find.text('Correo inválido'), findsNothing);
  });

  testWidgets('el botón de ver contraseña alterna el ocultamiento', (tester) async {
    await tester.pumpWidget(_wrap(const Login()));

    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();
    expect(find.byIcon(Icons.visibility), findsOneWidget);
  });
}
