import 'package:flutter/material.dart';

import '../design/design.dart';
import '../models/models.dart';
import '../utils/session.dart';
import 'dashboard_director.dart';
import 'dashboard_employee.dart';
import 'dashboard_manager.dart';

/// Lee `Session.getCachedRole()` (sin red) y muestra el dashboard que
/// corresponde al rol del usuario autenticado. Si el rol no se pudo
/// determinar (falló el fetch de `/user/me` o la sesión es muy antigua),
/// se trata como [AppRole.employee] por defecto.
import 'login.dart';

/// Muestra el dashboard que corresponde al rol del usuario autenticado. Si
/// el rol no se pudo determinar (falló el fetch de `/user/me`), se trata
/// como [AppRole.employee] por defecto.
///
/// IMPORTANTE: pide el rol con `Session.fetchCurrentUser(token)` (red) en
/// vez de `Session.getCachedRole()` (solo caché). El login dispara ese
/// mismo fetch en segundo plano sin esperarlo (`unawaited`) antes de
/// navegar al `BottomNavBar`, así que justo después de iniciar sesión el
/// caché todavía puede tener el rol de la sesión anterior. Usar el caché
/// aquí producía el bug de "se ve el dashboard del rol viejo hasta que
/// navego a otra pestaña y regreso a Inicio".
class RoleDashboardRouter extends StatefulWidget {
  const RoleDashboardRouter({super.key});

  @override
  State<RoleDashboardRouter> createState() => _RoleDashboardRouterState();
}

class _RoleDashboardRouterState extends State<RoleDashboardRouter> {
  late Future<AppRole?> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = Session.getCachedRole();
    _roleFuture = _resolveRole();
  }

  Future<AppRole?> _resolveRole() async {
    final token = await secureStorage.readSecureData(key);
    final profile = await Session.fetchCurrentUser(token ?? '');
    if (profile != null) return profile.role;
    // El fetch falló (sin red, token vencido, etc.): usar lo último que
    // haya quedado cacheado en vez de forzar siempre a "employee".
    return Session.getCachedRole();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppRole?>(
      future: _roleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.bgBase,
            body: LoadingState(),
          );
        }

        switch (snapshot.data) {
          case AppRole.director:
            return const DirectorDashboard();
          case AppRole.manager:
            return const ManagerDashboard();
          case AppRole.employee:
          case null:
            return const EmployeeDashboard();
        }
      },
    );
  }
}
