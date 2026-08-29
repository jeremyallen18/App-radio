// app dev starts here
// only push here in dev branch 
// do not merge in main branch

import 'package:brl_task4/screens/MarkTaskDone.dart';
import 'package:brl_task4/screens/dashboard.dart';
import 'package:brl_task4/screens/dashboard_director.dart';
import 'package:brl_task4/screens/dashboard_employee.dart';
import 'package:brl_task4/screens/dashboard_manager.dart';
import 'package:brl_task4/screens/role_dashboard_router.dart';
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
import 'package:brl_task4/leave approval/leave.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'utils/radio_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Debe inicializarse ANTES de crear cualquier AudioPlayer (por eso va
  // antes de tocar RadioPlayer.instance): habilita el foreground service
  // de Android que mantiene la radio sonando con la app minimizada o la
  // pantalla bloqueada, con controles en la notificación.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.brl_task4.radio',
    androidNotificationChannelName: 'Radio Doliv en vivo',
    androidNotificationOngoing: true,
  );
  // Referenciar el singleton aquí (antes de mostrar cualquier pantalla)
  // dispara su precarga del stream en segundo plano lo antes posible, para
  // que cuando el usuario llegue a tocar el botón de radio ya esté listo.
  RadioPlayer.instance;
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
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
        MyRoutes.DirectorDashboardRoutes: (context) => const DirectorDashboard(),
        MyRoutes.ManagerDashboardRoutes: (context) => const ManagerDashboard(),
        MyRoutes.EmployeeDashboardRoutes: (context) => const EmployeeDashboard(),
        MyRoutes.DoneTask: (context) => const doneTask(),
        MyRoutes.Reset: (context) => const ResetPass(),
        if (!kReleaseMode)
          MyRoutes.ComponentGallery: (context) => const ComponentGalleryScreen(),
      },
    );
  }
}
