// app dev starts here

import 'package:doliv_social/shared/board/dashboard.dart';
import 'package:doliv_social/shared/directory/colleague_directory_screen.dart';
import 'package:doliv_social/shared/teams/join_team.dart';
import 'package:doliv_social/shared/auth/signup.dart';
import 'package:doliv_social/shared/auth/login.dart';
import 'package:doliv_social/core/Routes.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/design/gallery/component_gallery_screen.dart';
import 'package:doliv_social/shared/teams/create_join_team/create-team.dart';
import 'package:doliv_social/features/shell/bottomnavbar.dart';
import 'package:doliv_social/shared/auth/forgot_password/forgot_pass.dart';
import 'package:doliv_social/core/connectivity_gate.dart';
import 'package:doliv_social/core/route_refresh.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Formateo de fechas/números en español de México para toda la app.
  // Debe correr antes de `runApp` para que el primer frame ya salga localizado.
  Intl.defaultLocale = 'es_MX';
  await initializeDateFormatting('es_MX', null);

  final dynamic storedValue = await secureStorage.readSecureData(key);
  // Si el usuario dejó "Recuérdame" apagado, la sesión no debe sobrevivir a
  // un reinicio de la app aunque el token siga guardado: se descarta aquí y
  // se manda a Login. Una bandera ausente se trata como "recordar".
  final dynamic rememberMe = await secureStorage.readSecureData(rememberMeKey);
  final bool hasSession = storedValue != null && rememberMe != '0';
  if (storedValue != null && !hasSession) {
    await secureStorage.deleteSecureData(key);
    await secureStorage.deleteSecureData(rememberMeKey);
  }
  runApp(MyApp(hasSession: hasSession));
}

/// Widget de app único: el tema y la tabla de rutas se declaran una sola vez.
/// [hasSession] decide únicamente la pantalla inicial.
class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.hasSession});

  final bool hasSession;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      navigatorObservers: [routeObserver],
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return ColoredBox(
          color: AppColors.bgBase,
          child: ConnectivityGate(child: child),
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) => hasSession ? const BottomNavBar() : const SignUp(),
        MyRoutes.SignUpRoutes: (context) => const SignUp(),
        MyRoutes.LoginRoutes: (context) => const Login(),
        MyRoutes.dashbMemRoutes: (context) => const dashb_mem(),
        MyRoutes.jointeamRoutes: (context) => const join_team(),
        MyRoutes.CreateTeamScreen: (context) => const CreateTeamScreen(),
        MyRoutes.BottomNavBar: (context) => const BottomNavBar(),
        MyRoutes.DirectoryRoutes: (context) => const ColleagueDirectoryScreen(),
        MyRoutes.Reset: (context) => const ResetPass(),
        if (!kReleaseMode)
          MyRoutes.ComponentGallery: (context) =>
              const ComponentGalleryScreen(),
      },
    );
  }
}
