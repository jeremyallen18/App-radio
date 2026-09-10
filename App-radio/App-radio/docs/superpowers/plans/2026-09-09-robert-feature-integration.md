# Integración de funciones desde App-radio-robert — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Auditar el flujo "devolver tarea" ya existente, portar modo claro/oscuro desde el fork, y completar ver/descargar de documentos e imágenes con manejo de errores.

**Architecture:** Flutter (`doliv_social`) + backend PHP modular (`hive-backend/*.php`). El tema usa `AppColors` con getters resueltos por un flag `_isDark`, `AppTheme.light/dark` construidos por paleta, un `ThemeController` singleton persistido en `shared_preferences`, y `main.dart` reconstruye la app con `AnimatedBuilder` + `KeyedSubtree`. Archivos: `open_filex` para abrir documentos; descarga de imagen con `FilePicker.saveFile`.

**Tech Stack:** Flutter 3.41.x, Dart, `shared_preferences ^2.2.2`, `file_picker ^12.2.0`, `path_provider ^2.1.5`, `open_filex` (nuevo), PHP 8 / PDO.

**Spec:** `docs/superpowers/specs/2026-09-09-robert-feature-integration-design.md`

## Global Constraints

- Toda la interfaz permanece 100% en español; ningún texto nuevo en inglés.
- No exponer rutas del servidor al cliente.
- `flutter analyze` limpio y `flutter test` verde al cerrar cada fase.
- Rama de trabajo: `feat/robert-feature-integration` (ya creada). Commits en español.
- No añadir "devolver tarea" al sistema legacy `/team/*`.
- Trailers de commit: `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` y `Claude-Session: https://claude.ai/code/session_01Spc2LcGNsPTHcFSVawV4R7`.
- Colores de marca (`brandNavy`, `brandBlue`, `onBrand*`) NO dependen del modo: quedan `const`.

---

## FASE 1 — Return Task: auditoría

### Task 1: Auditar el flujo devolver-tarea y escribir el informe

**Files:**
- Create: `docs/superpowers/notes/2026-09-09-return-task-audit.md`
- Read only: `hive-backend/dept_tasks.php` (`deptTaskReview`, `deptTaskSetStatus`), `lib/services/team_service.dart` (`DeptTaskApi.review`), `lib/shared/teams/task_board_screen.dart` (`_review`), `lib/shared/teams/task_board_card.dart` (`_ReviewActions`, `_RejectNote`), `lib/shared/teams/task_detail_sheet.dart` (`_ReturnedNote`), `lib/models/dept_task.dart`

**Interfaces:**
- Produces: informe con veredicto (OK / lista de fallos menores) por cada punto de la sección "Función 1 → Trabajo a realizar" del spec.

- [ ] **Step 1: Releer los 6 archivos** y verificar, punto por punto, los 3 bloques de la sección "Función 1" del spec (estados/permisos backend; visibilidad y validación de UI; rutas de fallo).
- [ ] **Step 2: Correr los tests PHP de dept-tasks si existen**
  Run: `ls hive-backend/tests 2>/dev/null; find . -name "*dept*task*test*"`
  Si hay suite, ejecutarla y anotar resultado. Si no, dejar constancia en el informe.
- [ ] **Step 3: Correr la suite Flutter existente**
  Run: `flutter test`
  Expected: PASS (línea base antes de cualquier cambio).
- [ ] **Step 4: Escribir `docs/superpowers/notes/2026-09-09-return-task-audit.md`** con: qué se revisó, veredicto por punto, y lista de fallos menores encontrados (si los hay) con archivo:línea.
- [ ] **Step 5: Commit**
  ```bash
  git add docs/superpowers/notes/2026-09-09-return-task-audit.md
  git commit -m "docs: auditoría del flujo devolver-tarea (dept_tasks)"
  ```

### Task 2 (condicional): Corregir los fallos menores de la auditoría

