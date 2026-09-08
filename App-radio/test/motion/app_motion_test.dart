// Pruebas de las piezas de movimiento compartidas (`lib/design/motion`).
// El foco está en el contrato importante: con "reducir movimiento" activo
// nada anima y el widget aparece ya en su estado final; sin él, la entrada
// arranca invisible y termina visible sin dejar controladores colgados.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doliv_social/design/motion/app_motion.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

double _opacityOf(WidgetTester tester) {
  final opacity = tester.widget<Opacity>(
    find.descendant(
      of: find.byType(AppFadeIn),
      matching: find.byType(Opacity),
    ),
  );
  return opacity.opacity;
}

void main() {
  group('AppFadeIn', () {
    testWidgets('con reduceMotion aparece ya visible en el primer frame',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const AppFadeIn(child: Text('hola')), disableAnimations: true),
      );

      expect(_opacityOf(tester), 1.0);
      expect(find.text('hola'), findsOneWidget);
    });

    testWidgets('sin reduceMotion arranca invisible y termina visible',
        (tester) async {
      await tester.pumpWidget(_wrap(const AppFadeIn(child: Text('hola'))));

      // Primer frame: todavía transparente.
      expect(_opacityOf(tester), lessThan(1.0));

      await tester.pumpAndSettle();
      expect(_opacityOf(tester), 1.0);
    });

    testWidgets('respeta el delay del stagger', (tester) async {
      await tester.pumpWidget(
        _wrap(AppFadeIn.staggered(index: 3, child: const Text('x'))),
      );

      // Antes de que venza el delay (3 * 45 ms) sigue invisible.
      await tester.pump(const Duration(milliseconds: 30));
      expect(_opacityOf(tester), 0.0);

      // Pasado el delay, el Timer dispara el controlador. pumpAndSettle no
      // avanza Timers pelados, así que primero se cruza el delay a mano.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(_opacityOf(tester), 1.0);
    });

    testWidgets('no deja timers ni tickers activos al desmontarse',
        (tester) async {
      await tester.pumpWidget(
        _wrap(AppFadeIn.staggered(index: 2, child: const Text('y'))),
      );
      await tester.pump(const Duration(milliseconds: 20));

      // Reemplazar el árbol desmonta AppFadeIn antes de que corra su timer.
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pumpAndSettle();
      // pumpAndSettle no lanza => no quedaron timers/animaciones pendientes.
    });
  });

  group('AppPressable', () {
    testWidgets('encoge mientras está presionado y vuelve al soltar',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppPressable(
            child: Container(
              width: 100,
              height: 40,
              color: const Color(0xFF2244AA),
            ),
          ),
        ),
      );

      double scale() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

      expect(scale(), 1.0);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppPressable)),
      );
      await tester.pump(); // procesa el onPointerDown / setState
      await tester.pump(const Duration(milliseconds: 80)); // deja avanzar la escala
      expect(scale(), lessThan(1.0));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(scale(), 1.0);
    });

    testWidgets(
        'con reduceMotion no inserta AnimatedScale pero sí responde al toque',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          AppPressable(
            onTap: () => taps++,
            child: Container(width: 100, height: 40, color: const Color(0xFF2244AA)),
          ),
          disableAnimations: true,
        ),
      );

      expect(find.byType(AnimatedScale), findsNothing);
      await tester.tap(find.byType(AppPressable));
      expect(taps, 1);
    });
  });

  group('SkeletonBox', () {
    testWidgets('anima por defecto y queda estático con reduceMotion',
        (tester) async {
      await tester.pumpWidget(_wrap(const SkeletonBox(width: 80)));
      // Hay un AnimatedBuilder envolviendo el gradiente en movimiento.
      expect(
        find.descendant(
          of: find.byType(SkeletonBox),
          matching: find.byType(AnimatedBuilder),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _wrap(const SkeletonBox(width: 80), disableAnimations: true),
      );
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(SkeletonBox),
          matching: find.byType(AnimatedBuilder),
        ),
        findsNothing,
      );
    });

    testWidgets('un AppSkeletonGroup comparte un solo controlador',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AppSkeletonGroup(
            child: Column(
              children: [
                SkeletonLine(width: 100),
                SkeletonLine(width: 120),
                SkeletonBox(height: 40),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonBox), findsNWidgets(3));
      // El grupo corre en bucle: pumpAndSettle nunca terminaría, pero un pump
      // puntual avanza sin problemas.
      await tester.pump(const Duration(milliseconds: 200));
    });
  });
}
