import 'package:flutter/widgets.dart';

/// Puntos de quiebre y helpers para adaptar la UI entre móvil, tablet y
/// escritorio.
///
/// Tres tamaños:
/// - móvil (`< tablet`): una sola columna, navegación inferior.
/// - tablet (`tablet`..`desktop`): sigue con navegación inferior pero con
///   más aire y, donde aplica, 2 columnas.
/// - escritorio (`>= desktop`): barra de navegación lateral (`NavigationRail`)
///   en vez de la inferior, y grillas de hasta 3 columnas donde el contenido
///   lo permite.
class AppBreakpoints {
  AppBreakpoints._();

  /// Ancho a partir del cual se considera "tablet": ya no es un teléfono en
  /// mano, pero tampoco tiene el espacio de una ventana de escritorio.
  static const double tablet = 600;

  /// Ancho a partir del cual se considera "escritorio" (ventana redimensionable,
  /// mouse/teclado como entrada principal, espacio para navegación lateral).
  static const double desktop = 900;

  /// Ancho máximo del contenido en pantallas de formulario/lectura (login,
  /// signup, detalle), para evitar que se estiren de borde a borde.
  static const double maxContentWidth = 640;

  /// Ancho máximo de un botón primario en escritorio.
  static const double maxButtonWidth = 360;

  /// Ancho de la barra de navegación lateral en escritorio.
  static const double sidebarWidth = 220;
  static const double sidebarWidthCollapsed = 88;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;

  /// Cuántas columnas caben para tarjetas de tamaño similar (departamentos,
  /// equipos, tareas), dado el ancho disponible para el contenido (ya
  /// descontada cualquier barra lateral).
  static int columnsForWidth(double width) {
    if (width >= 900) return 3;
    if (width >= tablet) return 2;
    return 1;
  }
}
