// app dev starts here
// only push here in dev branch
// do not merge in main branch

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
import 'package:doliv_social/core/Routes.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;
import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/design/gallery/component_gallery_screen.dart';
import 'package:doliv_social/shared/teams/create_join_team/create-team.dart';
import 'package:doliv_social/features/shell/bottomnavbar.dart';
import 'package:doliv_social/shared/auth/forgot_password/forgot_pass.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:doliv_social/core/connectivity_gate.dart';
import 'package:doliv_social/core/audio/radio_player.dart';
import 'package:doliv_social/core/route_refresh.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Formateo de fechas/números en español de México para toda la app
  // (calendarios, `intl` DateFormat, table_calendar). Debe correr antes de
  // `runApp` para que el primer frame ya salga localizado.
  Intl.defaultLocale = 'es_MX';
  await initializeDateFormatting('es_MX', null);

  // just_audio no trae implementación nativa para Windows ni Linux (solo
  // Android/iOS/macOS/Web). just_audio_media_kit le agrega esas dos
  // plataformas por debajo con media_kit (libmpv) sin cambiar la API que
  // usa `RadioPlayer`; en el resto de plataformas no hace nada (deja la
  // implementación nativa de just_audio intacta).
  JustAudioMediaKit.title = 'Radio Doliv';
  JustAudioMediaKit.ensureInitialized();

  // `just_audio_background` (controles en notificación / pantalla de
  // bloqueo) depende de audio_service, que TAMPOCO tiene implementación
  // para Windows/Linux — inicializarlo ahí lanzaría una excepción antes de
  // llegar a `runApp`. En esas dos plataformas la radio simplemente suena
  // sin esos controles; en el resto (donde sí aplica el concepto de
  // "reproducción en segundo plano") se inicializa como siempre.
  final bool supportsBackgroundAudio = !kIsWeb &&
      defaultTargetPlatform != TargetPlatform.windows &&
      defaultTargetPlatform != TargetPlatform.linux;
  if (supportsBackgroundAudio) {
    // Debe inicializarse ANTES de crear cualquier AudioPlayer (por eso va
    // antes de tocar RadioPlayer.instance): habilita el foreground service
    // de Android que mantiene la radio sonando con la app minimizada o la
    // pantalla bloqueada, con controles en la notificación.
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
  }
  // Referenciar el singleton aquí (antes de mostrar cualquier pantalla)
  // dispara su precarga del stream en segundo plano lo antes posible, para
  // que cuando el usuario llegue a tocar el botón de radio ya esté listo.
  RadioPlayer.instance;
  final dynamic storedValue = await secureStorage.readSecureData(key);
  // Si el usuario dejó "Recuérdame" apagado, la sesión no debe sobrevivir a
  // un reinicio de la app aunque el token siga guardado: se descarta aquí y
  // se manda a Login. Una bandera ausente (instalaciones previas a este
  // cambio) se trata como "recordar" para no cerrar sesión a nadie de golpe.
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
      // Todos los widgets de calendario/fecha del sistema en español.
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // El centrado a ancho fijo en escritorio ahora lo decide cada pantalla
      // (ver `AppScaffold.centerOnDesktop`): las pantallas de formulario/
      // lectura siguen centradas y angostas, pero el shell principal
      // (`BottomNavBar`) usa todo el ancho disponible para mostrar una barra
      // de navegación lateral y grillas de varias columnas.
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
        MyRoutes.RoleDashboardRoutes: (context) => const RoleDashboardRouter(),
        MyRoutes.DirectorDashboardRoutes: (context) =>
            const DirectorDashboard(),
        MyRoutes.ManagerDashboardRoutes: (context) => const ManagerDashboard(),
        MyRoutes.EmployeeDashboardRoutes: (context) =>
            const EmployeeDashboard(),
        MyRoutes.SiteContentHubRoutes: (context) =>
            const SiteContentAuthGate(child: SiteContentHubScreen()),
        MyRoutes.DirectoryRoutes: (context) => const ColleagueDirectoryScreen(),
        MyRoutes.Reset: (context) => const ResetPass(),
        if (!kReleaseMode)
          MyRoutes.ComponentGallery: (context) =>
              const ComponentGalleryScreen(),
      },
    );
  }
}
