# Plan de rediseño del frontend

> Documento transversal: afecta a **todas** las áreas de
> [`actualizaciones/`](actualizaciones/README.md). Léelo antes de escribir
> pantallas nuevas para la reestructuración de Radio Doliv
> (ver [Actualizacion.md](Actualizacion.md)).

---

## 1. Diagnóstico

El problema no es que la app se vea mal: es que **conviven dos diseños** y el
nuevo nunca se terminó de propagar.

| Hallazgo | Medición |
|---|---|
| Pantallas que usan el sistema nuevo (`AppColors`) | **3 de 36** — solo `login.dart`, `tasks.dart`, `teamDetail.dart` |
| Pantallas con colores hardcodeados | 33 — `Colors.indigo`, `Color.fromARGB(255, 56, 72, 108)`, botones `Colors.black` |
| `Scaffold` independientes, cada uno con su propio fondo y padding | 30 |
| Llamadas a `withOpacity` (deprecado) | 16 |
| Dependencias declaradas y no usadas | 7 |
| Texto de UI en inglés (viola requisito obligatorio de español) | `profile.dart`: "Edit Profile", "Security", "Suggestion and Feedback" |

Causas de fondo, no cosméticas:

1. **El tema no está conectado.** `main.dart` declara
   `ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue)` — un tema
   **claro**— mientras las 3 pantallas rediseñadas pintan a mano un fondo
   **oscuro** por `Scaffold`. El tema y las pantallas se contradicen, así que
   cualquier widget que herede del tema (diálogos, `SnackBar`, menús) sale con
   la apariencia equivocada.
2. **`MyApp` y `MyApp2` duplican tema y tabla de rutas** (la única diferencia
   es la pantalla inicial). Todo cambio de tema hay que hacerlo dos veces.
3. **No hay escala tipográfica ni de espaciado.** Los tamaños de fuente van
   sueltos por pantalla (`fontSize: 40`, `25`, `24`, `18`...) y los paddings
   también.
4. **No hay componentes de estado.** Cada `FutureBuilder` resuelve a su manera
   el vacío, la carga y el error; muchos simplemente muestran
   `Text('Error: $snapshot.error')` en crudo al usuario.
5. **La navegación no conoce los roles.** `BottomNavBar` tiene 4 pestañas fijas,
   pero el roadmap exige tres dashboards distintos según rol.

---

## 2. Estrategia: la fundación va primero, y va ya

Hay **cinco personas a punto de escribir pantallas nuevas** en ramas paralelas
(`abraham`, `diana`, `jona`, `robert`, `wen`): dashboards por rol, gestión de
departamentos, anuncios, workflow de tareas, permisos/chat/recursos.

Eso define el orden. Si el rediseño se hace pantalla por pantalla mientras
ellos construyen, pasan dos cosas malas: se rediseña código que aún no existe,
y las 5 ramas nacen con el diseño viejo y hay que rediseñarlas otra vez.

> **Recomendación principal: la Fase 0 (tokens + tema + componentes) se mergea a
> `main` antes de que las ramas avancen con UI.** Es la fase más pequeña y la
> única bloqueante. Todo lo demás puede ir en paralelo y por partes.

El orden de fases refleja eso: primero lo que desbloquea a otros, después lo
que solo nos afecta a nosotros.

---

## 3. Fase 0 — Fundación *(bloqueante, entrega en un solo PR)* ✅ Aplicada

> Implementada: `lib/design/` (tokens, tema, 8 componentes base), `MyApp`/
> `MyApp2` fusionados en `lib/main.dart`, y `login.dart`/`tasks.dart`/
> `teamDetail.dart` migrados a los tokens nuevos. Galería de referencia en
> `/_ComponentGallery` (solo debug). `flutter analyze` sin errores nuevos y
> `flutter test` en verde — ver detalle abajo.

### 3.1 Tokens de color anclados a la marca

Los colores actuales de `AppColors` derivan hacia el índigo/violeta y no
coinciden con la marca. Los valores reales del logo
(`assets/logo/logo.png`) son:

| Color de marca | Hex | Presencia en el logo |
|---|---|---|
| Azul marino | `#00356F` | 76 % |
| Azul medio | `#004691` | 23 % |
| Blanco | `#F2F2F2` | 1 % |

> ⚠️ **Regla de uso obligatoria.** Los azules de marca **no sirven como texto ni
> iconos sobre fondo oscuro** — el contraste es 1.48:1 y 1.94:1, muy por debajo
> del mínimo WCAG AA de 4.5:1. Solo funcionan como **relleno** (blanco sobre
> `#004691` da 9.19:1, AAA). Para texto, iconos, enlaces y bordes sobre oscuro
> se usan los tintes claros. Esto no es opinable: es lo que hace la app legible.