Solo si el Task 1 encontró fallos. Por cada fallo: test que lo reproduce (si aplica) → fix mínimo → `flutter test` → commit `fix(tareas): <descripción>`. Si no hubo fallos, marcar esta tarea como N/A en el informe.

---

## FASE 2 — Ver/descargar documentos e imágenes

### Task 3: Añadir `open_filex` y `DocumentService.openInApp`

**Files:**
- Modify: `pubspec.yaml` (sección `dependencies`, junto a `file_picker`)
- Modify: `lib/services/document_service.dart`
- Test: `test/document_service_open_test.dart` (nuevo)

**Interfaces:**
- Consumes: `TeamDocument` (`id`, `originalName`, `mime`, `extension`), `kBaseUrl`, `secureStorage`/`key`.
- Produces:
  - `class OpenedDocument { final String path; OpenedDocument(this.path); }`
  - `static Future<OpenedDocument> DocumentService.fetchToTemp(TeamDocument doc)` — descarga a un archivo temporal y devuelve su ruta; lanza `DocumentException` con mensaje en español si `statusCode != 200` (404 → "El archivo ya no está disponible.").

- [ ] **Step 1: Escribir el test**
  ```dart
  // test/document_service_open_test.dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:doliv_social/services/document_service.dart';

  void main() {
    test('DocumentException expone el mensaje tal cual', () {
      expect(DocumentException('El archivo ya no está disponible.').toString(),
          'El archivo ya no está disponible.');
    });

    test('sanitizeFileName quita caracteres inválidos de sistema de archivos', () {
      expect(DocumentService.sanitizeFileName('a/b:c*?"<>|.pdf'), 'a_b_c______.pdf');
    });
  }
  ```
- [ ] **Step 2: Correr y ver fallar**
  Run: `flutter test test/document_service_open_test.dart`
  Expected: FAIL (`sanitizeFileName` no existe).
- [ ] **Step 3: Añadir dependencia**
  En `pubspec.yaml`, bajo `file_picker: ^12.2.0`, añadir:
  ```yaml
  # Abrir un documento descargado con el visor nativo del sistema
  # (lib/shared/resources/team_documents_screen.dart).
  open_filex: ^4.5.0
  ```
  Run: `flutter pub get`
  Expected: resuelve sin conflicto. Si el build de Android falla por gradle, fijar `open_filex: 4.4.0` y anotar en el informe final.
- [ ] **Step 4: Implementar en `document_service.dart`**
  Añadir imports `dart:io`, `package:path_provider/path_provider.dart`, `package:open_filex/open_filex.dart`.
  ```dart
  class OpenedDocument {
    OpenedDocument(this.path);
    final String path;
  }

  // ... dentro de class DocumentService:

  static String sanitizeFileName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

  /// Descarga el documento a la carpeta temporal y devuelve la ruta local.
  /// Úsalo para abrirlo con [OpenFilex]; para "guardar como" usa [download].
  static Future<OpenedDocument> fetchToTemp(TeamDocument doc) async {
    final DownloadedDocument dl = await download(doc); // reусa validación + errores
    final dir = await getTemporaryDirectory();
    final safe = sanitizeFileName(doc.originalName);
    final file = File('${dir.path}/${doc.id}_$safe');
    await file.writeAsBytes(dl.bytes, flush: true);
    return OpenedDocument(file.path);
  }
  ```
- [ ] **Step 5: Correr el test**
  Run: `flutter test test/document_service_open_test.dart`
  Expected: PASS.
- [ ] **Step 6: analyze**
  Run: `flutter analyze lib/services/document_service.dart test/document_service_open_test.dart`
  Expected: No issues.
- [ ] **Step 7: Commit**
  ```bash
  git add pubspec.yaml pubspec.lock lib/services/document_service.dart test/document_service_open_test.dart
  git commit -m "feat(recursos): DocumentService.fetchToTemp para abrir documentos con open_filex"
  ```

### Task 4: Abrir documento al tocarlo en `TeamDocumentsScreen`

