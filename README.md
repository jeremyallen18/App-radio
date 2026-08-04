# Team Management App

Aplicación Flutter para gestionar equipos de trabajo: creación y unión a equipos por código, asignación de tareas por área, seguimiento de progreso, chat interno, solicitudes de permiso (leave), recursos compartidos y notificaciones in-app. Todo el texto de la interfaz está en español.

## Tabla de contenidos

- [Arquitectura general](#arquitectura-general)
- [Stack técnico](#stack-técnico)
- [Configuración del backend](#configuración-del-backend)
- [Sistema de diseño](#sistema-de-diseño)
- [Ícono de la app](#ícono-de-la-app)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Flujo de la aplicación](#flujo-de-la-aplicación)
- [Backend PHP (`hive-backend`)](#backend-php-hive-backend)
- [Esquema de base de datos (`hive_db`)](#esquema-de-base-de-datos-hive_db)
- [Endpoints](#endpoints)
- [Herramientas y pruebas](#herramientas-y-pruebas)
- [Cómo correr el proyecto (guía paso a paso)](#cómo-correr-el-proyecto-guía-paso-a-paso)

## Arquitectura general

```
┌─────────────────────────┐        HTTP (REST, JSON / urlencoded)
│  App Flutter            │  ───────────────────────────────────────►  ┌──────────────────────────┐
│  (Android/iOS/Desktop)  │                                            │  Apache (XAMPP) :80      │
│                         │  ◄───────────────────────────────────────  │  C:\xampp\htdocs\        │
│  kBaseUrl ──────────────┼──►  http://<host>/hive-backend             │      hive-backend\       │
└─────────────────────────┘        Authorization: <token crudo>        │   index.php (router)     │
                                                                       │   helpers.php (auth/DB)  │
                                                                       │   config.php (PDO)       │
                                                                       │   uploads/ (imágenes)    │
                                                                       └────────────┬─────────────┘
                                                                                    │ PDO/MySQL
                                                                       ┌────────────▼─────────────┐
                                                                       │  MySQL  ·  hive_db       │
                                                                       └──────────────────────────┘
```

**El backend en producción es el PHP** en [`hive-backend/`](hive-backend/), dentro de este repo, servido localmente por Apache (XAMPP) sobre la base `hive_db`. Es el único que la app consume. El stack completo del proyecto es **Dart (Flutter) + PHP + MySQL**; no hay ningún otro backend en el repo.

En local, `C:\xampp\htdocs\hive-backend` es una **junction** de Windows que apunta a `hive-backend/` dentro de este repo — así Apache lo sigue sirviendo en la misma URL sin duplicar archivos. Si necesitas recrearla (por ejemplo, en otra máquina):

```powershell
New-Item -ItemType Junction -Path "C:\xampp\htdocs\hive-backend" -Target "C:\xampp\htdocs\App-radio\hive-backend"
```

Credenciales de DB y la ruta base ya no están hardcodeadas: viven en `hive-backend/.env` (fuera de git, ver `.env.example`). Al desplegar a Hostinger, copia `hive-backend/` completo y crea un `.env` propio con las credenciales de esa base y, si el backend no vive en la raíz del dominio, ajusta `APP_BASE_PATH` ahí **y** `RewriteBase` en `hive-backend/.htaccess` (ese sí es estático, Apache lo lee antes de que corra PHP).

## Stack técnico

**Cliente**

- **Flutter / Dart** (Material 3, tema oscuro propio en [`lib/design/theme/app_theme.dart`](lib/design/theme/app_theme.dart) — ver [Sistema de diseño](#sistema-de-diseño)).
- **http** para llamadas REST contra el backend.
- **flutter_secure_storage** para persistir el token de sesión (`accessToken`).
- **multi_select_flutter**, **table_calendar**, **fl_chart**, **image_picker**, **socket_io_client**, **audioplayers**, **cached_network_image**, **dio** como dependencias de features puntuales.
- **flutter_launcher_icons** para generar el ícono de la app en todas las plataformas desde un único archivo fuente.

**Servidor**

- **PHP 8 + PDO** sobre Apache (XAMPP), sin framework: un router por expresiones regulares en `index.php`.
- **MySQL** (`hive_db`, InnoDB, utf8mb4).
- Autenticación por **token opaco** (32 bytes hex) guardado en `users.token`; contraseñas con `password_hash` (bcrypt).
- Subida de imágenes al directorio `uploads/`, servido estáticamente por el mismo Apache.

## Configuración del backend

Toda la app apunta a un único backend a través de una variable central:

```
lib/utils/api_config.dart
```

```dart
const String kBaseUrl = 'http://192.168.3.44/hive-backend';
```

Para apuntar la app a otro servidor/IP/dominio, **solo hay que cambiar esta línea** — el resto del código arma cada endpoint como `'$kBaseUrl/user/login'`, `'$kBaseUrl/team/createTeam'`, etc. Como el dispositivo físico y XAMPP están en la misma red local, aquí va la IP LAN del equipo que corre Apache (no `localhost`).

## Sistema de diseño

Toda la app corre sobre un tema oscuro único, anclado a los colores de marca (azul marino/azul medio/blanco extraídos de `assets/logo/logo.png`, con contraste WCAG verificado). Vive en `lib/design/`:

```
lib/design/
├── tokens/      colors.dart (AppColors) · spacing.dart (AppSpacing/AppRadius) · typography.dart
├── theme/       app_theme.dart          # ThemeData único, usado por MyApp en main.dart
├── components/  app_scaffold.dart · app_button.dart · app_card.dart · app_text_field.dart
│                state_views.dart (LoadingState/EmptyState/ErrorState) · section_header.dart
│                stat_tile.dart · app_dialog.dart (showAppConfirmDialog) · app_badge.dart
└── design.dart  # barrel: import '../design/design.dart' trae todo lo anterior
```

**Regla de uso de color, no opinable**: `AppColors.brandNavy` y `AppColors.brandBlue` (los azules del logo) solo sirven como **relleno** (fondos, botones sólidos) — su contraste como texto/ícono sobre el fondo oscuro es de 1.48:1 y 1.94:1, muy por debajo del mínimo AA (4.5:1). Para texto, íconos, enlaces y bordes sobre fondo oscuro se usan `AppColors.accent` (5.65:1) o `AppColors.accentStrong` (7.29:1). Nunca uses `Colors.black`, `Colors.white` ni un `Color(0x...)` suelto en una pantalla — todo sale de estos tokens.

⚠️ **Ojo con `elevatedButtonTheme.minimumSize`** (`app_theme.dart`): tiene que ser un `Size` de ancho **finito** (hoy `Size(64, 50)`). `Size.fromHeight(...)` fija un ancho mínimo infinito, que revienta con `BoxConstraints... NOT NORMALIZED` en cualquier `ElevatedButton` que además reciba un `maximumSize` explícito (pasó en `home_page/teams.dart`).

Pantalla de referencia visual (solo debug, no es parte del flujo de usuario): `/_ComponentGallery` — ver `lib/design/gallery/component_gallery_screen.dart`.

El rediseño completo (motivación, fases, qué falta) está documentado en [`Rediseno-Frontend.md`](Rediseno-Frontend.md). Hoy está aplicada la Fase 0 (fundación: tokens, tema, componentes base, `login.dart`/`tasks.dart`/`teamDetail.dart`/`profile.dart`/`bottomnavbar.dart`/`teams.dart` migrados). El resto de las pantallas todavía usa colores sueltos y algo de texto en inglés — hay que migrarlas antes de darlas por terminadas (ver ese documento para el orden y los criterios).

## Ícono de la app

El logo fuente vive en `assets/logo/logo.png` (no en `lib/assets/`, que es la carpeta de imágenes usadas dentro de las pantallas). Los íconos nativos de cada plataforma (Android `mipmap`/adaptive icon, iOS `AppIcon.appiconset`, Windows `.ico`, macOS `.icns`) se generan a partir de ese archivo con:

```bash
dart run flutter_launcher_icons
```

La configuración vive al final de `pubspec.yaml`, bajo la clave `flutter_launcher_icons:`. Si cambias el logo, reemplaza `assets/logo/logo.png` y vuelve a correr ese comando para regenerar los íconos en todas las plataformas.

## Estructura del proyecto

```
hive-backend/                   # ← BACKEND EN USO. C:\xampp\htdocs\hive-backend es una
│                                 # junction que apunta aquí (Apache lo sirve igual).
├── index.php                    # Router + todos los handlers (auth, equipos, tareas,
│                                 # chat, recursos, permisos, notificaciones).
├── helpers.php                  # Respuestas JSON/texto, parseo del body, require_auth,
│                                 # require_team_member / require_team_leader, notify_user.
├── config.php                   # Carga .env, conexión PDO a hive_db + config de uploads.
├── .env                         # Credenciales de DB y APP_BASE_PATH (fuera de git).
├── .env.example                 # Plantilla de .env.
├── .htaccess                    # Router + bloquea acceso directo a .sql/.log/.env.
├── schema.sql                   # Esquema MySQL de hive_db.
├── migrations/                  # Cambios incrementales al esquema.
└── uploads/                     # Imágenes subidas desde ResourceM (fuera de git salvo .gitkeep).

tools/                          # Utilidades Node contra el backend PHP en vivo.
├── php-backend-test.js          # Suite de integración end-to-end (crea y limpia sus datos).
├── php-backend-test-org.js      # Suite de integración de la estructura organizacional.
└── reset-database.js            # Vacía las tablas y reinicia AUTO_INCREMENT (destructivo).

assets/
└── logo/logo.png               # Logo fuente usado para generar el ícono de la app.

lib/
├── main.dart                   # Entry point. MyApp único: lee el accessToken guardado para
│                                # decidir la ruta inicial (BottomNavBar vs SignUp), aplica
│                                # AppTheme.dark y define el mapa de rutas con nombre.
│
├── design/                     # Sistema de diseño (tokens, tema, componentes base).
│                                 # Ver la sección "Sistema de diseño" arriba.
│
├── utils/
│   ├── api_config.dart         # kBaseUrl: única fuente de la IP/dominio del backend.
│   ├── session.dart             # Session.fetchCurrentUser()/getCachedRole(): perfil y rol
│   │                             # organizacional (GET /user/me), cacheado tras el login.
│   └── Routes.dart              # Nombres de ruta (MyRoutes.*) usados con Navigator.pushNamed.
│
├── models/
│   ├── storeToken.dart          # SecureStorage: guarda/lee el accessToken cifrado en disco.
│   ├── models.dart               # AppRole, DepartmentInfo, UserProfile (estructura organizacional).
│   ├── join_model.dart            # Modelo de respuesta de join_team.dart.
│   └── appbar.dart                # AppBar superior con avatar, saludo, nombre de usuario y
│                                   # campana de notificaciones con badge de no leídas.
│
├── screens/                     # Pantallas de autenticación y flujos de equipo/tarea.
│   ├── login.dart                # Login (migrada al sistema de diseño).
│   ├── signup.dart                # Registro.
│   ├── forgot password/           # Recuperación de contraseña (correo → OTP → nueva clave).
│   ├── join_team.dart              # Unirse a un equipo con un código.
│   ├── dashboard.dart               # Lista de equipos del usuario (dashb_mem).
│   ├── teamDetail.dart               # Detalle de un equipo: áreas, miembros, tareas y acciones
│   │                                  # (migrada).
│   ├── addTask.dart                   # Asignar tarea nueva (dropdowns de área/miembro).
│   ├── notifications.dart              # Bandeja de notificaciones; marcar como leída al tocar.
│   ├── MarkTaskDone.dart                # Pantalla legacy de completar tarea a mano (ya no
│   │                                     enlazada desde la UI).
│   ├── chat.dart / chatHistory.dart      # Chat del equipo con historial.
│   ├── LResign.dart / MResign.dart        # Renuncia del líder / de un miembro.
│   └── recaptcha.dart                      # Import muerto en signup.dart; sin flujo real (stub).
│
├── create&join-Team/
│   ├── create-team.dart          # Crear equipo + seleccionar áreas (multi-select).
│   └── Domain-team.dart           # Invitar miembros por correo a cada área tras crear el equipo.
│
├── home_page/                    # Contenido de la BottomNavBar una vez logueado.
│   ├── bottomnavbar.dart           # Barra inferior: Progreso / Tablero / Inicio / Perfil
│   │                                 (migrada; hereda navigationBarTheme, sin colores propios).
│   ├── home_page_home.dart          # Pestaña "Inicio": alterna entre Tareas y Equipos.
│   ├── tasks.dart                     # Resumen de tareas pendientes/completadas (migrada).
│   ├── teams.dart                      # Lista de equipos del usuario dentro de "Inicio" (migrada).
│   ├── progress.dart                    # Gráfico de progreso (fl_chart).
│   └── profile.dart                      # Perfil de usuario (migrada, texto en español).
│
├── leave approval/
│   └── leave.dart               # Solicitar permiso (leave) y ver el resultado del líder.
│
└── ResourceM/                    # Recursos compartidos del equipo (documentos, imágenes, texto).
    ├── Resources.dart              # Pantalla contenedora de recursos del equipo.
    ├── doc.dart / getR.dart / fetchR.dart / imagecc.dart  # Publicar/leer recursos e imágenes.
    └── Leaderassist.dart            # Mensaje directo del miembro al líder.
```

> Nota: `lib/assets/` contiene las imágenes usadas dentro de las pantallas (ilustraciones, íconos propios). `assets/logo/` es solo el logo fuente para generar el ícono de la app — son carpetas con propósitos distintos y ambas están declaradas en `pubspec.yaml → flutter → assets`.

## Flujo de la aplicación

### 1. Arranque y sesión

`main.dart` revisa si hay un `accessToken` guardado en `flutter_secure_storage` y se lo pasa a `MyApp(hasSession: ...)`, que decide la ruta inicial `/`:
- **Sin token** → `SignUp`.
- **Con token** → `BottomNavBar` (entra directo a la app).

### 2. Autenticación

`Signup` → `Login` → (`forgot password/*` si olvida la clave). Al loguear con éxito el backend genera un token nuevo, lo guarda en `users.token` y lo devuelve; la app lo persiste cifrado y lo manda **crudo** (sin `Bearer `) en el header `Authorization` de cada llamada autenticada.

### 3. Equipos

- **Crear equipo** (`create-team.dart`): nombre + selección múltiple de áreas → `POST /team/createTeam` → pantalla de invitar miembros por área (`Domain-team.dart`).
- **Unirse a equipo** (`join_team.dart`): se ingresa un código de equipo → `POST /team/joinTeam`.
- **Ver equipos** (`dashboard.dart` / pestaña "Equipos" en Inicio): lista los equipos del usuario, cada uno navega a `teamDetail.dart`.
- **Detalle de equipo** (`teamDetail.dart`): tarjeta por cada área con sus miembros (chips) y sus tareas (pendientes/completadas), resumen de avance, y acciones según el rol:
  - **Miembro**: Salir del equipo, Renunciar (a esa área), Chat, Recursos.
  - **Líder**: Agregar tarea, Chat, Recursos, Gestionar miembros (quitar un miembro o transferir el liderazgo) y **Eliminar equipo** (`POST /team/deleteTeam/:teamId`, borra en transacción tareas, áreas, miembros, recursos, permisos y los archivos subidos).
- **Renuncia** (`LResign.dart` líder / `MResign.dart` miembro): remover miembro o transferir liderazgo.

### 4. Tareas — asignación y completado

- **Asignar** (`addTask.dart`): el líder elige el **área** y luego el **miembro** con dos dropdowns encadenados, más descripción y fecha límite → `POST /team/task/:teamcode`.
- **Completar** (dentro de `teamDetail.dart`): cada tarjeta de área tiene un botón **"Completar tarea"** (solo visible para el líder y solo si hay tareas pendientes en esa área). Al tocarlo se abre la lista de tareas pendientes *de esa área*; se elige una y se marca como hecha al instante (`POST /team/taskDone`).
- **Resumen global** (pestaña "Inicio" → Tareas, `home_page/tasks.dart`): lista de solo lectura de tareas pendientes/completadas de todos los equipos del usuario, con un diálogo de detalle al tocar cada una.

### 5. Chat, permisos y recursos

- **Chat** (`chat.dart` + `chatHistory.dart`): mensajería con historial. Requiere token; el autor del mensaje se toma **del token, nunca del body**, para que nadie pueda publicar suplantando a otro.
- **Permisos** (`leave approval/leave.dart`): un miembro del equipo solicita un permiso (fecha inicio/fin + motivo) con `applyLeave`, que lo guarda en estado `pending`; después `leaveResult/:leaveId` lo pasa a `submitted`. Solo el solicitante o el líder pueden tocar esa solicitud.
- **Recursos** (`ResourceM/*`): documentación, imágenes y texto compartidos por equipo; también hay un canal directo de asistencia al líder (`Leaderassist.dart`).

### 6. Notificaciones in-app

La campana del `MyAppBar` consulta `GET /notifications` y muestra un badge rojo con la cantidad de no leídas. `screens/notifications.dart` lista las últimas 100 y marca cada una como leída al tocarla (`POST /notifications/:id/read`). El backend las emite en tres situaciones:

| `type`            | Cuándo se emite                         | A quién                   |
|-------------------|------------------------------------------|----------------------------|
| `member_removed`  | El líder quita a un miembro del equipo   | Al miembro removido        |
| `leader_assigned` | Se transfiere el liderazgo               | Al nuevo líder             |
| `team_deleted`    | El líder elimina el equipo               | A todos los demás miembros |

### Paleta y diseño

Ver [Sistema de diseño](#sistema-de-diseño) arriba y [`Rediseno-Frontend.md`](Rediseno-Frontend.md) para el detalle completo (tokens, regla de contraste, qué pantallas faltan migrar).

## Backend PHP (`hive-backend`)

Vive en [`hive-backend/`](hive-backend/), dentro de este repo. Localmente, `C:\xampp\htdocs\hive-backend` es una junction que apunta a esta carpeta, así que Apache lo sirve igual que antes. Son cuatro archivos:

- **`config.php`** — carga `.env` (host/usuario/clave de DB y `APP_BASE_PATH`), conexión PDO a `hive_db` (`ERRMODE_EXCEPTION`, `FETCH_ASSOC`) y constantes de subida (`UPLOAD_DIR`, `UPLOAD_URL_BASE`).
- **`helpers.php`** — utilidades compartidas: respuestas (`json_response`, `raw_json_response`, `text_response`, `error_response`), generación de ids/tokens/códigos/OTP, `request_body()`, y toda la capa de autorización.
- **`index.php`** — tabla de rutas (método + regex + handler) y los handlers.
- **`schema.sql`** — el esquema de `hive_db`.

### Autenticación y autorización

- `require_auth($pdo)` resuelve el usuario a partir del header `Authorization` (acepta el token crudo o con prefijo `Bearer`) contra `users.token`; responde `401` si falta o no existe.
- `require_team_member()` / `require_team_leader()` se aplican en cada endpoint con `:teamId`. Como el esquema referencia personas **por correo**, la comprobación se hace sobre `teams.leader_email` y `team_members.email`. Un usuario que no pertenece al equipo recibe `403`.
- Los endpoints de tareas resuelven primero el equipo con `team_from_code()`, porque `tasks` se guarda contra `team_code` y no contra `team_id`.

### Detalles de compatibilidad con el frontend

- **Login** responde el token como **string JSON puro** (`"a1b2c3..."`), no como `{ "token": "..." }` — así es como `login.dart` hace `jsonDecode(response.body)` directo.
- Los ids de `users`, `teams` y `leaves` son `CHAR(24)` hex generados por `generate_id()`, imitando el `ObjectId` de Mongo del backend original; parte del código Dart asume esa forma.
- Varias pantallas mandan el body como `application/x-www-form-urlencoded` y otras como `application/json`; `request_body()` acepta ambos e incluso adivina el formato si falta el header.
- Los parámetros de ruta se pasan por `urldecode`, para que un correo (`a%40b.com`) o un área con espacio (`Machine%20Learning`) coincidan con lo guardado en la base.
- `/googleOAuth` es un stub (`501`): el botón de Google del signup no completa ningún flujo real todavía.

> ⚠️ PHP está configurado en `Europe/Berlin` mientras MySQL corre en la hora del sistema: nunca compares un `time()` de PHP contra un timestamp generado por MySQL — haz las comparaciones de fecha dentro del SQL.

## Esquema de base de datos (`hive_db`)

Cargar con:

```bash
mysql -u root -p < C:\xampp\htdocs\hive-backend\schema.sql
```

| Tabla             | Para qué sirve                                                                | Usada por (pantalla) |
|-------------------|--------------------------------------------------------------------------------|-----------------------|
| `users`           | Cuenta (id CHAR(24), nombre, correo único, hash bcrypt, `token` de sesión, OTP). | `signup.dart`, `login.dart`, `appbar.dart`, `forgot password/*` |
| `teams`           | Equipo: `team_name`, `team_code` único, `leader_email`.                         | `create-team.dart`, `dashboard.dart`, `join_team.dart` |
| `team_members`    | Pertenencia a nivel de equipo (`UNIQUE(team_id, email)`).                        | `join_team.dart`, `teamDetail.dart` |
| `domains`         | Área/departamento dentro de un equipo (FK a `teams`, `ON DELETE CASCADE`).       | `create-team.dart`, `teamDetail.dart` |
| `domain_members`  | Correos asignados a cada área (FK a `domains`).                                  | Lista de miembros y dropdown de `addTask.dart` |
| `tasks`           | Tarea por `team_code` + `domain_name` + `email`, con `completed` y `deadline`.   | `addTask.dart`, `teamDetail.dart`, `home_page/tasks.dart` |
| `leaves`          | Solicitud de permiso con `status` (pending/approved/rejected).                   | `leave approval/leave.dart` |
| `chat_messages`   | Mensajes de chat (`team_id` nullable, `username`, `message`).                    | `chat.dart`, `chatHistory.dart` |
| `images`          | Imágenes compartidas del equipo (`img_path` apunta a `uploads/`).                | `ResourceM/getR.dart`, `fetchR.dart`, `imagecc.dart` |
| `texts`           | Documentación/texto compartido del equipo.                                       | `ResourceM/doc.dart`, `getR.dart` |
| `leader_messages` | Mensaje directo de un miembro al líder.                                          | `ResourceM/Leaderassist.dart`, `screens/MResign.dart` |
| `notifications`   | Notificaciones in-app por correo, con `type`, `message` y `read_at`.             | `models/appbar.dart`, `screens/notifications.dart` |

### Relaciones

```
teams 1───N domains ───N domain_members       (FK con ON DELETE CASCADE)
teams 1───N team_members
teams 1───N leaves / texts / images / leader_messages
teams ─── team_code ───N tasks                 (relación por código, sin FK)
users ─── email ─── (leader_email, *.email)    (todo se referencia por correo, no por id)
notifications ─── email                        (team_id nullable: queda NULL si el equipo se borra)
```

> Este modelo relaciona por **correo**, no por claves foráneas a `users.id`. Es deliberado: replica la forma del JSON que el cliente Flutter ya esperaba del backend original en Mongo, y evita tener que tocar el código Dart.

## Endpoints

Todos bajo `http://<host>/hive-backend`. 🔒 = requiere header `Authorization`.

| Método | Ruta                                              | Auth | Pantalla que la llama |
|--------|----------------------------------------------------|:----:|------------------------|
| GET    | `/`                                                 |      | (health check) |
| POST   | `/user/signup`                                      |      | `signup.dart` |
| POST   | `/user/login`                                       |      | `login.dart` |
| GET    | `/user/sendName`                                    | 🔒   | `models/appbar.dart`, `home_page/profile.dart` |
| POST   | `/user/resetPassword`                               |      | `forgot password/forgot_pass.dart` |
| POST   | `/user/verifyOTP/:email`                            |      | `forgot password/otp_verify.dart` |
| POST   | `/user/newPassword/:email`                          |      | `forgot password/new_password.dart` |
| POST   | `/user/sendMessage/:teamId`                         | 🔒   | `ResourceM/Leaderassist.dart`, `screens/MResign.dart` |
| GET    | `/googleOAuth`                                      |      | `signup.dart` (stub `501`) |
| POST   | `/team/createTeam`                                  | 🔒   | `create-team.dart` |
| POST   | `/team/joinTeam`                                    | 🔒   | `join_team.dart` |
| GET    | `/team/showTeams`                                   | 🔒   | `dashboard.dart`, `home_page/teams.dart` |
| POST   | `/team/sendTeamcode/:teamId/:domainName`            | 🔒   | `Domain-team.dart` |
| POST   | `/team/task/:teamcode`                              | 🔒   | `addTask.dart` |
| POST   | `/team/taskDone`                                    | 🔒   | `teamDetail.dart` |
| GET    | `/team/incompleteTasks` · `/team/completedTasks`    | 🔒   | `home_page/tasks.dart` |
| POST   | `/team/deleteMember/:teamId`                        | 🔒 líder | `LResign.dart` (desde "Gestionar miembros") |
| POST   | `/team/leaderResign/:teamId`                        | 🔒 líder | `LResign.dart` (desde "Gestionar miembros") |
| POST   | `/team/deleteTeam/:teamId`                          | 🔒 líder | `teamDetail.dart` |
| GET    | `/chat/getAllChats` · POST `/chat/sendMessage`      | 🔒   | `chat.dart`, `chatHistory.dart` |
| POST   | `/image/addImage` · GET `/image/showImage/:teamId`  | 🔒   | `ResourceM/getR.dart`, `fetchR.dart`, `imagecc.dart` |
| POST   | `/text/addText/:teamId` · GET `/text/showText/:teamId` | 🔒 | `ResourceM/getR.dart`, `doc.dart` |
| POST   | `/leave/applyLeave/:teamId`                         | 🔒   | `leave approval/leave.dart` |
| POST   | `/leave/leaveResult/:leaveId`                       | 🔒 solicitante o líder | `leave approval/leave.dart` |
| GET    | `/notifications`                                    | 🔒   | `models/appbar.dart`, `screens/notifications.dart` |
| POST   | `/notifications/:id/read`                           | 🔒   | `screens/notifications.dart` |

## Herramientas y pruebas

Ambas requieren Apache y MySQL de XAMPP corriendo, y se ejecutan desde la raíz del repo. La primera vez, instala sus dependencias (`mysql2`):

```bash
cd tools && npm install && cd ..
```

**Suite de integración contra el backend en vivo** — recorre el flujo completo (signup → login → crear equipo → invitar → asignar tarea → completarla → chat → permiso → recursos → notificaciones) usando correos marcados (`zz_phpit_...@test.invalid`) que borra al terminar, así que no ensucia los datos reales:

```bash
node tools/php-backend-test.js
```

**Reset de la base** — vacía todas las tablas y reinicia los `AUTO_INCREMENT`, dejando el esquema intacto. Es destructivo y exige `--yes`:

```bash
node tools/reset-database.js --yes
```

Pruebas de widget de Flutter:

```bash
flutter test
```

## Cómo correr el proyecto (guía paso a paso)

Esta guía asume que nunca instalaste este proyecto antes. Andá paso por paso, sin saltarte ninguno — cada uno depende del anterior. Si algo no coincide exactamente con lo que ves en tu pantalla, no sigas adivinando: preguntá en el grupo del equipo antes de continuar.

Vas a necesitar instalar, en este orden:

1. **[Git](https://git-scm.com/downloads)** — para descargar el código del proyecto.
2. **[XAMPP](https://www.apachefriends.org/es/download.html)** — un programa que simula, en tu propia computadora, el servidor donde vive el backend (la parte PHP) y la base de datos (MySQL). Instalalo en la ubicación por defecto (`C:\xampp`).
3. **[Flutter](https://docs.flutter.dev/get-started/install)** — el kit con el que está hecha la app. Seguí la guía oficial para Windows; al final corré `flutter doctor` en una terminal y resolvé cualquier cosa marcada en rojo antes de seguir.
4. Un editor de código — **[Android Studio](https://developer.android.com/studio)** o **[VS Code](https://code.visualstudio.com/)** funcionan bien. Si vas a probar en un celular Android o en un emulador, necesitás Android Studio igual, aunque después edites el código en VS Code.

Una vez instalado todo eso:

### 1. Descargar el proyecto

Abrí una terminal (en Windows, buscá "Git Bash" o "PowerShell") y corré:

```bash
cd C:\xampp\htdocs
git clone https://github.com/jeremyallen18/App-radio.git
```

Esto crea la carpeta `C:\xampp\htdocs\App-radio` con todo el código.

### 2. Conectar el backend con XAMPP

El backend (la carpeta `hive-backend/`) vive *dentro* del proyecto que acabás de descargar, pero XAMPP necesita encontrarlo en `C:\xampp\htdocs\hive-backend` (un nivel más arriba) para poder servirlo. Para lograr eso sin duplicar archivos, se crea un **acceso directo especial de Windows** (se llama "junction") que hace que esas dos ubicaciones apunten a la misma carpeta real.

Abrí **PowerShell** (no hace falta ser administrador) y pegá esto tal cual:

```powershell
New-Item -ItemType Junction -Path "C:\xampp\htdocs\hive-backend" -Target "C:\xampp\htdocs\App-radio\hive-backend"
```

Si no da ningún error, funcionó. No hace falta entender exactamente qué hace el comando — solo ejecutarlo una vez, la primera vez que instalás el proyecto en tu computadora.

### 3. Configurar las claves de acceso a la base de datos

Dentro de la carpeta `hive-backend`, buscá el archivo `.env.example` y hacé una copia llamada `.env` (sin el `.example` al final). En Windows, lo más fácil es: click derecho sobre `.env.example` → Copiar, click derecho en la misma carpeta → Pegar, y renombrar la copia a `.env`.

Si estás usando la configuración estándar de XAMPP (usuario `root`, sin contraseña), no necesitás cambiar nada más adentro de ese archivo.

### 4. Prender Apache y MySQL

Abrí el **Panel de Control de XAMPP** y hacé clic en **Start** al lado de **Apache** y de **MySQL**. Ambos deberían quedar en verde. Si alguno no arranca, generalmente es porque otro programa (como Skype) está usando el mismo puerto — cerrá ese programa y probá de nuevo.

### 5. Crear la base de datos

Con MySQL ya prendido, abrí una terminal y corré (te va a pedir la contraseña de MySQL; si nunca la cambiaste, apretá Enter sin escribir nada):

```bash
mysql -u root -p < C:\xampp\htdocs\hive-backend\schema.sql
```

Esto crea todas las tablas que la app necesita. Solo hay que hacerlo una vez.

### 6. Decirle a la app dónde está tu backend

Como cada persona del equipo corre su propio backend en su propia computadora, la app necesita saber la dirección de red (IP) de *tu* máquina.

Para encontrarla en Windows, abrí una terminal y corré:

```bash
ipconfig
```

Buscá la línea que dice **"Dirección IPv4"** (algo como `192.168.1.25`) dentro de tu red Wi-Fi o Ethernet — esa es tu IP.

Abrí el archivo [`lib/utils/api_config.dart`](lib/utils/api_config.dart) y reemplazá la IP que ya está por la tuya, dejando el resto igual:

```dart
const String kBaseUrl = 'http://TU_IP_AQUI/hive-backend';
```

> ⚠️ Si vas a probar la app en un **celular físico**, tu celular y tu computadora tienen que estar conectados a la **misma red Wi-Fi**. Si solo vas a usar un emulador o la versión de escritorio, con seguir estos pasos alcanza.

### 7. Instalar las dependencias de Flutter y correr la app

Ya en la carpeta del proyecto (`C:\xampp\htdocs\App-radio`):

```bash
flutter pub get
flutter run
```

`flutter pub get` descarga todas las librerías que usa el proyecto (solo hace falta cuando cambian, no cada vez). `flutter run` te va a preguntar en qué dispositivo abrir la app (un emulador, tu celular conectado por USB, o Windows/Chrome) — elegí uno y esperá a que compile. La primera vez puede tardar varios minutos.

Si todo salió bien, deberías ver la pantalla de inicio de sesión de la app.

### Problemas comunes

- **La app no carga nada / se queda cargando para siempre**: revisá que Apache y MySQL sigan en verde en XAMPP, y que la IP en `api_config.dart` sea la correcta (las IPs pueden cambiar si te reconectás al Wi-Fi).
- **"No se pudo crear la junction" en el paso 2**: puede que ya exista una carpeta `C:\xampp\htdocs\hive-backend` de una instalación anterior — borrala primero (asegurate de que esté vacía o que no tenga nada importante) y volvé a correr el comando.
- **`flutter doctor` marca cosas en rojo**: no sigas hasta resolverlas; casi siempre son instrucciones claras (aceptar licencias de Android, instalar un componente que falta, etc.).
- Si te trabás en cualquier paso, avisá en el grupo del equipo con el mensaje de error exacto — no hace falta que lo resuelvas solo.

### Regenerar los íconos de la app

Esto solo lo necesitás si cambiaste el logo (`assets/logo/logo.png`):

```bash
dart run flutter_launcher_icons
```

## Código de conducta y contribución

Ver [Code of Conduct](CODE_OF_CONDUCT.md), [contribution guidelines](CONTRIBUTING.md) y [Security Policy](SECURITY.md). Este proyecto está bajo licencia [MIT](LICENSE).