Paleta propuesta, con contraste ya verificado sobre el fondo base `#0A1730`:

| Token | Hex | Contraste | Uso |
|---|---|---|---|
| `bgBase` | `#0A1730` | — | Fondo de la app |
| `surface` | `#122240` | 1.13:1 vs fondo | Tarjetas, campos, hojas |
| `surfaceBorder` | `#1E3355` | — | Bordes de tarjeta y campo |
| `brandNavy` | `#00356F` | *solo relleno* | Cabeceras, franjas, fondos de marca |
| `brandBlue` | `#004691` | *solo relleno* | Botón primario (texto blanco: 9.19:1 AAA) |
| `accent` | `#4D93E8` | **5.65:1 AA** | Iconos, enlaces, estados activos |
| `accentStrong` | `#6FA9EE` | **7.29:1 AAA** | Texto de énfasis, foco |
| `textPrimary` | `#F2F2F2` | **15.92:1 AAA** | Texto principal (blanco de marca) |
| `textMuted` | `#9FB0CC` | **8.11:1 AAA** | Texto secundario, ayudas |

`textMuted` sustituye al `darkMuted` actual (`#8993B5`, 5.86:1): mismo papel,
mejor legibilidad, sin costo.

Falta definir además los **colores semánticos** (éxito, advertencia, error,
info) con el mismo criterio de contraste — hoy se usan `Colors.red` y
`Colors.redAccent` sueltos.

### 3.2 Escalas

- **Espaciado**: escala de 4 pt (`4, 8, 12, 16, 24, 32, 48`). Hoy hay
  `SizedBox(height: 40)`, `20`, `15`, `36` sin criterio.
- **Radios**: `8` (chips), `16` (campos y tarjetas — ya es el valor de
  `CustomTextFormField`), `999` (píldoras).
- **Tipografía**: escala de 6 pasos mapeada sobre `TextTheme` de Material 3
  (`displaySmall`, `headlineMedium`, `titleLarge`, `bodyLarge`, `bodyMedium`,
  `labelSmall`), con los pesos que ya usa `login.dart` (`w800` títulos,
  `w500` cuerpo).

### 3.3 Tema real, y uno solo

- Construir `ThemeData` **oscuro completo** desde los tokens:
  `ColorScheme.dark(...)`, `scaffoldBackgroundColor`, `textTheme`,
  `inputDecorationTheme` (extraído de `CustomTextFormField`),
  `elevatedButtonTheme`, `snackBarTheme`, `dialogTheme`, `navigationBarTheme`,
  `appBarTheme`.
- **Fusionar `MyApp` y `MyApp2`** en un solo widget con `initialRoute`
  calculado según haya token o no. Elimina la duplicación de tema y rutas.
- Meta: que una pantalla nueva se vea correcta **sin** declarar un solo color.

### 3.4 Componentes base

```
lib/design/
├── tokens/      colors.dart · spacing.dart · typography.dart
├── theme/       app_theme.dart
└── components/  app_scaffold.dart · app_button.dart · app_card.dart
                 app_text_field.dart · state_views.dart · section_header.dart
                 stat_tile.dart · app_dialog.dart · app_badge.dart
```

El más importante es **`state_views.dart`** (`EmptyState`, `LoadingState`,
`ErrorState`): es el hueco más grande de la app y el que más pantallas nuevas
va a ahorrar a las 5 ramas. Todos sus textos, en español.

`CustomTextFormField` y `GradientButton` ya existen y se absorben aquí; el
gradiente actual se re-deriva de `brandNavy → brandBlue`.

**Entregable de la fase**: `flutter analyze` limpio, `flutter test` en verde, y
una pantalla de referencia (galería de componentes) para revisar la dirección
de un vistazo.

---

## 4. Fase 1 — Shell y navegación por rol

Depende de Fase 0. **Coordinar con `abraham`**, que tiene asignados los
dashboards por rol: esta fase le entrega el contenedor, él entrega el contenido.

- `AppScaffold`: fondo, `SafeArea`, padding y `AppBar` coherentes; sustituye a
  los 30 `Scaffold` sueltos.
- Rehacer `MyAppBar`: hoy pinta un gradiente `Colors.black → Colors.indigo`
  hardcodeado y consulta el nombre con un endpoint aparte. Debe leer de
  `Session`/`UserProfile` y mostrar rol y departamento.
- **`BottomNavBar` variable según rol**: hoy son 4 destinos fijos. Director,
  Manager y Empleado necesitan juegos distintos (ver
  [Actualizacion.md](Actualizacion.md) § *Rediseño del Dashboard*). El destino
  inicial se resuelve con `Session.getCachedRole()`, con `employee` como
  fallback si es `null`.
- `profile.dart`: traducir al español y reconstruir con los componentes nuevos.

---

## 5. Fase 2 — Migración de pantallas