**Files:**
- Modify: `lib/shared/resources/team_documents_screen.dart`

**Interfaces:**
- Consumes: `DocumentService.fetchToTemp`, `OpenFilex.open`, `ResultType`.

- [ ] **Step 1: Leer el archivo completo** para ubicar el `ListView`/tile de documento y el estado (`_downloadingId` o equivalente).
- [ ] **Step 2: Añadir estado y método**
  ```dart
  String? _openingId;

  Future<void> _open(TeamDocument doc) async {
    setState(() => _openingId = doc.id);
    try {
      final opened = await DocumentService.fetchToTemp(doc);
      final res = await OpenFilex.open(opened.path);
      if (res.type != ResultType.done && mounted) {
        _snack('No se pudo abrir el documento. Instala una app compatible '
            'con .${doc.extension} o descárgalo.');
      }
    } on DocumentException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Ocurrió un error al abrir el documento.');
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }
  ```
  (Si el `_snack` helper no existe, usar `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(...)))` con guarda `mounted`.)
  Imports: `package:open_filex/open_filex.dart`.
- [ ] **Step 3: Cablear en el tile**
  - `onTap` de la tarjeta del documento → `_openingId == null ? () => _open(doc) : null`.
  - Añadir un `IconButton(icon: Icon(Icons.visibility_rounded), tooltip: 'Ver', onPressed: ...)` junto al de descargar; mientras `_openingId == doc.id` mostrar un `SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2))` en su lugar.
  - El botón/acción de descarga actual queda igual.
- [ ] **Step 4: analyze**
  Run: `flutter analyze lib/shared/resources/team_documents_screen.dart`
  Expected: No issues.
- [ ] **Step 5: Commit**
  ```bash
  git add lib/shared/resources/team_documents_screen.dart
  git commit -m "feat(recursos): abrir un documento del equipo con el visor nativo"
  ```

### Task 5: Descargar imagen desde el visor + placeholders de error

**Files:**
- Modify: `lib/shared/resources/imagecc.dart`
- Test: `test/image_detail_download_test.dart` (nuevo)

**Interfaces:**
- Consumes: `FilePicker.saveFile`, `http.get`.
- Produces: `ImageDetailScreen({required String imageUrl, String imageName})`; helper `imageExtFromUrl(String url) -> String` (top-level o estático), valores permitidos `jpg jpeg png gif webp`, fallback `jpg`.

- [ ] **Step 1: Escribir el test**
  ```dart
  // test/image_detail_download_test.dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:doliv_social/shared/resources/imagecc.dart';

  void main() {
    test('imageExtFromUrl reconoce extensiones válidas y cae a jpg', () {
      expect(imageExtFromUrl('https://x/y/foto.PNG'), 'png');
      expect(imageExtFromUrl('https://x/y/foto.webp?v=2'), 'webp');
      expect(imageExtFromUrl('https://x/y/sin-extension'), 'jpg');
      expect(imageExtFromUrl('https://x/y/archivo.bmp'), 'jpg');
    });
  }
  ```
- [ ] **Step 2: Correr y ver fallar**
  Run: `flutter test test/image_detail_download_test.dart`
  Expected: FAIL (`imageExtFromUrl` no existe / no exportada).
