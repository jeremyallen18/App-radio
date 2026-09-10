import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/shared/home/announcements_board.dart';
import 'package:doliv_social/shared/widgets/appbar.dart';
import 'package:doliv_social/shared/widgets/app_menu_drawer.dart';

/// Dashboard para usuarios con rol [AppRole.employee] (o cuando el rol no
/// se pudo determinar — ver `RoleDashboardRouter`).
///
/// La pantalla de inicio queda dedicada a los anuncios internos
/// ([AnnouncementsBoard]); todas las secciones operativas viven ahora en el
/// menú hamburguesa ([AppMenuDrawer]), que arma sus opciones según el rol.
class EmployeeDashboard extends StatelessWidget {
  /// Cuando se muestra como pestaña de `BottomNavBar`, el shell ya pinta la
  /// `MyAppBar` y el menú (fijos, no se deslizan al cambiar de pestaña), así
  /// que aquí se omiten. Como ruta suelta (`/dashboard/employee`) sí los trae.
  const EmployeeDashboard({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      appBar: embedded ? null : const MyAppBar(),
      drawer: embedded ? null : const AppMenuDrawer(),
      body: const AnnouncementsBoard(),
    );
  }
}
