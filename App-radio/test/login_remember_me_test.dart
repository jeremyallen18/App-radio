// "Recordar" en el login NO repinta las credenciales en los campos: solo
// recuerda el estado del check y deja que el gestor de contraseñas del sistema
// (Android Autofill / iCloud Llavero) guarde y ofrezca correo y contraseña.

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doliv_social/core/remember_me.dart';
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/shared/auth/login.dart';

Widget _host(Widget screen) => MaterialApp(theme: AppTheme.dark, home: screen);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('RememberMe (bandera del check)', () {
    test('loadFlag devuelve true solo cuando la marca es "1"', () async {
      FlutterSecureStorage.setMockInitialValues({'rememberMeFlag': '1'});
      expect(await RememberMe.loadFlag(), isTrue);

      FlutterSecureStorage.setMockInitialValues({'rememberMeFlag': '0'});
      expect(await RememberMe.loadFlag(), isFalse);

      FlutterSecureStorage.setMockInitialValues({});
      expect(await RememberMe.loadFlag(), isFalse);
    });

    test('saveFlag persiste "1" / "0"', () async {
      await RememberMe.saveFlag(true);
      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'rememberMeFlag'), '1');

      await RememberMe.saveFlag(false);
      expect(await storage.read(key: 'rememberMeFlag'), '0');
    });
  });

  testWidgets(
      'con la marca activa el check aparece marcado pero los campos '
      'siguen vacíos', (tester) async {
    // Aunque hubiera valores de una versión anterior de la app, NO se usan.
    FlutterSecureStorage.setMockInitialValues({
      'rememberMeFlag': '1',
      'savedEmail': 'ana@radiodoliv.com',
      'savedPassword': 'Secr3to!',
    });

    await tester.pumpWidget(_host(const Login()));
    await tester.pumpAndSettle();

    final fields =
        tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(fields[0].controller?.text, isEmpty);
    expect(fields[1].controller?.text, isEmpty);
    expect(find.text('ana@radiodoliv.com'), findsNothing);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });

  testWidgets('sin marca: campos vacíos y check apagado', (tester) async {
    await tester.pumpWidget(_host(const Login()));
    await tester.pumpAndSettle();

    final fields =
        tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(fields[0].controller?.text, isEmpty);
    expect(fields[1].controller?.text, isEmpty);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
  });

  testWidgets('el formulario expone autofill del sistema (grupo + hints)',
      (tester) async {
    await tester.pumpWidget(_host(const Login()));
    await tester.pumpAndSettle();

    expect(find.byType(AutofillGroup), findsOneWidget);

    final inputs =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(inputs[0].autofillHints, contains(AutofillHints.username));
    expect(inputs[1].autofillHints, contains(AutofillHints.password));
  });
}
