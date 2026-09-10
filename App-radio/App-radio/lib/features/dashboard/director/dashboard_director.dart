import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/features/dashboard/director/director_home.dart';
import 'package:doliv_social/shared/widgets/appbar.dart';
import 'package:doliv_social/shared/widgets/app_menu_drawer.dart';

/// Dashboard para usuarios con rol [AppRole.director]: vista de toda la
/// empresa.
///
/// La pantalla de inicio ([DirectorHome]) muestra un recuadro para crear la
/// empresa mientras no exista y, en cuanto existe, los anuncios internos; la
/// administración de equipos, asistencia, contenido del sitio y calendario
/// vive ahora en el menú hamburguesa ([AppMenuDrawer]), que arma sus opciones
/// según el rol.
class DirectorDashboard extends StatelessWidget {
  /// Cuando se muestra como pestaña de `BottomNavBar`, el shell ya pinta la
  /// `MyAppBar` y el menú (fijos, no se deslizan al cambiar de pestaña), así
  /// que aquí se omiten. Como ruta suelta (`/dashboard/director`) sí los trae.
  const DirectorDashboard({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      appBar: embedded ? null : const MyAppBar(),
      drawer: embedded ? null : const AppMenuDrawer(),
      body: const DirectorHome(),
    );
  }
}