- [ ] **Step 3: Implementar**
  En `imagecc.dart`:
  - Añadir top-level:
    ```dart
    String imageExtFromUrl(String url) {
      final clean = url.split('?').first;
      final dot = clean.lastIndexOf('.');
      const allowed = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
      if (dot == -1 || dot == clean.length - 1) return 'jpg';
      final ext = clean.substring(dot + 1).toLowerCase();
      return allowed.contains(ext) ? ext : 'jpg';
    }
    ```
  - `ImageListScreen`: pasar `imageName: images[index]['imgName'] ?? ''` al navegar a `ImageDetailScreen`.
  - Grid `Image.network(...)`: añadir
    ```dart
    errorBuilder: (_, __, ___) => Container(
      color: AppColors.bgBase,
      child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
    ),
    ```
  - `ImageDetailScreen` → convertir a `StatefulWidget`; campos `final String imageUrl; final String imageName;` (default `''`). Estado `bool _downloading = false;`.
  - `AppBar.actions`: botón de descarga (o spinner si `_downloading`):
    ```dart
    Future<void> _download() async {
      if (_downloading) return;
      setState(() => _downloading = true);
      try {
        final res = await http.get(Uri.parse(widget.imageUrl));
        if (res.statusCode != 200) {
          _snack('No se pudo descargar la imagen (${res.statusCode}).');
          return;
        }
        final ext = imageExtFromUrl(widget.imageUrl);
        final base = widget.imageName.trim().isNotEmpty ? widget.imageName.trim() : 'imagen';
        final name = base.toLowerCase().endsWith('.$ext') ? base : '$base.$ext';
        final out = await FilePicker.saveFile(
          dialogTitle: 'Guardar imagen', fileName: name, bytes: res.bodyBytes);
        _snack(out != null ? 'Imagen guardada.' : 'Descarga cancelada.');
      } catch (_) {
        _snack('Error de red al descargar la imagen.');
      } finally {
        if (mounted) setState(() => _downloading = false);
      }
    }
    ```
    (`_snack` = guard `mounted` + `ScaffoldMessenger`.)
  - El `Image.network` del detalle también recibe el mismo `errorBuilder` (icono grande, `Colors.white54`).
  - Imports: `package:file_picker/file_picker.dart`, `package:http/http.dart` as `http` (ya está).
- [ ] **Step 4: Correr el test**
  Run: `flutter test test/image_detail_download_test.dart`
  Expected: PASS.
- [ ] **Step 5: analyze**
  Run: `flutter analyze lib/shared/resources/imagecc.dart test/image_detail_download_test.dart`
  Expected: No issues.
- [ ] **Step 6: Commit**
  ```bash
  git add lib/shared/resources/imagecc.dart test/image_detail_download_test.dart
  git commit -m "feat(recursos): descargar imagen desde el visor y placeholder de imagen rota"
  ```

### Task 6: Informe de auditoría de control de acceso a archivos

**Files:**
- Create: `docs/superpowers/notes/2026-09-09-file-access-audit.md`
- Read only: `hive-backend/documents.php`, `hive-backend/legacy_teams.php` (`showImage`, `addImage`), `hive-backend/helpers.php` (`require_team_member`, `require_auth`), `hive-backend/config.php` (`UPLOAD_URL_BASE`, `DOCUMENT_DIR`, `UPLOAD_DIR`), `hive-backend/.htaccess`

- [ ] **Step 1: Verificar documentos** — confirmar que `teamDocumentsList` / `teamDocumentDownload` / `teamDocumentDelete` llaman `require_auth` + `require_team_member`, que download hace `is_file` → 404 limpio sin ruta, y que delete se limita a subidor o líder. (Estado esperado según spec: ya correcto.)
- [ ] **Step 2: Verificar imágenes** — `showImage`/`addImage` exigen `require_auth` + `require_team_member`. Determinar si `imgURL` (`UPLOAD_URL_BASE . img_path`) es un archivo estático público servido fuera de PHP: revisar `.htaccess` y la ubicación de `UPLOAD_DIR`. Anotar si el acceso a la imagen en sí queda sin validar (aceptable-por-diseño como asset compartible, o a endurecer).
- [ ] **Step 3: Escribir el informe** con hallazgos y, si algo requiere endurecerse, describir el cambio propuesto (no implementarlo aquí salvo que sea trivial y de bajo riesgo).
- [ ] **Step 4: Commit**
  ```bash
  git add docs/superpowers/notes/2026-09-09-file-access-audit.md
  git commit -m "docs: auditoría de control de acceso a documentos e imágenes"
  ```

---

## FASE 3 — Modo claro/oscuro (portado del fork)

### Task 7: Portar `colors.dart` a getters mode-aware + paletas

