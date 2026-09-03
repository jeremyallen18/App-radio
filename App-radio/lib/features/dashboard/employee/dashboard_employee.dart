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
  const EmployeeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      padding: EdgeInsets.zero,
      appBar: MyAppBar(),
      drawer: AppMenuDrawer(),
      body: AnnouncementsBoard(),
    );
  }
}
