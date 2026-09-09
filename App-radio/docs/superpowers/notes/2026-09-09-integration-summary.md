# Integración de funciones desde App-radio-robert — Resumen

Fecha: 2026-09-09
Rama: `feat/robert-feature-integration`
Spec: `docs/superpowers/specs/2026-09-09-robert-feature-integration-design.md`
Plan: `docs/superpowers/plans/2026-09-09-robert-feature-integration.md`

---

## 1. Qué se extrajo del proyecto de referencia

- **Modo claro/oscuro** — se portó completo desde
  `App-radio-robert/lib/design/`:
  - `tokens/colors.dart`: tokens públicos como getters resueltos por
    `AppColors.isDark`, paleta clara, `darkPalette`/`lightPalette`
    (`AppPalette`), `onBrand*`.
  - `theme/app_theme.dart`: `_buildTheme(AppPalette, Brightness)` → `light` +
    `dark`.
  - `theme/theme_controller.dart`: singleton `ChangeNotifier`, persiste
    `app_theme_is_dark` en `shared_preferences`, default oscuro.
  - `main.dart`: `AnimatedBuilder` + `themeMode` + `KeyedSubtree` atado al modo.
- **Abrir documentos con el visor nativo** — se adoptó el enfoque de
  `App-radio-robert/lib/ResourceM/documents.dart` (`open_filex` sobre un
  archivo temporal descargado).
- **Descargar imagen desde el visor** — se adoptó el patrón de
  `App-radio-robert/lib/ResourceM/imagecc.dart` (`FilePicker.saveFile` con
  nombre derivado de la URL).

## 2. Qué se adaptó en lugar de copiar

- **Return Task**: no se copió nada. El fork **no** tiene esa función; el
  proyecto actual ya la tiene completa en el flujo `dept_tasks` (backend +
  Flutter + hilo de comentarios). Solo se auditó
  (`docs/superpowers/notes/2026-09-09-return-task-audit.md`): correcta de
  punta a punta, sin fallos, sin cambios de código.
- **colors.dart / app_theme.dart**: el fork tenía una estructura más simple;
  se conservaron los hex oscuros exactos del proyecto actual y su
  `pageTransitionsTheme` (`AppFadeThroughPageTransitionsBuilder`), que el fork
  no trae.
- **Barrido de `const`**: el fork ya venía migrado; aquí hubo que quitar
  `const` de ~544 expresiones que pasaban a referenciar un getter. Se hizo con
  un script iterativo guiado por `flutter analyze` (borrado). Los casos que no
  eran `const`-de-widget se adaptaron a mano:
  - `TaskTone.color` → getter con `switch (this)`.
  - `SiteFieldColors.blue/green/orange/red` → getters.
  - `IdentityAvatar._palette` → getter.
  - defaults de parámetro (`InfoBanner.color`, `StatTile.accentColor`,
    `TaskFlagIcon.color`, `SiteFormField.iconColor`, `TeamCard._statChip`) →
    nullable con fallback resuelto en `build()`.
  - `AppTypography.dark` (TextTheme precomputado) → eliminado (sin uso).
- **Documentos**: se reutilizó el `DocumentService` / `TeamDocumentsScreen`
  actuales; solo se añadió `fetchToTemp()` + la acción "Ver". La descarga
  "guardar como" no cambió.
- **Visor de imagen**: se añadió solo el botón de descarga + `errorBuilder` +
  `InteractiveViewer`. No se portó el overlay nombre/descripción del fork
  (decisión del usuario).
- **Interruptor de tema**: `SwitchListTile` "Tema oscuro" simple en el pie del
  menú lateral (no un triple Claro/Oscuro/Automático).

## 3. Archivos modificados

**Flutter — tema (fase 3):**
- `lib/design/tokens/colors.dart` (reescrito)
- `lib/design/tokens/typography.dart`
- `lib/design/theme/app_theme.dart` (reescrito)
- `lib/design/theme/theme_controller.dart` (nuevo)
- `lib/design/design.dart` (export)
- `lib/main.dart`
- `lib/shared/widgets/app_menu_drawer.dart`
- ~95 archivos más bajo `lib/` — solo borrado de `const` y ajustes puntuales
  descritos arriba; `dart format` reformateó de paso los archivos tocados.

