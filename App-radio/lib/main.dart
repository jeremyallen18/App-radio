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

  // Push (FCM) solo está configurado para Android por ahora
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

  // Formateo de fechas/números en español de México
  Intl.defaultLocale = 'es_MX';
  await initializeDateFormatting('es_MX', null);

  // Tema (claro/oscuro) antes del primer frame para evitar parpadeo.
  await ThemeController.instance.init();

  // `just_audio_background` (controles en notificación / pantalla de
  // bloqueo).
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.example.brl_task4.radio',
      androidNotificationChannelName: 'Radio Doliv en vivo',
      androidNotificationOngoing: true,
    );
    // Ya es seguro usar el tag MediaItem al reproducir.
    radioBackgroundReady = true;
  } catch (e, st) {
    debugPrint('JustAudioBackground.init falló, se continúa sin él: $e\n$st');
  }
  // Tocar el singleton dispara la precarga del stream lo antes posible.
  RadioPlayer.instance;
  final dynamic storedValue = await secureStorage.readSecureData(key);
  // La sesión persiste mientras exista el token; solo "Cerrar sesión" o un
  // token rechazado la terminan.
  final bool hasSession = storedValue != null;
  if (hasSession && supportsPush) {
    unawaited(PushService.instance.init());
  }
  runApp(MyApp(hasSession: hasSession));
}

/// Widget raíz de la app: tema y rutas. [hasSession] elige la pantalla inicial.
class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.hasSession});

  final bool hasSession;

  @override
  Widget build(BuildContext context) {
    // Reconstruye al cambiar el modo (claro/oscuro).
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) => _buildApp(context),
    );
  }

  Widget _buildApp(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeController.instance.themeMode,
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
      // Fondo de marca + gate de conectividad. El `KeyedSubtree` atado al modo
      // reconstruye todo al cambiar de tema (reinicia la navegación) para que
      // cada pantalla relea `AppColors`.
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return KeyedSubtree(
          key: ValueKey(ThemeController.instance.isDark),
          child: ColoredBox(
            color: AppColors.bgBase,
            child: ConnectivityGate(child: child),
          ),
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
