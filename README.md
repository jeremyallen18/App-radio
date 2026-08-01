# Team Management App

Aplicación Flutter para gestionar equipos de trabajo: creación y unión a equipos por código, asignación de tareas por área, seguimiento de progreso, chat interno, solicitudes de permiso (leave) y recursos compartidos por equipo. Todo el texto de la interfaz está en español.

## Tabla de contenidos

- [Stack técnico](#stack-técnico)
- [Configuración del backend](#configuración-del-backend)
- [Ícono de la app](#ícono-de-la-app)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Flujo de la aplicación](#flujo-de-la-aplicación)
- [Esquema de base de datos](#esquema-de-base-de-datos)
- [Backend (Node + MySQL)](#backend-node--mysql)
- [Cómo correr el proyecto](#cómo-correr-el-proyecto)

## Stack técnico

- **Flutter / Dart** (Material 3, `colorSchemeSeed: Colors.blue` como paleta global).
- **http** para llamadas REST contra el backend (`hive-backend`).
- **flutter_secure_storage** para persistir el token de sesión (`accessToken`).
- **multi_select_flutter**, **table_calendar**, **fl_chart**, **image_picker**, **socket_io_client**, **audioplayers**, **cached_network_image**, **dio** como dependencias de features puntuales.
- **flutter_launcher_icons** para generar el ícono de la app en todas las plataformas a partir de un único archivo fuente.

## Configuración del backend

Toda la app apunta a un único backend a través de una variable central:

```
lib/utils/api_config.dart
```

```dart
const String kBaseUrl = 'http://192.168.100.250/hive-backend';
```

Para apuntar la app a otro servidor/IP/dominio, **solo hay que cambiar esta línea** — el resto del código arma cada endpoint como `'$kBaseUrl/user/login'`, `'$kBaseUrl/team/createTeam'`, etc.

## Ícono de la app

El logo fuente vive en `assets/logo/logo.png` (no en `lib/assets/`, que es la carpeta de imágenes usadas dentro de las pantallas). Los íconos nativos de cada plataforma (Android `mipmap`/adaptive icon, iOS `AppIcon.appiconset`, Windows `.ico`, macOS `.icns`) se generan a partir de ese archivo con:

```bash
dart run flutter_launcher_icons
```

La configuración vive al final de `pubspec.yaml`, bajo la clave `flutter_launcher_icons:`. Si cambias el logo, reemplaza `assets/logo/logo.png` y vuelve a correr ese comando para regenerar los íconos en todas las plataformas.

## Estructura del proyecto

```
backend/                       # Backend propio en Node/Express + MySQL (reemplaza al
│                               # hive-backend original en Mongo). Ver sección "Backend" abajo.
├── package.json
├── .env.example
└── src/
    ├── index.js                 # Monta todas las rutas bajo BASE_PATH (=/hive-backend).
    ├── db.js                    # Pool de conexión MySQL (mysql2/promise).
    ├── middleware/auth.js        # Verifica el token crudo del header Authorization.
    ├── utils/token.js             # Firma/verifica el JWT de sesión.
    └── routes/
        ├── auth.routes.js          # /user/* (signup, login, sendName, reset/verify/new
        │                            # password, sendMessage al líder).
        ├── teams.routes.js          # /team/* (crear/unirse/listar equipos, tareas,
        │                            # invitar por área, eliminar miembro, cambiar líder).
        ├── leave.routes.js           # /leave/* (solicitar permiso).
        ├── chat.routes.js             # /chat/* (mensajería global, sin scope de equipo).
        └── resources.routes.js         # /image/* y /text/* (recursos compartidos).

database/
└── schema.sql                 # Esquema MySQL (tablas, relaciones, índices) que usa backend/.
                                # Ver la sección "Esquema de base de datos" más abajo.

assets/
└── logo/
    └── logo.png                # Logo fuente usado para generar el ícono de la app.

lib/
├── main.dart                  # Entry point. Decide MyApp (sin sesión) vs MyApp2 (con sesión)
│                               # según haya un accessToken guardado. Define el theme global
│                               # (Material 3, seed azul) y el mapa de rutas con nombre.
│
├── utils/
│   ├── api_config.dart        # kBaseUrl: única fuente de la IP/dominio del backend.
│   ├── colors.dart             # Paleta azul compartida (AppColors) usada por login y demás.
│   └── Routes.dart             # Nombres de ruta (MyRoutes.*) usados con Navigator.pushNamed.
│
├── widgets/
│   ├── custom_text_form_field.dart  # Input de texto reutilizable con estilo oscuro/azul.
│   └── gradient_button.dart         # Botón "pill" con gradiente, usado en el login.
│
├── models/
│   ├── storeToken.dart          # SecureStorage: guarda/lee el accessToken cifrado en disco.
│   └── appbar.dart              # AppBar superior con avatar, saludo y nombre de usuario.
│
├── screens/                     # Pantallas de autenticación y flujos de equipo/tarea.
│   ├── login.dart                # Login (rediseñado, tema oscuro).
│   ├── signup.dart                # Registro.
│   ├── forgot password/           # Recuperación de contraseña (correo → OTP → nueva clave).
│   ├── join_team.dart              # Unirse a un equipo con un código.
│   ├── dashboard.dart               # Lista de equipos del usuario (dashb_mem).
│   ├── teamDetail.dart               # Detalle de un equipo: áreas, miembros, tareas y acciones.
│   ├── addTask.dart                   # Asignar tarea nueva (dropdowns de área/miembro).
│   ├── MarkTaskDone.dart                # Pantalla legacy de completar tarea a mano (ya no
│   │                                     enlazada desde la UI; ver sección de tareas más abajo).
│   ├── chat.dart / chatHistory.dart      # Chat en tiempo real por equipo.
│   ├── LResign.dart / MResign.dart        # Renuncia del líder / de un miembro.
│   └── recaptcha.dart, homescreen.dart     # No usados actualmente por ninguna ruta.
│
├── create&join-Team/
│   ├── create-team.dart          # Crear equipo + seleccionar áreas (multi-select).
│   └── Domain-team.dart           # Invitar miembros por correo a cada área tras crear el equipo.
│
├── home_page/                    # Contenido de la BottomNavBar una vez logueado.
│   ├── bottomnavbar.dart           # Barra inferior: Progreso / Tablero / Inicio / Perfil.
│   ├── home_page_home.dart          # Pestaña "Inicio": alterna entre Tareas y Equipos.
│   ├── tasks.dart                     # Resumen de tareas pendientes/completadas del usuario.
│   ├── teams.dart                      # Lista de equipos del usuario dentro de "Inicio".
│   ├── progress.dart                    # Gráfico de progreso (fl_chart).
│   └── profile.dart / todo.dart           # Perfil de usuario / lista de tareas legacy sin uso.
│
├── leave approval/
│   └── leave.dart               # Solicitar permiso (leave) y ver el resultado del líder.
│
├── ResourceM/                    # Recursos compartidos del equipo (documentos, imágenes, texto).
│   ├── Resources.dart              # Pantalla contenedora de recursos del equipo.
│   ├── doc.dart / getR.dart / fetchR.dart / imagecc.dart  # Publicar/leer recursos e imágenes.
│   └── Leaderassist.dart            # Mensaje directo del miembro al líder.
│
└── music/
    └── music.dart                # "Zona Zen": módulo de reproducción de audio. No está
                                    enlazado a ninguna ruta ni pantalla actualmente (código
                                    huérfano, se deja tal cual por si se retoma más adelante).
```

> Nota: `lib/assets/` contiene las imágenes usadas dentro de las pantallas (ilustraciones, íconos propios). `assets/logo/` es solo el logo fuente para generar el ícono de la app — son carpetas con propósitos distintos y ambas están declaradas en `pubspec.yaml → flutter → assets`.

## Flujo de la aplicación

### 1. Arranque y sesión

`main.dart` revisa si hay un `accessToken` guardado en `flutter_secure_storage`:
- **Sin token** → `MyApp`, ruta inicial `/` = `SignUp`.
- **Con token** → `MyApp2`, ruta inicial `/` = `BottomNavBar` (entra directo a la app).

### 2. Autenticación

`Signup` → `Login` → (`forgot password/*` si olvida la clave). Al loguear con éxito, el backend devuelve un token que se guarda cifrado y se navega a `BottomNavBar`.

### 3. Equipos

- **Crear equipo** (`create-team.dart`): nombre + selección múltiple de áreas → `POST /team/createTeam` → pantalla de invitar miembros por área (`Domain-team.dart`).
- **Unirse a equipo** (`join_team.dart`): se ingresa un código de equipo → `POST /team/joinTeam`.
- **Ver equipos** (`dashboard.dart` / pestaña "Equipos" en Inicio): lista los equipos del usuario, cada uno navega a `teamDetail.dart`.
- **Detalle de equipo** (`teamDetail.dart`): tarjeta por cada área con sus miembros (chips) y sus tareas (pendientes/completadas), resumen de avance, y acciones según el rol:
  - **Miembro**: Salir del equipo, Renunciar (a esa área), Chat, Recursos.
  - **Líder**: Agregar tarea, Chat, Recursos, Gestionar miembros (quitar un miembro o transferir el liderazgo — no borra el equipo).
- **Renuncia** (`LResign.dart` líder / `MResign.dart` miembro): remover miembro o transferir liderazgo.

### 4. Tareas — asignación y completado

- **Asignar** (`addTask.dart`): el líder elige el **área** y luego el **miembro** con dos dropdowns encadenados (ya no se escriben a mano), más descripción y fecha límite → `POST /team/task/:teamcode`.
- **Completar** (dentro de `teamDetail.dart`): cada tarjeta de área tiene un botón **"Completar tarea"** (solo visible para el líder y solo si hay tareas pendientes en esa área). Al tocarlo se abre una lista con las tareas pendientes *de esa área*; se elige una y se marca como hecha al instante (`POST /team/taskDone`), sin tener que re-escribir equipo/área/correo/tarea a mano.
- **Resumen global** (pestaña "Inicio" → Tareas, `home_page/tasks.dart`): lista de solo lectura de tareas pendientes/completadas de todos los equipos del usuario, con un diálogo de detalle al tocar cada una.

### 5. Chat, permisos y recursos

- **Chat** (`chat.dart` + `chatHistory.dart`): mensajería dentro del equipo, con historial.
- **Permisos** (`leave approval/leave.dart`): un miembro solicita un permiso (fecha inicio/fin + motivo) y el líder ve el resultado.
- **Recursos** (`ResourceM/*`): documentación, imágenes y texto compartidos por equipo; también hay un canal directo de asistencia al líder (`Leaderassist.dart`).

### Paleta y diseño

Toda la app usa una paleta azul/índigo (`Colors.indigo`, `AppColors` en `lib/utils/colors.dart`, tema global azul en `main.dart`). No quedan referencias a morado en el código. La pestaña de "Análisis" (gráficos ML sobre el chat) fue eliminada junto con el módulo `ml/` que la sostenía.

## Esquema de base de datos

> **Historial:** el `hive-backend` original (no incluido en este repo) usaba **MongoDB** — se notaba en el propio JSON que consume el frontend (`_id`, `createdAt`/`updatedAt` estilo Mongoose, `domains` embebidos con `members`/`tasks` anidados). Ese backend fue **reemplazado por completo** por el que vive en [`backend/`](backend/), que usa MySQL de punta a punta. La app Flutter no necesitó ningún cambio: el nuevo backend responde con la misma forma de JSON (incluido el `_id` como *nombre de campo*, aunque ahora sea un id autoincremental de MySQL, no un ObjectId de Mongo).

El archivo [`database/schema.sql`](database/schema.sql) es el esquema que usa ese backend en producción — no es un diseño hipotético, se probó de punta a punta (signup → login → crear equipo → invitar miembro → asignar tarea → completarla → chat → permiso → recursos) contra una instancia real de MySQL antes de darlo por terminado. Los nombres de columna siguen los mismos campos que ya viajan en los JSON de las llamadas (`email`, `teamCode`, `domainName`, `assignedTo`, `deadline`, `startDate`/`endDate`/`reason`, etc.).

### De documentos anidados (Mongo) a tablas con FK (MySQL)

| Antes (Mongo, documento embebido)                          | Ahora (MySQL, tabla con FK)                     |
|-----------------------------------------------------------|------------------------------------------------------|
| Colección `teams` (documento con `_id`, `createdAt`, `updatedAt`) | Tabla `teams` (`id`, `created_at`, `updated_at`) |
| `team.domains[]` (array embebido)                          | Tabla `domains` con `team_id` (FK)                    |
| `team.domains[].members[]` (array de strings embebido)     | Tablas `team_members` (nivel equipo) + `domain_members` (nivel área) |
| `team.domains[].tasks[]` (array embebido)                   | Tabla `tasks` con `domain_id` + `team_id` (FK)        |
| `team.leaderEmail` (string suelto)                          | `teams.leader_id` → FK a `users.id`                   |

### Tablas

| Tabla                  | Para qué sirve                                                                 | Usada por (pantalla / endpoint) |
|-------------------------|--------------------------------------------------------------------------------|----------------------------------|
| `users`                 | Cuenta de usuario (nombre, correo único, password hasheado, foto).             | `signup.dart`, `login.dart`, `appbar.dart` |
| `password_reset_otps`   | OTP de un solo uso para recuperar contraseña.                                   | `forgot_pass.dart` → `otp_verify.dart` → `new_password.dart` |
| `teams`                 | Equipo: nombre, `team_code` único, líder.                                       | `create-team.dart`, `dashboard.dart`, `join_team.dart` |
| `team_members`          | Pertenencia a nivel de equipo (unirse por código, sin área todavía).           | `join_team.dart` |
| `domains`               | Área/departamento dentro de un equipo (Backend, Frontend, etc.).                | `create-team.dart` (multi-select), `teamDetail.dart` |
| `domain_members`        | Relación N:M usuario ↔ área (implica también `team_members`).                   | Lista de "Miembros" y dropdown de `addTask.dart` |
| `tasks`                 | Tarea asignada a un miembro de un área, con `completed` y `deadline`.           | `addTask.dart` (crear), `teamDetail.dart` (completar), `home_page/tasks.dart` (resumen) |
| `leave_requests`        | Solicitud de permiso con `status` (pending/approved/rejected).                 | `leave approval/leave.dart` |
| `chat_messages`         | Mensajería **global**, sin scope de equipo (así la llama el frontend hoy).      | `chat.dart`, `chatHistory.dart` |
| `leader_messages`       | Mensaje directo de un miembro al líder.                                         | `ResourceM/Leaderassist.dart`, `screens/MResign.dart` |
| `resource_texts`        | Documentación/texto compartido del equipo.                                      | `ResourceM/doc.dart`, `getR.dart` |
| `resource_images`       | Imágenes compartidas del equipo.                                                | `ResourceM/getR.dart`, `fetchR.dart`, `imagecc.dart` |

### Relaciones principales

```
users 1───N teams                (leader_id)
teams 1───N team_members ── N users      (unirse por código, sin área)
teams 1───N domains
domains 1───N domain_members ── N users   (miembros por área)
domains 1───N tasks ── N users             (assigned_to)
teams 1───N leave_requests ── N users
teams 1───N resource_texts / resource_images ── N users
chat_messages                              (global, sin FK a teams)
```

### Cómo cargarlo

```bash
mysql -u root -p < database/schema.sql
```

Esto crea la base `team_management` (utf8mb4, InnoDB con foreign keys) y todas las tablas listas para conectar el backend. El archivo incluye al final, comentado, un `INSERT` de ejemplo para poblar un equipo de prueba.

## Backend (Node + MySQL)

El backend que da servicio a la app vive en [`backend/`](backend/): Node.js + Express + `mysql2`, con JWT para sesión, `bcryptjs` para contraseñas y `multer` para subir imágenes. Implementa **todos** los endpoints que el frontend ya llama (auth, equipos, tareas, permisos, chat y recursos), con las mismas rutas y la misma forma de JSON que espera cada pantalla — no hubo que tocar el código Dart.

### Levantarlo

```bash
cd backend
npm install
cp .env.example .env      # y edita DB_USER/DB_PASSWORD/JWT_SECRET
mysql -u root -p < ../database/schema.sql   # si no lo cargaste todavía
npm start
```

Por defecto sirve en `http://localhost:<PORT>${BASE_PATH}` (`BASE_PATH=/hive-backend` por defecto, igual que espera `kBaseUrl`). Para que la app apunte a esta instancia, actualiza [`lib/utils/api_config.dart`](lib/utils/api_config.dart) con el host/puerto donde corra este servidor.

### Detalles importantes de compatibilidad con el frontend

- **Login** responde el token como **string JSON puro** (`"eyJhbGciOi..."`), no como `{ "token": "..." }` — así es como `login.dart` hace `jsonDecode(response.body)` directo.
- Todas las llamadas autenticadas mandan el token crudo en el header `Authorization` (sin `Bearer `), así que el middleware lo lee tal cual.
- Varias pantallas mandan el body como `application/x-www-form-urlencoded` (p. ej. `login.dart`, `signup.dart`, `addTask.dart`) y otras como `application/json` (p. ej. `create-team.dart`, `leave.dart`) — el servidor acepta ambos formatos.
- `chat/getAllChats` y `chat/sendMessage` no llevan token ni `teamId` porque así los llama hoy `chat.dart` (chat global, no por equipo) — ver la nota en `database/schema.sql`.
- `/googleOAuth` es un stub (`501`): el botón de Google en el signup no completa ningún flujo real en el frontend todavía.
- Los `INSERT ... ON DUPLICATE`/`INSERT IGNORE` en `team_members`/`domain_members` evitan errores si alguien invita dos veces al mismo correo.

### Endpoints implementados

| Método | Ruta (bajo `/hive-backend`)                     | Pantalla que la llama |
|--------|--------------------------------------------------|-------------------------|
| POST   | `/user/signup`                                    | `signup.dart` |
| POST   | `/user/login`                                     | `login.dart` |
| GET    | `/user/sendName`                                  | `models/appbar.dart`, `home_page/profile.dart` |
| POST   | `/user/resetPassword`                             | `forgot password/forgot_pass.dart` |
| POST   | `/user/verifyOTP/:email`                          | `forgot password/otp_verify.dart` |
| POST   | `/user/newPassword/:email`                        | `forgot password/new_password.dart` |
| POST   | `/user/sendMessage/:teamId`                       | `ResourceM/Leaderassist.dart`, `screens/MResign.dart` |
| GET    | `/googleOAuth`                                    | `signup.dart` (stub) |
| POST   | `/team/createTeam`                                | `create-team.dart` |
| POST   | `/team/joinTeam`                                  | `join_team.dart` |
| GET    | `/team/showTeams`                                 | `dashboard.dart` |
| POST   | `/team/sendTeamcode/:teamId/:domainName`          | `Domain-team.dart` |
| POST   | `/team/task/:teamcode`                            | `addTask.dart` |
| POST   | `/team/taskDone`                                  | `teamDetail.dart`, `MarkTaskDone.dart` |
| GET    | `/team/incompleteTasks` / `/team/completedTasks`  | `home_page/tasks.dart` |
| POST   | `/team/deleteMember/:teamId`                      | `LResign.dart` |
| POST   | `/team/leaderResign/:teamId`                      | `LResign.dart` |
| POST   | `/leave/applyLeave/:teamid`                       | `leave approval/leave.dart` |
| POST   | `/leave/leaveResult/:leaveId`                     | `leave approval/leave.dart` |
| GET    | `/chat/getAllChats` / POST `/chat/sendMessage`    | `chat.dart`, `chatHistory.dart` |
| POST   | `/image/addImage` / GET `/image/showImage/:teamId`| `ResourceM/getR.dart`, `fetchR.dart`, `imagecc.dart` |
| POST   | `/text/addText/:teamId` / GET `/text/showText/:teamId` | `ResourceM/getR.dart`, `doc.dart` |

## Cómo correr el proyecto

```bash
flutter pub get
flutter run
```

Para generar los íconos nativos tras cambiar el logo:

```bash
dart run flutter_launcher_icons
```

## Código de conducta y contribución

Ver [Code of Conduct](CODE_OF_CONDUCT.md), [contribution guidelines](CONTRIBUTING.md) y [Security Policy](SECURITY.md). Este proyecto está bajo licencia [MIT](LICENSE).
