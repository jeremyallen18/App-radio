# Diseño — `test_1`: clon recortado de App-radio

**Fecha:** 2026-09-05
**Estado:** Aprobado (diseño)

## Objetivo

Construir en `C:\xampp\htdocs\radio-doliv\test_1` (hoy un template Flutter
por defecto) un clon de `App-radio` que contenga **únicamente**:

- **Autenticación por defecto:** login, registro y recuperación de contraseña.
- **Semana 1 — Perfil de usuario:** pantalla completa del empleado (datos,
  puesto y departamento); foto de perfil subible/cambiable desde la galería;
  indicadores de tareas pendientes, completadas y equipos; ajuste de
  márgenes y comportamiento responsive (móvil y escritorio).
- **Semana 2 — Directorio de compañeros del área:** listado con búsqueda por
  área y ficha de cada compañero (contacto y rol).
- **Tareas:** el tablero de tareas por departamento y "mis tareas".

Se muestran como **"Próximamente"** (entrada visible, sin funcionalidad, el
código funcional se elimina):

- Registro de entrada y salida (asistencia).
- Semana 3 — Edición de la página web (contenido de radiodoliv.com).
- Semana 4 — Sintonización de la transmisión ("En vivo").

Todo lo demás se elimina por completo.

## Decisiones tomadas

| Tema | Decisión |
|---|---|
| Estrategia | Copiar todo `App-radio` a `test_1` y luego recortar. |
| Backend | El clon apunta al backend existente (`lib/core/api_config.dart` sin cambios: `http://192.168.100.250/hive-backend`). No se copia `hive-backend/`. |
| Funciones omitidas | Pantalla "Próximamente" reutilizando `coming_soon_card.dart` / `coming_soon_list.dart`. |
| Paquete Dart | Se mantiene `doliv_social` (no se renombra ningún import). |
| Navegación | `BottomNavBar` pasa de 4 a 3 pestañas: Tareas · Directorio · Perfil. |
| Tests | No hay suite que dependa de las áreas tocadas; la verificación es `flutter analyze` limpio + compilación. |

## Base del proyecto

Copiar de `App-radio/` a `test_1/` sobrescribiendo el template:

- `lib/` (completo, luego se recorta)
- `android/`, `ios/`, `web/`, `windows/`, `linux/`, `macos/`
- `assets/` (contiene `assets/logo/logo.png` y `logo.svg`; también existe
  `lib/assets/**` que ya está declarado en pubspec)
