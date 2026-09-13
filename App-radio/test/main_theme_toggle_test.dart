import 'package:doliv_social/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Regresión: alternar el tema (claro/oscuro) desde el switch del drawer debe
// refrescar la pantalla que quedó debajo, sin necesidad de navegar a otro
// lado. `AppColors` son getters sobre una bandera estática, no un
// InheritedWidget, así que nada avisa a un widget ya montado que debe
// releerlos; visto en producción como texto del modo claro sobre fondo
// oscuro y viceversa, en pantallas que el BottomNavBar mantiene vivas entre
// pestañas o que simplemente quedan debajo del drawer donde vive el switch.
//
// `ThemeController.setDark()` corrige esto llamando a
// `WidgetsBinding.instance.reassembleApplication()` (la misma llamada que usa
// el hot reload) para forzar que el árbol ya montado vuelva a ejecutar
// build(). Un intento anterior de arreglarlo con una `key` en `MaterialApp`
// no servía: su `Navigator` vive bajo un `GlobalKey` persistente
// (`navigatorKey`, como `appNavigatorKey` en main.dart) que Flutter reutiliza
// aunque todo lo de arriba cambie, así que ese Navigator (y todo lo que ya
// tenía adentro) nunca llegaba a reconstruirse de verdad. Este test reproduce
// esa misma forma real (MaterialApp con un navigatorKey persistente) para
// evitar que el caso vuelva a "arreglarse en el test" sin arreglarse en la app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final appNavigatorKey = GlobalKey<NavigatorState>();
  int buildCount = 0;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    buildCount = 0;
  });

  testWidgets(
      'toggling ThemeController rebuilds an already-mounted screen (persistent navigatorKey)',
      (tester) async {
    await tester.pumpWidget(
      AnimatedBuilder(
        animation: ThemeController.instance,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeController.instance.themeMode,
          navigatorKey: appNavigatorKey,
          home: Scaffold(
            body: Builder(builder: (context) {
              buildCount++;
              return Text('color=${AppColors.textPrimary}');
            }),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final countBefore = buildCount;

    await tester.runAsync(() async {
      await ThemeController.instance.setDark(!ThemeController.instance.isDark);
    });
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(buildCount, greaterThan(countBefore),
        reason: 'La pantalla que ya estaba montada debe reconstruirse '
            '(y releer AppColors) al alternar el tema, sin navegar a otro lado.');
  });
}
