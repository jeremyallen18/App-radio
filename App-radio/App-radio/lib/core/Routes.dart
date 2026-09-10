class MyRoutes {
  static String signUpRoutes = "/SignUp";
  static String loginRoutes = "/Login";
  static String dashbMemRoutes = "/dashb_mem";
  static String jointeamRoutes = "/join_team";
  static String createTeamScreen = "/CreateTeamScreen";
  static String bottomNavBar = "/BottomNavBar";

  /// Dashboards por rol. Entrada normal: `roleDashboardRoutes` (enruta por el
  /// rol cacheado); las específicas solo para navegación directa.
  static String roleDashboardRoutes = "/dashboard";
  static String directorDashboardRoutes = "/dashboard/director";

  /// Contenido del sitio público (RADIODOLIV_PAGINA), solo director.
  static String siteContentHubRoutes = "/dashboard/director/site-content";
  static String managerDashboardRoutes = "/dashboard/manager";
  static String employeeDashboardRoutes = "/dashboard/employee";

  /// Directorio interno de compañeros (búsqueda por área).
  static String directoryRoutes = "/directory";

  static String reset = "/ResetPass";

  /// Solo debug: galería del sistema de diseño.
  static String componentGallery = "/_ComponentGallery";
}
