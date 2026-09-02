import 'package:brl_task4/screens/dashboard.dart';
import 'package:brl_task4/screens/join_team.dart';
import 'package:brl_task4/screens/signup.dart';
import 'package:brl_task4/screens/login.dart';
import 'package:brl_task4/utils/Routes.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import'package:flutter/material.dart';
import 'design/design.dart';
import 'design/gallery/component_gallery_screen.dart';
import 'create&join-Team/create-team.dart';
import 'home_page/bottomnavbar.dart';
import 'package:brl_task4/screens/forgot%20password/forgot_pass.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Carga la preferencia de tema guardada ANTES del primer frame, para que
  // la app arranque directamente en el modo correcto (sin parpadeo).
  await ThemeController.instance.init();
  final dynamic storedValue = await secureStorage.readSecureData(key);
  runApp(MyApp(hasSession: storedValue != null));
}

/// Widget de app único: el tema y la tabla de rutas se declaran una sola vez.
/// [hasSession] decide únicamente la pantalla inicial.
class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.hasSession});

  final bool hasSession;

  @override
  Widget build(BuildContext context) {
    // `AnimatedBuilder` re-ejecuta este `build` cada vez que
    // `ThemeController` notifica un cambio de modo (claro/oscuro).
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeController.instance.themeMode,
          initialRoute: '/',
          routes: {
            '/': (context) => hasSession ? BottomNavBar() : SignUp(),
            MyRoutes.SignUpRoutes: (context) => SignUp(),
            MyRoutes.LoginRoutes: (context) => Login(),
            MyRoutes.dashbMemRoutes: (context) => dashb_mem(),
            MyRoutes.jointeamRoutes: (context) => join_team(),
            MyRoutes.CreateTeamScreen: (context) => CreateTeamScreen(),
            MyRoutes.BottomNavBar: (context) => BottomNavBar(),
            MyRoutes.Reset: (context) => ResetPass(),
            if (!kReleaseMode)
              MyRoutes.ComponentGallery: (context) => ComponentGalleryScreen(),
          },
          // Muchas pantallas leen sus colores directamente de `AppColors`
          // (no solo vía `Theme.of(context)`). Como esos son valores
          // estáticos, no se refrescan solos cuando cambia el modo: por
          // eso, además de pasar `theme`/`darkTheme`/`themeMode` arriba
          // (para lo que sí usa `Theme.of(context)`), se envuelve todo el
          // contenido navegable en un widget con una `Key` atada al modo
          // actual. Al cambiar la key, Flutter reconstruye ese árbol desde
          // cero, así que cada pantalla vuelve a leer `AppColors` con el
          // valor correcto. Esto reinicia la pila de navegación al
          // alternar el tema, que es el único costo de este approach.
          builder: (context, child) {
            return KeyedSubtree(
              key: ValueKey(ThemeController.instance.isDark),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
