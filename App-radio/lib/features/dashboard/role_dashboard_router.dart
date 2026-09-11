import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/core/store_token.dart';
import 'package:doliv_social/core/session.dart';
import 'package:doliv_social/features/dashboard/director/dashboard_director.dart';
import 'package:doliv_social/features/dashboard/employee/dashboard_employee.dart';
import 'package:doliv_social/features/dashboard/manager/dashboard_manager.dart';

const String _tokenKey = 'accessToken';
final SecureStorage _secureStorage = SecureStorage();

/// Pide el rol actual con `Session.getFreshRole()` (refresca contra
/// `/user/me` y cae al caché solo si falla) y muestra el dashboard que
/// corresponde al rol del usuario autenticado. Así un cambio de rol hecho
/// en el backend se refleja la próxima vez que se abre esta pantalla, sin
/// necesidad de cerrar sesión. Si el rol no se pudo determinar, se trata
/// como [AppRole.employee] por defecto.
class RoleDashboardRouter extends StatefulWidget {
  /// Se propaga al dashboard de rol: `true` cuando es la pestaña "Inicio" del
  /// `BottomNavBar` (el shell ya pone la `MyAppBar` fija).
  const RoleDashboardRouter({super.key, this.embedded = false});

  final bool embedded;

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
    return Session.getFreshRole(token);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppRole?>(
      future: _roleFuture,
      builder: (context, snapshot) {
        final embedded = widget.embedded;
        Widget content;
        if (snapshot.connectionState == ConnectionState.waiting) {
          content = embedded
              ? ColoredBox(
                  key: ValueKey('loading'),
                  color: AppColors.bgBase,
                  child: LoadingState(),
                )
              : Scaffold(
                  key: ValueKey('loading'),
                  backgroundColor: AppColors.bgBase,
                  body: LoadingState(),
                );
        } else {
          switch (snapshot.data) {
            case AppRole.director:
              content = DirectorDashboard(
                  key: const ValueKey('director'), embedded: embedded);
            case AppRole.manager:
              content = ManagerDashboard(
                  key: const ValueKey('manager'), embedded: embedded);
            case AppRole.employee:
            case null:
              content = EmployeeDashboard(
                  key: const ValueKey('employee'), embedded: embedded);
          }
        }
        return AnimatedSwitcher(
          duration: AppDurations.medium,
          child: content,
        );
      },
    );
  }
}