Siete PRs pequeños, agrupados por flujo para que cada uno sea revisable y
probable de forma aislada. Ninguno bloquea a otro.

| # | Flujo | Pantallas |
|---|---|---|
| 1 | Autenticación | `signup`, `forgot_pass`, `otp_verify`, `new_password` *(login ya está)* |
| 2 | Inicio y progreso | `home_page_home`, `dashboard`, `progress`, `teams` |
| 3 | Tareas | `addTask`, `MarkTaskDone` *(tasks ya está)* |
| 4 | Equipos | `create-team`, `Domain-team`, `join_team`, `LResign`, `MResign` *(teamDetail ya está)* |
| 5 | Recursos | `Resources`, `getR`, `fetchR`, `doc`, `imagecc`, `Leaderassist` |
| 6 | Chat | `chat`, `chatHistory` |
| 7 | Permisos y avisos | `leave`, `notifications` |

Criterio de "migrada" para cada pantalla:

- Cero colores literales; todo sale de tokens o del tema.
- Estados de vacío, carga y error resueltos con `state_views`.
- Nada de `Text('Error: $e')` crudo hacia el usuario: mensaje en español y
  accionable.
- 100 % del texto visible en español.

Los PRs 5, 6 y 7 tocan módulos que `wen` está extendiendo (recursos, chat,
permisos): **hacerlos después de que su rama mergee**, o coordinar el orden con
él. No hay razón para pelearse por los mismos archivos.

---

## 6. Fase 3 — Pulido

- **Auditoría de accesibilidad**: contraste de todo par texto/fondo, área táctil
  mínima de 48×48, `semanticsLabel` en iconos que hoy van sin etiqueta.
- **Auditoría de español**: barrido final de texto visible; hoy ya hay
  violaciones (`profile.dart`) y el requisito es explícito y obligatorio.
- **Respuesta a distintos tamaños**: la app usa `MediaQuery...height * 0.06`
  para espaciar; revisar en pantallas chicas y con fuente del sistema ampliada.
- **Consistencia de movimiento**: duraciones y curvas de transición unificadas.

---

## 7. Limpieza transversal *(oportunista, en cualquier PR)*

- **7 dependencias sin usar** en `pubspec.yaml`: `audioplayers`,
  `cached_network`, `cached_network_image`, `dio`, `modal_progress_hud_nsn`,
  `socket_io_client`, `table_calendar`.
  → `table_calendar` conviene **conservarla**: el dashboard del Empleado pide
  "Mi Calendario". Las otras 6 se pueden quitar.
- **16 `withOpacity`** → `withValues(alpha:)` (ya deprecado en la versión de
  Flutter del proyecto).
- **Rutas de carpeta problemáticas**: `create&join-Team/` (el `&` obliga a
  escapes en shell y URLs), `leave approval/` y `forgot password/` (espacios,
  que ya obligan a `forgot%20password` en un import de `main.dart`).
- **Nombres de clase fuera de convención**: `dashb_mem`, `t_detail`,
  `join_team`, `doneTask` → `PascalCase`. Renombrar junto con la migración de
  cada pantalla, no en un PR aparte.
- **`actualizaciones/README.md`, regla 1 está desactualizada**: menciona la
  carpeta `backend/` de Node y la ruta externa del backend PHP; ambas cambiaron
  en la consolidación reciente. Confunde a las 5 personas que la leen primero.

---

## 8. Riesgos

| Riesgo | Mitigación |
|---|---|
| Conflictos de merge con las 5 ramas activas | Fase 0 primero y pequeña; Fase 2 agrupada por flujo y coordinada con el dueño de cada módulo |
| El rediseño rompe flujos que hoy funcionan | Migrar por flujo completo y probar cada uno contra el backend real antes de mergear |
| La cobertura de test es mínima (solo `login`) | Añadir pruebas de widget al migrar cada flujo; el patrón ya está en `test/widget_test.dart` |
| Reaparece texto en inglés | Auditoría de la Fase 3 + revisión en cada PR |

## 9. Verificación

- `flutter analyze` sin errores nuevos (hoy: 244 avisos, ninguno error).
- `flutter test` en verde.
- Backend intacto: `node tools/php-backend-test.js` (89/89) y
  `node tools/php-backend-test-org.js` (28/28).
- Revisión visual de cada flujo migrado contra la galería de componentes.

---

## Resumen de secuencia

```
Fase 0  Fundación (tokens · tema · componentes)     ← BLOQUEANTE, va primero
   │
   ├─→ Fase 1  Shell y navegación por rol            ← coordinar con abraham
   │
   └─→ Fase 2  Migración por flujo (7 PRs)           ← en paralelo, PRs 5-7 tras wen
          │
          └─→ Fase 3  Pulido (a11y · español · responsive)
```
