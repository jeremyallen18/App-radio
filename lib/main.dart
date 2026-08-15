// app dev starts here
// only push here in dev branch
// do not merge in main branch

import 'package:doliv_social/screens/MarkTaskDone.dart';
import 'package:doliv_social/screens/dashboard.dart';
import 'package:doliv_social/screens/dashboard_director.dart';
import 'package:doliv_social/screens/dashboard_employee.dart';
import 'package:doliv_social/screens/dashboard_manager.dart';
import 'package:doliv_social/screens/role_dashboard_router.dart';
import 'package:doliv_social/screens/join_team.dart';
import 'package:doliv_social/screens/signup.dart';
import 'package:doliv_social/screens/login.dart';
import 'package:doliv_social/utils/Routes.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'design/design.dart';
import 'design/gallery/component_gallery_screen.dart';
import 'create&join-Team/create-team.dart';
import 'home_page/bottomnavbar.dart';
import 'package:doliv_social/screens/forgot%20password/forgot_pass.dart';
import 'utils/connectivity_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        MyRoutes.DoneTask: (context) => const doneTask(),
        MyRoutes.Reset: (context) => const ResetPass(),
        if (!kReleaseMode)
          MyRoutes.ComponentGallery: (context) =>
              const ComponentGalleryScreen(),
      },
    );
  }
}
