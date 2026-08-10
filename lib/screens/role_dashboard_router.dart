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
