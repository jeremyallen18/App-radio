# App-radio — app interna de Radio Doliv

App para el **personal** de Radio Doliv: asistencia con geocerca, permisos/vacaciones,
tareas por área, chat, calendario de eventos y edición del contenido del sitio web
público. Toda la interfaz está en español.

> Este proyecto convive con `RADIODOLIV_PAGINA` (el sitio web público) dentro de la
> carpeta `radio-doliv/`. Ver [el README general](../README.md) para cómo encajan y
> cómo montar la base de datos compartida.

## 1. Qué es y cómo está hecho

| Parte | Tecnología |
|---|---|
| App (cliente) | **Flutter / Dart**, Material 3, tema oscuro propio. Funciona en Android, iOS, Windows y web. |
| API (servidor) | **PHP 8 + PDO** sobre Apache, sin framework. Un router por expresiones regulares en `hive-backend/index.php`. |
| Base de datos | **MySQL** (`hive_db`), compartida con el sitio web público. |

La app habla con **un único backend**, `hive-backend/` (dentro de este mismo repo). Todo
lo demás (chat, imágenes, PDF de asistencia, correo con código OTP) pasa por ahí.

## 2. Estructura del proyecto

```
App-radio/
├── lib/                    Código Flutter
│   ├── core/api_config.dart    Dirección del backend (kBaseUrl) y del sitio (kSiteBaseUrl)
│   ├── features/               Pantallas agrupadas por función (asistencia, tareas, etc.)
│   ├── models/                  Modelos de datos (usuario, tarea, programa de radio, etc.)
│   ├── services/                Llamadas HTTP al backend
│   └── design/                  Tema y componentes visuales compartidos
├── hive-backend/            API en PHP
│   ├── index.php                Router: aquí está la lista completa de rutas
│   ├── *.php                    Un archivo por módulo (attendance, dept_tasks, site_content...)
│   ├── config.php, helpers.php  Conexión a MySQL y utilidades (auth, respuestas JSON)
│   ├── schema.sql                Esquema completo de la base, para instalar desde cero
│   └── migrations/               Cambios incrementales, para bases que ya tienen datos
├── android/, ios/           Proyectos nativos generados por Flutter
└── tools/                   Scripts de prueba y de reseteo de la base de datos
```

## 3. Requisitos para desarrollar

- **XAMPP** (Apache + PHP 8+) — sirve `hive-backend/` en tu computadora.
- **MySQL** con la base `hive_db` ya creada (ver [README general](../README.md), sección 4).
- **Flutter SDK** (correr `flutter doctor` y resolver lo que salga en rojo).
- **Android Studio** (para compilar/probar en Android) y/o **Xcode** (solo para iOS).

## 4. Cómo correr el proyecto por primera vez

1. **Ubicar el proyecto** en `C:\xampp\htdocs\radio-doliv\App-radio` (ruta fija, sin copias).

2. **Decirle a Apache dónde está el backend.** Se hace una sola vez por computadora:
   abrí `C:\xampp\apache\conf\extra\httpd-xampp.conf` y agregá al final:
   ```apacheconf
   Alias /hive-backend "C:/xampp/htdocs/radio-doliv/App-radio/hive-backend/"
   <Directory "C:/xampp/htdocs/radio-doliv/App-radio/hive-backend">
       AllowOverride All
       Require all granted
   </Directory>
   ```
   Guardá y reiniciá Apache desde el Panel de Control de XAMPP.

3. **Configurar la conexión a la base de datos:**
   ```bash
   copy hive-backend\.env.example hive-backend\.env
   ```
   Con la configuración estándar de XAMPP (usuario `root`, sin contraseña) no hace falta
   cambiar nada más.

4. **Prender Apache y MySQL** desde el Panel de Control de XAMPP.

5. **Decirle a la app dónde está tu backend.** Cada persona corre su propio backend, así
   que la app necesita tu IP de red local:
   ```bash
   ipconfig
   ```
   Buscá "Dirección IPv4" y ponela en [`lib/core/api_config.dart`](lib/core/api_config.dart):
   ```dart
   const String kBaseUrl = 'http://TU_IP_AQUI/hive-backend';
   ```
   > Si vas a probar en un celular físico, el celular y la computadora deben estar en la
   > misma red Wi-Fi. Con emulador o versión de escritorio no hace falta este paso extra.

6. **Instalar dependencias y correr la app:**
   ```bash
   flutter pub get
   flutter run
   ```

