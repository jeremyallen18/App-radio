// app dev starts here
// only push here in dev branch
// do not merge in main branch

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:doliv_social/core/push/push_service.dart';
import 'package:doliv_social/shared/board/dashboard.dart';
import 'package:doliv_social/features/dashboard/director/dashboard_director.dart';
import 'package:doliv_social/features/dashboard/employee/dashboard_employee.dart';
import 'package:doliv_social/features/dashboard/manager/dashboard_manager.dart';
import 'package:doliv_social/shared/directory/colleague_directory_screen.dart';
import 'package:doliv_social/features/dashboard/role_dashboard_router.dart';
import 'package:doliv_social/features/dashboard/director/site_content/site_content_auth_gate.dart';
import 'package:doliv_social/features/dashboard/director/site_content/site_content_hub.dart';
import 'package:doliv_social/shared/teams/join_team.dart';
import 'package:doliv_social/shared/auth/signup.dart';
import 'package:doliv_social/shared/auth/login.dart';
import 'package:doliv_social/core/routes.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/design/gallery/component_gallery_screen.dart';
import 'package:doliv_social/shared/teams/create_join_team/create_team.dart';
import 'package:doliv_social/features/shell/bottomnavbar.dart';
import 'package:doliv_social/shared/auth/forgot_password/forgot_pass.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:doliv_social/core/connectivity_gate.dart';
import 'package:doliv_social/core/audio/radio_player.dart';
import 'package:doliv_social/core/route_refresh.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Push (FCM) solo está configurado para Android (ver firebase_options.dart,
  // que lanza en otras plataformas). En iOS se omite para no romper el
  // arranque de la app. Nunca debe impedir llegar a `runApp`.
  final bool supportsPush =
      defaultTargetPlatform == TargetPlatform.android;
  if (supportsPush) {
    try {
      await ensureFirebaseInitialized();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Firebase/push init falló, se continúa sin push: $e');
    }
  }

  // Formateo de fechas/números en español de México para toda la app
  // (calendarios, `intl` DateFormat, table_calendar). Debe correr antes de
  // `runApp` para que el primer frame ya salga localizado.
  Intl.defaultLocale = 'es_MX';
  await initializeDateFormatting('es_MX', null);

  // `just_audio_background` (controles en notificación / pantalla de
  // bloqueo). Debe inicializarse ANTES de crear cualquier AudioPlayer (por
  // eso va antes de tocar RadioPlayer.instance): habilita el foreground
  // service de Android que mantiene la radio sonando con la app minimizada o
  // la pantalla bloqueada, con controles en la notificación.
  //
  // Si esta inicialización falla (por ejemplo audio_service no puede
  // registrar su servicio en ciertas versiones/OEMs de Android), NO debe
  // impedir que la app arranque: se captura el error y se sigue sin los
  // controles en segundo plano — la radio igual suena desde la app.
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.example.brl_task4.radio',
      androidNotificationChannelName: 'Radio Doliv en vivo',
      androidNotificationOngoing: true,
    );
    // Solo ahora es seguro usar el tag MediaItem al reproducir la radio.
    radioBackgroundReady = true;
  } catch (e, st) {
    debugPrint('JustAudioBackground.init falló, se continúa sin él: $e\n$st');
  }
  // Referenciar el singleton aquí (antes de mostrar cualquier pantalla)
  // dispara su precarga del stream en segundo plano lo antes posible, para
  // que cuando el usuario llegue a tocar el botón de radio ya esté listo.
  RadioPlayer.instance;
  final dynamic storedValue = await secureStorage.readSecureData(key);
  // La sesión persiste mientras exista el token: sobrevive a cerrar o matar la
  // app y solo termina cuando el usuario pulsa "Cerrar sesión" (o el backend
  // rechaza el token). El check "Recuérdame" ya no interviene aquí; solo
  // decide si el formulario de login aparece con las credenciales precargadas.
  final bool hasSession = storedValue != null;
  if (hasSession && supportsPush) {
    unawaited(PushService.instance.init());
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
      navigatorKey: appNavigatorKey,
      navigatorObservers: [routeObserver],
      // Todos los widgets de calendario/fecha del sistema en español.
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Envuelve toda la app en el fondo de marca + el gate de conectividad
      // (muestra `OfflineView` si el backend no responde).
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return ColoredBox(
          color: AppColors.bgBase,
          child: ConnectivityGate(child: child),
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) => hasSession ? const BottomNavBar() : const Login(),
        MyRoutes.signUpRoutes: (context) => const SignUp(),
        MyRoutes.loginRoutes: (context) => const Login(),
        MyRoutes.dashbMemRoutes: (context) => const DashbMem(),
        MyRoutes.jointeamRoutes: (context) => const JoinTeamScreen(),
        MyRoutes.createTeamScreen: (context) => const CreateTeamScreen(),
        MyRoutes.bottomNavBar: (context) => const BottomNavBar(),
        MyRoutes.roleDashboardRoutes: (context) => const RoleDashboardRouter(),
        MyRoutes.directorDashboardRoutes: (context) =>
            const DirectorDashboard(),
        MyRoutes.managerDashboardRoutes: (context) => const ManagerDashboard(),
        MyRoutes.employeeDashboardRoutes: (context) =>
            const EmployeeDashboard(),
        MyRoutes.siteContentHubRoutes: (context) =>
            const SiteContentAuthGate(child: SiteContentHubScreen()),
        MyRoutes.directoryRoutes: (context) => const ColleagueDirectoryScreen(),
        MyRoutes.reset: (context) => const ResetPass(),
        if (!kReleaseMode)
          MyRoutes.componentGallery: (context) =>
              const ComponentGalleryScreen(),
      },
    );
  }
}
