// Humo: las cinco pantallas de autenticación montan sin excepciones con el
// tema de la app, y la validación local sigue funcionando sin red.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/shared/auth/forgot_password/forgot_pass.dart';
import 'package:doliv_social/shared/auth/forgot_password/new_password.dart';
import 'package:doliv_social/shared/auth/forgot_password/otp_verify.dart';
import 'package:doliv_social/shared/auth/login.dart';
import 'package:doliv_social/shared/auth/signup.dart';
import 'package:doliv_social/shared/auth/widgets/auth_header.dart';
import 'package:doliv_social/shared/auth/widgets/otp_code_field.dart';

Widget host(Widget screen) => MaterialApp(theme: AppTheme.dark, home: screen);

void main() {
  testWidgets('Login monta con cabecera, dial y campos', (tester) async {
    await tester.pumpWidget(host(const Login()));
    await tester.pumpAndSettle();
    expect(find.byType(AuthHeader), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(find.text('Recuérdame'), findsOneWidget);

    // Validación local sin red.
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa tu correo'), findsOneWidget);
    expect(find.text('Mínimo 6 caracteres'), findsOneWidget);
  });

  testWidgets('Registro monta y muestra el medidor al escribir', (tester) async {
    await tester.pumpWidget(host(const SignUp()));
    await tester.pumpAndSettle();
    expect(find.text('Crea tu cuenta'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(2), 'Doliv2026!');
    await tester.pumpAndSettle();
    expect(find.text('Fuerte'), findsOneWidget);
  });

  testWidgets('Recuperar (correo) monta con paso 1 de 3', (tester) async {
    await tester.pumpWidget(host(const ResetPass()));
    await tester.pumpAndSettle();
    expect(find.text('RECUPERAR ACCESO · PASO 1 DE 3'), findsOneWidget);
  });

  testWidgets('Código monta con 6 casillas y cuenta atrás de reenvío',
      (tester) async {
    await tester.pumpWidget(host(const OTPVerify(email: 'ana@doliv.test')));
    await tester.pump();
    expect(find.text('RECUPERAR ACCESO · PASO 2 DE 3'), findsOneWidget);
    expect(find.byType(OtpCodeField), findsOneWidget);
    expect(find.textContaining('Reenviar código en'), findsOneWidget);
    expect(find.textContaining('ana@doliv.test'), findsOneWidget);
    // Desmontar cancela el temporizador.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Nueva contraseña monta con paso 3 de 3 y valida coincidencia',
      (tester) async {
    await tester.pumpWidget(host(const ChangePassword(email: 'ana@doliv.test')));
    await tester.pumpAndSettle();
    expect(find.text('RECUPERAR ACCESO · PASO 3 DE 3'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'abcdef');
    await tester.enterText(find.byType(TextFormField).at(1), 'abcdeg');
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
  });
}