Si todo salió bien, ves la pantalla de inicio de sesión.

### Problemas comunes

- **La app no carga nada**: revisá que Apache y MySQL sigan en verde, y que la IP en
  `api_config.dart` sea la actual (cambia si te reconectás al Wi-Fi).
- **Error 404 en `http://localhost/hive-backend`**: el `Alias` del paso 2 no quedó bien
  guardado o Apache no se reinició. Revisá el bloque y hacé Stop/Start de Apache.
- **Apache no arranca** después de tocar `httpd-xampp.conf`: hay un error de sintaxis en
  el bloque que pegaste (falta una llave o comilla).
- **`flutter doctor` marca cosas en rojo**: resolvelas antes de seguir; el propio comando
  suele decir cómo (aceptar licencias de Android, instalar un componente, etc.).

## 5. Base de datos (`hive_db`)

El esquema completo vive en [`hive-backend/schema.sql`](hive-backend/schema.sql). Se
importa una sola vez:
```bash
mysql -u root -p hive_db < hive-backend/schema.sql
```
Si tu base ya tiene datos, no reimportes ese archivo: aplicá solo los `.sql` nuevos de
`hive-backend/migrations/`.

Grupos principales de tablas:

| Grupo | Para qué |
|---|---|
| `users`, `notifications` | Cuentas, sesión y notificaciones in-app |
| `teams`, `domains`, `domain_members` | Estructura de equipos y áreas |
| `dept_tasks` y relacionadas | Tareas por área, con evidencia y revisión |
| `attendance_*` | Registro de entrada/comida/salida con geocerca |
| `leave_requests` | Permisos, vacaciones e incapacidades |
| `events` | Calendario de eventos |
| `anuncios`, `radio_events`, `radio_programs`, `radio_podcasts`, `radio_team`, `radio_services`, `sponsors` | Contenido del sitio web público (editado desde esta app) |

> **Vínculo Programas ↔ Equipo:** la tabla `radio_program_hosts` vincula cada programa
> con cualquier cantidad de integrantes reales de `radio_team` (locutor principal +
> co-conductores, sin límite). Al editar un programa se eligen uno o varios locutores ya
> registrados en Equipo (en vez de escribir el nombre a mano); al editar un integrante de
> Equipo se puede marcar qué programas conduce. El nombre mostrado (`host`) se mantiene
> siempre sincronizado, uniendo los nombres de todos los vinculados ("Fernanda y Amanda").

## 6. Rutas principales de la API (`hive-backend`)

Todas bajo `http://<host>/hive-backend`. 🔒 = requiere header `Authorization` con el
token de sesión. El listado completo, ruta por ruta, está al inicio de
[`hive-backend/index.php`](hive-backend/index.php).

| Prefijo | Para qué |
|---|---|
| `/user/*` | Registro, login, recuperar contraseña, perfil |
| `/company/*`, `/department/*` | Estructura organizacional |
| `/dept-tasks/*` | Tareas por área |
| `/attendance/*` | Asistencia con geocerca |
| `/leave/*`, `/leave-requests/*` | Permisos, vacaciones, incapacidades |
| `/events/*` | Calendario de eventos |
| `/site/*` 🔒 (solo director) | Edición del contenido público: anuncios, eventos, servicios, equipo, programas, patrocinadores, podcasts |
| `/radio/programs` | Lectura de la parrilla de programación |

## 7. Herramientas y pruebas

Requieren Apache y MySQL prendidos. La primera vez, instalar dependencias:
```bash
cd tools && npm install && cd ..
```

- **Prueba de extremo a extremo contra el backend real** (usa correos de prueba que
  borra al terminar, no ensucia datos reales):
  ```bash
  node tools/php-backend-test.js
  ```
- **Reiniciar la base de datos** (borra todos los datos, deja el esquema intacto —
  requiere `--yes` porque es destructivo):
  ```bash
  node tools/reset-database.js --yes
  ```
- **Pruebas de Flutter:**
  ```bash
  flutter test
  ```

## 8. Subir a producción (Hostinger)

Ver la sección "Despliegue en Hostinger" del [README general](../README.md#6-subir-a-producción-hostinger),
que cubre ambos proyectos juntos (backend + sitio web).

## 9. Regenerar el ícono de la app

Solo si cambiás el logo (`assets/logo/logo.png`):
```bash
dart run flutter_launcher_icons
```