**Files:**
- Modify: `lib/design/tokens/colors.dart` (reescritura)
- Reference: `C:\Users\jerem\Desktop\App-radio-robert\App-radio-robert\lib\design\tokens\colors.dart`

**Interfaces:**
- Produces (API pública de `AppColors`, sin cambiar nombres):
  - `static bool get isDark`; `static void setDark(bool)`
  - getters `Color`: `bgBase, surface, surfaceBorder, accent, accentStrong, textPrimary, textMuted, success, warning, error, info`
  - getter `LinearGradient get buttonGradient`
  - `const Color`: `brandNavy, brandBlue, onBrand, onBrandMuted, onBrandAccent`
  - `const AppPalette darkPalette, lightPalette`
  - `class AppPalette` con `bgBase, surface, surfaceBorder, accent, accentStrong, textPrimary, textMuted, success, warning, error` (todos `final Color`)

- [ ] **Step 1: Reescribir `lib/design/tokens/colors.dart`** copiando la estructura del fork. Valores oscuros = los actuales exactos. Valores claros = los del fork (ver spec §"Función 2 → Componentes → colors.dart"). Mantener el `LinearGradient` de `buttonGradient` con los mismos colores (`[brandBlue, brandNavy]`). Añadir `onBrand/onBrandMuted/onBrandAccent` (no existen hoy). Conservar el docstring actualizado (español, explica el modo dual).
- [ ] **Step 2: analyze solo del archivo**
  Run: `flutter analyze lib/design/tokens/colors.dart`
  Expected: No issues en el archivo (los errores de `const` aparecen en los consumidores, se arreglan en Task 9).
- [ ] **Step 3: NO commitear todavía** (el árbol no compila hasta Task 9). Continuar.

### Task 8: `AppTheme` por paleta + `ThemeController` + barrel

**Files:**
- Modify: `lib/design/theme/app_theme.dart`
- Modify: `lib/design/tokens/typography.dart` (solo si `AppTypography.dark` estorba)
- Create: `lib/design/theme/theme_controller.dart`
- Modify: `lib/design/design.dart` (añadir export)
- Reference: fork `lib/design/theme/app_theme.dart` y `lib/design/theme/theme_controller.dart`

**Interfaces:**
- Produces:
  - `AppTheme._buildTheme(AppPalette p, Brightness b) -> ThemeData` (privado)
  - `static ThemeData get AppTheme.dark` / `static ThemeData get AppTheme.light`
  - `class ThemeController extends ChangeNotifier` singleton `ThemeController.instance`; `bool get isDark`; `ThemeMode get themeMode`; `Future<void> init()`; `Future<void> toggle()`; `Future<void> setDark(bool)`; clave prefs `'app_theme_is_dark'` (default `true`).

- [ ] **Step 1: Refactor `app_theme.dart`** al patrón del fork: `_buildTheme(AppPalette p, Brightness brightness)` con `final textTheme = AppTypography.textTheme(p.textPrimary, p.textMuted);` y todos los colores tomados de `p.*` / `AppColors.brandBlue` / `AppColors.onBrand`. **Conservar** el `pageTransitionsTheme` con `AppFadeThroughPageTransitionsBuilder` que tiene la versión actual (el fork no lo trae). `onPrimary`/`onError` = `AppColors.onBrand`; `navigationBarTheme` etiqueta/ícono seleccionados = `AppColors.onBrand` (como el fork). Exponer `dark` y `light` como getters que llaman `_buildTheme(AppColors.darkPalette|lightPalette, ...)`.
- [ ] **Step 2: `typography.dart`** — si `static final TextTheme dark = textTheme(AppColors.textPrimary, AppColors.textMuted);` genera warning por evaluación temprana o deja de usarse, dejarlo si compila; si molesta, quitarlo y arreglar sus usos (`grep -rn "AppTypography.dark" lib`).
- [ ] **Step 3: Crear `lib/design/theme/theme_controller.dart`** copiando del fork (singleton `ChangeNotifier`, `_prefsKey='app_theme_is_dark'`, `_isDark=true`, `init()` idempotente que hace `AppColors.setDark(_isDark)`, `toggle()`/`setDark()` con `notifyListeners()` + persistencia best-effort try/catch). Comentarios en español.
- [ ] **Step 4: `design.dart`** — añadir `export 'package:doliv_social/design/theme/theme_controller.dart';`.
- [ ] **Step 5: analyze de los archivos tocados**
  Run: `flutter analyze lib/design/theme/app_theme.dart lib/design/theme/theme_controller.dart lib/design/design.dart lib/design/tokens/typography.dart`
  Expected: No issues (salvo, quizá, `const` en `app_theme.dart` mismo → quitar esos `const` acá).
