# Integración de funciones desde App-radio-robert — Diseño

Fecha: 2026-09-09
Estado: aprobado para plan de implementación

## Contexto

El proyecto de referencia `C:\Users\jerem\Desktop\App-radio-robert\App-radio-robert`
es un fork anterior de la app (estructura `lib/screens/`, paquete `brl_task4`,
backend monolítico `hive-backend/index.php`). Se pidió extraer y adaptar tres
funciones al proyecto actual (`C:\xampp\htdocs\radio-doliv\App-radio`, paquete
`doliv_social`, backend modular en `hive-backend/*.php`).

Tras revisar ambos proyectos, el alcance real quedó así:

| Función | Hallazgo | Alcance acordado |
|---|---|---|
| Return Task (devolver tarea) | **Ya está implementada** de punta a punta en el flujo `dept_tasks` del proyecto actual. El fork **no** tiene esta función. | Solo auditar y pulir. |
| Modo claro/oscuro | Falta en el proyecto actual (es dark-only). El fork tiene una implementación limpia y portable. | Portar del fork (Approach A). |
| Ver/descargar documentos e imágenes subidas | El proyecto actual descarga documentos pero no los abre; el visor de imágenes es básico. El fork tiene ambas cosas. | Rellenar los huecos + endurecer errores + auditar permisos. |

Requisito transversal: toda la interfaz permanece 100% en español.

---

## Función 1 — Return Task: auditoría y pulido

### Estado actual (ya existe)

**Backend** `hive-backend/dept_tasks.php`:
- `deptTaskReview(PDO, id)` — `POST /dept-tasks/{id}/review`. Solo `director` o el
  `manager` del departamento (`dept_task_can_admin`). Exige que la tarea esté en
  `review_status = 'pendiente_revision'`. Body `decision` ∈ `approve|reject`.
  - `approve` → `review_status='aprobada'`, `reviewed_by/at`, `dept_task_spawn_next`,
    notifica al asignado "fue aprobada".
  - `reject` → **`note` obligatorio** (400 si vacío); `status='en_progreso'`,
    `review_status='rechazada'`, limpia `completed_by/at`, notifica al asignado
    "Tu tarea … fue devuelta: {note}".
- `deptTaskSetStatus` — al reenviar como `completada` un empleado vuelve a dejar la
  tarea en `pendiente_revision` (limpia `review_note/reviewed_by/at`), así el ciclo
  devolver → corregir → reenviar → revisar funciona indefinidamente.

