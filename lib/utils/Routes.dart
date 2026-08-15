class MyRoutes {
  static String SignUpRoutes = "/SignUp";
  static String LoginRoutes = "/Login";
  static String dashbMemRoutes = "/dashb_mem";
  static String jointeamRoutes = "/join_team";
  static String tdetailRoutes = "/t_detail";
  static String CreateTeamScreen = "/CreateTeamScreen";
  static String BottomNavBar ="/BottomNavBar";

  /// Dashboards por rol (Director / Manager / Employee). El punto de
  /// entrada normal es `RoleDashboardRoutes` (lee el rol cacheado y
  /// enruta); las tres rutas específicas solo son necesarias para
  /// navegación directa (deep link, back button, debug).
  static String RoleDashboardRoutes = "/dashboard";
  static String DirectorDashboardRoutes = "/dashboard/director";

  /// Gestión de contenido del sitio público (RADIODOLIV_PAGINA), exclusiva
  /// del director. La navegación interna (lista -> formulario) no usa
  /// rutas nombradas, solo esta pantalla de entrada.
  static String SiteContentHubRoutes = "/dashboard/director/site-content";
  static String ManagerDashboardRoutes = "/dashboard/manager";
  static String EmployeeDashboardRoutes = "/dashboard/employee";

  static String MResign = "/Mresign";
  static String AddTask = "/addTask";
  static String DoneTask = "/doneTask";
  static String Reset = "/ResetPass";

  /// Solo debug: galería de referencia del sistema de diseño (Fase 0).
  static String ComponentGallery = "/_ComponentGallery";
}