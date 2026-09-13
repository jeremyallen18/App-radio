# Site Content API Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden `hive-backend/site_content.php` (the authenticated `/site/*` write API that manages RADIODOLIV_PAGINA's public content) with audit logging, scoped API-key auth, upload limits, orphaned-file cleanup, correct delete semantics, transactional safety, field validation, a documented contract, and a non-breaking version marker.

**Architecture:** Two new small PHP modules (`site_audit.php` for actor identity + audit log + versioned response helpers, `site_validation.php` for field validators) sit alongside `site_content.php` and are `require`d before it from `index.php`, matching this codebase's existing pattern of one-file-per-concern PHP includes with no autoloader. `site_content.php` itself is edited resource-by-resource (anuncios, eventos, servicios, equipo, programas, patrocinadores, podcasts) to call into the new modules. No routes change and no response shapes are removed — only a `version` key and (for delete) a `404` status are added.

**Tech Stack:** PHP 8.2 (procedural, PDO/MySQL, no framework, no autoloader — every file is `require`d explicitly from `index.php`), MySQL/MariaDB via XAMPP, manual numbered `.sql` migrations under `hive-backend/migrations/`, verification via `php -l` + `curl` against the local XAMPP server (this codebase has no PHPUnit).

**Spec:** The task instructions given directly in this conversation (10 numbered requirements: audit logging, API key hardening, upload size limits, orphaned file cleanup, 404 on missing delete, transaction rollbacks, field validation, actor/authorization separation, multipart contract docs, API versioning) — no separate spec file exists; this plan document carries the spec inline in each task.

## Global Constraints

- Do not modify `RADIODOLIV_PAGINA/api/*` (the public read-only API) unless required for compatibility — none of the tasks below touch it.
- Do not remove director-session authentication; both director-session and `X-Api-Key` auth paths must keep working.
- Do not break existing Flutter app routes or response shapes; only add fields (`version`) or previously-missing status codes (`404` on a no-op delete).
- Never delete a file outside `RADIODOLIV_PAGINA_PATH` (see `config.php`), even if a stored path were somehow manipulated.
- Recommended upload limits: images 5 MB, audio 100 MB. Reject with HTTP 400 and a clear JSON `{"error": "..."}` body.
- Keep the existing allowed-extension and `getimagesize()` real-image checks; add to them, don't replace them.
- This repo's commits carry no AI co-author trailer for this project — see the attribution rule already configured for this session; follow whatever the session's actual git commit instructions say at commit time.

---

## File Structure

- **Create** `hive-backend/migrations/036_site_content_audit_log.sql` — new `site_content_audit_log` table.
- **Modify** `hive-backend/schema.sql` — append the same table (fresh installs read from here, per the file's own header comment).
- **Modify** `hive-backend/.env.example` and `hive-backend/config.php` — add `APP_ENV`.
- **Create** `hive-backend/site_audit.php` — actor-context resolution (`site_actor_context()`), scope checks, audit logging (`site_audit_log()`), and the two versioned-response helpers (`site_response_item()`, `site_response_list()`) used by every resource.
- **Create** `hive-backend/site_validation.php` — field validators (text/date/int/hour/url/JSON-array decode/id-list) shared by every resource.
- **Modify** `hive-backend/site_content.php` — per-resource: swap `site_require_director()` for `site_actor_context()`, add audit calls, add validation calls, wrap `beginTransaction()` blocks in `try/catch`, check delete `rowCount()`, clean up replaced files after commit, use the versioned response helpers.
- **Modify** `hive-backend/index.php` — `require` the two new files before `site_content.php`.
- **Create** `hive-backend/site_content_orphan_cleanup.php` — CLI maintenance script that sweeps `RADIODOLIV_PAGINA/assets/img/*` and `assets/audio/*` for files no longer referenced by any row.
- **Create** `docs/site-content-api.md` — per-endpoint developer contract (method, URL, fields, files, JSON-encoded fields, example request/response, error responses).

---

### Task 1: Audit log table + `APP_ENV`

**Files:**
- Create: `hive-backend/migrations/036_site_content_audit_log.sql`
- Modify: `hive-backend/schema.sql` (append after `sponsor_socials`, i.e. after line 927)
- Modify: `hive-backend/.env.example` (add `APP_ENV`, extend the `SITE_CONTENT_KEY` comment)
- Modify: `hive-backend/config.php` (define `APP_ENV`)

**Interfaces:**
- Produces: table `site_content_audit_log(id, resource, action, record_id, actor_type, actor_id, actor_email, request_ip, before_json, after_json, created_at)`; constant `APP_ENV` (string, `'local'` unless `.env` sets `APP_ENV=production`).

- [ ] **Step 1: Write the migration**

```sql
-- Migración: bitácora de auditoría para el API de contenido del sitio
-- público (site_content.php, rutas /site/*). Aplicar una sola vez. Ver
-- hive-backend/schema.sql para el esquema completo (instalaciones nuevas
-- parten de ahí).
--
-- Registra cada create/update/delete hecho a través de /site/* para poder
-- rastrear quién cambió o borró algo por error. `before_json`/`after_json`
-- son opcionales (NULL si no aplica, p. ej. en un delete no se guarda
-- "after"). `actor_id` es el id de usuario (sesión de director) o el nombre
-- fijo de la integración (llave de API) — nunca NULL, para que el log
-- siempre sea atribuible a algo.
USE hive_db;

CREATE TABLE IF NOT EXISTS site_content_audit_log (
  id BIGINT NOT NULL AUTO_INCREMENT,
  resource VARCHAR(50) NOT NULL,
  action ENUM('create', 'update', 'delete') NOT NULL,
  record_id INT DEFAULT NULL,
  actor_type ENUM('session', 'api_key') NOT NULL,
  actor_id VARCHAR(100) NOT NULL,
  actor_email VARCHAR(255) DEFAULT NULL,
  request_ip VARCHAR(45) DEFAULT NULL,
  before_json LONGTEXT DEFAULT NULL,
  after_json LONGTEXT DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY resource_record (resource, record_id),
  KEY created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [ ] **Step 2: Append the identical `CREATE TABLE` to `schema.sql`**

Add the same `CREATE TABLE IF NOT EXISTS site_content_audit_log (...)` block (without the `USE hive_db;` line, matching the style of every other table already in `schema.sql`) right after the `sponsor_socials` table definition (currently ends at line 927).

- [ ] **Step 3: Apply the migration to the local DB**

Run: `"/c/xampp/mysql/bin/mysql.exe" -u hive_user -p'HivePass_2026!' hive_db < "C:/xampp/htdocs/radio-doliv/App-radio/hive-backend/migrations/036_site_content_audit_log.sql"`
(Adjust the mysql.exe path if different — check `C:\Program Files\MySQL\MySQL Server 9.6\bin\mysql.exe` per this project's memory if the XAMPP one isn't on PATH.)

Expected: no output (success). Verify with:
Run: `"/c/xampp/mysql/bin/mysql.exe" -u hive_user -p'HivePass_2026!' hive_db -e "DESCRIBE site_content_audit_log;"`
Expected: prints the 11 columns above.

- [ ] **Step 4: Add `APP_ENV` to `.env.example`**

In `hive-backend/.env.example`, right before the existing `SITE_CONTENT_KEY` block, add:

```
# Entorno de ejecución: 'local' (por defecto) o 'production'. En producción,
# SITE_CONTENT_KEY debe tener al menos 32 caracteres (ver site_audit.php);
# en local no se exige, para no bloquear pruebas con una llave corta.
APP_ENV=local

```

And extend the existing `SITE_CONTENT_KEY` comment block by appending this line after the `bin2hex(random_bytes(24))` line:

```
# En producción (APP_ENV=production) esta llave DEBE tener 32+ caracteres;
# random_bytes(24) ya produce 48 caracteres hex, así que basta con generarla
# como se indica arriba y no acortarla.
```

- [ ] **Step 5: Define `APP_ENV` in `config.php`**

In `hive-backend/config.php`, immediately after the existing `define('APP_BASE_PATH', ...)` line, add:

```php
// 'local' (por defecto) o 'production'. Usado por site_audit.php para
// exigir una SITE_CONTENT_KEY larga solo fuera de desarrollo.
define('APP_ENV', strtolower((string) (env_get('APP_ENV') ?: 'local')));
```

- [ ] **Step 6: Syntax-check and commit**

Run: `"/c/xampp/php/php.exe" -l hive-backend/config.php`
Expected: `No syntax errors detected`

```bash
git add hive-backend/migrations/036_site_content_audit_log.sql hive-backend/schema.sql hive-backend/.env.example hive-backend/config.php
git commit -m "Agrega tabla de auditoria site_content_audit_log y APP_ENV"
```

---

### Task 2: `site_audit.php` — actor context, scopes, audit log, versioned responses

**Files:**
- Create: `hive-backend/site_audit.php`
- Modify: `hive-backend/index.php` (require the new file)

**Interfaces:**
- Consumes: `env_get()`, `error_response()`, `require_auth()`, `require_role()` (all from `helpers.php`, already loaded); `APP_ENV` constant from Task 1.
- Produces (used by every later task):
  - `SITE_CONTENT_SCOPES` — `['site:read', 'site:write', 'site:delete']`
  - `site_actor_context(PDO $pdo, string $requiredScope = 'site:write'): array` → `['actor_type' => 'session'|'api_key', 'actor_id' => string, 'actor_email' => ?string, 'role' => string, 'scopes' => string[]]`
  - `site_audit_log(PDO $pdo, array $actorContext, string $resource, string $action, ?int $recordId, ?array $before = null, ?array $after = null): void`
  - `site_response_item(array $item, int $status = 200): void` — `json_response(['version' => '1', 'item' => $item], $status)`
  - `site_response_list(array $items): void` — `json_response(['version' => '1', 'items' => $items])`

- [ ] **Step 1: Write `hive-backend/site_audit.php`**

```php
<?php
// Identidad del actor + bitácora de auditoría para el API de contenido del
// sitio público (site_content.php, rutas /site/*). Ver
// docs/site-content-api.md para el contrato completo de cada endpoint.

// Alcances posibles para una llave de API (X-Api-Key). Hoy SITE_CONTENT_KEY
// es una sola llave con acceso total (se le asignan los tres), así que esto
// todavía no restringe nada -- deja preparado el terreno para llaves con
// permisos más finos sin cambiar la forma del auth context ni el código que
// ya lo consume.
const SITE_CONTENT_SCOPES = ['site:read', 'site:write', 'site:delete'];

// Devuelve el valor de la cabecera X-Api-Key sin importar cómo la exponga el
// servidor (variable $_SERVER o getallheaders()), o null si no vino.
function site_request_api_key(): ?string {
    if (isset($_SERVER['HTTP_X_API_KEY']) && $_SERVER['HTTP_X_API_KEY'] !== '') {
        return trim((string) $_SERVER['HTTP_X_API_KEY']);
    }
    if (function_exists('getallheaders')) {
        foreach (getallheaders() as $name => $value) {
            if (strcasecmp($name, 'X-Api-Key') === 0) {
                return trim((string) $value);
            }
        }
    }
    return null;
}

function site_request_ip(): ?string {
    return isset($_SERVER['REMOTE_ADDR']) ? (string) $_SERVER['REMOTE_ADDR'] : null;
}

// Autoriza la edición del contenido del sitio público y devuelve un
// contexto de auditoría estructurado (nunca una fila cruda de `users`,
// porque la llave de API no tiene una). Dos formas de entrar:
//
//   1. App Flutter del director (App-radio): sesión + rol 'director'.
//   2. App interna de Sistemas (proyecto beta_web): NO tiene login. Se
//      identifica con una llave estática en la cabecera X-Api-Key que debe
//      coincidir con SITE_CONTENT_KEY del .env. Si SITE_CONTENT_KEY está
//      vacío o no está definido, esta vía queda deshabilitada y todo sigue
//      exactamente como antes (solo director por sesión).
//
// $requiredScope se compara contra los scopes del actor -- hoy siempre pasa
// porque la única llave existente tiene los tres, pero cualquier llamador
// que ya declare qué alcance necesita ('site:write' para crear/editar,
// 'site:delete' para borrar) queda listo para cuando existan llaves con
// permisos reducidos.
function site_actor_context(PDO $pdo, string $requiredScope = 'site:write'): array {
    $configuredKey = (string) env_get('SITE_CONTENT_KEY', '');
    if ($configuredKey !== '') {
        if (APP_ENV === 'production' && strlen($configuredKey) < 32) {
            error_response('Configuración inválida: SITE_CONTENT_KEY debe tener al menos 32 caracteres en producción', 500);
        }
        $sentKey = site_request_api_key();
        if ($sentKey !== null && hash_equals($configuredKey, $sentKey)) {
            $context = [
                'actor_type'  => 'api_key',
                'actor_id'    => 'site_content_integration',
                'actor_email' => null,
                'role'        => 'system',
                'scopes'      => SITE_CONTENT_SCOPES,
            ];
            site_require_scope($context, $requiredScope);
            return $context;
        }
    }

    $user = require_auth($pdo);
    require_role($user, ['director']);
    return [
        'actor_type'  => 'session',
        'actor_id'    => (string) $user['id'],
        'actor_email' => $user['email'],
        'role'        => $user['role'],
        // El director por sesión siempre tiene acceso total; los scopes
        // limitados son un concepto exclusivo de llaves de API.
        'scopes'      => SITE_CONTENT_SCOPES,
    ];
}

function site_require_scope(array $actorContext, string $scope): void {
    if (!in_array($scope, $actorContext['scopes'], true)) {
        error_response("La credencial usada no tiene el alcance requerido: $scope", 403);
    }
}

// Guarda un registro de auditoría. $before/$after son arrays asociativos
// (fila de la tabla, o subconjunto relevante) o null -- se guardan como
// JSON para poder reconstruir qué cambió si algo se edita o borra por
// error. $resource debe ser SIEMPRE el mismo valor que el segmento de la
// URL /site/{resource} (p. ej. 'anuncios', 'equipo', 'programas') para que
// el log se pueda filtrar por endpoint.
function site_audit_log(
    PDO $pdo,
    array $actorContext,
    string $resource,
    string $action,
    ?int $recordId,
    ?array $before = null,
    ?array $after = null
): void {
    $stmt = $pdo->prepare(
        'INSERT INTO site_content_audit_log
            (resource, action, record_id, actor_type, actor_id, actor_email, request_ip, before_json, after_json)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $resource,
        $action,
        $recordId,
        $actorContext['actor_type'],
        $actorContext['actor_id'],
        $actorContext['actor_email'],
        site_request_ip(),
        $before !== null ? json_encode($before) : null,
        $after !== null ? json_encode($after) : null,
    ]);
}