- [ ] **Step 6: NO commitear todavía.**

### Task 9: Barrido de `const` en todo `lib/` y `test/`

**Files:**
- Modify: hasta ~82 archivos bajo `lib/`, más algunos en `test/` (solo quitar `const`; sin cambios de lógica)

- [ ] **Step 1: Primer análisis global**
  Run: `flutter analyze 2>&1 | tee /tmp/analyze1.txt | tail -40`
  Expected: muchos `const_with_non_constant_argument` / `const_with_non_constant_type` / `invalid_constant`.
- [ ] **Step 2: `dart fix` automático**
  Run: `dart fix --apply`
  Luego: `flutter analyze 2>&1 | tee /tmp/analyze2.txt | tail -60`
- [ ] **Step 3: Arreglo iterativo manual**
  Para cada error restante: abrir el archivo:línea, quitar el `const` del nodo que referencia el token dinámico (`AppColors.bgBase/surface/surfaceBorder/accent/accentStrong/textPrimary/textMuted/success/warning/error/info/buttonGradient`) y de los ancestros que dejen de ser constantes. Repetir `flutter analyze` hasta 0 errores. Sin tocar lógica, sin reformatear de más.
- [ ] **Step 4: Ajustar `test/`**
  Run: `grep -rn "AppColors\.\(bgBase\|surface\|surfaceBorder\|accent\|accentStrong\|textPrimary\|textMuted\|success\|warning\|error\|info\|buttonGradient\)" test/`
  Quitar `const` donde corresponda. En el `setUp` de tests de widget que dependan del modo, añadir `AppColors.setDark(true);`. `test/login_remember_me_test.dart` usa `AppTheme.dark` — debe seguir compilando y pasando.
- [ ] **Step 5: Verde total**
  Run: `flutter analyze`
  Expected: No issues found.
  Run: `dart format $(git diff --name-only --diff-filter=ACM | grep '\.dart$')`
  Run: `flutter test`
  Expected: All tests passed (mismo conteo que la línea base de Task 1, salvo los tests nuevos de Fase 2).
- [ ] **Step 6: Commit**
  ```bash
  git add -A
  git commit -m "refactor(tema): AppColors mode-aware (getters) + AppTheme claro/oscuro + ThemeController"
  ```

### Task 10: Cablear el tema en `main.dart`

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: `init()` antes de `runApp`** — en `main()`, junto a `initializeDateFormatting`, añadir `await ThemeController.instance.init();` (import vía `package:doliv_social/design/design.dart`, ya importado).
- [ ] **Step 2: Envolver `MaterialApp`**
  ```dart
  return AnimatedBuilder(
    animation: ThemeController.instance,
    builder: (context, _) => MaterialApp(
      // ...igual que ahora...
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeController.instance.themeMode,
      // ...
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return KeyedSubtree(
          key: ValueKey(ThemeController.instance.isDark),
          child: ColoredBox(
            color: AppColors.bgBase,
            child: ConnectivityGate(child: child),
          ),
        );
      },
      // ...
    ),
  );
  ```
- [ ] **Step 3: analyze + test**
  Run: `flutter analyze lib/main.dart && flutter test`
  Expected: limpio / verde.
