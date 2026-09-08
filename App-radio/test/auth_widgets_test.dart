// Componentes de las pantallas de autenticación rediseñadas: casillas OTP,
// medidor de fortaleza y cabecera con dial.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/shared/auth/widgets/auth_header.dart';
import 'package:doliv_social/shared/auth/widgets/otp_code_field.dart';
import 'package:doliv_social/shared/auth/widgets/password_strength_meter.dart';

Widget host(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('OtpCodeField', () {
    testWidgets('muestra los dígitos escritos y avisa al completar los 6',
        (tester) async {
      final controller = TextEditingController();
      String? completed;
      await tester.pumpWidget(host(OtpCodeField(
        controller: controller,
        onCompleted: (c) => completed = c,
      )));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '123');
      await tester.pumpAndSettle();
      expect(completed, isNull);
      for (final d in ['1', '2', '3']) {
        expect(find.text(d), findsOneWidget);
      }

      // Pegar el código completo de golpe.
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pumpAndSettle();
      expect(completed, '123456');
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('ignora letras y recorta a 6 dígitos', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(host(OtpCodeField(controller: controller)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '12ab34567');
      await tester.pumpAndSettle();
      expect(controller.text, '123456');
    });
  });

  group('PasswordStrength.evaluate', () {
    test('vacía y cortas', () {
      expect(PasswordStrength.evaluate(''), PasswordStrength.empty);
      expect(PasswordStrength.evaluate('Ab1!'), PasswordStrength.weak);
      expect(PasswordStrength.evaluate('abcdef'), PasswordStrength.weak);
    });
    test('media y fuerte', () {
      expect(PasswordStrength.evaluate('abcdefg1'), PasswordStrength.medium);
      expect(PasswordStrength.evaluate('Doliv2026!'), PasswordStrength.strong);
    });
  });

  testWidgets('el medidor enciende barras y etiqueta según la contraseña',
      (tester) async {
    await tester.pumpWidget(host(const PasswordStrengthMeter(password: '')));
    expect(find.text('Débil'), findsNothing);

    await tester.pumpWidget(host(const PasswordStrengthMeter(password: 'Doliv2026!')));
    await tester.pumpAndSettle();
    expect(find.text('Fuerte'), findsOneWidget);
  });

  testWidgets('la cabecera deriva el eyebrow de la estación', (tester) async {
    await tester.pumpWidget(host(const AuthHeader(
      station: AuthStation.resetCode,
      title: 'Ingresa el código',
    )));
    await tester.pumpAndSettle();
    expect(find.text('RECUPERAR ACCESO · PASO 2 DE 3'), findsOneWidget);
    expect(find.byType(FrequencyDial), findsOneWidget);
  });

  test('las estaciones quedan en orden y dentro del dial', () {
    final positions = AuthStation.values.map((s) => s.position).toList();
    for (var i = 1; i < positions.length; i++) {
      expect(positions[i], greaterThan(positions[i - 1]));
    }
    expect(positions.first, greaterThan(0));
    expect(positions.last, lessThan(1));
  });
}
