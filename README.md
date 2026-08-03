# Team Management App

Aplicación Flutter para gestionar equipos de trabajo: creación y unión a equipos por código, asignación de tareas por área, seguimiento de progreso, chat interno, solicitudes de permiso (leave), recursos compartidos y notificaciones in-app. Todo el texto de la interfaz está en español.

## Tabla de contenidos

- [Arquitectura general](#arquitectura-general)
- [Stack técnico](#stack-técnico)
- [Configuración del backend](#configuración-del-backend)
- [Ícono de la app](#ícono-de-la-app)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Flujo de la aplicación](#flujo-de-la-aplicación)
- [Backend PHP (`hive-backend`)](#backend-php-hive-backend)
- [Esquema de base de datos (`hive_db`)](#esquema-de-base-de-datos-hive_db)
- [Endpoints](#endpoints)
- [Herramientas y pruebas](#herramientas-y-pruebas)
- [Backend Node (alternativo, no en uso)](#backend-node-alternativo-no-en-uso)
- [Cómo correr el proyecto](#cómo-correr-el-proyecto)

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

**El backend en producción es el PHP** que vive en `C:\xampp\htdocs\hive-backend` (fuera de este repo, servido por Apache de XAMPP sobre la base `hive_db`). Es el único que la app consume. La carpeta [`backend/`](backend/) de este repositorio es una reimplementación en Node/Express contra otra base (`team_management`) que **no está en uso** — ver la [sección correspondiente](#backend-node-alternativo-no-en-uso) antes de tocar nada ahí.

## Stack técnico

**Cliente**

- **Flutter / Dart** (Material 3, `colorSchemeSeed: Colors.blue` como paleta global).
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

## Ícono de la app

El logo fuente vive en `assets/logo/logo.png` (no en `lib/assets/`, que es la carpeta de imágenes usadas dentro de las pantallas). Los íconos nativos de cada plataforma (Android `mipmap`/adaptive icon, iOS `AppIcon.appiconset`, Windows `.ico`, macOS `.icns`) se generan a partir de ese archivo con:

```bash
dart run flutter_launcher_icons
```

La configuración vive al final de `pubspec.yaml`, bajo la clave `flutter_launcher_icons:`. Si cambias el logo, reemplaza `assets/logo/logo.png` y vuelve a correr ese comando para regenerar los íconos en todas las plataformas.

## Estructura del proyecto

```
C:\xampp\htdocs\hive-backend\   # ← BACKEND EN USO (fuera del repo, servido por Apache)
├── index.php                    # Router + todos los handlers (auth, equipos, tareas,
│                                 # chat, recursos, permisos, notificaciones).
├── helpers.php                  # Respuestas JSON/texto, parseo del body, require_auth,
│                                 # require_team_member / require_team_leader, notify_user.
├── config.php                   # Conexión PDO a hive_db + config de uploads.
├── schema.sql                   # Esquema MySQL de hive_db.
└── uploads/                     # Imágenes subidas desde ResourceM.

tools/                          # Utilidades Node contra el backend PHP en vivo.
├── php-backend-test.js          # Suite de integración end-to-end (crea y limpia sus datos).
└── reset-database.js            # Vacía las tablas y reinicia AUTO_INCREMENT (destructivo).

backend/                        # Reimplementación Node/Express — NO en uso. Ver sección abajo.
database/schema.sql             # Esquema de esa versión Node (base team_management).

assets/
└── logo/logo.png               # Logo fuente usado para generar el ícono de la app.

lib/
├── main.dart                   # Entry point. Decide MyApp (sin sesión) vs MyApp2 (con sesión)
│                                # según haya un accessToken guardado. Define el theme global
│                                # (Material 3, seed azul) y el mapa de rutas con nombre.
│
├── utils/
│   ├── api_config.dart         # kBaseUrl: única fuente de la IP/dominio del backend.
│   ├── colors.dart              # Paleta azul compartida (AppColors) usada por login y demás.
│   └── Routes.dart              # Nombres de ruta (MyRoutes.*) usados con Navigator.pushNamed.
│
├── widgets/
│   ├── custom_text_form_field.dart  # Input de texto reutilizable con estilo oscuro/azul.
│   └── gradient_button.dart         # Botón "pill" con gradiente, usado en el login.
│
├── models/
│   ├── storeToken.dart          # SecureStorage: guarda/lee el accessToken cifrado en disco.
│   └── appbar.dart              # AppBar superior con avatar, saludo, nombre de usuario y
│                                 # campana de notificaciones con badge de no leídas.
│
├── screens/                     # Pantallas de autenticación y flujos de equipo/tarea.
│   ├── login.dart                # Login (tema oscuro).
│   ├── signup.dart                # Registro.
│   ├── forgot password/           # Recuperación de contraseña (correo → OTP → nueva clave).
│   ├── join_team.dart              # Unirse a un equipo con un código.
│   ├── dashboard.dart               # Lista de equipos del usuario (dashb_mem).
│   ├── teamDetail.dart               # Detalle de un equipo: áreas, miembros, tareas y acciones.
│   ├── addTask.dart                   # Asignar tarea nueva (dropdowns de área/miembro).
│   ├── notifications.dart              # Bandeja de notificaciones; marcar como leída al tocar.
│   ├── MarkTaskDone.dart                # Pantalla legacy de completar tarea a mano (ya no
│   │                                     enlazada desde la UI).
│   ├── chat.dart / chatHistory.dart      # Chat del equipo con historial.
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
    └── music.dart               # "Zona Zen": módulo de audio. No enlazado a ninguna ruta
                                   (código huérfano, se deja por si se retoma).
```

> Nota: `lib/assets/` contiene las imágenes usadas dentro de las pantallas (ilustraciones, íconos propios). `assets/logo/` es solo el logo fuente para generar el ícono de la app — son carpetas con propósitos distintos y ambas están declaradas en `pubspec.yaml → flutter → assets`.

## Flujo de la aplicación

### 1. Arranque y sesión

`main.dart` revisa si hay un `accessToken` guardado en `flutter_secure_storage`:
- **Sin token** → `MyApp`, ruta inicial `/` = `SignUp`.
- **Con token** → `MyApp2`, ruta inicial `/` = `BottomNavBar` (entra directo a la app).

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

Toda la app usa una paleta azul/índigo (`Colors.indigo`, `AppColors` en `lib/utils/colors.dart`, tema global azul en `main.dart`). No quedan referencias a morado en el código.

## Backend PHP (`hive-backend`)

Vive en `C:\xampp\htdocs\hive-backend` (fuera de este repositorio, porque Apache lo sirve desde su propio *document root*). Son cuatro archivos:

- **`config.php`** — conexión PDO a `hive_db` (`ERRMODE_EXCEPTION`, `FETCH_ASSOC`) y constantes de subida (`UPLOAD_DIR`, `UPLOAD_URL_BASE`).
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

Ambas requieren Apache y MySQL de XAMPP corriendo, y se ejecutan desde la raíz del repo.

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

## Backend Node (alternativo, no en uso)

La carpeta [`backend/`](backend/) contiene una reimplementación completa en **Node.js + Express + mysql2**, con JWT, `bcryptjs` y `multer`, sobre el esquema [`database/schema.sql`](database/schema.sql) (base `team_management`). Cubre los mismos endpoints con la misma forma de JSON.

**No es el backend que la app consume hoy.** Difiere del PHP en el modelo de datos (ids enteros con claves foráneas en lugar de correos y `CHAR(24)`) y en la base de datos, así que **un cambio hecho aquí no tiene ningún efecto sobre la app**. Cualquier corrección de backend va a los archivos PHP en `htdocs`. Se conserva por si más adelante se migra el despliegue a Node.

Para levantarlo (solo si se retoma esa vía):

```bash
cd backend
npm install
cp .env.example .env
mysql -u root -p < ../database/schema.sql
npm start
```

## Cómo correr el proyecto

1. Levantar **Apache** y **MySQL** desde el panel de XAMPP.
2. Cargar el esquema si es la primera vez: `mysql -u root -p < C:\xampp\htdocs\hive-backend\schema.sql`.
3. Ajustar `kBaseUrl` en [`lib/utils/api_config.dart`](lib/utils/api_config.dart) con la IP LAN de la máquina que corre Apache.
4. Correr la app:

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
