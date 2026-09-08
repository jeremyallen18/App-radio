// Regresión: en equipos con fuente del sistema grande / "zoom de pantalla"
// activado (Honor/EMUI, Samsung "enorme", accesibilidad), la fila de
// "Recuérdame" + "¿Olvidaste tu contraseña?" del login se desbordaba y los
// controles se pintaban unos encima de otros. Debe reacomodarse sin overflow.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/shared/auth/login.dart';

Widget _host(Widget screen) => MaterialApp(theme: AppTheme.dark, home: screen);

void main() {
  testWidgets(
    'Login no se desborda con pantalla estrecha y fuente del sistema grande',
    (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 780 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: _host(const Login()),
        ),
      );
      await tester.pumpAndSettle();

      // Ambos controles siguen presentes...
      expect(find.text('Recuérdame'), findsOneWidget);
      expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);

      // ...y ningún RenderFlex se desbordó al montar.
      expect(tester.takeException(), isNull);
    },
  );
}