- `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `.metadata`

Se conserva de `test_1`: el directorio `.git`, `README.md`, `.idea/`,
`test_1.iml`.

## Funciones que se conservan (funcionales)

### Autenticación
- `lib/shared/auth/login.dart`, `signup.dart`, `verify_email_banner.dart`
- `lib/shared/auth/forgot_password/**` (`forgot_pass.dart`, `otp_verify.dart`,
  `new_password.dart`, `reset_api.dart`)
- `lib/shared/auth/widgets/**` (`auth_form_panel.dart`, `auth_header.dart`,
  `otp_code_field.dart`, `password_strength_meter.dart`)
- `lib/services/auth_service.dart`

### Perfil (Semana 1)
- `lib/shared/home/profile.dart`, `profile_hero.dart`, `profile_widgets.dart`
- `lib/services/profile_service.dart` — `ProfileApi.fetchOverview()`
  (perfil + contadores pendientes/completadas + equipos) y
  `ProfileApi.uploadPhoto(filePath)` (galería vía `image_picker`).

### Directorio (Semana 2)
- `lib/shared/directory/colleague_directory_screen.dart`,
  `colleague_profile_screen.dart`, `directory_api.dart`

### Tareas y soporte de equipos
- `lib/shared/board/dashboard.dart` (pestaña "Tablero"/Tareas) — **se elimina
  el `FloatingActionButton` de chat** (`_openMessages`, `ChatService`,
  `_unreadMessages`, `_unreadTimer`, `UnreadCountBadge`, import de
  `chatHistory.dart`).
- `lib/shared/home/tasks.dart` (`TaskContainer`)
- `lib/shared/teams/**` salvo lo que dependa exclusivamente de features
  eliminadas: se conservan `task_board_screen.dart`, `task_board_card.dart`,
  `task_detail_sheet.dart`, `task_form_screen.dart`, `team_detail_screen.dart`,
  `team_detail_widgets.dart`, `teamDetail.dart`, `create_join_team/**`,
  `join_team.dart`, `user_picker_sheet.dart`, `widgets/**`,
  `evidence_confirm_sheet.dart`, `LResign.dart`, `MResign.dart`.
- `lib/shared/home/teams.dart` (`TeamPage`)
- `lib/services/team_service.dart`
- Modelos: `lib/models/dept_task.dart`, `team_document.dart`, `join_model.dart`
  y `models.dart` (recortado, ver abajo).

### Núcleo / diseño
- `lib/core/**` salvo `audio/`, `location/`, `notifications_controller.dart`
  (`api_config.dart`, `Routes.dart` recortado, `session*.dart`, `storeToken.dart`,
  `connectivity_gate.dart`, `route_refresh.dart`).
- `lib/design/**` salvo componentes huérfanos (ver "Se elimina").
- `lib/shared/widgets/**` (`appbar.dart`, `app_menu_drawer.dart`,
  `app_menu_sections.dart` recortado, `evidence_viewer.dart`).

## Navegación

### `lib/features/shell/bottomnavbar.dart`
Tres destinos en `_destinations` y `_pages` / `_mobilePages`:

1. **Tareas** — `dashb_mem` (de `lib/shared/board/dashboard.dart`).
2. **Directorio** — `ColleagueDirectoryScreen(me: profile)`. Como la pantalla
   necesita el `UserProfile`, la pestaña se envuelve en un cargador que
   obtiene el perfil (patrón `Session.fetchCurrentUser`) y muestra
   `LoadingState` mientras tanto.
3. **Perfil** — `Profile()`.

Se eliminan las pestañas *Progreso* (`ProgressChart`) y *Inicio*
(`RoleDashboardRouter`). Ajustar `currentPageIndex` inicial, `_profileIndex`,
`_pageController` initialPage y el `NavigationRail` de escritorio al nuevo
conteo.

### `lib/shared/widgets/app_menu_sections.dart`
Reescribir `appMenuSectionsForRole` para devolver, sin importar el rol:

- **Directorio:** "Buscar compañeros" → `ColleagueDirectoryScreen`.
- **Tareas:** "Todas mis tareas" → `TaskContainer`; "Mis equipos" →
  `TeamPage`; "Crear equipo" / "Unirse a un equipo" (rutas existentes).
- **Próximamente** (`enabled: false`, `trailingLabel: 'Próximamente'`):
  "Registro de entrada y salida", "Edición de la página web",
  "Sintonización En vivo".

Se eliminan todos los imports de pantallas borradas en ese archivo.

### `lib/main.dart`
- Quitar el arranque de audio: `JustAudioMediaKit`, `JustAudioBackground`,
  `RadioPlayer.instance`, `radioBackgroundReady`, `supportsBackgroundAudio` y
  los imports `just_audio_background`, `just_audio_media_kit`,
  `core/audio/radio_player.dart`.
- Conservar: init de `intl`/`initializeDateFormatting`, la lógica de sesión
  (`secureStorage`, `rememberMe`), `ConnectivityGate`, `routeObserver`.
- Tabla `routes`: conservar `/`, `SignUpRoutes`, `LoginRoutes`,
  `dashbMemRoutes`, `jointeamRoutes`, `CreateTeamScreen`, `BottomNavBar`,
  `DirectoryRoutes`, `Reset`, y `ComponentGallery` (solo debug). Eliminar
  `RoleDashboardRoutes`, `DirectorDashboardRoutes`, `ManagerDashboardRoutes`,
  `EmployeeDashboardRoutes`, `SiteContentHubRoutes` y sus imports.
- `initialRoute '/'`: `hasSession ? const BottomNavBar() : const SignUp()`
  (sin cambios).

### `lib/core/Routes.dart`
Eliminar las constantes de rutas de dashboards por rol y de site-content.

## Funciones "Próximamente"

Una sola pantalla stub reutilizable, p. ej.
`lib/shared/coming_soon/coming_soon_screen.dart`, que renderiza
`AppScaffold` + `ComingSoonCard` con título/descripcion parametrizados. Las
tres entradas del menú abren esta pantalla (o se dejan `enabled: false` con
`trailingLabel`, que es el patrón que la app ya usa — **se usa el patrón
`enabled: false` + `trailingLabel`**, sin pantalla navegable, para máxima
simplicidad). Si más adelante se quiere que sean navegables, la pantalla
stub queda disponible.

## Eliminación completa

Directorios/archivos a borrar (con sus rutas e imports):

- `lib/shared/attendance/**`
- `lib/shared/leave/**`
- `lib/shared/calendar/**`
- `lib/shared/chat/**`
- `lib/shared/radio/**`
- `lib/shared/resources/**`
- `lib/shared/notifications/**`
- `lib/shared/home/announcements_board.dart`, `progress.dart`,
  `progress_widgets.dart`, `progress/**`, `director_performance_view.dart`,
  `personal_progress_view.dart`
- `lib/features/dashboard/director/**` **completo** (site_content, admin_*,
  attendance_*, leave_*, internal_announcement_*, team_admin_screen,
  dashboard_director.dart)
- `lib/features/dashboard/manager/dashboard_manager.dart`
- `lib/features/dashboard/employee/dashboard_employee.dart`
- `lib/features/dashboard/role_dashboard_router.dart`
- `lib/core/audio/**`, `lib/core/location/**`,
  `lib/core/notifications_controller.dart`
- Services: `attendance_service.dart`, `absence_service.dart`,
  `leave_service.dart`, `calendar_service.dart`, `chat_service.dart`,
  `document_service.dart`, `internal_announcement_service.dart`,
  `radio_service.dart`
- Models: `attendance.dart`, `leave_request.dart`, `calendar_event.dart`,
  `radio_program.dart`
- Componentes de diseño huérfanos: `radio_player_button.dart`,
  `chat_bubble.dart`, `message_composer.dart`, `emoji_picker_panel.dart`,
  `emoji_catalog.dart`, `unread_count_badge.dart`, `day_divider.dart`,
  `notification_tile.dart`

**`lib/models/models.dart`:** quitar `export`/`part`/referencias a los
modelos borrados (`attendance`, `leave_request`, `calendar_event`,
`radio_program`) y cualquier enum/campo que solo ellos usen. Conservar
`UserProfile`, `AppRole`, `DepartmentInfo` y lo que consuman perfil,
directorio y tareas.

**`lib/design/design.dart`:** quitar los `export` de los componentes
borrados.

## `pubspec.yaml`

Eliminar (sin uso tras el recorte):

`just_audio`, `just_audio_background`, `just_audio_media_kit`,
`audio_service`, `media_kit_libs_windows_audio`, `media_kit_libs_linux`,
`table_calendar`, `flutter_map`, `latlong2`, `geolocator`, `local_auth`,
`share_plus`, `fl_chart`, `file_picker`.

Conservar:

`flutter`, `flutter_localizations`, `cupertino_icons`, `http`,
`multi_select_flutter`, `path_provider`, `flutter_secure_storage`,
`shared_preferences`, `intl`, `image_picker`.

Revisar la sección `flutter_launcher_icons` / `flutter_native_splash` y
`assets:` — se conservan (`lib/assets/`, `assets/logo/`).

## Verificación

1. `flutter pub get` en `test_1/` sin errores.
2. `flutter analyze` sin errores (iterar sobre imports colgantes y símbolos
   sin definir hasta limpiar).
3. Compilación de humo: `flutter build apk --debug` (o `flutter run -d windows`)
   arranca y muestra Login/Signup.
4. Recorrido manual: registro/login/recuperación abren; las 3 pestañas
   cargan; el menú muestra las 3 entradas "Próximamente" deshabilitadas.

## Riesgos

- **Acoplamiento oculto:** `models.dart`, `session.dart` o `team_service.dart`
  podrían referenciar tipos de modelos borrados. Mitigación: recortar
  `models.dart` con cuidado y apoyarse en `flutter analyze` iterativo.
- **`app_menu_drawer.dart`** puede leer el perfil/rol para construir
  secciones; al simplificar `app_menu_sections.dart` hay que mantener la
  firma que el drawer espera (`onPushScreen`, `onPushNamed`).
- **Pestaña Directorio** necesita `UserProfile`; el cargador nuevo es el
  único código realmente nuevo de este trabajo.

---

## Addendum 2026-09-05 — Se re-agregan chat, mensajes y gráficas

A petición del usuario se restauran desde `App-radio` tres áreas que el
recorte inicial había eliminado. Disposición "como en App-radio".

**Archivos restaurados verbatim de App-radio:**

- Chat: `lib/shared/chat/chat.dart`, `chatHistory.dart`;
  `lib/services/chat_service.dart`
- Componentes de diseño: `chat_bubble.dart`, `message_composer.dart`,
  `emoji_picker_panel.dart`, `emoji_catalog.dart`, `day_divider.dart`,
  `unread_count_badge.dart` (y sus `export` en `design/design.dart`)
- Gráficas: `lib/shared/home/progress.dart`, `progress_widgets.dart`,
  `personal_progress_view.dart`, `director_performance_view.dart`,
  `lib/shared/home/progress/{completion_gauge,department_stack_bars,
  progress_sections,weekly_rhythm_chart}.dart`

**`pubspec.yaml`:** vuelve `fl_chart: ^1.2.0`.

**Navegación:** `BottomNavBar` vuelve a 4 pestañas —
**Progreso** (`ProgressChart`) · **Tablero** (`dashb_mem`) ·
**Directorio** · **Perfil**. `_profileIndex = 3`, pestaña inicial = Tablero.

**Chat (igual que App-radio):**

- FAB de mensajes en `dashb_mem` con contador de no leídas
  (`ChatService.unreadTotal`, timer de 15 s) → abre `ChatScreenfetch`.
- Entrada "Chat del departamento" (sección "Comunicación") en
  `app_menu_drawer.dart`.
- Botón "Enviar mensaje" en `colleague_profile_screen.dart` → `ChatScreen`.
- Botones "Chat" (líder y no líder) en `team_detail_widgets.dart`.
- **No** se restauran "Salir" (permiso/leave) ni "Recursos" — siguen fuera
  de alcance.

**Menú:** nueva entrada "Mi progreso" → `ProgressChart` en la sección
"Mis tareas".

**Verificación:** `flutter analyze` 0 errores; `flutter test` y
`flutter build web` OK.