// ---- respuestas versionadas -------------------------------------------
// Todas las respuestas de /site/* llevan ahora 'version' => '1' junto al
// payload existente ('item'/'items'), sin quitar ni renombrar nada, para
// que un cliente futuro (o beta_web) pueda detectar el contrato que está
// hablando sin que cambien las rutas.

function site_response_item(array $item, int $status = 200): void {
    json_response(['version' => '1', 'item' => $item], $status);
}

function site_response_list(array $items): void {
    json_response(['version' => '1', 'items' => $items]);
}
```

- [ ] **Step 2: Require it from `index.php`**

In `hive-backend/index.php`, change:

```php
require __DIR__ . '/config.php';
require __DIR__ . '/helpers.php';
require __DIR__ . '/site_content.php';
```

to:

```php
require __DIR__ . '/config.php';
require __DIR__ . '/helpers.php';
require __DIR__ . '/site_audit.php';
require __DIR__ . '/site_validation.php';
require __DIR__ . '/site_content.php';
```

(The `site_validation.php` require is added here now even though Task 3 creates the file next, so this edit only needs to happen once.)

- [ ] **Step 3: Placeholder-create `site_validation.php` so the app boots**

Create `hive-backend/site_validation.php` with just `<?php` for now (Task 3 fills it in). This keeps `index.php` bootable between tasks.

- [ ] **Step 4: Syntax-check**

Run: `"/c/xampp/php/php.exe" -l hive-backend/site_audit.php && "/c/xampp/php/php.exe" -l hive-backend/site_validation.php && "/c/xampp/php/php.exe" -l hive-backend/index.php`
Expected: `No syntax errors detected` three times.

Run: `curl -s http://localhost/hive-backend/site/anuncios -H "X-Api-Key: wrong"`
Expected: still works exactly as before this task (site_content.php hasn't been touched yet) — `{"error":"Missing Authorization header"}` with HTTP 401, confirming the app still boots with the two new requires in place.

- [ ] **Step 5: Commit**

```bash
git add hive-backend/site_audit.php hive-backend/site_validation.php hive-backend/index.php
git commit -m "Agrega site_audit.php: contexto de actor, scopes y bitacora versionada"
```

---

### Task 3: `site_validation.php` — shared field validators

**Files:**
- Modify: `hive-backend/site_validation.php` (replace the placeholder from Task 2)

**Interfaces:**
- Consumes: `error_response()` from `helpers.php`, `safe_external_url()` from `helpers.php`.
- Produces (used by every resource task below):
  - `site_required_text(string $field, string $label): string`
  - `site_optional_text(string $field): string`
  - `site_valid_date(string $field, string $label): ?string`
  - `site_valid_int(string $field, string $label, int $default = 0): int`
  - `site_valid_hour(string $field, string $label): ?int`
  - `site_valid_url(string $rawValue, string $label, bool $required = false): string`
  - `site_decode_json_array(string $raw, string $label): array`
  - `site_valid_ids_in_table(PDO $pdo, string $raw, string $table, string $label): array`

- [ ] **Step 1: Write `hive-backend/site_validation.php`**

```php
<?php
// Validadores de campos compartidos por todos los recursos de
// site_content.php. Cada función corta la petición con error_response()
// (HTTP 400) si el valor es inválido; si es válido, devuelve el valor ya
// normalizado/casteado, listo para usarse directo en un bind de PDO.

function site_required_text(string $field, string $label): string {
    $value = trim((string) ($_POST[$field] ?? ''));
    if ($value === '') {
        error_response("$label es requerido", 400);
    }
    return $value;
}

function site_optional_text(string $field): string {
    return trim((string) ($_POST[$field] ?? ''));
}

// Espera 'YYYY-MM-DD' (lo que manda un date picker de Flutter). Cadena
// vacía => null (campo opcional sin fecha). Cualquier otra cosa que no sea
// una fecha real (p. ej. "2026-02-30") es rechazada.
function site_valid_date(string $field, string $label): ?string {
    $raw = trim((string) ($_POST[$field] ?? ''));
    if ($raw === '') return null;
    $parts = explode('-', $raw);
    if (count($parts) !== 3 || !checkdate((int) $parts[1], (int) $parts[2], (int) $parts[0])) {
        error_response("$label debe ser una fecha válida (AAAA-MM-DD)", 400);
    }
    return $raw;
}

function site_valid_int(string $field, string $label, int $default = 0): int {
    $raw = trim((string) ($_POST[$field] ?? ''));
    if ($raw === '') return $default;
    if (filter_var($raw, FILTER_VALIDATE_INT) === false) {
        error_response("$label debe ser un número entero", 400);
    }
    return (int) $raw;
}

// Hora entera 0-23, o null si el campo llegó vacío (usado por slot_start /
// slot_end de radio_programs, que son opcionales en pareja).
function site_valid_hour(string $field, string $label): ?int {
    $raw = trim((string) ($_POST[$field] ?? ''));
    if ($raw === '') return null;
    if (filter_var($raw, FILTER_VALIDATE_INT) === false) {
        error_response("$label debe ser una hora entera entre 0 y 23", 400);
    }
    $hour = (int) $raw;
    if ($hour < 0 || $hour > 23) {
        error_response("$label debe estar entre 0 y 23", 400);
    }
    return $hour;
}

// A diferencia de safe_external_url() (que silenciosamente convierte una
// URL inválida en '' para no romper una fila existente al leerla), esto se
// usa al ESCRIBIR: si el director/la integración mandó algo y no es una URL
// http(s) válida, se rechaza con 400 en vez de guardar '' en silencio.
function site_valid_url(string $rawValue, string $label, bool $required = false): string {
    $raw = trim($rawValue);
    if ($raw === '') {
        if ($required) {
            error_response("$label es requerido", 400);
        }
        return '';
    }
    $safe = safe_external_url($raw);
    if ($safe === '') {
        error_response("$label no es una URL válida (debe empezar con http:// o https://)", 400);
    }
    return $safe;
}

// Decodifica un campo JSON-array enviado por multipart (socials_json,
// episodes_json). A diferencia del comportamiento previo (JSON inválido =>
// tratar como lista vacía, en silencio), esto rechaza con 400 para que un
// error de serialización del cliente no borre datos existentes sin avisar.
function site_decode_json_array(string $raw, string $label): array {
    $raw = trim($raw) !== '' ? $raw : '[]';
    $decoded = json_decode($raw, true);
    if (!is_array($decoded)) {
        error_response("$label debe ser un arreglo JSON válido", 400);
    }
    return $decoded;
}

// Valida que cada id en una lista separada por comas exista en $table, y
// devuelve solo los ids válidos, deduplicados y en el orden en que llegaron
// (usado por host_team_ids de programas y program_ids de equipo). $table
// nunca viene de entrada del cliente (siempre una llamada fija en
// site_content.php), así que interpolarlo en la consulta es seguro, igual
// que en site_unique_slug().
function site_valid_ids_in_table(PDO $pdo, string $raw, string $table, string $label): array {
    $raw = trim($raw);
    if ($raw === '') return [];

    $ids = array_values(array_unique(array_filter(
        array_map('intval', explode(',', $raw)),
        fn($n) => $n > 0
    )));
    if ($ids === []) return [];

    $placeholders = implode(',', array_fill(0, count($ids), '?'));
    $stmt = $pdo->prepare("SELECT id FROM `$table` WHERE id IN ($placeholders)");
    $stmt->execute($ids);
    $found = array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));

    if (count($found) !== count($ids)) {
        error_response("$label contiene un id que ya no existe", 400);
    }
    return $ids;
}
```

- [ ] **Step 2: Syntax-check**

Run: `"/c/xampp/php/php.exe" -l hive-backend/site_validation.php`
Expected: `No syntax errors detected`

- [ ] **Step 3: Commit**

```bash
git add hive-backend/site_validation.php
git commit -m "Agrega validadores de campo compartidos para site_content.php"
```

---

### Task 4: Upload size limits + safe orphan-file deletion helper

**Files:**
- Modify: `hive-backend/site_content.php:46-108` (`site_handle_image`, `site_handle_audio`)

**Interfaces:**
- Consumes: `RADIODOLIV_PAGINA_PATH` constant (from `config.php`).
- Produces: constants `SITE_MAX_IMAGE_BYTES` (5 MB), `SITE_MAX_AUDIO_BYTES` (100 MB); function `site_delete_old_file(string $relativePath): void` (used by every resource task from here on, always called AFTER a successful `commit()`/`execute()`, never before, so a rolled-back write never deletes a file that's still referenced).

- [ ] **Step 1: Add size constants and the safe-delete helper**

Right after the `site_slugify` function (around line 24), insert:

```php
// Límites de subida (ver docs/site-content-api.md). Se comprueban aquí,
// además de los límites de php.ini (upload_max_filesize/post_max_size),
// porque este backend quiere un tope explícito y documentado
// independiente de la configuración del servidor.
const SITE_MAX_IMAGE_BYTES = 5 * 1024 * 1024;   // 5 MB
const SITE_MAX_AUDIO_BYTES = 100 * 1024 * 1024; // 100 MB

// Borra un archivo dentro de RADIODOLIV_PAGINA_PATH, típicamente una imagen
// o audio que se acaba de reemplazar. SIEMPRE se llama después de que el
// UPDATE en la base de datos ya tuvo éxito (nunca antes de un commit), para
// que una transacción que falle no borre un archivo que la fila todavía
// referencia. Nunca borra nada fuera de RADIODOLIV_PAGINA_PATH, incluso si
// $relativePath viniera manipulado (belt-and-suspenders: en la práctica
// $relativePath siempre sale de una columna que este mismo archivo escribió).
function site_delete_old_file(?string $relativePath): void {
    if ($relativePath === null || $relativePath === '') return;

    $base = realpath(RADIODOLIV_PAGINA_PATH);
    $target = realpath(RADIODOLIV_PAGINA_PATH . '/' . $relativePath);
    if ($base === false || $target === false) return;
    if (strpos($target, $base . DIRECTORY_SEPARATOR) !== 0) return;

    @unlink($target);
}
```

- [ ] **Step 2: Enforce the image size limit in `site_handle_image`**

In `site_handle_image` (currently line 46), change:

```php
    $file = $_FILES[$field];
    if ($file['error'] !== UPLOAD_ERR_OK) {
        error_response('No se pudo subir la imagen', 400);
    }

    $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    $allowed = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    if (!in_array($ext, $allowed, true) || @getimagesize($file['tmp_name']) === false) {
        error_response('Solo se permiten imágenes jpg, jpeg, png, gif o webp', 400);
    }
```

to:

```php
    $file = $_FILES[$field];
    if (in_array($file['error'], [UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE], true)) {
        error_response('La imagen supera el tamaño máximo permitido por el servidor', 400);
    }
    if ($file['error'] !== UPLOAD_ERR_OK) {
        error_response('No se pudo subir la imagen', 400);
    }
    if ($file['size'] > SITE_MAX_IMAGE_BYTES) {
        error_response('La imagen supera el tamaño máximo permitido (5 MB)', 400);
    }

    $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    $allowed = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    if (!in_array($ext, $allowed, true) || @getimagesize($file['tmp_name']) === false) {
        error_response('Solo se permiten imágenes jpg, jpeg, png, gif o webp', 400);
    }
```

- [ ] **Step 3: Enforce the audio size limit in `site_handle_audio`**

In `site_handle_audio` (currently line 79), change:

```php
    $file = $_FILES[$field];
    if ($file['error'] !== UPLOAD_ERR_OK) {
        error_response('No se pudo subir el audio', 400);
    }

    $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    $allowed = ['mp3', 'wav', 'm4a', 'ogg'];
    if (!in_array($ext, $allowed, true)) {
        error_response('Solo se permiten archivos de audio mp3, wav, m4a u ogg', 400);
    }
```

to:

```php
    $file = $_FILES[$field];
    if (in_array($file['error'], [UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE], true)) {
        error_response('El audio supera el tamaño máximo permitido por el servidor', 400);
    }
    if ($file['error'] !== UPLOAD_ERR_OK) {
        error_response('No se pudo subir el audio', 400);
    }
    if ($file['size'] > SITE_MAX_AUDIO_BYTES) {
        error_response('El audio supera el tamaño máximo permitido (100 MB)', 400);
    }

    $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    $allowed = ['mp3', 'wav', 'm4a', 'ogg'];
    if (!in_array($ext, $allowed, true)) {
        error_response('Solo se permiten archivos de audio mp3, wav, m4a u ogg', 400);
    }
```

- [ ] **Step 4: Confirm `php.ini`'s own ceilings won't silently truncate a 100 MB audio upload before PHP even sees it**

Run: `"/c/xampp/php/php.exe" -i | grep -E "upload_max_filesize|post_max_size"`
Expected: both values are ≥ 100M. If either is smaller (XAMPP's default `php.ini` often ships with `upload_max_filesize=40M`/`post_max_size=48M`), raise both to `110M` in `C:\xampp\php\php.ini` (leave headroom over the 100 MB app-level check) and restart Apache from the XAMPP control panel. Note this in `docs/site-content-api.md` (Task 14) as a deployment requirement for the production host too.

- [ ] **Step 5: Syntax-check**

Run: `"/c/xampp/php/php.exe" -l hive-backend/site_content.php`
Expected: `No syntax errors detected`

- [ ] **Step 6: Commit**

```bash
git add hive-backend/site_content.php hive-backend/.env.example
git commit -m "Agrega limites de tamano de subida y borrado seguro de archivos reemplazados"
```

(If `php.ini` was changed in Step 4, that file lives outside the repo — nothing else to stage for it.)

---

### Task 5: Anuncios — actor context, audit, 404, validation, versioned response

**Files:**
- Modify: `hive-backend/site_content.php:150-211` (`siteAnunciosList`, `siteAnuncioCreate`, `siteAnuncioUpdate`, `siteAnuncioDelete`)

**Interfaces:**
- Consumes: `site_actor_context()`, `site_audit_log()`, `site_response_item()`, `site_response_list()` (Task 2); `site_required_text()`, `site_optional_text()`, `site_valid_date()`, `site_valid_url()` (Task 3); `site_delete_old_file()` (Task 4).

- [ ] **Step 1: Rewrite the four functions**

Replace lines 150-211 with:

```php
function siteAnunciosList(PDO $pdo) {
    site_actor_context($pdo, 'site:read');
    $rows = $pdo->query('SELECT * FROM anuncios ORDER BY fecha_publicacion DESC, id DESC')->fetchAll();
    site_response_list($rows);
}

function siteAnuncioCreate(PDO $pdo) {
    $actor = site_actor_context($pdo, 'site:write');
    $titulo = site_required_text('titulo', 'titulo');

    $imagenUrl = site_handle_image('imagen', 'anuncios', $titulo, '');
    $stmt = $pdo->prepare('INSERT INTO anuncios (titulo, descripcion, imagen_url, link_web, link_facebook, link_whatsapp, fecha_publicacion) VALUES (?, ?, ?, ?, ?, ?, ?)');
    $stmt->execute([
        $titulo,
        site_optional_text('descripcion'),
        $imagenUrl,
        site_valid_url((string) ($_POST['link_web'] ?? ''), 'link_web'),
        site_valid_url((string) ($_POST['link_facebook'] ?? ''), 'link_facebook'),
        site_valid_url((string) ($_POST['link_whatsapp'] ?? ''), 'link_whatsapp'),
        site_valid_date('fecha_publicacion', 'fecha_publicacion'),
    ]);

    $id = (int) $pdo->lastInsertId();
    $stmt = $pdo->prepare('SELECT * FROM anuncios WHERE id = ?');
    $stmt->execute([$id]);
    $item = $stmt->fetch();
    site_audit_log($pdo, $actor, 'anuncios', 'create', $id, null, $item);
    site_response_item($item, 201);
}

function siteAnuncioUpdate(PDO $pdo, string $id) {
    $actor = site_actor_context($pdo, 'site:write');
    $stmt = $pdo->prepare('SELECT * FROM anuncios WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Anuncio no encontrado', 404);

    $titulo = site_required_text('titulo', 'titulo');
    $imagenUrl = site_handle_image('imagen', 'anuncios', $titulo, $existing['imagen_url'] ?? '');
    $stmt = $pdo->prepare('UPDATE anuncios SET titulo=?, descripcion=?, imagen_url=?, link_web=?, link_facebook=?, link_whatsapp=?, fecha_publicacion=? WHERE id=?');
    $stmt->execute([
        $titulo,
        site_optional_text('descripcion'),
        $imagenUrl,
        site_valid_url((string) ($_POST['link_web'] ?? ''), 'link_web'),
        site_valid_url((string) ($_POST['link_facebook'] ?? ''), 'link_facebook'),
        site_valid_url((string) ($_POST['link_whatsapp'] ?? ''), 'link_whatsapp'),
        site_valid_date('fecha_publicacion', 'fecha_publicacion'),
        $id,
    ]);
    if ($imagenUrl !== ($existing['imagen_url'] ?? '')) {
        site_delete_old_file($existing['imagen_url'] ?? '');
    }

    $stmt = $pdo->prepare('SELECT * FROM anuncios WHERE id = ?');
    $stmt->execute([$id]);
    $item = $stmt->fetch();
    site_audit_log($pdo, $actor, 'anuncios', 'update', (int) $id, $existing, $item);
    site_response_item($item);
}

function siteAnuncioDelete(PDO $pdo, string $id) {
    $actor = site_actor_context($pdo, 'site:delete');
    $stmt = $pdo->prepare('SELECT * FROM anuncios WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Resource not found', 404);

    $pdo->prepare('DELETE FROM anuncios WHERE id = ?')->execute([$id]);
    site_audit_log($pdo, $actor, 'anuncios', 'delete', (int) $id, $existing, null);
    json_response(['version' => '1', 'ok' => true]);
}
```

Note: the delete now does a `SELECT` first instead of checking `rowCount()` after — both satisfy requirement 5 ("check whether a row was actually deleted"), but the pre-`SELECT` is required anyway here to capture `$before` for the audit log, so it doubles as the existence check and avoids a wasted second query.

- [ ] **Step 2: Syntax-check**

Run: `"/c/xampp/php/php.exe" -l hive-backend/site_content.php`
Expected: `No syntax errors detected`

- [ ] **Step 3: Manual curl verification (requires Apache + MySQL running via XAMPP control panel, and a director session token — reuse one from a prior session or log in via `POST /user/login`)**

```bash
TOKEN="<director session token>"
BASE="http://localhost/hive-backend"

# create
curl -s -X POST "$BASE/site/anuncios" -H "Authorization: Bearer $TOKEN" \
  -F "titulo=Prueba plan" -F "descripcion=desc" -F "link_web=https://doliv.site"
# expect: HTTP 201, {"version":"1","item":{...,"titulo":"Prueba plan",...}}

# invalid url is rejected instead of silently saved as ''
curl -s -X POST "$BASE/site/anuncios" -H "Authorization: Bearer $TOKEN" \
  -F "titulo=Prueba url mala" -F "link_web=javascript:alert(1)"
# expect: HTTP 400, {"error":"link_web no es una URL válida ..."}

# delete a real id, then delete it again
curl -s -o /dev/null -w "%{http_code}\n" -X POST "$BASE/site/anuncios/<id>/delete" -H "Authorization: Bearer $TOKEN"
curl -s -o /dev/null -w "%{http_code}\n" -X POST "$BASE/site/anuncios/<id>/delete" -H "Authorization: Bearer $TOKEN"
# expect: 200 then 404

# audit rows were written
"/c/xampp/mysql/bin/mysql.exe" -u hive_user -p'HivePass_2026!' hive_db -e \
  "SELECT resource, action, record_id, actor_type, actor_email FROM site_content_audit_log WHERE resource='anuncios' ORDER BY id DESC LIMIT 5;"
# expect: rows for create/update/delete you just did, actor_type=session, actor_email=<the director's email>
```

Expected: every response above matches its comment.

- [ ] **Step 4: Commit**

```bash
git add hive-backend/site_content.php
git commit -m "Endurece anuncios: contexto de actor, auditoria, 404 y validacion"
```

---

### Task 6: Eventos — actor context, audit, 404, validation, versioned response

**Files:**
- Modify: `hive-backend/site_content.php:215-280` (`siteEventosList`, `site_evento_fields`, `siteEventoCreate`, `siteEventoUpdate`, `siteEventoDelete`)

**Interfaces:**
- Consumes: same Task 2/3/4 helpers as Task 5.

- [ ] **Step 1: Rewrite the resource**

Replace lines 215-280 with:

```php
function siteEventosList(PDO $pdo) {
    site_actor_context($pdo, 'site:read');
    $rows = $pdo->query('SELECT * FROM radio_events ORDER BY sort_order ASC, id ASC')->fetchAll();
    site_response_list($rows);
}

function site_evento_fields(): array {
    return [
        site_optional_text('artist'),
        site_optional_text('location'),
        site_optional_text('weekday'),
        site_optional_text('day'),
        site_optional_text('month'),
        site_optional_text('year'),
        site_valid_date('event_date', 'event_date'),
        site_optional_text('time_label'),
        site_optional_text('description'),
        site_valid_int('sort_order', 'sort_order'),
    ];
}

function siteEventoCreate(PDO $pdo) {
    $actor = site_actor_context($pdo, 'site:write');
    $title = site_required_text('title', 'title');

    [$artist, $location, $weekday, $day, $month, $year, $eventDate, $timeLabel, $description, $sortOrder] = site_evento_fields();
    $image = site_handle_image('image', 'eventos', $title, '');
    $slug = site_unique_slug($pdo, 'radio_events', $title);

    $stmt = $pdo->prepare('INSERT INTO radio_events (slug, title, artist, location, image, weekday, day, month, year, event_date, time_label, description, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
    $stmt->execute([$slug, $title, $artist, $location, $image, $weekday, $day, $month, $year, $eventDate, $timeLabel, $description, $sortOrder]);

    $id = (int) $pdo->lastInsertId();
    $stmt = $pdo->prepare('SELECT * FROM radio_events WHERE id = ?');
    $stmt->execute([$id]);
    $item = $stmt->fetch();
    site_audit_log($pdo, $actor, 'eventos', 'create', $id, null, $item);
    site_response_item($item, 201);
}

function siteEventoUpdate(PDO $pdo, string $id) {
    $actor = site_actor_context($pdo, 'site:write');
    $stmt = $pdo->prepare('SELECT * FROM radio_events WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Evento no encontrado', 404);

    $title = site_required_text('title', 'title');
    [$artist, $location, $weekday, $day, $month, $year, $eventDate, $timeLabel, $description, $sortOrder] = site_evento_fields();
    $image = site_handle_image('image', 'eventos', $title, $existing['image'] ?? '');

    $stmt = $pdo->prepare('UPDATE radio_events SET title=?, artist=?, location=?, image=?, weekday=?, day=?, month=?, year=?, event_date=?, time_label=?, description=?, sort_order=? WHERE id=?');
    $stmt->execute([$title, $artist, $location, $image, $weekday, $day, $month, $year, $eventDate, $timeLabel, $description, $sortOrder, $id]);
    if ($image !== ($existing['image'] ?? '')) {
        site_delete_old_file($existing['image'] ?? '');
    }

    $stmt = $pdo->prepare('SELECT * FROM radio_events WHERE id = ?');
    $stmt->execute([$id]);
    $item = $stmt->fetch();
    site_audit_log($pdo, $actor, 'eventos', 'update', (int) $id, $existing, $item);
    site_response_item($item);
}

function siteEventoDelete(PDO $pdo, string $id) {
    $actor = site_actor_context($pdo, 'site:delete');
    $stmt = $pdo->prepare('SELECT * FROM radio_events WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Resource not found', 404);

    $pdo->prepare('DELETE FROM radio_events WHERE id = ?')->execute([$id]);
    site_audit_log($pdo, $actor, 'eventos', 'delete', (int) $id, $existing, null);
    json_response(['version' => '1', 'ok' => true]);
}
```

Note: `title` dropped out of `site_evento_fields()`'s return tuple (it's read separately via `site_required_text` in both Create and Update, same as the original code already did — the original tuple's first slot was an unused `,` placeholder for title, now removed cleanly instead of destructured-and-discarded).

- [ ] **Step 2: Syntax-check**

Run: `"/c/xampp/php/php.exe" -l hive-backend/site_content.php`
Expected: `No syntax errors detected`

- [ ] **Step 3: Curl verification**

```bash
curl -s -X POST "$BASE/site/eventos" -H "Authorization: Bearer $TOKEN" -F "title=Prueba evento" -F "sort_order=abc"
# expect: HTTP 400, {"error":"sort_order debe ser un número entero"}

curl -s -X POST "$BASE/site/eventos" -H "Authorization: Bearer $TOKEN" -F "title=Prueba evento" -F "event_date=2026-13-40"
# expect: HTTP 400, {"error":"event_date debe ser una fecha válida (AAAA-MM-DD)"}

curl -s -X POST "$BASE/site/eventos" -H "Authorization: Bearer $TOKEN" -F "title=Prueba evento" -F "event_date=2026-10-05" -F "sort_order=1"
# expect: HTTP 201 with version:"1" and the new item
```

Expected: matches each comment.

- [ ] **Step 4: Commit**

```bash
git add hive-backend/site_content.php
git commit -m "Endurece eventos: contexto de actor, auditoria, 404 y validacion"
```

---

### Task 7: Servicios — actor context, audit, 404, validation, versioned response

**Files:**
- Modify: `hive-backend/site_content.php:284-345` (`siteServiciosList`, `siteServicioCreate`, `siteServicioUpdate`, `siteServicioDelete`)

**Interfaces:** same as Task 5/6.

- [ ] **Step 1: Rewrite the resource**

Replace lines 284-345 with:

```php
function siteServiciosList(PDO $pdo) {
    site_actor_context($pdo, 'site:read');
    $rows = $pdo->query('SELECT * FROM radio_services ORDER BY sort_order ASC, id ASC')->fetchAll();
    site_response_list($rows);
}

function siteServicioCreate(PDO $pdo) {
    $actor = site_actor_context($pdo, 'site:write');
    $title = site_required_text('title', 'title');
    // category/category_label agrupan servicios en RADIODOLIV_PAGINA
    // (get_services_by_category()); no hay un catálogo fijo (el director
    // puede crear categorías nuevas), pero deben venir para que el
    // agrupamiento tenga sentido.
    $category = site_required_text('category', 'category');

    $image = site_handle_image('image', 'servicios', $title, '');
    $stmt = $pdo->prepare('INSERT INTO radio_services (title, image, description, whatsapp_url, category, icon, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?)');
    $stmt->execute([
        $title,
        $image,
        site_optional_text('description'),
        site_valid_url((string) ($_POST['whatsapp_url'] ?? ''), 'whatsapp_url'),
        $category,
        site_optional_text('icon'),
        site_valid_int('sort_order', 'sort_order'),
    ]);

    $id = (int) $pdo->lastInsertId();
    $stmt = $pdo->prepare('SELECT * FROM radio_services WHERE id = ?');
    $stmt->execute([$id]);
    $item = $stmt->fetch();
    site_audit_log($pdo, $actor, 'servicios', 'create', $id, null, $item);
    site_response_item($item, 201);
}

function siteServicioUpdate(PDO $pdo, string $id) {
    $actor = site_actor_context($pdo, 'site:write');
    $stmt = $pdo->prepare('SELECT * FROM radio_services WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Servicio no encontrado', 404);

    $title = site_required_text('title', 'title');
    $category = site_required_text('category', 'category');
    $image = site_handle_image('image', 'servicios', $title, $existing['image'] ?? '');
    $stmt = $pdo->prepare('UPDATE radio_services SET title=?, image=?, description=?, whatsapp_url=?, category=?, icon=?, sort_order=? WHERE id=?');
    $stmt->execute([
        $title,
        $image,
        site_optional_text('description'),
        site_valid_url((string) ($_POST['whatsapp_url'] ?? ''), 'whatsapp_url'),
        $category,
        site_optional_text('icon'),
        site_valid_int('sort_order', 'sort_order'),
        $id,
    ]);
    if ($image !== ($existing['image'] ?? '')) {
        site_delete_old_file($existing['image'] ?? '');
    }

    $stmt = $pdo->prepare('SELECT * FROM radio_services WHERE id = ?');
    $stmt->execute([$id]);
    $item = $stmt->fetch();
    site_audit_log($pdo, $actor, 'servicios', 'update', (int) $id, $existing, $item);
    site_response_item($item);
}

function siteServicioDelete(PDO $pdo, string $id) {
    $actor = site_actor_context($pdo, 'site:delete');
    $stmt = $pdo->prepare('SELECT * FROM radio_services WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Resource not found', 404);

    $pdo->prepare('DELETE FROM radio_services WHERE id = ?')->execute([$id]);
    site_audit_log($pdo, $actor, 'servicios', 'delete', (int) $id, $existing, null);
    json_response(['version' => '1', 'ok' => true]);
}
```

**Behavior change flagged for the checkpoint:** `category` becomes required (it was silently optional before, defaulting to `''`, which would have grouped the service under an empty bucket in `get_services_by_category()` anyway). Confirm this is acceptable before merging, or relax back to `site_optional_text('category')` if some existing services intentionally have no category.

- [ ] **Step 2: Check whether relaxing is actually needed**

Run: `"/c/xampp/mysql/bin/mysql.exe" -u hive_user -p'HivePass_2026!' hive_db -e "SELECT id, title, category FROM radio_services WHERE category IS NULL OR category = '';"`
If this returns any rows, either backfill a category for them first, or change `site_required_text('category', 'category')` to `site_optional_text('category')` in both Create and Update above before proceeding.

- [ ] **Step 3: Syntax-check and curl-verify**

Run: `"/c/xampp/php/php.exe" -l hive-backend/site_content.php`
Expected: `No syntax errors detected`

```bash
curl -s -X POST "$BASE/site/servicios" -H "Authorization: Bearer $TOKEN" -F "title=Prueba servicio"
# expect: HTTP 400, {"error":"category es requerido"}  (unless Step 2 said to relax it)

curl -s -X POST "$BASE/site/servicios" -H "Authorization: Bearer $TOKEN" -F "title=Prueba servicio" -F "category=comida" -F "whatsapp_url=https://wa.me/521234567890"
# expect: HTTP 201
```

- [ ] **Step 4: Commit**

```bash
git add hive-backend/site_content.php
git commit -m "Endurece servicios: contexto de actor, auditoria, 404 y validacion"
```

---

### Task 8: Equipo — actor context, audit (incl. socials/programs snapshot), rollback, 404, validation

**Files:**
- Modify: `hive-backend/site_content.php:353-575` (team socials, program sync, `siteEquipoList/Create/Update/Delete`)

**Interfaces:**
- Consumes: Task 2/3/4 helpers; existing `site_team_with_socials()`, `site_save_team_socials()`, `site_sync_team_programs()`, `SITE_EQUIPO_CATEGORIES`, `site_equipo_category()` (all unchanged in shape, only their callers/inputs get validated).

- [ ] **Step 1: Validate `socials_json` entries inside `site_save_team_socials`**

In `site_save_team_socials` (currently line 369), change:

```php
function site_save_team_socials(PDO $pdo, int $teamId): void {
    $pdo->prepare('DELETE FROM team_socials WHERE team_id = ?')->execute([$teamId]);

    $raw = $_POST['socials_json'] ?? '[]';
    $rows = json_decode($raw, true);
    if (!is_array($rows)) return;

    $insert = $pdo->prepare('INSERT INTO team_socials (team_id, label, icon, url, sort_order) VALUES (?, ?, ?, ?, ?)');
    $order = 0;
    foreach ($rows as $row) {
        $label = trim((string) ($row['label'] ?? ''));
        $url = safe_external_url($row['url'] ?? '');
        if ($label === '' && $url === '') continue;
        $insert->execute([$teamId, $label, trim((string) ($row['icon'] ?? '')), $url, $order++]);
    }
}
```

to:

```php
function site_save_team_socials(PDO $pdo, int $teamId): void {
    $rows = site_decode_json_array((string) ($_POST['socials_json'] ?? '[]'), 'socials_json');
    $pdo->prepare('DELETE FROM team_socials WHERE team_id = ?')->execute([$teamId]);

    $insert = $pdo->prepare('INSERT INTO team_socials (team_id, label, icon, url, sort_order) VALUES (?, ?, ?, ?, ?)');
    $order = 0;
    foreach ($rows as $row) {
        $label = trim((string) ($row['label'] ?? ''));
        $rawUrl = trim((string) ($row['url'] ?? ''));
        if ($label === '' && $rawUrl === '') continue;
        $url = site_valid_url($rawUrl, "socials_json[$order].url");
        $insert->execute([$teamId, $label, trim((string) ($row['icon'] ?? '')), $url, $order++]);
    }
}
```

- [ ] **Step 2: Reuse `site_valid_ids_in_table` inside `site_sync_team_programs`**

In `site_sync_team_programs` (currently line 443), change:

```php
    $raw = trim((string) $_POST['program_ids']);
    $ids = $raw === '' ? [] : array_values(array_unique(array_filter(
        array_map('intval', explode(',', $raw)),
        fn($n) => $n > 0
    )));

    if ($ids !== []) {
        $placeholders = implode(',', array_fill(0, count($ids), '?'));
        $valid = $pdo->prepare("SELECT id FROM radio_programs WHERE id IN ($placeholders)");
        $valid->execute($ids);
        $ids = array_map('intval', $valid->fetchAll(PDO::FETCH_COLUMN));
    }
```

to:

```php
    $ids = site_valid_ids_in_table($pdo, (string) $_POST['program_ids'], 'radio_programs', 'program_ids');
```

(Behavior note: this now rejects with 400 if a `program_ids` entry doesn't exist, instead of the previous silent drop — flagged for the checkpoint same as Task 7's category change.)

- [ ] **Step 3: Rewrite `siteEquipoList/Create/Update/Delete`**

Replace lines 386-400 (`siteEquipoList`) with:

```php
function siteEquipoList(PDO $pdo) {
    site_actor_context($pdo, 'site:read');
    $rows = $pdo->query('SELECT * FROM radio_team ORDER BY sort_order ASC, id ASC')->fetchAll();
    $socialsStmt = $pdo->query('SELECT team_id, label, icon, url FROM team_socials ORDER BY team_id ASC, sort_order ASC');
    $byMember = [];
    foreach ($socialsStmt->fetchAll() as $s) {
        $byMember[$s['team_id']][] = ['label' => $s['label'], 'icon' => $s['icon'], 'url' => $s['url']];
    }
    $byHost = site_team_program_ids_by_team($pdo);
    foreach ($rows as &$row) {
        $row['socials'] = $byMember[$row['id']] ?? [];
        $row['program_ids'] = $byHost[$row['id']] ?? [];
    }
    site_response_list($rows);
}
```

Replace lines 500-575 (`siteEquipoCreate` through `siteEquipoDelete`) with:

```php
function siteEquipoCreate(PDO $pdo) {
    $actor = site_actor_context($pdo, 'site:write');
    $name = site_required_text('name', 'name');
    $category = site_equipo_category();

    $image = site_handle_image('image', 'locutores', $name, '');
    $slug = site_unique_slug($pdo, 'radio_team', $name);

    try {
        $pdo->beginTransaction();
        // El integrante más reciente siempre aparece primero: recorre a todos
        // los demás una posición y este entra en sort_order = 0.
        $pdo->exec('UPDATE radio_team SET sort_order = sort_order + 1');
        $stmt = $pdo->prepare('INSERT INTO radio_team (slug, name, role, category, accent, image, short_desc, bio, path, interests, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)');
        $stmt->execute([
            $slug,
            $name,
            site_optional_text('role'),
            $category,
            site_optional_text('accent'),
            $image,
            site_optional_text('short_desc'),
            site_equipo_text('bio'),
            site_equipo_text('path'),
            site_equipo_text('interests'),
        ]);

        $id = (int) $pdo->lastInsertId();
        site_save_team_socials($pdo, $id);
        site_sync_team_programs($pdo, $id);
        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $e;
    }

    $item = site_team_with_socials($pdo, $id);
    site_audit_log($pdo, $actor, 'equipo', 'create', $id, null, $item);
    site_response_item($item, 201);
}

function siteEquipoUpdate(PDO $pdo, string $id) {
    $actor = site_actor_context($pdo, 'site:write');
    $stmt = $pdo->prepare('SELECT * FROM radio_team WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Integrante no encontrado', 404);
    $before = site_team_with_socials($pdo, (int) $id);

    $name = site_required_text('name', 'name');
    $category = site_equipo_category();
    $image = site_handle_image('image', 'locutores', $name, $existing['image'] ?? '');

    try {
        $pdo->beginTransaction();
        // sort_order no se toca aquí a propósito: editar un integrante no debe
        // reordenar la lista (solo crear uno nuevo la reordena, ver Create).
        $stmt = $pdo->prepare('UPDATE radio_team SET name=?, role=?, category=?, accent=?, image=?, short_desc=?, bio=?, path=?, interests=? WHERE id=?');
        $stmt->execute([
            $name,
            site_optional_text('role'),
            $category,
            site_optional_text('accent'),
            $image,
            site_optional_text('short_desc'),
            site_equipo_text('bio'),
            site_equipo_text('path'),
            site_equipo_text('interests'),
            $id,
        ]);
        site_save_team_socials($pdo, (int) $id);
        site_sync_team_programs($pdo, (int) $id);
        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $e;
    }
    if ($image !== ($existing['image'] ?? '')) {
        site_delete_old_file($existing['image'] ?? '');
    }

    $item = site_team_with_socials($pdo, (int) $id);
    site_audit_log($pdo, $actor, 'equipo', 'update', (int) $id, $before, $item);
    site_response_item($item);
}

function siteEquipoDelete(PDO $pdo, string $id) {
    $actor = site_actor_context($pdo, 'site:delete');
    $stmt = $pdo->prepare('SELECT * FROM radio_team WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Resource not found', 404);
    $before = site_team_with_socials($pdo, (int) $id);

    // team_socials y radio_program_hosts tienen ON DELETE CASCADE hacia
    // radio_team.
    $pdo->prepare('DELETE FROM radio_team WHERE id = ?')->execute([$id]);
    site_audit_log($pdo, $actor, 'equipo', 'delete', (int) $id, $before, null);
    json_response(['version' => '1', 'ok' => true]);
}
```

- [ ] **Step 4: Syntax-check**

Run: `"/c/xampp/php/php.exe" -l hive-backend/site_content.php`
Expected: `No syntax errors detected`

- [ ] **Step 5: Curl verification, including the rollback path**

```bash
# happy path
curl -s -X POST "$BASE/site/equipo" -H "Authorization: Bearer $TOKEN" \
  -F "name=Prueba Locutor" -F "category=locutores" -F "socials_json=[{\"label\":\"IG\",\"url\":\"https://instagram.com/x\"}]"
# expect: HTTP 201, item.socials has one entry

# invalid social url must reject the WHOLE create (transaction rollback), not partially save
curl -s -X POST "$BASE/site/equipo" -H "Authorization: Bearer $TOKEN" \
  -F "name=Prueba Rollback" -F "category=locutores" -F "socials_json=[{\"label\":\"bad\",\"url\":\"javascript:alert(1)\"}]"
# expect: HTTP 400
curl -s "$BASE/site/equipo" -H "Authorization: Bearer $TOKEN" | grep -o "Prueba Rollback"
# expect: NO output -- the team member row must not exist (rolled back before commit,
# since site_valid_url() calls error_response()->exit() from inside site_save_team_socials(),
# which runs AFTER beginTransaction() but BEFORE commit())
```

Note: because `error_response()` calls `exit()` immediately, a validation failure inside the `try` block never reaches `$pdo->commit()` and the script terminates before Step "check whether a row was actually deleted" logic ever runs — but it ALSO means the `catch (Throwable $e)` block's `rollBack()` never executes either (there's no exception, `exit()` just ends the process). Since PHP-FPM/Apache mod_php closes the DB connection at request end, MySQL implicitly rolls back the uncommitted transaction on disconnect, so the invariant holds — but do not skip Step 5's curl check, it's the only way to confirm this assumption is actually true against this server's PDO/MySQL configuration, not just in theory.

- [ ] **Step 6: Commit**

```bash
git add hive-backend/site_content.php
git commit -m "Endurece equipo: contexto de actor, auditoria, rollback y validacion"
```

---

### Task 9: Programas — actor context, audit, rollback, 404, validation

**Files:**
- Modify: `hive-backend/site_content.php:579-786` (`siteProgramasList`, `site_programa_*` helpers, `siteProgramaCreate/Update/Delete`)

**Interfaces:** consumes Task 2/3/4 helpers plus existing `site_program_with_hosts()`, `site_sync_program_hosts()`, `site_programa_host()`, `site_programa_days_label()`.

- [ ] **Step 1: Update `siteProgramasList`**

Replace lines 579-587 with:

```php
function siteProgramasList(PDO $pdo) {
    site_actor_context($pdo, 'site:read');
    $rows = $pdo->query('SELECT * FROM radio_programs ORDER BY sort_order ASC, id ASC')->fetchAll();
    $byProgram = site_program_host_ids_by_program($pdo);
    foreach ($rows as &$row) {
        $row['host_team_ids'] = $byProgram[$row['id']] ?? [];
    }
    site_response_list($rows);
}
```

- [ ] **Step 2: Replace `site_programa_hour`/`site_programa_host` bodies with the shared validators**

Delete the whole `site_programa_hour` function (lines 708-719) — it's now `site_valid_hour` from Task 3. In `site_programa_fields` (line 632), change:

```php
    $slotStart = site_programa_hour('slot_start');
    $slotEnd = site_programa_hour('slot_end');
```

to:

```php
    $slotStart = site_valid_hour('slot_start', 'slot_start');
    $slotEnd = site_valid_hour('slot_end', 'slot_end');
```

In `site_programa_host` (line 681-706), replace the id-parsing block:

```php
    $ids = array_values(array_unique(array_filter(
        array_map('intval', explode(',', $raw)),
        fn($n) => $n > 0
    )));
    if ($ids === []) {
        return [[], trim($_POST['host'] ?? '')];
    }

    $placeholders = implode(',', array_fill(0, count($ids), '?'));
    $stmt = $pdo->prepare("SELECT id, name FROM radio_team WHERE id IN ($placeholders)");
    $stmt->execute($ids);
    $namesById = [];
    foreach ($stmt->fetchAll() as $row) {
        $namesById[(int) $row['id']] = $row['name'];
    }
    if (count($namesById) !== count($ids)) {
        error_response('Alguno de los locutores seleccionados ya no existe.', 400);
    }
    $names = array_map(fn($id) => $namesById[$id], $ids);
    return [$ids, site_join_names_with_y($names)];
```

with:

```php
    $ids = site_valid_ids_in_table($pdo, $raw, 'radio_team', 'host_team_ids');
    if ($ids === []) {
        return [[], trim($_POST['host'] ?? '')];
    }

    $placeholders = implode(',', array_fill(0, count($ids), '?'));
    $stmt = $pdo->prepare("SELECT id, name FROM radio_team WHERE id IN ($placeholders)");
    $stmt->execute($ids);
    $namesById = [];
    foreach ($stmt->fetchAll() as $row) {
        $namesById[(int) $row['id']] = $row['name'];
    }
    $names = array_map(fn($id) => $namesById[$id], $ids);
    return [$ids, site_join_names_with_y($names)];
```

(`site_valid_ids_in_table` already errors 400 on any missing id, so the old `count($namesById) !== count($ids)` re-check is now dead code and is removed.)

- [ ] **Step 3: Wrap Create/Update in `try/catch` + `rollBack`, add audit + 404 + versioned response**

Replace lines 740-786 (`siteProgramaCreate` through `siteProgramaDelete`) with:

```php
function siteProgramaCreate(PDO $pdo) {
    $actor = site_actor_context($pdo, 'site:write');
    $title = site_required_text('title', 'title');

    [$modalTitle, $host, $hostTeamIds, $schedule, $slotStart, $slotEnd, $weekdays, $badgeIcon, $badgeTime, $badgeLabel, $accent, $icon, $categories, $cardDesc, $indexDesc, $summary, $sortOrder] = site_programa_fields($pdo);
    $image = site_handle_image('image', 'programas', $title, '');
    $slug = site_unique_slug($pdo, 'radio_programs', $title);

    try {
        $pdo->beginTransaction();
        $stmt = $pdo->prepare('INSERT INTO radio_programs (slug, title, modal_title, host, schedule, slot_start, slot_end, weekdays, badge_icon, badge_time, badge_label, accent, icon, image, categories, card_desc, index_desc, summary, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
        $stmt->execute([$slug, $title, $modalTitle, $host, $schedule, $slotStart, $slotEnd, $weekdays, $badgeIcon, $badgeTime, $badgeLabel, $accent, $icon, $image, $categories, $cardDesc, $indexDesc, $summary, $sortOrder]);

        $id = (int) $pdo->lastInsertId();
        site_sync_program_hosts($pdo, $id, $hostTeamIds);
        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $e;
    }

    $item = site_program_with_hosts($pdo, $id);
    site_audit_log($pdo, $actor, 'programas', 'create', $id, null, $item);
    site_response_item($item, 201);
}

function siteProgramaUpdate(PDO $pdo, string $id) {
    $actor = site_actor_context($pdo, 'site:write');
    $stmt = $pdo->prepare('SELECT * FROM radio_programs WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Programa no encontrado', 404);
    $before = site_program_with_hosts($pdo, (int) $id);

    $title = site_required_text('title', 'title');
    [$modalTitle, $host, $hostTeamIds, $schedule, $slotStart, $slotEnd, $weekdays, $badgeIcon, $badgeTime, $badgeLabel, $accent, $icon, $categories, $cardDesc, $indexDesc, $summary, $sortOrder] = site_programa_fields($pdo);
    $image = site_handle_image('image', 'programas', $title, $existing['image'] ?? '');

    try {
        $pdo->beginTransaction();
        $stmt = $pdo->prepare('UPDATE radio_programs SET title=?, modal_title=?, host=?, schedule=?, slot_start=?, slot_end=?, weekdays=?, badge_icon=?, badge_time=?, badge_label=?, accent=?, icon=?, image=?, categories=?, card_desc=?, index_desc=?, summary=?, sort_order=? WHERE id=?');
        $stmt->execute([$title, $modalTitle, $host, $schedule, $slotStart, $slotEnd, $weekdays, $badgeIcon, $badgeTime, $badgeLabel, $accent, $icon, $image, $categories, $cardDesc, $indexDesc, $summary, $sortOrder, $id]);
        site_sync_program_hosts($pdo, (int) $id, $hostTeamIds);
        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $e;
    }
    if ($image !== ($existing['image'] ?? '')) {
        site_delete_old_file($existing['image'] ?? '');
    }

    $item = site_program_with_hosts($pdo, (int) $id);
    site_audit_log($pdo, $actor, 'programas', 'update', (int) $id, $before, $item);
    site_response_item($item);
}

function siteProgramaDelete(PDO $pdo, string $id) {
    $actor = site_actor_context($pdo, 'site:delete');
    $stmt = $pdo->prepare('SELECT * FROM radio_programs WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Resource not found', 404);
    $before = site_program_with_hosts($pdo, (int) $id);

    $pdo->prepare('DELETE FROM radio_programs WHERE id = ?')->execute([$id]);
    site_audit_log($pdo, $actor, 'programas', 'delete', (int) $id, $before, null);
    json_response(['version' => '1', 'ok' => true]);
}
```

- [ ] **Step 4: Syntax-check**

Run: `"/c/xampp/php/php.exe" -l hive-backend/site_content.php`
Expected: `No syntax errors detected`

- [ ] **Step 5: Curl verification**

```bash
curl -s -X POST "$BASE/site/programas" -H "Authorization: Bearer $TOKEN" -F "title=Prueba" -F "slot_start=10"
# expect: HTTP 400, "Indica la hora de inicio y la hora final, o deja ambas vacías."

curl -s -X POST "$BASE/site/programas" -H "Authorization: Bearer $TOKEN" -F "title=Prueba" -F "host_team_ids=999999"
# expect: HTTP 400, "host_team_ids contiene un id que ya no existe"

curl -s -X POST "$BASE/site/programas" -H "Authorization: Bearer $TOKEN" -F "title=Prueba OK" -F "slot_start=10" -F "slot_end=12"
# expect: HTTP 201
```

- [ ] **Step 6: Commit**

```bash
git add hive-backend/site_content.php
git commit -m "Endurece programas: contexto de actor, auditoria, rollback y validacion"
```

---

### Task 10: Patrocinadores — actor context, audit, rollback, 404, `map` URL validation

**Files:**
- Modify: `hive-backend/site_content.php:825-933` (sponsor socials, `sitePatrocinadoresList`, `siteSponsorCreate/Update/Delete`)

**Interfaces:** consumes Task 2/3/4 helpers.

- [ ] **Step 1: Validate `socials_json` in `site_save_sponsor_socials`**, mirroring Task 8 Step 1

Change (currently line 838):

```php
function site_save_sponsor_socials(PDO $pdo, int $sponsorId): void {
    $pdo->prepare('DELETE FROM sponsor_socials WHERE sponsor_id = ?')->execute([$sponsorId]);

    $raw = $_POST['socials_json'] ?? '[]';
    $rows = json_decode($raw, true);
    if (!is_array($rows)) return;

    $insert = $pdo->prepare('INSERT INTO sponsor_socials (sponsor_id, label, icon, url, sort_order) VALUES (?, ?, ?, ?, ?)');
    $order = 0;
    foreach ($rows as $row) {
        $label = trim((string) ($row['label'] ?? ''));
        $url = safe_external_url($row['url'] ?? '');
        if ($label === '' && $url === '') continue;
        $insert->execute([$sponsorId, $label, trim((string) ($row['icon'] ?? '')), $url, $order++]);
    }
}
```

to:

```php
function site_save_sponsor_socials(PDO $pdo, int $sponsorId): void {
    $rows = site_decode_json_array((string) ($_POST['socials_json'] ?? '[]'), 'socials_json');
    $pdo->prepare('DELETE FROM sponsor_socials WHERE sponsor_id = ?')->execute([$sponsorId]);

    $insert = $pdo->prepare('INSERT INTO sponsor_socials (sponsor_id, label, icon, url, sort_order) VALUES (?, ?, ?, ?, ?)');
    $order = 0;
    foreach ($rows as $row) {
        $label = trim((string) ($row['label'] ?? ''));
        $rawUrl = trim((string) ($row['url'] ?? ''));
        if ($label === '' && $rawUrl === '') continue;
        $url = site_valid_url($rawUrl, "socials_json[$order].url");
        $insert->execute([$sponsorId, $label, trim((string) ($row['icon'] ?? '')), $url, $order++]);
    }
}
```

- [ ] **Step 2: Rewrite `sitePatrocinadoresList/Create/Update/Delete`**

Replace lines 855-933 with:

```php
function sitePatrocinadoresList(PDO $pdo) {
    site_actor_context($pdo, 'site:read');
    $rows = $pdo->query('SELECT * FROM sponsors ORDER BY sort_order ASC, id ASC')->fetchAll();
    $socialsStmt = $pdo->query('SELECT sponsor_id, label, icon, url FROM sponsor_socials ORDER BY sponsor_id ASC, sort_order ASC');
    $bySponsor = [];
    foreach ($socialsStmt->fetchAll() as $s) {
        $bySponsor[$s['sponsor_id']][] = ['label' => $s['label'], 'icon' => $s['icon'], 'url' => $s['url']];
    }
    foreach ($rows as &$row) {
        $row['socials'] = $bySponsor[$row['id']] ?? [];
    }
    site_response_list($rows);
}

function siteSponsorCreate(PDO $pdo) {
    $actor = site_actor_context($pdo, 'site:write');
    $name = site_required_text('name', 'name');
    // `map` se inyecta como src= de un <iframe> en seccionazul.js sin
    // escapar -- debe ser siempre una URL http(s) real, nunca texto libre,
    // o un valor manipulado podría inyectar HTML en la página pública.
    $map = site_valid_url((string) ($_POST['map'] ?? ''), 'map');

    $image = site_handle_image('image', 'patrocinadores', $name, '');
    try {
        $pdo->beginTransaction();
        $stmt = $pdo->prepare('INSERT INTO sponsors (name, category, category_label, icon, image, subtitle, summary, description, map, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
        $stmt->execute([
            $name,
            site_required_text('category', 'category'),
            site_required_text('category_label', 'category_label'),
            site_optional_text('icon'),
            $image,
            site_optional_text('subtitle'),
            site_optional_text('summary'),
            trim(str_replace("\r\n", "\n", (string) ($_POST['description'] ?? ''))),
            $map,
            site_valid_int('sort_order', 'sort_order'),
        ]);
        $id = (int) $pdo->lastInsertId();
        site_save_sponsor_socials($pdo, $id);
        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $e;
    }

    $item = site_sponsor_with_socials($pdo, $id);
    site_audit_log($pdo, $actor, 'patrocinadores', 'create', $id, null, $item);
    site_response_item($item, 201);
}

function siteSponsorUpdate(PDO $pdo, string $id) {
    $actor = site_actor_context($pdo, 'site:write');
    $stmt = $pdo->prepare('SELECT * FROM sponsors WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Patrocinador no encontrado', 404);
    $before = site_sponsor_with_socials($pdo, (int) $id);

    $name = site_required_text('name', 'name');
    $map = site_valid_url((string) ($_POST['map'] ?? ''), 'map');
    $image = site_handle_image('image', 'patrocinadores', $name, $existing['image'] ?? '');

    try {
        $pdo->beginTransaction();
        $stmt = $pdo->prepare('UPDATE sponsors SET name=?, category=?, category_label=?, icon=?, image=?, subtitle=?, summary=?, description=?, map=?, sort_order=? WHERE id=?');
        $stmt->execute([
            $name,
            site_required_text('category', 'category'),
            site_required_text('category_label', 'category_label'),
            site_optional_text('icon'),
            $image,
            site_optional_text('subtitle'),
            site_optional_text('summary'),
            trim(str_replace("\r\n", "\n", (string) ($_POST['description'] ?? ''))),
            $map,
            site_valid_int('sort_order', 'sort_order'),
            $id,
        ]);
        site_save_sponsor_socials($pdo, (int) $id);
        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $e;
    }
    if ($image !== ($existing['image'] ?? '')) {
        site_delete_old_file($existing['image'] ?? '');
    }

    $item = site_sponsor_with_socials($pdo, (int) $id);
    site_audit_log($pdo, $actor, 'patrocinadores', 'update', (int) $id, $before, $item);
    site_response_item($item);
}

function siteSponsorDelete(PDO $pdo, string $id) {
    $actor = site_actor_context($pdo, 'site:delete');
    $stmt = $pdo->prepare('SELECT * FROM sponsors WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Resource not found', 404);
    $before = site_sponsor_with_socials($pdo, (int) $id);

    // sponsor_socials tiene ON DELETE CASCADE hacia sponsors.
    $pdo->prepare('DELETE FROM sponsors WHERE id = ?')->execute([$id]);
    site_audit_log($pdo, $actor, 'patrocinadores', 'delete', (int) $id, $before, null);
    json_response(['version' => '1', 'ok' => true]);
}
```

Note `category`/`category_label` become required here too (same rationale and same pre-flight check as Task 7 — run the analogous `SELECT id, name, category FROM sponsors WHERE category IS NULL OR category = '' OR category_label = '';` check before committing to `site_required_text`, and relax to `site_optional_text` if existing rows would fail).

- [ ] **Step 3: Pre-flight check + syntax-check**

Run: `"/c/xampp/mysql/bin/mysql.exe" -u hive_user -p'HivePass_2026!' hive_db -e "SELECT id, name, category, category_label, map FROM sponsors WHERE category='' OR category_label='' OR (map IS NOT NULL AND map <> '' AND map NOT LIKE 'http%');"`
If any row has a non-empty, non-http `map` value (e.g. a bare address or an already-invalid value), the `siteSponsorUpdate` validation will reject the NEXT edit of that row until its `map` is fixed via direct SQL or a one-off edit that clears it — note this as a known, one-time migration nuisance rather than a bug, and fix any such rows now:
Run: `"/c/xampp/mysql/bin/mysql.exe" -u hive_user -p'HivePass_2026!' hive_db -e "UPDATE sponsors SET map='' WHERE map IS NOT NULL AND map <> '' AND map NOT LIKE 'http%';"` (only if the previous SELECT found such rows).

Run: `"/c/xampp/php/php.exe" -l hive-backend/site_content.php`
Expected: `No syntax errors detected`

- [ ] **Step 4: Curl verification**

```bash
curl -s -X POST "$BASE/site/patrocinadores" -H "Authorization: Bearer $TOKEN" \
  -F "name=Prueba" -F "category=comida" -F "category_label=Comida" -F 'map=<script>alert(1)</script>'
# expect: HTTP 400, "map no es una URL válida ..."

curl -s -X POST "$BASE/site/patrocinadores" -H "Authorization: Bearer $TOKEN" \
  -F "name=Prueba" -F "category=comida" -F "category_label=Comida" -F "map=https://maps.google.com/embed?x=1"
# expect: HTTP 201
```

- [ ] **Step 5: Commit**

```bash
git add hive-backend/site_content.php
git commit -m "Endurece patrocinadores: contexto de actor, auditoria, rollback y validacion de map"
```

---

### Task 11: Podcasts — actor context, audit, rollback, 404, episode validation + orphaned episode-audio cleanup

**Files:**
- Modify: `hive-backend/site_content.php:937-1032` (`site_save_podcast_episodes`, `sitePodcastsList`, `sitePodcastCreate/Update/Delete`)

**Interfaces:** consumes Task 2/3/4 helpers; `site_save_podcast_episodes` signature changes from `void` to `array` (returns orphaned audio paths to delete post-commit).

- [ ] **Step 1: Rewrite `site_save_podcast_episodes` to validate episodes and report orphaned audio**

Change (currently line 949):

```php
function site_save_podcast_episodes(PDO $pdo, int $podcastId): void {
    $pdo->prepare('DELETE FROM radio_podcast_episodes WHERE podcast_id = ?')->execute([$podcastId]);

    $raw = $_POST['episodes_json'] ?? '[]';
    $rows = json_decode($raw, true);
    if (!is_array($rows)) return;

    $insert = $pdo->prepare('INSERT INTO radio_podcast_episodes (podcast_id, title, description, audio_url, category_label, sort_order) VALUES (?, ?, ?, ?, ?, ?)');
    $order = 0;
    foreach ($rows as $row) {
        $title = trim((string) ($row['title'] ?? ''));
        if ($title === '') continue;
        $existingAudio = trim((string) ($row['audio_url'] ?? ''));
        $audioUrl = site_handle_audio("episode_audio_$order", 'podcasts', $title, $existingAudio);
        $insert->execute([
            $podcastId,
            $title,
            trim((string) ($row['description'] ?? '')),
            $audioUrl,
            trim((string) ($row['category_label'] ?? '')),
            $order++,
        ]);
    }
}
```

to:

```php
// Reemplaza por completo los episodios de un podcast con los que llegaron
// en $_POST['episodes_json']. Devuelve las rutas de audio que quedaron
// huérfanas (reemplazadas o eliminadas) para que el llamador las borre
// DESPUÉS de un commit exitoso -- nunca aquí dentro, porque si la
// transacción se revierte esos archivos todavía pertenecen a la fila que
// sigue existiendo.
function site_save_podcast_episodes(PDO $pdo, int $podcastId): array {
    $oldAudioStmt = $pdo->prepare('SELECT audio_url FROM radio_podcast_episodes WHERE podcast_id = ?');
    $oldAudioStmt->execute([$podcastId]);
    $oldAudioUrls = array_values(array_filter($oldAudioStmt->fetchAll(PDO::FETCH_COLUMN)));

    $rows = site_decode_json_array((string) ($_POST['episodes_json'] ?? '[]'), 'episodes_json');
    $pdo->prepare('DELETE FROM radio_podcast_episodes WHERE podcast_id = ?')->execute([$podcastId]);

    $insert = $pdo->prepare('INSERT INTO radio_podcast_episodes (podcast_id, title, description, audio_url, category_label, sort_order) VALUES (?, ?, ?, ?, ?, ?)');
    $order = 0;
    $keptAudioUrls = [];
    foreach ($rows as $row) {
        $title = trim((string) ($row['title'] ?? ''));
        if ($title === '') {
            error_response("episodes_json[$order].title es requerido", 400);
        }
        $existingAudio = trim((string) ($row['audio_url'] ?? ''));
        $audioUrl = site_handle_audio("episode_audio_$order", 'podcasts', $title, $existingAudio);
        $keptAudioUrls[] = $audioUrl;
        $insert->execute([
            $podcastId,
            $title,
            trim((string) ($row['description'] ?? '')),
            $audioUrl,
            trim((string) ($row['category_label'] ?? '')),
            $order++,
        ]);
    }

    return array_values(array_diff($oldAudioUrls, $keptAudioUrls));
}
```

- [ ] **Step 2: Rewrite `sitePodcastsList/Create/Update/Delete`**

Replace lines 974-1032 with:

```php
function sitePodcastsList(PDO $pdo) {
    site_actor_context($pdo, 'site:read');
    $rows = $pdo->query('SELECT * FROM radio_podcasts ORDER BY sort_order ASC, id ASC')->fetchAll();
    $episodesStmt = $pdo->query('SELECT podcast_id, title, description, audio_url, category_label FROM radio_podcast_episodes ORDER BY podcast_id ASC, sort_order ASC');
    $byPodcast = [];
    foreach ($episodesStmt->fetchAll() as $e) {
        $byPodcast[$e['podcast_id']][] = ['title' => $e['title'], 'description' => $e['description'], 'audio_url' => $e['audio_url'], 'category_label' => $e['category_label']];
    }
    foreach ($rows as &$row) {
        $row['episodes'] = $byPodcast[$row['id']] ?? [];
    }
    site_response_list($rows);
}

function sitePodcastCreate(PDO $pdo) {
    $actor = site_actor_context($pdo, 'site:write');
    $title = site_required_text('title', 'title');

    $cover = site_handle_image('cover', 'portadas', $title, '');
    $slug = site_unique_slug($pdo, 'radio_podcasts', $title);

    try {
        $pdo->beginTransaction();
        $stmt = $pdo->prepare('INSERT INTO radio_podcasts (slug, title, filter_icon, cover, sort_order) VALUES (?, ?, ?, ?, ?)');
        $stmt->execute([$slug, $title, site_optional_text('filter_icon'), $cover, site_valid_int('sort_order', 'sort_order')]);
        $id = (int) $pdo->lastInsertId();
        $orphanedAudio = site_save_podcast_episodes($pdo, $id);
        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $e;
    }
    foreach ($orphanedAudio as $path) {
        site_delete_old_file($path);
    }

    $item = site_podcast_with_episodes($pdo, $id);
    site_audit_log($pdo, $actor, 'podcasts', 'create', $id, null, $item);
    site_response_item($item, 201);
}

function sitePodcastUpdate(PDO $pdo, string $id) {
    $actor = site_actor_context($pdo, 'site:write');
    $stmt = $pdo->prepare('SELECT * FROM radio_podcasts WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Podcast no encontrado', 404);
    $before = site_podcast_with_episodes($pdo, (int) $id);

    $title = site_required_text('title', 'title');
    $cover = site_handle_image('cover', 'portadas', $title, $existing['cover'] ?? '');

    try {
        $pdo->beginTransaction();
        $stmt = $pdo->prepare('UPDATE radio_podcasts SET title=?, filter_icon=?, cover=?, sort_order=? WHERE id=?');
        $stmt->execute([$title, site_optional_text('filter_icon'), $cover, site_valid_int('sort_order', 'sort_order'), $id]);
        $orphanedAudio = site_save_podcast_episodes($pdo, (int) $id);
        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $e;
    }
    if ($cover !== ($existing['cover'] ?? '')) {
        site_delete_old_file($existing['cover'] ?? '');
    }
    foreach ($orphanedAudio as $path) {
        site_delete_old_file($path);
    }

    $item = site_podcast_with_episodes($pdo, (int) $id);
    site_audit_log($pdo, $actor, 'podcasts', 'update', (int) $id, $before, $item);
    site_response_item($item);
}

function sitePodcastDelete(PDO $pdo, string $id) {
    $actor = site_actor_context($pdo, 'site:delete');
    $stmt = $pdo->prepare('SELECT * FROM radio_podcasts WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Resource not found', 404);
    $before = site_podcast_with_episodes($pdo, (int) $id);

    // radio_podcast_episodes tiene ON DELETE CASCADE hacia radio_podcasts.
    $pdo->prepare('DELETE FROM radio_podcasts WHERE id = ?')->execute([$id]);
    site_audit_log($pdo, $actor, 'podcasts', 'delete', (int) $id, $before, null);
    json_response(['version' => '1', 'ok' => true]);
}
```

Note the deleted podcast's episode audio files and cover are intentionally NOT cleaned up synchronously here — the cascade delete removes the DB rows, and Task 13's maintenance script sweeps the resulting orphaned files. (Doing it inline would need to re-fetch every episode's `audio_url` before the cascade delete and is a reasonable follow-up, but the maintenance sweep already covers it and keeps this delete handler simple and fast.)

- [ ] **Step 3: Syntax-check**

Run: `"/c/xampp/php/php.exe" -l hive-backend/site_content.php`
Expected: `No syntax errors detected`

- [ ] **Step 4: Curl verification**

```bash
curl -s -X POST "$BASE/site/podcasts" -H "Authorization: Bearer $TOKEN" \
  -F "title=Prueba Podcast" -F 'episodes_json=[{"title":""}]'
# expect: HTTP 400, "episodes_json[0].title es requerido"

curl -s -X POST "$BASE/site/podcasts" -H "Authorization: Bearer $TOKEN" \
  -F "title=Prueba Podcast" -F 'episodes_json=[{"title":"Ep1"}]' \
  -F "episode_audio_0=@/path/to/small.mp3"
# expect: HTTP 201, item.episodes[0].audio_url set

# oversized audio (create or find a >100MB file first, e.g. `fallocate -l 101M big.mp3` on WSL,
# or on Windows: fsutil file createnew big.mp3 106000000)
curl -s -X POST "$BASE/site/podcasts" -H "Authorization: Bearer $TOKEN" \
  -F "title=Prueba Grande" -F 'episodes_json=[{"title":"Ep1"}]' \
  -F "episode_audio_0=@big.mp3"
# expect: HTTP 400, "El audio supera el tamaño máximo permitido (100 MB)"
```

- [ ] **Step 5: Commit**

```bash
git add hive-backend/site_content.php
git commit -m "Endurece podcasts: contexto de actor, auditoria, rollback y limpieza de audio huerfano"
```

---

### Task 12: Orphan-file maintenance sweep script

**Files:**
- Create: `hive-backend/site_content_orphan_cleanup.php`

**Interfaces:**
- Consumes: `config.php` (for `RADIODOLIV_PAGINA_PATH` and `$pdo`), no new shared functions produced (this is a standalone CLI script, not `require`d from `index.php`).

- [ ] **Step 1: Write the script**

```php
<?php
// Script de mantenimiento: recorre RADIODOLIV_PAGINA/assets/img/* y
// assets/audio/* y borra los archivos que ya no están referenciados por
// ninguna fila de las tablas que site_content.php administra. Cubre los
// huérfanos que site_content.php no limpia en el momento (p. ej. audio de
// episodios de un podcast que se borró por completo -- ver Task 11).
//
// Uso: php site_content_orphan_cleanup.php [--dry-run]
//   --dry-run  Solo imprime qué borraría, no borra nada. Úsalo siempre la
//              primera vez que corras esto en un servidor nuevo.
//
// NUNCA borra nada fuera de RADIODOLIV_PAGINA_PATH/assets, sin excepción.

require __DIR__ . '/config.php';

$dryRun = in_array('--dry-run', $argv, true);

// [directorio relativo a assets/, columna(s) que referencian archivos ahí]
$sources = [
    ['img/anuncios',        'anuncios',               ['imagen_url']],
    ['img/eventos',         'radio_events',           ['image']],
    ['img/servicios',       'radio_services',         ['image']],
    ['img/locutores',       'radio_team',             ['image']],
    ['img/programas',       'radio_programs',         ['image']],
    ['img/patrocinadores',  'sponsors',               ['image']],
    ['img/portadas',        'radio_podcasts',         ['cover']],
    ['audio/podcasts',      'radio_podcast_episodes', ['audio_url']],
];

$deleted = 0;
$kept = 0;

foreach ($sources as [$relDir, $table, $columns]) {
    $dir = RADIODOLIV_PAGINA_PATH . '/assets/' . $relDir;
    if (!is_dir($dir)) continue;

    $referenced = [];
    foreach ($columns as $column) {
        $stmt = $pdo->query("SELECT `$column` FROM `$table` WHERE `$column` IS NOT NULL AND `$column` <> ''");
        foreach ($stmt->fetchAll(PDO::FETCH_COLUMN) as $path) {
            $referenced[basename($path)] = true;
        }
    }

    foreach (scandir($dir) as $file) {
        if ($file === '.' || $file === '..') continue;
        $fullPath = $dir . '/' . $file;
        if (!is_file($fullPath)) continue;

        if (isset($referenced[$file])) {
            $kept++;
            continue;
        }

        echo ($dryRun ? '[dry-run] borraría: ' : 'borrando: ') . "assets/$relDir/$file" . PHP_EOL;
        if (!$dryRun) {
            @unlink($fullPath);
        }
        $deleted++;
    }
}

echo PHP_EOL . ($dryRun ? "Total a borrar: $deleted" : "Total borrado: $deleted") . " (referenciados y conservados: $kept)" . PHP_EOL;
```

- [ ] **Step 2: Syntax-check and dry-run against the local DB**

Run: `"/c/xampp/php/php.exe" -l hive-backend/site_content_orphan_cleanup.php`
Expected: `No syntax errors detected`

Run: `"/c/xampp/php/php.exe" hive-backend/site_content_orphan_cleanup.php --dry-run`
Expected: a list of `[dry-run] borraría: ...` lines (if any orphans already exist from before this plan) followed by a `Total a borrar: N` summary. Inspect the listed files manually before ever running it without `--dry-run` — confirm none of them are one of the test uploads created during this plan's own curl verification steps that you actually want to keep, or files referenced by RADIODOLIV_PAGINA content this backend doesn't know about (there should be none, since site_content.php is the only writer of these directories, but confirm).

- [ ] **Step 3: Commit**

```bash
git add hive-backend/site_content_orphan_cleanup.php
git commit -m "Agrega script de mantenimiento para archivos huerfanos de site_content"
```

---

### Task 13: Developer documentation for the multipart contract

**Files:**
- Create: `docs/site-content-api.md`

**Interfaces:** none (documentation only) — but every field name, JSON field, and error message documented here MUST match Tasks 5-11 exactly, since this doc is the thing beta_web's developers will actually read instead of the PHP source.

- [ ] **Step 1: Write the document**

Structure it with one `##` section per resource (anuncios, eventos, servicios, equipo, programas, patrocinadores, podcasts), and inside each, one `###` per endpoint (List/Create/Update/Delete). For each endpoint include, in this order: HTTP method + URL, auth (both methods, referencing `docs/site-content-api.md#autenticacion`), required fields, optional fields, file field names + size/extension limits, JSON-encoded fields with their inner shape, one example `curl` request, one example JSON response, and the common error responses with their status codes. Open with an `## Autenticación` section covering both auth paths (director session Bearer token; `X-Api-Key` header, referencing `SITE_CONTENT_SCOPES`) and a top-level note about the `version` field Task 2 added to every response. Pull every field name, default, and error message straight from the final code in Tasks 5-11 (write this task last, after all of them are committed, so nothing drifts) — do not invent field names not present in the code.

Below is the required content for the `equipo` resource as a concrete example other sections must match in depth and format (the doc must cover routes for anuncios, eventos, servicios, equipo, programas, patrocinadores and podcasts):

```markdown
# API de contenido del sitio público (`/site/*`)

Gestiona el contenido de RADIODOLIV_PAGINA (anuncios, eventos, servicios,
equipo, programas, patrocinadores, podcasts) desde `hive-backend`. Todas las
respuestas incluyen `"version": "1"` junto al payload existente.

## Autenticación

Dos formas, ambas siguen funcionando siempre:

1. **Sesión de director** (app Flutter): `Authorization: Bearer <token>` de
   un usuario con `role = 'director'`.
2. **Llave de API** (integración interna, p. ej. beta_web): cabecera
   `X-Api-Key: <SITE_CONTENT_KEY>`. En producción (`APP_ENV=production`) la
   llave debe tener 32+ caracteres o el servidor responde 500 en cada
   petición. Hoy la llave tiene acceso total (`site:read`, `site:write`,
   `site:delete`); el campo `scopes` del contexto interno deja preparada la
   estructura para llaves más restringidas en el futuro sin cambiar el
   contrato HTTP.

Errores comunes: `401 {"error":"Missing Authorization header"}`,
`401 {"error":"Invalid or expired token"}`,
`403 {"error":"No tienes permiso para realizar esta acción"}`.

## Equipo (`radio_team`)

### `GET /site/equipo` — listar

Requiere: sesión de director o `X-Api-Key`.

Respuesta 200:
```json
{
  "version": "1",
  "items": [
    {
      "id": 1, "slug": "fernanda-r", "name": "Fernanda R.", "role": "Conductora",
      "category": "locutores", "accent": "#ff6b35", "image": "assets/img/locutores/fernanda-r-a1b2c3d4.jpg",
      "short_desc": "...", "bio": "...", "path": "...", "interests": "...", "sort_order": 0,
      "socials": [{"label": "Instagram", "icon": "instagram", "url": "https://instagram.com/x"}],
      "program_ids": [3, 7]
    }
  ]
}
```

### `POST /site/equipo` — crear

Multipart form fields:

- `name` (requerido, texto)
- `category` (requerido, uno de: `locutores`, `reporteros`)
- `role`, `accent`, `short_desc` (opcionales, texto)
- `bio`, `path`, `interests` (opcionales, texto multilínea — una idea por línea; `bio` usa líneas en blanco para separar párrafos)
- `image` (opcional, archivo — jpg/jpeg/png/gif/webp, máx. 5 MB, debe ser una imagen real)
- `socials_json` (opcional, JSON: `[{"label": "Instagram", "icon": "instagram", "url": "https://..."}]` — cada `url` debe ser http(s) válida o la petición entera se rechaza)
- `program_ids` (opcional, ids de `radio_programs` separados por coma — vincula este integrante como conductor de esos programas; cualquier id inexistente rechaza la petición completa)

Ejemplo:

```bash
curl -X POST http://localhost/hive-backend/site/equipo \
  -H "Authorization: Bearer $TOKEN" \
  -F "name=Fernanda R." -F "category=locutores" \
  -F "socials_json=[{\"label\":\"Instagram\",\"icon\":\"instagram\",\"url\":\"https://instagram.com/x\"}]" \
  -F "program_ids=3,7" \
  -F "image=@fernanda.jpg"
```

Respuesta 201: mismo shape que un elemento de `items` arriba, envuelto en `{"version": "1", "item": {...}}`.

Errores: `400 {"error":"name es requerido"}`, `400 {"error":"category debe ser \"locutores\" o \"reporteros\"."}`, `400 {"error":"La imagen supera el tamaño máximo permitido (5 MB)"}`, `400 {"error":"socials_json[0].url no es una URL válida (debe empezar con http:// o https://)"}`, `400 {"error":"program_ids contiene un id que ya no existe"}`.

### `POST /site/equipo/{id}` — actualizar

Mismos campos que crear. `image` es opcional: si no se manda, conserva la imagen actual; si se manda una nueva, la anterior se borra del servidor tras guardar con éxito. `sort_order` no se puede editar aquí (solo cambia al crear un integrante nuevo, que reordena a todos los demás).

Errores adicionales: `404 {"error":"Integrante no encontrado"}`.

### `POST /site/equipo/{id}/delete` — eliminar

Borra el integrante y sus redes sociales (`ON DELETE CASCADE`) y sus vínculos de programa.

Respuesta 200: `{"version": "1", "ok": true}`. Si el id no existe: `404 {"error": "Resource not found"}`.
```

Repeat this depth for anuncios, eventos, servicios, programas, patrocinadores and podcasts, pulling exact field names/validators from the corresponding task above (e.g. podcasts documents `episode_audio_{n}` file fields and the `episodes_json` shape `{title, description, audio_url, category_label}`; programas documents `slot_start`/`slot_end`/`weekdays`/`host_team_ids`; patrocinadores documents the `map` URL requirement and why it's strict).

- [ ] **Step 2: Cross-check the doc against the code**

For each resource section written, re-open the corresponding function in `hive-backend/site_content.php` (post Tasks 5-11) and confirm every `$_POST[...]`/`$_FILES[...]` key mentioned in the doc appears verbatim in the code, and vice versa (no documented field that doesn't exist, no code field left undocumented).

- [ ] **Step 3: Commit**

```bash
git add docs/site-content-api.md
git commit -m "Documenta el contrato multipart de /site/*"
```

---

### Task 14: Final verification pass

**Files:** none modified — this task only runs checks across everything above.

- [ ] **Step 1: Syntax-check every touched file at once**

Run: `for f in hive-backend/config.php hive-backend/index.php hive-backend/site_audit.php hive-backend/site_validation.php hive-backend/site_content.php hive-backend/site_content_orphan_cleanup.php; do "/c/xampp/php/php.exe" -l "$f"; done`
Expected: `No syntax errors detected` six times, no `Errors parsing ...` lines.

- [ ] **Step 2: Full resource matrix over both auth methods**

For each of the 7 resources (`anuncios`, `eventos`, `servicios`, `equipo`, `programas`, `patrocinadores`, `podcasts`), run list/create/update/delete once with `-H "Authorization: Bearer $TOKEN"` and once with `-H "X-Api-Key: $(grep ^SITE_CONTENT_KEY hive-backend/.env | cut -d= -f2)"` (set `SITE_CONTENT_KEY` in `.env` first if it's currently empty — copy the generation command from `.env.example`). Confirm both produce `version: "1"` and identical shapes, and that both a create and an update via the API-key path also land rows in `site_content_audit_log` with `actor_type = 'api_key'` and `actor_email` NULL.

- [ ] **Step 3: Confirm the public site still reads correctly**

Open `http://localhost/RADIODOLIV_PAGINA/pages/equipo.php`, `.../servicios.php`, `.../seccionazul.php`, `.../podcast.php` (and home for anuncios/eventos) in a browser and visually confirm the content created/edited during Step 2's testing appears correctly, including any image/audio uploaded.

- [ ] **Step 4: Confirm the Flutter app's existing site-content screens still work unmodified**

Run the Flutter app (director account) against local `hive-backend`, open its "contenido del sitio" screens for at least 2 of the 7 resources, and perform one real create/edit/delete through the UI (not curl) to confirm no request the app sends was broken by the added validation (e.g. a field the app always sends empty that's now required would surface here as an unexpected 400).

- [ ] **Step 5: Clean up test data**

Delete every test row created during Steps 2-4 (`anuncios`/`radio_events`/etc. rows titled "Prueba ..."), and run `"/c/xampp/php/php.exe" hive-backend/site_content_orphan_cleanup.php --dry-run` once more to confirm their uploaded test images/audio are now listed as orphaned, then re-run without `--dry-run` to actually remove them.

- [ ] **Step 6: Final commit if any fixes were needed**

If Steps 2-5 surfaced any bug (e.g. a required-field regression against what the Flutter app actually sends), fix it in the relevant resource's file from Tasks 5-11, re-run that task's own syntax-check and curl steps, then:

```bash
git add hive-backend/site_content.php
git commit -m "Corrige regresion detectada en verificacion final de site_content"
```

If nothing needed fixing, this task produces no commit — verification-only tasks are allowed to end without one.

---

## Self-Review Notes

- **Spec coverage:** #1 audit logging → Tasks 1-2 (table) + 5-11 (calls at every create/update/delete). #2 API key hardening → Task 2 (`hash_equals` already existed and is preserved; production length check + distinct `actor_type` + scope structure added). #3 upload size limits → Task 4. #4 orphaned files → Task 4 (helper) + 5-11 (call sites) + Task 12 (sweep for what synchronous cleanup can't reach, e.g. cascade-deleted podcast episodes). #5 404 on delete → Tasks 5-11. #6 transaction rollbacks → Tasks 8-11 (the only resources with `beginTransaction()`). #7 field validation → Task 3 (helpers) + Tasks 5-11 (applied per field, per resource). #8 actor/authorization separation → Task 2 (`site_actor_context()` replaces `site_require_director()` everywhere in Tasks 5-11). #9 documentation → Task 13. #10 versioning → Task 2 (`site_response_item`/`site_response_list`) + Tasks 5-11 (adopted everywhere, no route changes). Verification section → Task 14.
- **Placeholder scan:** every step above contains literal code, literal curl commands with expected output, or a literal SQL query — no "add appropriate validation"-style steps remain.
- **Type consistency:** `site_actor_context()` return shape is defined once in Task 2 and consumed identically in Tasks 5-11 (`$actor['actor_type']`/`actor_id`/`actor_email` read only inside `site_audit_log()`, never destructured differently per resource). `site_save_podcast_episodes()`'s signature change from `void` to `array` is called out explicitly in Task 11 Step 1 and its only two call sites (Create/Update, both in Task 11 Step 2) are updated in the same task.