- [ ] **Step 4: Commit**
  ```bash
  git add lib/main.dart
  git commit -m "feat(tema): MaterialApp reacciona a ThemeController (claro/oscuro en caliente)"
  ```

### Task 11: Interruptor "Tema oscuro" en el menú lateral

**Files:**
- Modify: `lib/shared/widgets/app_menu_drawer.dart`

- [ ] **Step 1: Insertar el switch** entre el `Expanded(child: ListView(...))` y el `Divider` + `Padding("Radio Doliv")` del pie:
  ```dart
  const Divider(color: AppColors.surfaceBorder, height: 1),
  SwitchListTile(
    secondary: Icon(Icons.dark_mode_outlined, color: AppColors.accent),
    title: const Text(
      'Tema oscuro',
      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    ),
    value: ThemeController.instance.isDark,
    onChanged: (v) => ThemeController.instance.setDark(v),
  ),
  ```
  (Si tras `dart fix` `AppColors.textPrimary` ya no admite `const` aquí, ajustar el `TextStyle`.)
- [ ] **Step 2: Verificar cierre del drawer** — al alternar, el `AnimatedBuilder` de `main.dart` + el `KeyedSubtree` reconstruyen el árbol y el `Drawer` se cierra solo. Si en pruebas queda medio abierto, añadir `Navigator.of(context).maybePop();` antes del `setDark`. Anotar el comportamiento observado en el informe final.
- [ ] **Step 3: analyze**
  Run: `flutter analyze lib/shared/widgets/app_menu_drawer.dart`
  Expected: No issues.
- [ ] **Step 4: Commit**
  ```bash
  git add lib/shared/widgets/app_menu_drawer.dart
  git commit -m "feat(tema): interruptor \"Tema oscuro\" en el menú lateral"
  ```

### Task 12: Verificación visual y regresión

- [ ] **Step 1: `flutter analyze`** → No issues.
- [ ] **Step 2: `flutter test`** → todo verde.
- [ ] **Step 3: `flutter build apk --debug`** → compila (valida `open_filex` + overrides de Android).
- [ ] **Step 4: Recorrido en ambos modos** (emulador o dispositivo si está disponible; si no, dejar constancia de que queda pendiente en dispositivo): login, dashboards por rol, task board + ficha de tarea + devolver, chat, Recursos → Documentos (abrir/descargar) → Imágenes (ver/descargar/rota), formularios, calendario, menú lateral + toggle + reinicio de la app (persistencia).
- [ ] **Step 5: Escribir el resumen final** en `docs/superpowers/notes/2026-09-09-integration-summary.md` cubriendo los 6 puntos pedidos por el usuario (qué se extrajo, qué se adaptó, archivos modificados, bugs corregidos, pruebas hechas, riesgos/pendientes).
- [ ] **Step 6: Commit**
  ```bash
  git add docs/superpowers/notes/2026-09-09-integration-summary.md
  git commit -m "docs: resumen de la integración de funciones desde App-radio-robert"
  ```

---

## Self-Review (hecho)

- **Cobertura del spec:** Función 1 → Tasks 1-2. Función 2 → Tasks 7-12 (colors, theme, controller, sweep, main, menú, verificación). Función 3 → Tasks 3-6 (open_filex+servicio, abrir doc, descargar imagen+placeholder, auditoría accesos). Validación global → Task 12. Sin huecos.
- **Placeholders:** los pasos de código traen el código real; el barrido de `const` (Task 9) es inherentemente dirigido por el compilador — se describe el procedimiento exacto, no un "arréglalo".
- **Consistencia de tipos:** `DocumentService.fetchToTemp` → `OpenedDocument` (Task 3) consumido en Task 4. `imageExtFromUrl` (Task 5) usado en el mismo archivo. `ThemeController.instance` / `AppTheme.light|dark` / `AppColors.setDark` definidos en Tasks 7-8, usados en 10-11. `AppPalette` campos idénticos entre `colors.dart` y `app_theme.dart`.
