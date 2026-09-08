class MyRoutes {
  static String signUpRoutes = "/SignUp";
  static String loginRoutes = "/Login";
  static String dashbMemRoutes = "/dashb_mem";
  static String jointeamRoutes = "/join_team";
  static String createTeamScreen = "/CreateTeamScreen";
  static String bottomNavBar = "/BottomNavBar";

  /// Dashboards por rol (Director / Manager / Employee). El punto de
  /// entrada normal es `roleDashboardRoutes` (lee el rol cacheado y
  /// enruta); las tres rutas específicas solo son necesarias para
  /// navegación directa (deep link, back button, debug).
  static String roleDashboardRoutes = "/dashboard";
  static String directorDashboardRoutes = "/dashboard/director";

  /// Gestión de contenido del sitio público (RADIODOLIV_PAGINA), exclusiva
  /// del director. La navegación interna (lista -> formulario) no usa
  /// rutas nombradas, solo esta pantalla de entrada.
  static String siteContentHubRoutes = "/dashboard/director/site-content";
  static String managerDashboardRoutes = "/dashboard/manager";
  static String employeeDashboardRoutes = "/dashboard/employee";

  /// Directorio interno de compañeros (búsqueda por área). La ficha de una
  /// persona se abre por navegación directa desde el listado, sin ruta propia.
  static String directoryRoutes = "/directory";

  static String reset = "/ResetPass";

  /// Solo debug: galería de referencia del sistema de diseño (Fase 0).
  static String componentGallery = "/_ComponentGallery";
}