**Flutter**:
- `lib/services/team_service.dart` → `DeptTaskApi.review(id, {approve, note})`.
- `lib/shared/teams/task_board_screen.dart` → `_review(t, {approve})`: si `!approve`,
  diálogo "Devolver tarea" con campo de motivo; valida no-vacío ("Indica el motivo
  del rechazo."); llama `DeptTaskApi.review(...)`.
- `lib/shared/teams/task_board_card.dart` → `_ReviewActions` (botones "Devolver" /
  "Aprobar") visibles solo si `canManage && task.awaitingReview`; `_RejectNote`
  muestra el motivo en la tarjeta del empleado.
- `lib/shared/teams/task_detail_sheet.dart` → banner `_ReturnedNote` ("Devuelta por
  X" + nota) cuando `task.wasRejected`, más un hilo de comentarios bidireccional
  (`DeptTaskApi.comments` / `addComment`) para las aclaraciones sobre qué corregir.
- `lib/models/dept_task.dart` → `reviewStatus`, `reviewNote`, `reviewedBy`,
  `wasRejected`, `awaitingReview`, `reviewStatusLabel`.

### Trabajo a realizar

Auditoría, sin reescritura. Producir un informe corto de verificación cubriendo:

1. Backend: los estados y permisos de `deptTaskReview` y de la re-transición en
   `deptTaskSetStatus` se comportan como arriba (leer el código; si hay una suite
   PHP para dept-tasks, correrla).
2. Flutter: el revisor ve "Devolver/Aprobar" solo con `canManage && awaitingReview`;
   el diálogo exige motivo; tras devolver, el board y la ficha se refrescan y el
   empleado ve el motivo (`_RejectNote` / `_ReturnedNote`); el hilo de comentarios
   funciona en ambos sentidos.
3. Rutas de fallo: sin conexión, 403 (no eres revisor), 409 (ya no está pendiente).

### Correcciones admitidas (solo si la auditoría encuentra un fallo)

Cambios pequeños y localizados, cada uno documentado en el resumen final. Ejemplos
plausibles: falta de estado de carga en los botones de revisión; el board no
recarga tras `review`; el motivo no aparece en la tarjeta del empleado; `note` se
envía sin `trim`. **No** se añade "devolver" al sistema legacy de tareas de equipo
(`/team/*`, `tasks.dart`) — fuera de alcance por decisión del usuario.

### Criterios de aceptación

- Informe de verificación entregado.
- Devolver una tarea la deja en `en_progreso` / `rechazada` con el motivo visible
  para el asignado; reenviarla la vuelve a poner `pendiente_revision`; aprobarla la
  cierra (y genera la recurrencia si aplica).
- `flutter analyze` y `flutter test` sin regresiones.

---

## Función 2 — Modo claro/oscuro

### Objetivo

- Interruptor "Tema oscuro" (switch simple, no triple Claro/Oscuro/Automático) en
  el pie del menú lateral (`AppMenuDrawer`), encima de la línea "Radio Doliv".
- Modo por defecto: **oscuro** (comportamiento actual).
- Persistencia con `shared_preferences` (ya es dependencia, `^2.2.2`).
- Todas las pantallas responden al cambio.

### Enfoque elegido: A — getters mode-aware + `KeyedSubtree`

`AppColors` pasa de tokens `static const Color` a `static Color get` resueltos por
un flag `_isDark`. Es el mismo enfoque que ya aplicó el fork, así que el estado
final está probado. Coste: Dart prohíbe `const` con getter no-const, por lo que
hay que quitar `const` de **~306 expresiones en ~82 archivos** (en su mayoría
`const TextStyle(color: AppColors.textMuted)` dentro de árboles `const`, lo que
propaga hacia arriba). Se descartó el enfoque "solo tema" porque dejaría el modo
claro roto en toda pantalla que lee `AppColors.*` directamente.

### Componentes

**`lib/design/tokens/colors.dart`** — reescritura portando del fork:
- Flag `static bool _isDark = true;` + `static bool get isDark` + `static void setDark(bool)`.
- Valores oscuros (los actuales, sin cambio de hex): `_darkBgBase = 0xFF0A1730`,
  `_darkSurface = 0xFF122240`, `_darkSurfaceBorder = 0xFF1E3355`,
  `_darkAccent = 0xFF4D93E8`, `_darkAccentStrong = 0xFF6FA9EE`,
  `_darkTextPrimary = 0xFFF2F2F2`, `_darkTextMuted = 0xFF9FB0CC`,
  `_darkSuccess = 0xFF52C77E`, `_darkWarning = 0xFFE8B84D`, `_darkError = 0xFFEF6B6B`.
- Valores claros (del fork): `_lightBgBase = 0xFFF3F5F9`, `_lightSurface = 0xFFFFFFFF`,
  `_lightSurfaceBorder = 0xFFDCE2ED`, `_lightAccent = 0xFF004691`,
  `_lightAccentStrong = 0xFF00356F`, `_lightTextPrimary = 0xFF0A1730`,
  `_lightTextMuted = 0xFF4C596E`, `_lightSuccess = 0xFF1E7A45`,
  `_lightWarning = 0xFF8A6300`, `_lightError = 0xFFC22A2A`.
- Tokens públicos dinámicos (getters): `bgBase`, `surface`, `surfaceBorder`,
  `accent`, `accentStrong`, `textPrimary`, `textMuted`, `success`, `warning`,
  `error`, `info` (→ `accent`), `buttonGradient` (getter que devuelve el
  `LinearGradient` const).
- Tokens que **siguen `const`** (no dependen del modo): `brandNavy = 0xFF00356F`,
  `brandBlue = 0xFF004691`, `onBrand = Colors.white`, `onBrandMuted = Colors.white70`,
  `onBrandAccent = 0xFF6FA9EE`. (`onBrand*` no existen aún en el proyecto actual;
  se añaden porque `AppTheme` los usará para fondos de marca fijos.)
- `AppPalette` (clase inmutable con los 10 tokens) + `darkPalette` / `lightPalette`
  const, para que `AppTheme` construya cada `ThemeData` sin depender de `_isDark`.
- Conservar cualquier token que exista hoy en `colors.dart` y no en el fork (revisar
  al portar; el doc de comentario también se actualiza).

**`lib/design/theme/app_theme.dart`** — refactor a construcción por paleta:
- `_buildTheme(AppPalette p, Brightness b)` portado del fork (mismo cuerpo:
  `colorScheme` con `onPrimary/onError = AppColors.onBrand`, `appBarTheme`,
  `inputDecorationTheme`, botones, `navigationBarTheme` con etiqueta/ícono fijos en
  `onBrand` sobre el indicador azul, `switchTheme`, `checkboxTheme`, etc.).
- `static ThemeData get dark => _buildTheme(AppColors.darkPalette, Brightness.dark);`
- `static ThemeData get light => _buildTheme(AppColors.lightPalette, Brightness.light);`
- Verificar la firma de `AppTypography.textTheme(...)`: el fork la llama como
  `AppTypography.textTheme(p.textPrimary, p.textMuted)`. Si la actual difiere, se
  adapta la llamada (no se toca `typography.dart` salvo que sea imprescindible).

**`lib/design/theme/theme_controller.dart`** — nuevo, portado del fork
(`lib/design/theme/theme_controller.dart`, **no** el `lib/utils/theme_controller.dart`
que es una versión vieja sin usar):
- `class ThemeController extends ChangeNotifier` singleton (`ThemeController.instance`).
- `_prefsKey = 'app_theme_is_dark'`.
- `bool get isDark`, `ThemeMode get themeMode => _isDark ? dark : light`.
- `Future<void> init()` — idempotente; lee el pref (default `true`) y llama
  `AppColors.setDark(_isDark)`. Se invoca una vez en `main()` antes de `runApp`.
- `Future<void> toggle()` / `Future<void> setDark(bool)` — actualiza `_isDark`,
  `AppColors.setDark`, `notifyListeners()`, persiste best-effort (try/catch).

**`lib/design/design.dart`** — añadir
`export 'package:doliv_social/design/theme/theme_controller.dart';`.

**`lib/main.dart`**:
- En `main()`, tras `WidgetsFlutterBinding.ensureInitialized()` y antes de `runApp`:
  `await ThemeController.instance.init();` (sitúa junto a la carga de locale/`intl`).
- `MyApp.build`: envolver el `MaterialApp` en
  `AnimatedBuilder(animation: ThemeController.instance, builder: (_, __) => MaterialApp(...))`.
- En el `MaterialApp`: añadir `darkTheme: AppTheme.dark`, cambiar
  `theme: AppTheme.dark` por `theme: AppTheme.light`, añadir
  `themeMode: ThemeController.instance.themeMode`.
- En el `builder:` existente (que ya devuelve
  `ColoredBox(color: AppColors.bgBase, child: ConnectivityGate(child: child))`),
  envolver ese resultado en
  `KeyedSubtree(key: ValueKey(ThemeController.instance.isDark), child: ...)`.
  Consecuencia aceptada: alternar el tema reconstruye el árbol navegable desde cero
  (reinicia la pila de navegación). Es una acción de ajustes, es aceptable.
- El `ColoredBox` sigue leyendo `AppColors.bgBase` (ahora getter) — correcto.

**`lib/shared/widgets/app_menu_drawer.dart`**:
- Entre el `Expanded(ListView…)` y el `Divider`+"Radio Doliv" del pie, añadir un
  `Divider(color: AppColors.surfaceBorder, height: 1)` y un `SwitchListTile`:
  - `title: Text('Tema oscuro')` (estilo igual a los `ListTile` del menú).
  - `secondary: Icon(Icons.dark_mode_outlined, color: AppColors.accent)`.
  - `value: ThemeController.instance.isDark`.
  - `onChanged: (v) => ThemeController.instance.setDark(v)` (sin `pop()` del drawer;
    el `KeyedSubtree` reconstruye y el drawer se cierra solo al reconstruirse el
    árbol — verificar en dispositivo; si queda medio abierto, hacer `pop()` antes).
- Como el `AnimatedBuilder` de `main.dart` reconstruye toda la app al notificar, el
  switch refleja el estado sin `setState` local.

### Barrido de `const` (el grueso del trabajo)

1. Tras portar `colors.dart` como getters, `flutter analyze` listará cada
   `const_with_non_constant_argument` / `const_with_non_constant_type`.
2. Primero `dart fix --apply` (resuelve `unnecessary_const` y muchos `const`
   inválidos automáticamente).
3. Luego iterar sobre lo que quede: quitar `const` del nodo que menciona el token y
   de los ancestros `const` que dejen de serlo. Cambios puramente mecánicos, sin
   tocar lógica.
4. Repetir hasta `flutter analyze` limpio. Fallback por archivo si `dart fix`
   ensucia algo: edición manual sitio por sitio (Approach C).
5. `test/`: ajustar los pocos sitios con `AppColors` en contexto `const` y añadir
   `ThemeController`/`AppColors.setDark(true)` en el `setUp` de los tests de widget
   que dependan del modo (p. ej. `test/login_remember_me_test.dart` usa
   `AppTheme.dark`; debe seguir compilando).

### Riesgos y control

- **Ámbito del barrido**: se hace en un cambio enfocado, sin mezclar con otras
  funciones. `flutter analyze` limpio + `flutter test` verde antes de continuar.
- **Regresión visual**: revisar en ambos modos una muestra representativa —
  dashboards por rol, task board + ficha de tarea, chat, Recursos + documentos +
  visor de imagen, formularios (login, alta de tarea), calendario, menú lateral.
- `brandNavy`/`brandBlue`/`onBrand*` quedan `const`: gradientes de marca y texto
  sobre azul no se ven afectados por el modo.
- **Arranque sin parpadeo**: `init()` corre antes del primer frame, así que la
  primera pantalla ya sale en el modo correcto.
- **Almacenamiento no disponible** (algunos entornos de test): `init()` cae al
  default oscuro sin lanzar.

### Criterios de aceptación

- El switch del menú alterna claro/oscuro en toda la app.
- La preferencia sobrevive a cerrar y reabrir la app.
- Sin texto en inglés introducido.
- `flutter analyze` limpio; `flutter test` verde.
- Muestra de pantallas verificada en ambos modos sin colores ilegibles.

---

## Función 3 — Ver/descargar documentos e imágenes

Ambas pantallas se abren desde el hub `Recursos` de un equipo
(`lib/shared/resources/resources.dart` → `TeamDocumentsScreen`, `ImageListScreen`).

### 3a — Abrir documentos en la app nativa

- **Dependencia**: añadir `open_filex` a `pubspec.yaml` (misma que el fork;
  `path_provider` ya está). Verificar que no colisione con los `dependency_overrides`
  actuales de Android.
- **`lib/services/document_service.dart`**: nuevo
  `static Future<OpenResult> openInApp(TeamDocument doc)`:
  - `GET $kBaseUrl/document/download/{doc.id}` con `Authorization`.
  - Si `statusCode != 200` → lanzar `DocumentException` con mensaje claro
    (404 → "El archivo ya no está disponible.").
  - Escribir `response.bodyBytes` en
    `${getTemporaryDirectory().path}/{doc.id}_{safeName}` donde `safeName` limpia
    `[\\/:*?"<>|]`.
  - `return OpenFilex.open(path)`.
- **`lib/shared/resources/team_documents_screen.dart`**:
  - Tocar la fila (y un ícono nuevo "Ver", `Icons.visibility_rounded`) llama
    `openInApp`; spinner por fila mientras baja (`_openingId`).
  - Si `result.type != ResultType.done` → snackbar "No se pudo abrir el documento.
    Instala una app compatible con .{ext} o descárgalo."
  - El botón de descarga actual (`FilePicker.saveFile`) se mantiene igual.

### 3b — Descargar imagen desde el visor

- **`lib/shared/resources/imagecc.dart`**:
  - El grid ya tiene `imgName`; pasar `imageName` a `ImageDetailScreen`
    (además de `imageUrl`).
  - `ImageDetailScreen` (se mantiene `StatelessWidget` → pasa a `StatefulWidget`
    por el estado `_downloading`): botón de descarga en el `AppBar`:
    - `GET imageUrl` (sin auth si la URL es un asset público; con `Authorization`
      si 3d determina que hace falta).
    - `statusCode != 200` → snackbar "No se pudo descargar la imagen ({código})."
    - Derivar extensión de la URL (`jpg|jpeg|png|gif|webp`, fallback `jpg`);
      `fileName = '{imageName|imagen}.{ext}'`.
    - `FilePicker.saveFile(dialogTitle: 'Guardar imagen', fileName:, bytes:)`;
      snackbar "Imagen guardada." / "Descarga cancelada." / error de red.
  - **No** se porta el overlay con nombre/descripción ni el pinch-zoom del fork
    (decisión del usuario: botón de descarga mínimo basta).

### 3c — Archivos faltantes / referencias inválidas

- `Image.network` en el grid de `imagecc.dart` **y** en `ImageDetailScreen`: añadir
  `errorBuilder` → placeholder (`Icons.broken_image_outlined`, `AppColors.textMuted`,
  fondo `AppColors.bgBase`) en vez del recuadro rojo de excepción.
- Documentos: comprobar `statusCode` antes de escribir el archivo temporal; nunca
  crear un archivo vacío ante un 404.
- **Backend `hive-backend/documents.php`** (`teamDocumentDownload`): si la fila
  existe pero el archivo en disco no (`!is_file($path)`), responder un error
  JSON/texto limpio con 404 y **sin** incluir la ruta absoluta del servidor en el
  cuerpo ni en un warning de PHP (silenciar/capturar). Igual para el handler de
  imágenes si sirve archivos desde disco.

### 3d — Auditoría de control de acceso (informe; corregir si aplica)

Revisar en el backend actual y documentar en el resumen final:

- `hive-backend/documents.php`:
  - `teamDocumentList($teamId)` / `teamDocumentDownload($id)` — exigen `require_auth`
    **y** pertenencia del usuario al equipo (no solo token válido).
  - `teamDocumentDelete($id)` — restringido al que subió el documento o a
    manager/director del equipo/departamento.
- Handler de imágenes (`/image/showImage/{teamId}`, `DELETE /image/{id}`) — mismas
  reglas: listar solo si eres del equipo; borrar solo subida propia o rol admin.
- `imgURL`: determinar si apunta a un archivo estático servido directamente (asset
  compartible, aceptable por diseño) o a un endpoint que debe validar acceso. Se
  deja constancia de cuál es; si es un endpoint sin validar, se endurece.
- Cualquier corrección va como commit aparte y se lista en el resumen.

### Archivos tocados

`pubspec.yaml`, `pubspec.lock`, `lib/services/document_service.dart`,
`lib/shared/resources/team_documents_screen.dart`,
`lib/shared/resources/imagecc.dart`, `hive-backend/documents.php`
(+ archivo del handler de imágenes si lo hay), tests nuevos para
`DocumentService.openInApp` y las rutas de error.

### Criterios de aceptación

- Un documento subido se abre en el visor nativo del sistema; si no hay app para esa
  extensión, mensaje claro (no crash).
- Una imagen del equipo se puede guardar en el dispositivo desde el visor.
- Imagen rota o documento borrado → placeholder / mensaje claro, sin excepción
  visible ni ruta de servidor expuesta.
- Informe de permisos entregado; descargas/listados respetan rol y pertenencia.
- `flutter analyze` limpio; `flutter test` verde.

---

## Validación global

Antes de dar por cerrado, probar:

- **Return Task**: devolver con motivo → estado y notificación correctos; corregir y
  reenviar → vuelve a revisión; aprobar → cierra (+ recurrencia). Permisos: un
  empleado no ve los botones de revisión; un manager de otro departamento recibe 403.
- **Tema**: modo claro, modo oscuro, alternar en caliente, persistencia tras
  reiniciar. Muestra de pantallas en ambos modos.
- **Archivos**: ver imagen; abrir documento (PDF/Word/Excel); descargar imagen;
  descargar documento; archivo faltante; referencia inválida; control de acceso.
- **Regresión**: `flutter analyze` + `flutter test` completos; arranque de la app;
  flujo de login/sesión; hub de Recursos; task board.

## Orden de implementación sugerido

1. Función 1 (auditoría) — barata, informa si hay que tocar algo del board.
2. Función 3 (archivos) — acotada, sin dependencia del tema.
3. Función 2 (tema) — la más invasiva; se hace de último para no rebasar los
   diffs de las otras dos con el barrido de `const`.

## Fuera de alcance

- "Devolver tarea" en el sistema legacy de tareas de equipo (`/team/*`).
- Overlay nombre/descripción y pinch-zoom del visor de imágenes del fork.
- Triple selector de tema Claro/Oscuro/Automático (seguir al SO).
- Migrar otras diferencias entre el fork y el proyecto actual.