**Flutter — archivos (fase 2):**
- `pubspec.yaml`, `pubspec.lock` (`open_filex: ^4.5.0`)
- `lib/services/document_service.dart` (`OpenedDocument`, `sanitizeFileName`,
  `fetchToTemp`)
- `lib/shared/resources/team_documents_screen.dart` (acción "Ver" + spinner)
- `lib/shared/resources/imagecc.dart` (visor a `StatefulWidget` con descarga,
  `imageExtFromUrl`, `_BrokenImage`, `errorBuilder`, `InteractiveViewer`)

**Tests nuevos:**
- `test/document_service_open_test.dart`
- `test/image_detail_download_test.dart`

**Backend:** ningún cambio. La auditoría concluyó que `documents.php` ya es
correcto y que las imágenes se sirven como asset público con nombre aleatorio
(igual que el fork).

**Docs:**
- `docs/superpowers/specs/2026-09-09-robert-feature-integration-design.md`
- `docs/superpowers/plans/2026-09-09-robert-feature-integration.md`
- `docs/superpowers/notes/2026-09-09-return-task-audit.md`
- `docs/superpowers/notes/2026-09-09-file-access-audit.md`
- este resumen

## 4. Bugs corregidos

- **Documentos subidos no se podían abrir en la app**: solo había "descargar".
  Ahora tocar la tarjeta (o "Ver") los abre con el visor nativo; si no hay app
  para esa extensión, aviso claro en vez de nada.
- **Visor de imágenes sin descarga**: `ImageDetailScreen` no tenía forma de
  guardar la imagen. Ahora sí.
- **Imágenes rotas mostraban el recuadro rojo de excepción** de `Image.network`
  (grilla y visor). Ahora muestran un placeholder discreto (`errorBuilder`).
- **Documento borrado en el servidor**: `fetchToTemp`/`download` comprueban
  `statusCode` y propagan el mensaje del backend ("El archivo ya no está
  disponible…") en vez de escribir un archivo vacío.
- **Latente, introducido y corregido durante el barrido**: varios
  `static final Color = AppColors.x` habrían "congelado" el color del primer
  modo activo; se pasaron a getters para que sigan al modo.

Return Task: la auditoría no encontró bugs.

## 5. Pruebas realizadas

- `flutter analyze` → **No issues found** (tras el barrido y `dart fix` de los
  11 `curly_braces` que dejó el reformateo).
- `flutter test` → **125/125** (122 de línea base + 3 nuevos). Incluye
  `test/task_board_test.dart` (tono "devuelta").
- `flutter build apk --debug` → **OK**. Valida que `open_filex` convive con los
  `dependency_overrides` de Android del proyecto (sin conflicto de Gradle).
- Auditoría por lectura de código del flujo devolver-tarea (backend + Flutter)
  y del control de acceso a documentos e imágenes.

## 6. Riesgos y pendientes

- **Verificación en dispositivo real (pendiente)** — no se pudo hacer desde
  este entorno:
  - Alternar "Tema oscuro" en caliente: confirmar que todas las pantallas se
    releen bien en claro y que el `Drawer` se cierra al alternar (si queda
    medio abierto, añadir `Navigator.maybePop()` antes de `setDark`).
  - Persistencia del tema tras cerrar y reabrir la app.
  - Abrir un PDF/Word/Excel real con `OpenFilex`; el diálogo "guardar" de
    `FilePicker.saveFile` para imagen y documento.
  - Revisar una muestra de pantallas en modo claro por si algún color
    hardcodeado (fuera de `AppColors`) queda ilegible.
- **Alternar tema reinicia la pila de navegación** (por el `KeyedSubtree`). Es
  el costo conocido del enfoque; aceptable para una opción de ajustes.
- **`dart format` reformateó ~85 archivos** al vuelo (el formateador de este
  Flutter usa reglas nuevas). Va incluido en el commit del barrido; no cambia
  comportamiento pero infla el diff.
- **Imágenes servidas como asset público** (`UPLOAD_URL_BASE`): nombre
  aleatorio no adivinable, mismo diseño que el fork. Endurecerlo (servirlas por
  un endpoint autenticado) es un cambio de contrato aparte, documentado en
  `2026-09-09-file-access-audit.md`.
- **Fuga menor conocida**: el diálogo "Devolver tarea" no hace `dispose()` de
  su `TextEditingController` (un controlador por devolución). Fuera de alcance;
  impacto despreciable.
