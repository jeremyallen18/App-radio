import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/shared/home/announcements_board.dart';
import 'package:doliv_social/shared/widgets/appbar.dart';
import 'package:doliv_social/shared/widgets/app_menu_drawer.dart';

/// Dashboard para usuarios con rol [AppRole.manager].
///
/// La pantalla de inicio queda dedicada a los anuncios internos
/// ([AnnouncementsBoard]); las secciones del departamento (asistencia,
/// calendario, tareas…) viven ahora en el menú hamburguesa ([AppMenuDrawer]),
/// que arma sus opciones según el rol.
class ManagerDashboard extends StatelessWidget {
  /// Cuando se muestra como pestaña de `BottomNavBar`, el shell ya pinta la
  /// `MyAppBar` y el menú (fijos, no se deslizan al cambiar de pestaña), así
  /// que aquí se omiten. Como ruta suelta (`/dashboard/manager`) sí los trae.
  const ManagerDashboard({super.key, this.embedded = false});

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
