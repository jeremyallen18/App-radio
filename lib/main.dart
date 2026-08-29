// app dev starts here
// only push here in dev branch
// do not merge in main branch

import 'package:doliv_social/screens/MarkTaskDone.dart';
import 'package:doliv_social/screens/dashboard.dart';
import 'package:doliv_social/screens/dashboard_director.dart';
import 'package:doliv_social/screens/dashboard_employee.dart';
import 'package:doliv_social/screens/dashboard_manager.dart';
import 'package:doliv_social/screens/directory/colleague_directory_screen.dart';
import 'package:doliv_social/screens/role_dashboard_router.dart';
import 'package:doliv_social/screens/site_content/site_content_auth_gate.dart';
import 'package:doliv_social/screens/site_content/site_content_hub.dart';
import 'package:doliv_social/screens/join_team.dart';
import 'package:doliv_social/screens/signup.dart';
import 'package:doliv_social/screens/login.dart';
import 'package:doliv_social/utils/Routes.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'design/design.dart';
import 'design/gallery/component_gallery_screen.dart';
import 'create&join-Team/create-team.dart';
import 'home_page/bottomnavbar.dart';
import 'package:doliv_social/screens/forgot%20password/forgot_pass.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'utils/connectivity_gate.dart';
import 'utils/radio_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.example.brl_task4.radio',
      androidNotificationChannelName: 'Radio Doliv en vivo',
      androidNotificationOngoing: true,
    );
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
        MyRoutes.DoneTask: (context) => const doneTask(),
        MyRoutes.Reset: (context) => const ResetPass(),
        if (!kReleaseMode)
          MyRoutes.ComponentGallery: (context) =>
              const ComponentGalleryScreen(),
      },
    );
  }
}
