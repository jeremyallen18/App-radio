# Radio Doliv — documentación general

Esta carpeta agrupa los **dos proyectos** de Radio Doliv. Cada uno tiene su propio
repositorio de git; aquí solo viven juntos en disco y este archivo explica cómo encajan.

```
radio-doliv/
├── App-radio/            App interna (Flutter) + su API (hive-backend, PHP)
└── RADIODOLIV_PAGINA/    Sitio web público (doliv.site, PHP) + API de solo lectura
```

## 1. ¿Qué es cada proyecto?

| Proyecto | Qué es | Para quién |
|---|---|---|
| **App-radio** | App móvil/escritorio para el **personal** de la radio: asistencia, permisos, tareas, calendario, y edición del contenido del sitio público. | Empleados, managers y director. |
| **RADIODOLIV_PAGINA** | El **sitio web** que ve cualquier visitante: radio en vivo, programas, podcasts, eventos, equipo, patrocinadores y anuncios. | Público en general + la app (consume su API para el stream y el contenido). |

Los dos comparten **una sola base de datos MySQL: `hive_db`**. Cuando el director edita
contenido desde la app, se guarda en `hive_db` y el sitio web lo muestra de inmediato.

## 2. Cómo se conectan

```
App Flutter  ──►  hive-backend (API, escribe y lee, con login)  ──┐
                                                                    ├──►  MySQL hive_db
Visitante web ──►  RADIODOLIV_PAGINA (sitio + API de solo lectura) ┘
```

- `hive-backend` es el único que puede **crear/editar/borrar** datos (requiere sesión).
- La API de `RADIODOLIV_PAGINA/api/` solo **lee** datos, sin login, para que la app
  muestre el stream, los anuncios, el equipo, etc.
- Cuando el director sube una imagen desde la app, `hive-backend` la guarda directo en
  la carpeta de imágenes del sitio web, para que aparezca sin pasos extra.

## 3. Requisitos para desarrollar en tu computadora

- **XAMPP** (Apache + PHP 8+).
- **MySQL** (puede ser el de XAMPP o uno aparte) accesible en `127.0.0.1:3306`.
- **Flutter SDK** (`flutter doctor` sin errores) + Android Studio o Xcode si vas a compilar
  la app móvil.

## 4. Base de datos (una sola vez)

1. Crear la base:
   ```sql
   CREATE DATABASE hive_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```
2. Importar el archivo con todas las tablas:
   ```bash
   mysql -u root -p hive_db < App-radio/hive-backend/schema.sql
   ```
3. Cargar el contenido inicial del sitio (solo la primera vez, es seguro repetirlo):
   ```bash
   php RADIODOLIV_PAGINA/config/migrations/migrate_radio_content.php
   php RADIODOLIV_PAGINA/config/migrations/migrate_sponsors.php
   ```

Si tu base **ya tiene datos** y solo querés actualizarla, no vuelvas a importar
`schema.sql`: aplicá únicamente los archivos nuevos dentro de
`App-radio/hive-backend/migrations/` y `RADIODOLIV_PAGINA/config/migrations/`.

## 5. Cómo correr cada proyecto localmente

Cada proyecto trae su propia guía paso a paso:

- **App interna + API** → ver [`App-radio/README.md`](App-radio/README.md)
- **Sitio web público** → ver [`RADIODOLIV_PAGINA/README.md`](RADIODOLIV_PAGINA/README.md)

## 6. Subir a producción (Hostinger)

En `doliv.site`, `RADIODOLIV_PAGINA` vive en la raíz del dominio y `hive-backend/` como
subcarpeta del mismo dominio (`doliv.site/hive-backend`), así comparten origen y no hace
falta configurar CORS.

| Subir a | Contenido | No subir |
|---|---|---|
| `public_html/` | todo `RADIODOLIV_PAGINA/` | `.git/`, `config/.env`, archivos `.md`, audios pesados sin usar |
| `public_html/hive-backend/` | todo `App-radio/hive-backend/` | `.env`, `schema.sql` y `migrations/` (solo se usan para importar una vez) |

Pasos resumidos:

1. Crear `hive_db` en Hostinger e importar `schema.sql` (una sola vez).
2. Crear el archivo `.env` de cada proyecto directamente en el servidor, con las
   credenciales reales (nunca subir tu `.env` local — cada carpeta trae un
   `.env.example` de referencia).
3. Dar permisos de escritura a `hive-backend/uploads/`, `hive-backend/private/` y
   `public_html/assets/img/` (ahí se guardan las imágenes que sube el director).
4. Compilar la app apuntando al dominio real:
   ```bash
   flutter build apk --dart-define=BASE_URL=https://doliv.site/hive-backend --dart-define=SITE_BASE_URL=https://doliv.site/
   ```

## 7. Dónde buscar más detalle

| Tema | Dónde |
|---|---|
| Todo sobre la app y su API interna | [`App-radio/README.md`](App-radio/README.md) |
| Todo sobre el sitio web público | [`RADIODOLIV_PAGINA/README.md`](RADIODOLIV_PAGINA/README.md) |
| Esquema completo de la base de datos | `App-radio/hive-backend/schema.sql` |
| Rutas de la API interna | tabla al inicio de `App-radio/hive-backend/index.php` |
| Arquitectura a fondo del sitio | `RADIODOLIV_PAGINA/DOCUMENTACION_PROYECTO.md`, `RADIODOLIV_PAGINA/ESQUEMA_PROYECTO.md` |
