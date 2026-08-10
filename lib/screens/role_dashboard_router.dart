import 'package:flutter/material.dart';

import '../design/design.dart';
import '../models/models.dart';
import '../models/storeToken.dart';
import '../utils/session.dart';
import 'dashboard_director.dart';
import 'dashboard_employee.dart';
import 'dashboard_manager.dart';

const String _tokenKey = 'accessToken';
final SecureStorage _secureStorage = SecureStorage();

/// Pide el rol actual con `Session.getFreshRole()` (refresca contra
/// `/user/me` y cae al caché solo si falla) y muestra el dashboard que
/// corresponde al rol del usuario autenticado. Así un cambio de rol hecho
/// en el backend se refleja la próxima vez que se abre esta pantalla, sin
/// necesidad de cerrar sesión. Si el rol no se pudo determinar, se trata
/// como [AppRole.employee] por defecto.
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
    _roleFuture = _loadRole();
  }

  Future<AppRole?> _loadRole() async {
    final token = await _secureStorage.readSecureData(_tokenKey);
    return Session.getFreshRole(token as String?);
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
