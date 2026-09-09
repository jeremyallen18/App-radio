# Radio Doliv — documentación general del proyecto

Carpeta contenedora de los **dos proyectos** que forman el ecosistema Radio Doliv.
Cada uno mantiene su **propio repositorio git** independiente; esta carpeta solo los
agrupa en disco y documenta cómo encajan.

```
radio-doliv/
├── README.md                ← este archivo (visión global + instalación)
├── App-radio/               ← repo git propio · app interna DolivManager
│   ├── lib/                     Cliente Flutter (Android · iOS · Windows · Linux · Web)
│   └── hive-backend/            API REST PHP (gestión interna, con auth)
└── RADIODOLIV_PAGINA/       ← repo git propio · sitio público + API de solo lectura
    ├── index.php · pages/ · inc/ · assets/   Sitio web PHP (doliv.site)
    └── api/                     Endpoints JSON que consume la app Flutter
```

---

## Índice

1. [Visión general](#1-visión-general)
2. [Arquitectura cliente–servidor](#2-arquitectura-clienteservidor)
3. [Estructura de carpetas](#3-estructura-de-carpetas)
4. [Stack técnico y requisitos](#4-stack-técnico-y-requisitos)
5. [Base de datos `hive_db`](#5-base-de-datos-hive_db)
6. [Instalación local — Sitio web](#6-instalación-local--sitio-web)
7. [Instalación local — Backend interno (`hive-backend`)](#7-instalación-local--backend-interno-hive-backend)
8. [Instalación local — App Flutter](#8-instalación-local--app-flutter)
9. [Endpoints (resumen)](#9-endpoints-resumen)
10. [Despliegue en Hostinger (producción)](#10-despliegue-en-hostinger-producción)
11. [Documentación por proyecto](#11-documentación-por-proyecto)

---

## 1. Visión general

| Proyecto | Qué es | Consumidores |
|---|---|---|
| **App-radio** | App de **gestión interna** del personal de la radio: asistencia con geocerca, permisos/vacaciones/incapacidades, tareas por departamento (con evidencia y revisión), calendario de eventos, y edición del contenido del sitio público. Flutter + backend PHP propio (`hive-backend/`). | Empleados, managers y director de Radio Doliv. |
| **RADIODOLIV_PAGINA** | **Sitio web público** de la estación (`doliv.site`): home con radio en vivo, programas, podcasts, eventos, equipo, servicios, sección azul (patrocinadores) y anuncios. Renderizado en el servidor con PHP. Incluye una **API JSON de solo lectura** (`api/`) que expone ese mismo contenido. | Visitantes web + la app Flutter (stream, anuncios, equipo, eventos, programas). |

Ambos proyectos comparten **una sola base de datos MySQL: `hive_db`**, que es el punto de integración entre los dos.

---

## 2. Arquitectura cliente–servidor

```
┌─────────────────────────────┐
│   App-radio/lib  (Flutter)  │   Cliente único, multiplataforma
│                             │
│  lib/core/api_config.dart   │   kBaseUrl ─────┐   kSiteBaseUrl ─────────┐
│  lib/services/*.dart        │   (clases API)  │                        │
└─────────────────────────────┘                 │                        │
                                                ▼                        ▼
                            ┌──────────────────────────────┐  ┌────────────────────────────┐
                            │  App-radio/hive-backend/      │  │  RADIODOLIV_PAGINA/api/     │
                            │  API REST PHP  (escritura +   │  │  API JSON  (SOLO LECTURA    │
                            │  lectura, autenticada)        │  │  del contenido público)    │
                            │                               │  │                            │
                            │  index.php  = front controller│  │  *.php = controladores finos│
                            │  attendance.php leave_requests │  │  sobre inc/data/*.php       │
                            │  dept_tasks.php events.php     │  │  _bootstrap.php = envelope  │
                            │  site_content.php  helpers.php │  │  {success:bool,...}        │
                            └───────────────┬───────────────┘  └──────────────┬─────────────┘
                                            │                                │
                                            │        ┌───────────────────────┘
                                            ▼        ▼
                                   ┌────────────────────────────┐
                                   │   MySQL  ·  hive_db        │   Única fuente de verdad
                                   │   (compartida por ambos)   │
                                   └────────────────────────────┘

        Además: hive-backend/site_content.php ESCRIBE archivos de imagen
        directamente en el filesystem de RADIODOLIV_PAGINA/assets/img/…
        (ruta configurable con RADIODOLIV_PAGINA_PATH; por defecto asume
        que ambos proyectos son hermanos, como en esta carpeta).
```

### Reglas de la arquitectura

1. **El cliente Flutter nunca toca la base de datos.** Todo pasa por HTTP contra uno de los
   dos backends. Las URLs base viven centralizadas en
   [`App-radio/lib/core/api_config.dart`](App-radio/lib/core/api_config.dart) y se pueden
   sobreescribir por entorno con `--dart-define=BASE_URL=… --dart-define=SITE_BASE_URL=…`.
2. **`hive-backend`** es el único que **escribe** en `hive_db` y el único **autenticado**
   (token en el header `Authorization`). Cubre todo lo que un usuario logueado hace en la app.
3. **`RADIODOLIV_PAGINA/api`** es **solo lectura y sin auth**: expone en JSON exactamente las
   mismas fuentes de datos (`inc/data/*.php`) que ya renderizan las páginas PHP del sitio, sin
   duplicar lógica. Devuelve siempre el envelope `{ "success": true|false, … }`.
4. **La base de datos es el punto de integración.** El director edita el contenido del sitio
   desde la app → `hive-backend/site_content.php` lo guarda en `hive_db` (y sube las imágenes al
   filesystem del sitio) → el sitio web y `RADIODOLIV_PAGINA/api` lo leen de `hive_db`.
5. **Degradación amable:** si `hive_db` falla, cada backend responde un JSON de error legible
   (nunca un 500 en blanco); la app y el sitio muestran "no se pudo cargar", no una pantalla rota.

### Ejemplo de flujo — "el director publica un anuncio"

```
App Flutter (director)
  └─POST /hive-backend/site/anuncios  (multipart: texto + imagen, con token)
       └─ hive-backend/site_content.php
            ├─ INSERT en hive_db.anuncios
            └─ guarda la imagen en RADIODOLIV_PAGINA/assets/img/anuncios/xxx.jpg
  ...más tarde...
Visitante web  → RADIODOLIV_PAGINA/pages/anuncios.php          → lee hive_db.anuncios
App Flutter    → GET  /RADIODOLIV_PAGINA/api/anuncios.php      → lee hive_db.anuncios
```

---

## 3. Estructura de carpetas

```
App-radio/
├── lib/
│   ├── main.dart
│   ├── core/            api_config.dart, sesión, audio (radio en vivo), ubicación, rutas
│   ├── features/        pantallas por módulo (asistencia, permisos, tareas, calendario, …)
│   ├── services/        una clase por recurso del backend (llamadas HTTP)
│   ├── models/          modelos de datos
│   ├── shared/          widgets y utilidades compartidas
│   └── design/          tema Material 3 oscuro propio (tokens, componentes, motion)
├── android/ ios/ windows/ linux/ web/   proyectos nativos por plataforma
├── pubspec.yaml
└── hive-backend/        ← API REST PHP (ver sección 7)
    ├── index.php            front controller + tabla de rutas
    ├── config.php           conexión PDO (lee .env)
    ├── helpers.php          auth por token, helpers de request/response
    ├── attendance.php  leave_requests.php  dept_tasks.php  events.php  site_content.php
    ├── lib/                 PHPMailer (OTP por correo) · fpdf (reporte PDF de asistencia)
    ├── migrations/          001..013 — historial incremental de hive_db (RRHH)
    ├── schema.sql           ESQUEMA COMPLETO de hive_db (RRHH + sitio) para instalación nueva
    ├── uploads/             imágenes públicas subidas desde la app (fotos de perfil, etc.)
    ├── private/             evidencia de permisos y tareas (fuera del acceso web)
    └── .env                 credenciales (NO se versiona; ver .env.example)

RADIODOLIV_PAGINA/
├── index.php            home (renderizada en servidor)
├── pages/               conocenos · servicios · programas · podcast · eventos · equipo · seccionazul · anuncios (todas .php)
├── inc/
│   ├── partials/            head, navbar, footer, scripts (plantilla común)
│   ├── components/          fragmentos reutilizables (modales, filas de evento, …)
│   ├── data/               *.php — capa de datos: leen hive_db y devuelven arrays
│   ├── helpers/             env, formato, html, seo, assets
│   └── api/                 dolibot-chat.php (proxy al chatbot con OpenRouter)
├── api/                  endpoints JSON de solo lectura para la app (ver sección 9)
├── assets/              css/ js/ img/ audio/
├── config/
│   ├── db.php               get_pdo() — conexión PDO cacheada (lee config/.env)
│   ├── .env                 credenciales (NO se versiona; ver .env.example)
│   └── migrations/          create_radio_content.sql · create_sponsors.sql + scripts migrate_*.php (seed)
└── .htaccess            DirectoryIndex + redirecciones 301 de URLs históricas
```

---

## 4. Stack técnico y requisitos

| Capa | Tecnología |
|---|---|
| Cliente | **Flutter / Dart** (SDK Dart `>=3.2.0 <4.0.0`, Material 3). Paquetes clave: `http`, `just_audio` (radio en vivo), `flutter_map` + `latlong2` (elegir ubicación y previsualizar el radio del lugar de asistencia), `fl_chart`, `flutter_secure_storage`, `local_auth`, `shared_preferences`, `intl` (es_MX), `share_plus` + `path_provider` (exportar reporte). |
| Backend interno | **PHP 8+** sobre **Apache**, **PDO/MySQL**. Sin framework. `PHPMailer` para el OTP por correo (SMTP) y `fpdf` para el PDF de asistencia. |
| Sitio web | **PHP 8+** sobre **Apache**, renderizado en el servidor (plantillas en `inc/partials`, datos en `inc/data/*.php`). CSS/JS propios, sin build system. |
| Base de datos | **MySQL 8+ / 9.x**, base `hive_db`, `utf8mb4_unicode_ci`. Puerto `3306`. |

### Herramientas necesarias para desarrollar

- **XAMPP** (aporta Apache + PHP). También sirve cualquier Apache/PHP 8 con `pdo_mysql` y `openssl`.
- **MySQL Server** (independiente de XAMPP) + **MySQL Workbench**, conectando a `127.0.0.1:3306`.
  > En este entorno la BD **no** se maneja con el MySQL de XAMPP: se usa un MySQL Server propio
  > y MySQL Workbench. Las credenciales viven en los `.env` de cada proyecto.
- **Flutter SDK** (`flutter doctor` sin errores).
- **Android Studio** (SDK + emulador) y/o **Xcode** (solo iOS) para compilar la app móvil.
- **PHP en el PATH** (el que trae XAMPP sirve) para correr los scripts de seed de la BD.

---

## 5. Base de datos `hive_db`

Una sola base compartida. Dos formas de montarla:

### A) Instalación nueva (recomendada) — un solo archivo

1. Crear la base y el usuario (en MySQL Workbench, conexión a `127.0.0.1:3306`):

   ```sql
   CREATE DATABASE hive_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   CREATE USER 'hive_user'@'localhost' IDENTIFIED BY 'TU_PASSWORD';
   GRANT ALL PRIVILEGES ON hive_db.* TO 'hive_user'@'localhost';
   FLUSH PRIVILEGES;
   ```

2. Importar **solo** `App-radio/hive-backend/schema.sql` — contiene **todas** las tablas:
   las de gestión interna (migraciones `001`–`013` ya plegadas) y las del sitio público
   (`radio_events`, `radio_podcasts`, `radio_podcast_episodes`, `radio_programs`,
   `radio_services`, `radio_team`, `sponsors`, `sponsor_socials`).
   En Workbench: *Server → Data Import → Import from Self-Contained File*.

3. Cargar el contenido inicial del sitio (una sola vez; los scripts son idempotentes):

   ```bash
   php RADIODOLIV_PAGINA/config/migrations/migrate_radio_content.php
   php RADIODOLIV_PAGINA/config/migrations/migrate_sponsors.php
   ```

### B) Base de datos que ya tiene datos — migraciones incrementales

Aplicar solo los `.sql` nuevos, en orden:

- `App-radio/hive-backend/migrations/00X_*.sql` (traen `ALTER TABLE`, imprescindibles para
  no perder columnas al actualizar).
- `RADIODOLIV_PAGINA/config/migrations/2026_08_06_create_*.sql` si faltan las tablas del sitio.

> `schema.sql` = estado completo para empezar de cero. `migrations/` = historial para actualizar
> lo que ya existe. Se conservan ambos a propósito.

---

## 6. Instalación local — Sitio web

Requisitos: Apache corriendo (XAMPP), la base `hive_db` ya montada (sección 5).

1. **Ubicar el proyecto** bajo el `DocumentRoot` de Apache. Con XAMPP:
   `C:\xampp\htdocs\radio-doliv\RADIODOLIV_PAGINA\`.

2. **Configurar el `.env`:**

   ```bash
   cp RADIODOLIV_PAGINA/config/.env.example RADIODOLIV_PAGINA/config/.env
   ```

   Rellenar:
   - `DB_HOST=127.0.0.1`, `DB_NAME=hive_db`, `DB_USER=hive_user`, `DB_PASS=…`
   - `OPENROUTER_API_KEY=…` (para el chatbot DoliBot; se saca en <https://openrouter.ai/keys>)

3. **Abrir en el navegador:**
   `http://localhost/radio-doliv/RADIODOLIV_PAGINA/`

   Deberían cargar la home, la parrilla de programas y las páginas internas. `pages/anuncios.php`
   y las demás leen de `hive_db`; si algo falla ahí, revisar credenciales del `.env`.

> El sitio se sirve **por ruta** (no por Alias), por eso su URL local lleva el prefijo
> `/radio-doliv/`. En producción va en la **raíz del dominio** (ver sección 10).

---

## 7. Instalación local — Backend interno (`hive-backend`)

Se sirve con un **Alias de Apache**, así su URL no depende de dónde esté la carpeta en disco.

1. **Declarar el Alias** (una sola vez por máquina) en
   `C:\xampp\apache\conf\extra\httpd-xampp.conf`:

   ```apacheconf
   Alias /hive-backend "C:/xampp/htdocs/radio-doliv/App-radio/hive-backend/"
   <Directory "C:/xampp/htdocs/radio-doliv/App-radio/hive-backend">
       AllowOverride All
       Require all granted
   </Directory>
   ```

   Reiniciar Apache desde el panel de XAMPP.

2. **Configurar el `.env`:**

   ```bash
   cp App-radio/hive-backend/.env.example App-radio/hive-backend/.env
   ```

   Rellenar:
   - `DB_HOST=127.0.0.1`, `DB_NAME=hive_db`, `DB_USER=hive_user`, `DB_PASS=…`
   - `APP_BASE_PATH=/hive-backend` (en local siempre; coincide con `RewriteBase` del `.htaccess`)
   - `RADIODOLIV_PAGINA_PATH=` (vacío en local: asume el proyecto hermano bajo `htdocs`)
   - `SMTP_*` (opcional en local; solo para el OTP de recuperación de contraseña por correo)

3. **Permisos de escritura** en `hive-backend/uploads/` y `hive-backend/private/`.

4. **Probar:** `http://localhost/hive-backend/` debe responder un JSON (home del router).
   Un `POST` a `/hive-backend/user/login` con credenciales válidas devuelve un token.

---

## 8. Instalación local — App Flutter

Requisitos: Flutter SDK, y el backend interno accesible (sección 7).

1. **Dependencias:**

   ```bash
   cd App-radio
   flutter pub get
   ```

2. **Apuntar la app al backend.** Los valores por defecto están en
   [`lib/core/api_config.dart`](App-radio/lib/core/api_config.dart) (una IP de LAN de desarrollo).
   Para otra red, pasar la IP del PC donde corre Apache (no `localhost`, que en un teléfono
   físico apunta al propio teléfono):

   ```bash
   flutter run \
     --dart-define=BASE_URL=http://<IP-del-PC>/hive-backend \
     --dart-define=SITE_BASE_URL=http://<IP-del-PC>/radio-doliv/RADIODOLIV_PAGINA/
   ```

   En un emulador de Android en la misma máquina, `10.0.2.2` apunta al host.

3. **Compilar para distribuir** (apuntando a producción):

   ```bash
   # Android
   flutter build apk --release \
     --dart-define=BASE_URL=https://doliv.site/hive-backend \
     --dart-define=SITE_BASE_URL=https://doliv.site/

   # iOS (luego firmar/subir con Xcode)
   flutter build ipa --release \
     --dart-define=BASE_URL=https://doliv.site/hive-backend \
     --dart-define=SITE_BASE_URL=https://doliv.site/
   ```

   El `.apk` / `.ipa` se reparte aparte (Play Store, TestFlight, enlace directo).
   **La app no se sube al hosting**; a Hostinger solo va PHP.

---

## 9. Endpoints (resumen)

### `hive-backend` (REST, autenticado con `Authorization: <token>`)

La tabla completa de rutas está al inicio de
[`App-radio/hive-backend/index.php`](App-radio/hive-backend/index.php). Grupos principales:

| Prefijo | Módulo |
|---|---|
| `/user/*` | signup, login, OTP y nueva contraseña, `me`, foto de perfil, directorio interno |
| `/company/*`, `/department/*` | estructura organizacional (director asigna managers y empleados) |
| `/dept-tasks/*` | tareas por departamento: crear, estado, revisión, comentarios, evidencia, recurrencia |
| `/attendance/*` | registro de entrada/comida/salida con geocerca, horarios, correcciones |
| `/leave/*`, `/leave-requests/*` | permisos, vacaciones, incapacidades (con evidencia privada) |
| `/events/*` | calendario de eventos (general / por áreas, con override de asistencia) |
| `/site/*` | **gestión del contenido público** (solo director): anuncios, eventos, servicios, equipo, programas, patrocinadores, podcasts |
| `/radio/programs` | lectura de la parrilla para cualquier usuario logueado |

### `RADIODOLIV_PAGINA/api` (JSON, solo lectura, sin auth)

Envelope común `{ "success": bool, … }`. Un archivo por recurso:

| Endpoint | Devuelve |
|---|---|
| `api/config.php` | configuración del sitio que necesita la app (URL del stream, enlaces de DoliBot, WhatsApp) |
| `api/anuncios.php` | anuncios publicados |
| `api/eventos.php` | eventos activos |
| `api/programas.php` | parrilla de programas |
| `api/podcasts.php` | podcasts y episodios |
| `api/equipo.php` | locutores / equipo |
| `api/servicios.php` | servicios comerciales |
| `api/seccionazul.php` | patrocinadores y sus redes |

---

## 10. Despliegue en Hostinger (producción)

Layout previsto en `doliv.site`: `RADIODOLIV_PAGINA` en la **raíz del dominio** y
`hive-backend/` como **subcarpeta del mismo dominio** (`https://doliv.site/hive-backend`), de
modo que comparten origen y **no hace falta configurar CORS**.

### Qué subir

| Destino en Hostinger | Contenido | Excluir |
|---|---|---|
| `public_html/` | todo `RADIODOLIV_PAGINA/` | `.git/`, `.claude/`, `.agents/`, `config/.env`, `*.md`, `.mp3` pesados de `assets/audio/podcasts/` |
| `public_html/hive-backend/` | todo `App-radio/hive-backend/` | `.env`, `schema.sql` y `migrations/` (solo para importar), `seed_attendance_users.php` |

### Pasos

1. **Base de datos:** crear `hive_db` en hPanel e importar **un único archivo**,
   `App-radio/hive-backend/schema.sql`. Luego, una sola vez:
   `php RADIODOLIV_PAGINA/config/migrations/migrate_radio_content.php` y `migrate_sponsors.php`.
2. **`RADIODOLIV_PAGINA/config/.env`** (crear en el servidor): `DB_*` reales + `OPENROUTER_API_KEY`.
3. **`hive-backend/.env`** (crear en el servidor):
   - `DB_*` reales (usuario que asigne Hostinger)
   - `APP_BASE_PATH=/hive-backend` **y** el mismo valor en `RewriteBase` de `hive-backend/.htaccess`
   - `RADIODOLIV_PAGINA_PATH=/home/<usuario>/domains/doliv.site/public_html` (confirmar la ruta real
     en el Administrador de archivos / SSH)
   - `SMTP_*` reales
4. **Permisos de escritura:** `hive-backend/uploads/`, `hive-backend/private/`,
   `public_html/assets/img/` (ahí escribe la app las imágenes que sube el director).
5. **App:** compilar con `--dart-define=BASE_URL=https://doliv.site/hive-backend --dart-define=SITE_BASE_URL=https://doliv.site/` y distribuir el binario.

Los `.env` **no se versionan**: cada repo los ignora y trae un `.env.example` con las claves esperadas.

---

## 11. Documentación por proyecto

| Tema | Dónde |
|---|---|
| Alcance funcional de la app y el backend interno | `App-radio/README.md`, `App-radio/Actualizacion.md` |
| Esquema completo de `hive_db` (un archivo, para BD nueva) | `App-radio/hive-backend/schema.sql` |
| Migraciones incrementales (para BD con datos) | `App-radio/hive-backend/migrations/`, `RADIODOLIV_PAGINA/config/migrations/` |
| Rutas de la API interna | tabla al inicio de `App-radio/hive-backend/index.php` |
| Arquitectura y plan del sitio público | `RADIODOLIV_PAGINA/DOCUMENTACION_PROYECTO.md`, `RADIODOLIV_PAGINA/ESQUEMA_PROYECTO.md` |
| Endpoints JSON públicos | `RADIODOLIV_PAGINA/api/` (un archivo por recurso) |
