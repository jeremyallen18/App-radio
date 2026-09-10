# Vinculación de dispositivo y verificación biométrica en el fichaje — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Impedir que un empleado registre asistencia prestando su cuenta/teléfono a un compañero, vinculando cada cuenta a un solo dispositivo y exigiendo verificación biométrica del sistema operativo en entrada y salida.

**Architecture:** El backend PHP (`hive-backend/attendance.php` + `attendance_admin.php`) gana un paso de verificación de dispositivo intercalado en el pipeline de fichaje, más columnas de evidencia inmutables en `attendance`. Un dispositivo se vincula por *trust-on-first-use*; los cambios los aprueba el director desde una pantalla nueva. La app Flutter recoge un identificador estable de dispositivo (`ANDROID_ID` / `identifierForVendor`) y ejecuta `local_auth` antes de llamar al endpoint.

**Tech Stack:** PHP 8 + PDO/MySQL (`hive_db`); Flutter/Dart; paquetes nuevos `device_info_plus`, `android_id`, `package_info_plus`; ya presentes `local_auth`, `flutter_secure_storage`, `geolocator`, `http`.

**Spec:** `App-radio/docs/superpowers/specs/2026-09-09-asistencia-vinculacion-dispositivo-biometria-design.md`

## Global Constraints

- **1 dispositivo confiado por cuenta.** `attendance_trusted_devices.employee_id` es PRIMARY KEY.
- **Solo hashes en la base:** en el servidor se guarda `hash('sha256', $raw)` de `deviceKey` y `deviceUuid`; el valor crudo nunca se persiste.
- **Biometría obligatoria solo en `entrada` y `salida`.** El resto de eventos (`inicio_comida`, `fin_comida`, `salida`… perdón: `inicio_comida`, `fin_comida`, `sin_comida`) exigen dispositivo confiado pero **no** biometría.
- **Verificación de dispositivo en TODOS los eventos de fichaje** (`entrada`, `inicio_comida`, `fin_comida`, `salida`, `sin_comida`).
- **Alcance de usuarios:** `employee` y `manager` (ambos fichan). El `director` nunca ficha.
- **Solo el director** resuelve solicitudes de dispositivo y ve la pantalla "Dispositivos de asistencia". El `manager` recibe 403.
- **Aprobar una solicitud reemplaza** el dispositivo confiado anterior (es 1 solo): `REPLACE INTO attendance_trusted_devices`.
- **Marca oficial = hora del servidor** (sin cambios). `locationAccuracy`, `deviceTime` y demás datos del cliente son solo evidencia.
- **Códigos de error nuevos del backend:** `UNKNOWN_DEVICE` (409), `BIOMETRIC_REQUIRED` (409). La app ya propaga `AttendanceException.code`.
- **Mensajes al usuario en español**, tono del módulo actual (ver `attendance.php`: "Estás fuera de la zona autorizada…").
- **Migración:** archivo `hive-backend/migrations/033_attendance_device_binding.sql` + actualización manual de `hive-backend/schema.sql` (patrón del repo).
- **Tests de backend:** scripts en `hive-backend/scratchpad/test_*.php`, se ejecutan con `C:\xampp\php\php.exe scratchpad/test_xxx.php` desde `hive-backend/`; usan `require '../config.php'` (da `$pdo`) y `require '../helpers.php'`. Patrón `check(string $name, bool $ok)` + `register_shutdown_function('cleanup', ...)`.
- **Tests de Flutter:** `flutter test test/<archivo>_test.dart` desde `App-radio/`.

---

## File Structure

**Backend (crea):**
- `hive-backend/migrations/033_attendance_device_binding.sql` — DDL.
- `hive-backend/attendance_device.php` — helpers de identidad/verificación de dispositivo. Cargado por `index.php` junto a los otros `attendance*.php`.
- `hive-backend/scratchpad/test_attendance_device_binding.php` — harness backend.

**Backend (modifica):**
- `hive-backend/schema.sql` — refleja la migración 033.
- `hive-backend/index.php` — `require` del archivo nuevo + rutas.
- `hive-backend/attendance.php` — pipeline de fichaje + `attendance_insert_event()` + endpoints del trabajador.
- `hive-backend/attendance_admin.php` — endpoints del director.

**Flutter (crea):**
- `lib/core/device/device_identity.dart` — identificador estable + metadatos + UUID persistido.
- `lib/core/device/biometric_gate.dart` — envoltura de `local_auth`.
- `lib/features/dashboard/director/attendance_devices_screen.dart` — panel del director.
- `test/attendance_device_binding_test.dart` — tests unitarios/widget.

**Flutter (modifica):**
- `pubspec.yaml` — 3 dependencias nuevas.
- `lib/services/attendance_service.dart` — `perform()` extendido + métodos nuevos.
- `lib/models/attendance.dart` — modelos `AttendanceDeviceStatus`, `DeviceRequestRow`, `TrustedDeviceInfo`, `DeviceAnomaly`.
- `lib/shared/attendance/attendance_screen.dart` — biometría + identidad + estados nuevos en `_perform` + banner de estado.
- `lib/shared/widgets/app_menu_sections.dart` — entrada de menú del director.

---

## Task 1: Migración 033 + schema.sql

**Files:**
- Create: `hive-backend/migrations/033_attendance_device_binding.sql`
- Modify: `hive-backend/schema.sql`
- Test: `hive-backend/scratchpad/test_device_migration.php`

**Interfaces:**
- Consumes: nada.
- Produces: tablas `attendance_trusted_devices`, `attendance_device_requests`; columnas nuevas en `attendance`: `location_accuracy_m DECIMAL(6,1)`, `device_key VARCHAR(64)`, `device_status ENUM('trusted','first_use','director_approved')`, `biometric_result ENUM('ok','skipped','failed')`, `biometric_type VARCHAR(20)`.

- [ ] **Step 1: Write the failing test**

Create `hive-backend/scratchpad/test_device_migration.php`:

```php
<?php
// Verifica que la migración 033 dejó el esquema esperado.
// Uso: C:\xampp\php\php.exe scratchpad/test_device_migration.php
require __DIR__ . '/../config.php';

$pass = 0; $fail = 0;
function check(string $name, bool $ok): void {
    global $pass, $fail;
    echo ($ok ? "  OK   " : "  FAIL ") . $name . "\n";
    $ok ? $pass++ : $fail++;
}

function column(PDO $pdo, string $table, string $col): ?array {
    $st = $pdo->prepare(
        'SELECT DATA_TYPE, COLUMN_TYPE, IS_NULLABLE
         FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?'
    );
    $st->execute([$table, $col]);
    return $st->fetch() ?: null;
}
function tableExists(PDO $pdo, string $table): bool {
    $st = $pdo->prepare(
        'SELECT 1 FROM information_schema.TABLES
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?'
    );
    $st->execute([$table]);
    return (bool) $st->fetch();
}

check('tabla attendance_trusted_devices existe', tableExists($pdo, 'attendance_trusted_devices'));
check('tabla attendance_device_requests existe', tableExists($pdo, 'attendance_device_requests'));

check('attendance.device_key es varchar(64) nullable',
    (function () use ($pdo) {
        $c = column($pdo, 'attendance', 'device_key');
        return $c && $c['COLUMN_TYPE'] === 'varchar(64)' && $c['IS_NULLABLE'] === 'YES';
    })());
check('attendance.device_status es el enum esperado',
    (function () use ($pdo) {
        $c = column($pdo, 'attendance', 'device_status');
        return $c && $c['COLUMN_TYPE'] === "enum('trusted','first_use','director_approved')";
    })());
check('attendance.biometric_result es el enum esperado',
    (function () use ($pdo) {
        $c = column($pdo, 'attendance', 'biometric_result');
        return $c && $c['COLUMN_TYPE'] === "enum('ok','skipped','failed')";
    })());
check('attendance.biometric_type existe', column($pdo, 'attendance', 'biometric_type') !== null);
check('attendance.location_accuracy_m existe', column($pdo, 'attendance', 'location_accuracy_m') !== null);

check('trusted_devices.employee_id es PRIMARY KEY',
    (function () use ($pdo) {
        $st = $pdo->query(
            "SELECT COLUMN_KEY FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'attendance_trusted_devices'
               AND COLUMN_NAME = 'employee_id'"
        );
        $r = $st->fetch();
        return $r && $r['COLUMN_KEY'] === 'PRI';
    })());
check('device_requests tiene índice único (employee_id, device_key)',
    (function () use ($pdo) {
        $st = $pdo->query(
            "SHOW INDEX FROM attendance_device_requests WHERE Key_name = 'uq_att_dev_req'"
        );
        return count($st->fetchAll()) === 2;
    })());

echo "\n$pass passed, $fail failed\n";
exit($fail === 0 ? 0 : 1);
```

- [ ] **Step 2: Run test to verify it fails**

Run (desde `hive-backend/`): `C:\xampp\php\php.exe scratchpad/test_device_migration.php`
Expected: FAIL — "tabla attendance_trusted_devices existe" y las columnas fallan (aún no existen).

- [ ] **Step 3: Write the migration**

Create `hive-backend/migrations/033_attendance_device_binding.sql`:

```sql
-- Migración: vinculación de dispositivo + evidencia biométrica en el fichaje.
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado (instalaciones nuevas parten de ahí).
--
-- Cada cuenta que ficha (employee / manager) queda atada a UN dispositivo
-- confiado. El primero se registra por "trust-on-first-use"; cualquier cambio
-- lo aprueba el director. En la base solo se guardan HASHES (sha256) de los
-- identificadores del dispositivo, nunca el valor crudo.
USE hive_db;

CREATE TABLE IF NOT EXISTS attendance_trusted_devices (
  employee_id  CHAR(24) NOT NULL PRIMARY KEY,
  device_key   VARCHAR(64) NOT NULL,        -- sha256(ANDROID_ID | IDFV) o, si faltó, sha256(uuid)
  device_uuid  VARCHAR(64) NULL,            -- sha256(uuid de secure storage)
  platform     ENUM('android','ios') NOT NULL,
  model        VARCHAR(120) NULL,
  os_version   VARCHAR(60) NULL,
  app_version  VARCHAR(30) NULL,
  enrolled_at  DATETIME NOT NULL,
  enrolled_via ENUM('first_use','director') NOT NULL DEFAULT 'first_use',
  approved_by  CHAR(24) NULL,
  FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS attendance_device_requests (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  employee_id  CHAR(24) NOT NULL,
  device_key   VARCHAR(64) NOT NULL,
  device_uuid  VARCHAR(64) NULL,
  platform     ENUM('android','ios') NOT NULL,
  model        VARCHAR(120) NULL,
  os_version   VARCHAR(60) NULL,
  app_version  VARCHAR(30) NULL,
  status       ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  attempts     INT NOT NULL DEFAULT 1,
  first_seen   DATETIME NOT NULL,
  last_seen    DATETIME NOT NULL,
  resolved_by  CHAR(24) NULL,
  resolved_at  DATETIME NULL,
  note         VARCHAR(255) NULL,
  UNIQUE KEY uq_att_dev_req (employee_id, device_key),
  KEY idx_att_dev_req_status (status),
  FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (resolved_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

ALTER TABLE attendance
  ADD COLUMN location_accuracy_m DECIMAL(6,1) NULL AFTER longitude,
  ADD COLUMN device_key    VARCHAR(64) NULL AFTER method,
  ADD COLUMN device_status ENUM('trusted','first_use','director_approved') NULL AFTER device_key,
  ADD COLUMN biometric_result ENUM('ok','skipped','failed') NULL AFTER device_status,
  ADD COLUMN biometric_type   VARCHAR(20) NULL AFTER biometric_result;
```

Apply it: `C:\xampp\mysql\bin\mysql.exe -u <usuario de config.php> -p<contraseña> hive_db < migrations/033_attendance_device_binding.sql`
(los valores están en `hive-backend/config.php`; si el usuario no tiene contraseña, omitir `-p`).

- [ ] **Step 4: Update schema.sql**

En `hive-backend/schema.sql`:
1. Dentro de `CREATE TABLE ... attendance (...)`, añadir las 5 columnas nuevas después de `method VARCHAR(20) NOT NULL DEFAULT 'gps'` y antes de `created_at`:

```sql
  location_accuracy_m DECIMAL(6,1) NULL,
  device_key VARCHAR(64) NULL,
  device_status ENUM('trusted','first_use','director_approved') NULL,
  biometric_result ENUM('ok','skipped','failed') NULL,
  biometric_type VARCHAR(20) NULL,
```

2. Justo después del bloque de `attendance_location` (o del último `attendance_*`), pegar las dos sentencias `CREATE TABLE attendance_trusted_devices` y `CREATE TABLE attendance_device_requests` **idénticas** a las de la migración (sin el `USE hive_db;`).

- [ ] **Step 5: Run test to verify it passes**

Run: `C:\xampp\php\php.exe scratchpad/test_device_migration.php`
Expected: PASS — "9 passed, 0 failed" (o el número real de checks).

- [ ] **Step 6: Commit**

```bash
git add hive-backend/migrations/033_attendance_device_binding.sql hive-backend/schema.sql hive-backend/scratchpad/test_device_migration.php
git commit -m "feat(asistencia): esquema de vinculación de dispositivo y evidencia biométrica"
```

---

## Task 2: Helpers de dispositivo (`attendance_device.php`)

**Files:**
- Create: `hive-backend/attendance_device.php`
- Modify: `hive-backend/index.php:6-9` (añadir `require`)
- Test: `hive-backend/scratchpad/test_attendance_device_binding.php`

**Interfaces:**
- Consumes: `json_response()` (helpers.php), tablas de Task 1.
- Produces:
  - `attendance_hash_id(?string $raw): ?string`
  - `attendance_device_from_body(array $body): array` → `['key'=>?string,'uuid'=>?string,'platform'=>string,'model'=>?string,'osVersion'=>?string,'appVersion'=>?string]` (key/uuid ya hasheados)
  - `attendance_trusted_device_for(PDO $pdo, string $employeeId): ?array`
  - `attendance_device_matches(array $trusted, array $dev): bool`
  - `attendance_device_enroll(PDO $pdo, string $employeeId, array $dev, string $via, ?string $approvedBy = null): void`
  - `attendance_device_upsert_request(PDO $pdo, string $employeeId, array $dev): void`
  - `attendance_verify_device(PDO $pdo, string $employeeId, array $body): array` → `['status'=>'trusted'|'first_use'|'director_approved','key'=>?string]` o corta con `UNKNOWN_DEVICE`
  - `attendance_check_biometric(array $body, string $type): array` → `['result'=>?string,'type'=>?string]` o corta con `BIOMETRIC_REQUIRED`
  - `attendance_device_state_for(PDO $pdo, string $employeeId, array $dev): string` → `'trusted'|'none'|'pending'|'unknown'`
  - const `ATT_BIOMETRIC_TYPES = ['entrada','salida']`

- [ ] **Step 1: Write the failing test**

Create `hive-backend/scratchpad/test_attendance_device_binding.php`:

```php
<?php
// Harness de vinculación de dispositivo + biometría en el fichaje.
// Uso: C:\xampp\php\php.exe scratchpad/test_attendance_device_binding.php
require __DIR__ . '/../config.php';
require __DIR__ . '/../helpers.php';
require __DIR__ . '/../attendance_device.php';

$pass = 0; $fail = 0;
function check(string $name, bool $ok): void {
    global $pass, $fail;
    echo ($ok ? "  OK   " : "  FAIL ") . $name . "\n";
    $ok ? $pass++ : $fail++;
}
function expect_cut(callable $fn, string $wantCode): bool {
    // json_response() hace exit; se corre en un proceso hijo y se inspecciona la salida.
    return true; // marcador: los cortes se prueban en Task 3 vía HTTP-less handlers
}

$empId = 'tmpdev' . substr(bin2hex(random_bytes(9)), 0, 18);
$pdo->prepare(
  "INSERT INTO users (id, name, email, password, role, email_verified_at)
   VALUES (?, 'Tmp Dev', ?, 'x', 'employee', NOW())"
)->execute([$empId, $empId . '@test.local']);

function cleanup(PDO $pdo, string $empId): void {
    $pdo->prepare('DELETE FROM attendance_device_requests WHERE employee_id = ?')->execute([$empId]);
    $pdo->prepare('DELETE FROM attendance_trusted_devices WHERE employee_id = ?')->execute([$empId]);
    $pdo->prepare('DELETE FROM attendance WHERE employee_id = ?')->execute([$empId]);
    $pdo->prepare('DELETE FROM users WHERE id = ?')->execute([$empId]);
}
register_shutdown_function('cleanup', $pdo, $empId);

// --- hash ---
check('hash de cadena vacía es null', attendance_hash_id('') === null);
check('hash es sha256 hex de 64', strlen(attendance_hash_id('abc')) === 64
    && attendance_hash_id('abc') === hash('sha256', 'abc'));

// --- from_body normaliza ---
$dev = attendance_device_from_body([
    'deviceKey' => 'RAWKEY-1', 'deviceUuid' => 'RAWUUID-1',
    'platform' => 'ios', 'model' => 'iPhone14,2', 'osVersion' => 'iOS 17.5', 'appVersion' => '1.0.0+1',
]);
check('from_body hashea la key', $dev['key'] === hash('sha256', 'RAWKEY-1'));
check('from_body hashea el uuid', $dev['uuid'] === hash('sha256', 'RAWUUID-1'));
check('from_body respeta platform válida', $dev['platform'] === 'ios');
check('from_body cae a android si platform inválida',
    attendance_device_from_body(['platform' => 'x'])['platform'] === 'android');

// --- first-use enrolla ---
$devA = attendance_device_from_body(['deviceKey' => 'KEY-A', 'deviceUuid' => 'UUID-A', 'platform' => 'android']);
$r = attendance_verify_device($pdo, $empId, ['deviceKey' => 'KEY-A', 'deviceUuid' => 'UUID-A', 'platform' => 'android']);
check('first-use devuelve status first_use', $r['status'] === 'first_use');
$t = attendance_trusted_device_for($pdo, $empId);
check('first-use creó la fila confiada', $t !== null && $t['enrolled_via'] === 'first_use');
check('device_state=trusted para el mismo dispositivo',
    attendance_device_state_for($pdo, $empId, $devA) === 'trusted');

// --- mismo dispositivo => trusted ---
$r2 = attendance_verify_device($pdo, $empId, ['deviceKey' => 'KEY-A', 'deviceUuid' => 'UUID-A', 'platform' => 'android']);
check('segundo fichaje del mismo => trusted', $r2['status'] === 'trusted');

// --- match por uuid cuando falta la key ---
check('match por uuid si key ausente',
    attendance_device_matches($t, attendance_device_from_body(['deviceUuid' => 'UUID-A', 'platform' => 'android'])) === true);
check('no-match si key distinta y sin uuid',
    attendance_device_matches($t, attendance_device_from_body(['deviceKey' => 'KEY-Z', 'platform' => 'android'])) === false);

// --- dispositivo desconocido crea solicitud + estado ---
attendance_device_upsert_request($pdo, $empId,
    attendance_device_from_body(['deviceKey' => 'KEY-B', 'deviceUuid' => 'UUID-B', 'platform' => 'android', 'model' => 'Pixel 7']));
$reqCount = $pdo->prepare('SELECT COUNT(*) FROM attendance_device_requests WHERE employee_id = ? AND status = "pending"');
$reqCount->execute([$empId]);
check('upsert_request creó 1 pendiente', (int) $reqCount->fetchColumn() === 1);
attendance_device_upsert_request($pdo, $empId,
    attendance_device_from_body(['deviceKey' => 'KEY-B', 'deviceUuid' => 'UUID-B', 'platform' => 'android', 'model' => 'Pixel 7']));
$att = $pdo->prepare('SELECT attempts FROM attendance_device_requests WHERE employee_id = ? AND device_key = ?');
$att->execute([$empId, hash('sha256', 'KEY-B')]);
check('reintento sube attempts a 2', (int) $att->fetchColumn() === 2);
check('device_state=pending para KEY-B',
    attendance_device_state_for($pdo, $empId,
        attendance_device_from_body(['deviceKey' => 'KEY-B', 'platform' => 'android'])) === 'pending');

// --- enroll director reemplaza ---
attendance_device_enroll($pdo, $empId,
    attendance_device_from_body(['deviceKey' => 'KEY-C', 'deviceUuid' => 'UUID-C', 'platform' => 'ios', 'model' => 'iPhone']),
    'director', null);
$t2 = attendance_trusted_device_for($pdo, $empId);
check('enroll director reemplazó el dispositivo', $t2['device_key'] === hash('sha256', 'KEY-C')
    && $t2['enrolled_via'] === 'director');

// --- biometría ---
$b = attendance_check_biometric(['biometricResult' => 'ok', 'biometricType' => 'face'], 'entrada');
check('biometría ok en entrada pasa', $b['result'] === 'ok' && $b['type'] === 'face');
$b2 = attendance_check_biometric([], 'inicio_comida');
check('biometría no exigida en inicio_comida', $b2['result'] === null);

echo "\n$pass passed, $fail failed\n";
exit($fail === 0 ? 0 : 1);
```

- [ ] **Step 2: Run test to verify it fails**

Run (desde `hive-backend/`): `C:\xampp\php\php.exe scratchpad/test_attendance_device_binding.php`
Expected: FAIL — "require ... attendance_device.php" da error de archivo inexistente / "Call to undefined function attendance_hash_id()".

- [ ] **Step 3: Write `attendance_device.php`**

Create `hive-backend/attendance_device.php`:

```php
<?php
// Vinculación de dispositivo + evidencia biométrica del fichaje (Radio Doliv).
//
// Cada cuenta que ficha (employee / manager) queda atada a UN dispositivo
// confiado (`attendance_trusted_devices`, employee_id es PK). El primero se
// registra por "trust-on-first-use"; los cambios los aprueba el director.
// En la base solo se guardan HASHES sha256 de los identificadores.
//
// Cargado por index.php junto a attendance.php / attendance_admin.php; comparte
// los helpers json_response() y attendance_fail().

// Eventos que además exigen verificación biométrica del SO.
const ATT_BIOMETRIC_TYPES = ['entrada', 'salida'];

// sha256 hex de un identificador crudo; null si viene vacío.
function attendance_hash_id(?string $raw): ?string {
    $raw = trim((string) $raw);
    return $raw === '' ? null : hash('sha256', $raw);
}

// Normaliza los campos de dispositivo de un cuerpo (o de $_GET). key/uuid
// salen ya hasheados.
function attendance_device_from_body(array $body): array {
    $s = static fn($v, int $max) =>
        ($t = mb_substr(trim((string) ($v ?? '')), 0, $max)) === '' ? null : $t;
    $platform = $body['platform'] ?? '';
    return [
        'key'        => attendance_hash_id($body['deviceKey'] ?? null),
        'uuid'       => attendance_hash_id($body['deviceUuid'] ?? null),
        'platform'   => in_array($platform, ['android', 'ios'], true) ? $platform : 'android',
        'model'      => $s($body['model'] ?? null, 120),
        'osVersion'  => $s($body['osVersion'] ?? null, 60),
        'appVersion' => $s($body['appVersion'] ?? null, 30),
    ];
}

function attendance_trusted_device_for(PDO $pdo, string $employeeId): ?array {
    $st = $pdo->prepare('SELECT * FROM attendance_trusted_devices WHERE employee_id = ?');
    $st->execute([$employeeId]);
    return $st->fetch() ?: null;
}

// ¿El dispositivo de la petición es el confiado? Coincide por device_key; si la
// petición no trae key (el plugin falló), se acepta la coincidencia por uuid.
function attendance_device_matches(array $trusted, array $dev): bool {
    if ($dev['key'] !== null && hash_equals((string) $trusted['device_key'], $dev['key'])) {
        return true;
    }
    if ($dev['key'] === null && $dev['uuid'] !== null && $trusted['device_uuid'] !== null
        && hash_equals((string) $trusted['device_uuid'], $dev['uuid'])) {
        return true;
    }
    return false;
}

// Inserta o reemplaza el dispositivo confiado del empleado (es 1 solo).
function attendance_device_enroll(PDO $pdo, string $employeeId, array $dev, string $via, ?string $approvedBy = null): void {
    $key = $dev['key'] ?? $dev['uuid'];
    $st = $pdo->prepare(
        'REPLACE INTO attendance_trusted_devices
           (employee_id, device_key, device_uuid, platform, model, os_version, app_version,
            enrolled_at, enrolled_via, approved_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), ?, ?)'
    );
    $st->execute([
        $employeeId, $key, $dev['uuid'], $dev['platform'],
        $dev['model'], $dev['osVersion'], $dev['appVersion'], $via, $approvedBy,
    ]);
}

// Crea (o actualiza: +1 intento, reabre si estaba 'rejected') la solicitud de
// alta del dispositivo actual del empleado.
function attendance_device_upsert_request(PDO $pdo, string $employeeId, array $dev): void {
    $key = $dev['key'] ?? $dev['uuid'];
    if ($key === null) {
        return;
    }
    $st = $pdo->prepare(
        "INSERT INTO attendance_device_requests
           (employee_id, device_key, device_uuid, platform, model, os_version, app_version,
            status, attempts, first_seen, last_seen)
         VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', 1, NOW(), NOW())
         ON DUPLICATE KEY UPDATE
           attempts    = attempts + 1,
           last_seen   = NOW(),
           status      = IF(status = 'rejected', 'pending', status),
           device_uuid = VALUES(device_uuid),
           model       = VALUES(model),
           os_version  = VALUES(os_version),
           app_version = VALUES(app_version)"
    );
    $st->execute([
        $employeeId, $key, $dev['uuid'], $dev['platform'],
        $dev['model'], $dev['osVersion'], $dev['appVersion'],
    ]);
}

// Paso del pipeline de fichaje. Devuelve
//   ['status' => 'trusted'|'first_use'|'director_approved', 'key' => <hash|null>]
// o corta la petición con code=UNKNOWN_DEVICE (409) si hay un dispositivo
// confiado distinto.
function attendance_verify_device(PDO $pdo, string $employeeId, array $body): array {
    $dev = attendance_device_from_body($body);
    $key = $dev['key'] ?? $dev['uuid'];
    $trusted = attendance_trusted_device_for($pdo, $employeeId);

    if (!$trusted) {
        attendance_device_enroll($pdo, $employeeId, $dev, 'first_use');
        return ['status' => 'first_use', 'key' => $key];
    }
    if (attendance_device_matches($trusted, $dev)) {
        return [
            'status' => $trusted['enrolled_via'] === 'director' ? 'director_approved' : 'trusted',
            'key'    => $key,
        ];
    }
    attendance_device_upsert_request($pdo, $employeeId, $dev);
    json_response([
        'success' => false,
        'code'    => 'UNKNOWN_DEVICE',
        'message' => 'Este dispositivo no está autorizado para registrar tu asistencia. '
            . 'Solicita al director que lo autorice.',
    ], 409);
}

// Exige biometría solo en entrada y salida. Corta con BIOMETRIC_REQUIRED si el
// cliente no reporta una verificación válida ('ok' o 'skipped' = credencial del
// dispositivo). Devuelve ['result' => ?string, 'type' => ?string].
function attendance_check_biometric(array $body, string $type): array {
    if (!in_array($type, ATT_BIOMETRIC_TYPES, true)) {
        return ['result' => null, 'type' => null];
    }
    $result = $body['biometricResult'] ?? '';
    if (!in_array($result, ['ok', 'skipped'], true)) {
        json_response([
            'success' => false,
            'code'    => 'BIOMETRIC_REQUIRED',
            'message' => 'Debes completar la verificación de tu dispositivo para registrar la asistencia.',
        ], 409);
    }
    $btype = mb_substr(trim((string) ($body['biometricType'] ?? '')), 0, 20);
    return ['result' => $result, 'type' => $btype === '' ? null : $btype];
}

// Estado del dispositivo actual respecto de la cuenta, para pintar la UI:
//   'none'    — la cuenta no tiene dispositivo confiado (se vinculará al fichar)
//   'trusted' — este dispositivo es el confiado
//   'pending' — hay una solicitud pendiente para este dispositivo
//   'unknown' — hay otro dispositivo confiado y este no tiene solicitud pendiente
function attendance_device_state_for(PDO $pdo, string $employeeId, array $dev): string {
    $trusted = attendance_trusted_device_for($pdo, $employeeId);
    if (!$trusted) {
        return 'none';
    }
    if (attendance_device_matches($trusted, $dev)) {
        return 'trusted';
    }
    $key = $dev['key'] ?? $dev['uuid'];
    if ($key !== null) {
        $st = $pdo->prepare(
            'SELECT status FROM attendance_device_requests WHERE employee_id = ? AND device_key = ?'
        );
        $st->execute([$employeeId, $key]);
        $row = $st->fetch();
        if ($row && $row['status'] === 'pending') {
            return 'pending';
        }
    }
    return 'unknown';
}
```

- [ ] **Step 4: Wire the require into index.php**

En `hive-backend/index.php`, junto a los `require` de asistencia (líneas ~6-9), añadir:

```php
require __DIR__ . '/attendance_device.php';
```

(colócalo antes de `require __DIR__ . '/attendance.php';` porque `attendance.php` usará sus funciones).

- [ ] **Step 5: Run test to verify it passes**

Run: `C:\xampp\php\php.exe scratchpad/test_attendance_device_binding.php`
Expected: PASS — todas las líneas `OK`, "N passed, 0 failed".

- [ ] **Step 6: Commit**

```bash
git add hive-backend/attendance_device.php hive-backend/index.php hive-backend/scratchpad/test_attendance_device_binding.php
git commit -m "feat(asistencia): helpers de verificación de dispositivo y biometría"
```

---

## Task 3: Integrar verificación en el pipeline de fichaje

**Files:**
- Modify: `hive-backend/attendance.php` — `attendance_insert_event()` (~línea 468), `attendanceEntry()` (~497), `attendanceMealStart()` (~546), `attendanceMealSkip()` (~595), `attendanceMealEnd()` (~631), `attendanceExit()` (~672)
- Test: `hive-backend/scratchpad/test_attendance_device_pipeline.php`

**Interfaces:**
- Consumes: `attendance_verify_device()`, `attendance_check_biometric()` (Task 2).
- Produces: `attendance_insert_event(PDO $pdo, string $employeeId, string $workDate, string $type, array $body, array $evidence = []): array` — `$evidence` acepta `device_key`, `device_status`, `biometric_result`, `biometric_type`. Cada evento de fichaje persiste esas columnas + `location_accuracy_m` (de `$body['locationAccuracy']`).

- [ ] **Step 1: Write the failing test**

Create `hive-backend/scratchpad/test_attendance_device_pipeline.php`:

```php
<?php
// Pipeline de fichaje con verificación de dispositivo + biometría.
// Ejercita los handlers sin HTTP: llena $_SERVER/php://input vía un shim.
// Uso: C:\xampp\php\php.exe scratchpad/test_attendance_device_pipeline.php
require __DIR__ . '/../config.php';
require __DIR__ . '/../helpers.php';
require __DIR__ . '/../attendance_device.php';
require __DIR__ . '/../attendance.php';

$pass = 0; $fail = 0;
function check(string $n, bool $ok): void {
    global $pass, $fail; echo ($ok ? "  OK   " : "  FAIL ") . $n . "\n"; $ok ? $pass++ : $fail++;
}

$empId = 'tmppipe' . substr(bin2hex(random_bytes(9)), 0, 17);
$pdo->prepare(
  "INSERT INTO users (id, name, email, password, role, email_verified_at)
   VALUES (?, 'Tmp Pipe', ?, 'x', 'employee', NOW())"
)->execute([$empId, $empId . '@test.local']);
$pdo->prepare(
  "INSERT INTO employee_schedules
     (employee_id, entry_time, exit_time, meal_time, meal_max_minutes, late_tolerance_minutes)
   VALUES (?, '00:00:00', '23:59:00', '12:00:00', 60, 15)"
)->execute([$empId]);

function cleanup(PDO $pdo, string $empId): void {
    foreach (['attendance_device_requests','attendance_trusted_devices','attendance',
              'attendance_schedule_snapshots','employee_schedules'] as $t) {
        $pdo->prepare("DELETE FROM $t WHERE employee_id = ?")->execute([$empId]);
    }
    $pdo->prepare('DELETE FROM users WHERE id = ?')->execute([$empId]);
}
register_shutdown_function('cleanup', $pdo, $empId);

// Inserta una entrada directamente vía el helper (sin ventana horaria) para
// probar SOLO la persistencia de evidencia.
$ev = attendance_insert_event($pdo, $empId, date('Y-m-d'), 'entrada',
    ['latitude' => '1', 'longitude' => '2', 'locationAccuracy' => '7.5'],
    ['device_key' => 'HASHK', 'device_status' => 'first_use',
     'biometric_result' => 'ok', 'biometric_type' => 'face']);
$row = $pdo->query("SELECT * FROM attendance WHERE employee_id = '$empId' AND type = 'entrada'")->fetch();
check('evidencia: device_key persistido', $row['device_key'] === 'HASHK');
check('evidencia: device_status persistido', $row['device_status'] === 'first_use');
check('evidencia: biometric_result persistido', $row['biometric_result'] === 'ok');
check('evidencia: biometric_type persistido', $row['biometric_type'] === 'face');
check('evidencia: location_accuracy_m persistido', (float) $row['location_accuracy_m'] === 7.5);

// first-use: verify_device sobre una cuenta sin dispositivo confiado enrola.
$pdo->prepare('DELETE FROM attendance WHERE employee_id = ?')->execute([$empId]);
$r = attendance_verify_device($pdo, $empId,
    ['deviceKey' => 'K1', 'deviceUuid' => 'U1', 'platform' => 'android']);
check('verify_device first-use', $r['status'] === 'first_use'
    && attendance_trusted_device_for($pdo, $empId) !== null);

// dispositivo distinto: se corre en proceso hijo para capturar el exit + JSON.
$php = PHP_BINARY;
$script = __DIR__ . '/_child_unknown_device.php';
file_put_contents($script, <<<'PHP'
<?php
require __DIR__ . '/../config.php';
require __DIR__ . '/../helpers.php';
require __DIR__ . '/../attendance_device.php';
$empId = $argv[1];
attendance_verify_device($pdo, $empId, ['deviceKey' => 'OTHER', 'deviceUuid' => 'OTHER-U', 'platform' => 'android']);
PHP);
$out = shell_exec(escapeshellarg($php) . ' ' . escapeshellarg($script) . ' ' . escapeshellarg($empId) . ' 2>&1');
@unlink($script);
check('dispositivo distinto responde UNKNOWN_DEVICE', str_contains((string) $out, 'UNKNOWN_DEVICE'));
$pend = $pdo->prepare("SELECT COUNT(*) FROM attendance_device_requests WHERE employee_id = ? AND status='pending'");
$pend->execute([$empId]);
check('dispositivo distinto dejó solicitud pendiente', (int) $pend->fetchColumn() === 1);

echo "\n$pass passed, $fail failed\n";
exit($fail === 0 ? 0 : 1);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\xampp\php\php.exe scratchpad/test_attendance_device_pipeline.php`
Expected: FAIL — `attendance_insert_event()` aún no acepta `$evidence`; "device_key persistido" falla (columna guardada como NULL) o error de aridad.

- [ ] **Step 3: Extend `attendance_insert_event()`**

En `hive-backend/attendance.php`, reemplazar la función `attendance_insert_event` por:

```php
function attendance_insert_event(PDO $pdo, string $employeeId, string $workDate, string $type, array $body, array $evidence = []): array {
    [$lat, $lng] = attendance_coords_from_body($body);
    $method = $body['method'] ?? 'gps';
    if (!in_array($method, ['gps', 'qr', 'gps_qr'], true)) {
        $method = 'gps';
    }
    $deviceTime = isset($body['deviceTime']) && $body['deviceTime'] !== ''
        ? date('Y-m-d H:i:s', strtotime((string) $body['deviceTime'])) : null;
    $accuracy = isset($body['locationAccuracy']) && $body['locationAccuracy'] !== ''
        ? (float) $body['locationAccuracy'] : null;

    $now = date('Y-m-d H:i:s');
    $stmt = $pdo->prepare(
        'INSERT INTO attendance
           (employee_id, type, work_date, event_time, device_time, latitude, longitude,
            location_accuracy_m, method, device_key, device_status, biometric_result, biometric_type)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
    );
    try {
        $stmt->execute([
            $employeeId, $type, $workDate, $now, $deviceTime, $lat, $lng,
            $accuracy, $method,
            $evidence['device_key'] ?? null,
            $evidence['device_status'] ?? null,
            $evidence['biometric_result'] ?? null,
            $evidence['biometric_type'] ?? null,
        ]);
    } catch (PDOException $e) {
        if ($e->getCode() === '23000') {
            attendance_fail(attendance_duplicate_message($type), 409);
        }
        throw $e;
    }

    return ['type' => $type, 'timestamp' => $now];
}
```

- [ ] **Step 4: Wire the checks into the five handlers**

En cada handler, tras las validaciones actuales (rol / día / ausencia / ventana / geocerca) y **justo antes** de `attendance_insert_event(...)`, añadir la verificación y pasar la evidencia. El `$body` debe estar en una variable local (en `attendanceMealStart/Skip/End/Exit` hoy se llama `request_body()` inline dentro del insert — hoístalo).

**`attendanceEntry()`** — ya tiene `$body`. Tras `attendance_verify_location(...)`:

```php
    $deviceInfo = attendance_verify_device($pdo, $user['id'], $body);
    $bio = attendance_check_biometric($body, 'entrada');

    // Congela el horario del día ANTES de crear la entrada.
    attendance_snapshot_schedule($pdo, $user['id'], $workDate, $override['entry_time'] ?? null);
    $ev = attendance_insert_event($pdo, $user['id'], $workDate, 'entrada', $body, [
        'device_key'       => $deviceInfo['key'],
        'device_status'    => $deviceInfo['status'],
        'biometric_result' => $bio['result'],
        'biometric_type'   => $bio['type'],
    ]);
```

**`attendanceMealStart()`** — reemplazar la línea `$ev = attendance_insert_event($pdo, $user['id'], $workDate, 'inicio_comida', request_body());` por:

```php
    $body = request_body();
    $deviceInfo = attendance_verify_device($pdo, $user['id'], $body);
    $bio = attendance_check_biometric($body, 'inicio_comida'); // no exige biometría
    $ev = attendance_insert_event($pdo, $user['id'], $workDate, 'inicio_comida', $body, [
        'device_key'       => $deviceInfo['key'],
        'device_status'    => $deviceInfo['status'],
        'biometric_result' => $bio['result'],
        'biometric_type'   => $bio['type'],
    ]);
```

**`attendanceMealSkip()`** — igual, con tipo `'sin_comida'`:

```php
    $body = request_body();
    $deviceInfo = attendance_verify_device($pdo, $user['id'], $body);
    $bio = attendance_check_biometric($body, 'sin_comida');
    $ev = attendance_insert_event($pdo, $user['id'], $workDate, 'sin_comida', $body, [
        'device_key'       => $deviceInfo['key'],
        'device_status'    => $deviceInfo['status'],
        'biometric_result' => $bio['result'],
        'biometric_type'   => $bio['type'],
    ]);
```

**`attendanceMealEnd()`** — ya tiene `$body` (para la geocerca). Tras `attendance_verify_location($pdo, 'fin_comida', $lat, $lng);`:

```php
    $deviceInfo = attendance_verify_device($pdo, $user['id'], $body);
    $bio = attendance_check_biometric($body, 'fin_comida'); // no exige biometría
    $ev = attendance_insert_event($pdo, $user['id'], $workDate, 'fin_comida', $body, [
        'device_key'       => $deviceInfo['key'],
        'device_status'    => $deviceInfo['status'],
        'biometric_result' => $bio['result'],
        'biometric_type'   => $bio['type'],
    ]);
```

**`attendanceExit()`** — reemplazar `$ev = attendance_insert_event($pdo, $user['id'], $workDate, 'salida', request_body());` por:

```php
    $body = request_body();
    $deviceInfo = attendance_verify_device($pdo, $user['id'], $body);
    $bio = attendance_check_biometric($body, 'salida'); // exige biometría
    $ev = attendance_insert_event($pdo, $user['id'], $workDate, 'salida', $body, [
        'device_key'       => $deviceInfo['key'],
        'device_status'    => $deviceInfo['status'],
        'biometric_result' => $bio['result'],
        'biometric_type'   => $bio['type'],
    ]);
```

- [ ] **Step 5: Run test to verify it passes**

Run: `C:\xampp\php\php.exe scratchpad/test_attendance_device_pipeline.php`
Expected: PASS — "N passed, 0 failed".

- [ ] **Step 6: Regression — run the existing attendance harness**

Run: `C:\xampp\php\php.exe scratchpad/test_attendance_windows.php`
Expected: sigue en verde (los inserts ahora pasan `$evidence` vacío; comportamiento idéntico).

- [ ] **Step 7: Commit**

```bash
git add hive-backend/attendance.php hive-backend/scratchpad/test_attendance_device_pipeline.php
git commit -m "feat(asistencia): exigir dispositivo confiado y biometría al fichar"
```

---

## Task 4: Endpoints del trabajador (estado y solicitud de dispositivo)

**Files:**
- Modify: `hive-backend/attendance.php` (añadir `attendanceDeviceStatus()`, `attendanceDeviceRequest()` al final de la sección "endpoints: empleado")
- Modify: `hive-backend/index.php` (2 rutas)
- Test: `hive-backend/scratchpad/test_attendance_device_endpoints.php`

**Interfaces:**
- Consumes: `attendance_device_from_body()`, `attendance_device_state_for()`, `attendance_trusted_device_for()`, `attendance_device_matches()`, `attendance_device_upsert_request()`, `attendance_require_worker()`.
- Produces:
  - `GET /attendance/device/status?deviceKey=&deviceUuid=&platform=` → `{success, state: 'none'|'trusted'|'pending'|'unknown', device: {model, osVersion, enrolledAt, via}|null}`
  - `POST /attendance/device/request` (body de dispositivo) → `{success, state: 'trusted'|'pending', message?}`

- [ ] **Step 1: Write the failing test**

Create `hive-backend/scratchpad/test_attendance_device_endpoints.php`:

```php
<?php
// GET /attendance/device/status y POST /attendance/device/request.
// Se prueban vía funciones directas + child processes para los cortes.
require __DIR__ . '/../config.php';
require __DIR__ . '/../helpers.php';
require __DIR__ . '/../attendance_device.php';
require __DIR__ . '/../attendance.php';

$pass = 0; $fail = 0;
function check(string $n, bool $ok): void {
    global $pass, $fail; echo ($ok ? "  OK   " : "  FAIL ") . $n . "\n"; $ok ? $pass++ : $fail++;
}
function run_child(string $body): string {
    $script = __DIR__ . '/_child_ep.php';
    file_put_contents($script, $body);
    $out = shell_exec(escapeshellarg(PHP_BINARY) . ' ' . escapeshellarg($script) . ' 2>&1');
    @unlink($script);
    return (string) $out;
}

$empId = 'tmpep' . substr(bin2hex(random_bytes(9)), 0, 19);
$pdo->prepare(
  "INSERT INTO users (id, name, email, password, role, email_verified_at)
   VALUES (?, 'Tmp EP', ?, 'x', 'employee', NOW())"
)->execute([$empId, $empId . '@test.local']);
// token de sesión válido para require_auth: reutiliza el patrón de auth del repo.
$token = 'devtok' . bin2hex(random_bytes(20));
$pdo->prepare("INSERT INTO sessions (token, email, created_at) VALUES (?, ?, NOW())")
    ->execute([$token, $empId . '@test.local']);

function cleanup(PDO $pdo, string $empId, string $token): void {
    $pdo->prepare('DELETE FROM sessions WHERE token = ?')->execute([$token]);
    foreach (['attendance_device_requests','attendance_trusted_devices','attendance'] as $t) {
        $pdo->prepare("DELETE FROM $t WHERE employee_id = ?")->execute([$empId]);
    }
    $pdo->prepare('DELETE FROM users WHERE id = ?')->execute([$empId]);
}
register_shutdown_function('cleanup', $pdo, $empId, $token);

// --- status: none ---
$out = run_child(<<<PHP
<?php
\$_SERVER['REQUEST_METHOD']='GET';
\$_SERVER['HTTP_AUTHORIZATION']='$token';
\$_GET=['deviceKey'=>'K1','deviceUuid'=>'U1','platform'=>'android'];
require '{$GLOBALS['_composer_autoload_path']}'; // no-op si no existe
require __DIR__ . '/../config.php';
require __DIR__ . '/../helpers.php';
require __DIR__ . '/../attendance_device.php';
require __DIR__ . '/../attendance.php';
attendanceDeviceStatus(\$pdo);
PHP);
check('status sin dispositivo => "state":"none"', str_contains($out, '"state":"none"'));

// --- request crea pendiente ---
$out = run_child(<<<PHP
<?php
\$_SERVER['REQUEST_METHOD']='POST';
\$_SERVER['HTTP_AUTHORIZATION']='$token';
\$GLOBALS['__test_body']=['deviceKey'=>'K1','deviceUuid'=>'U1','platform'=>'android','model'=>'Pixel'];
require __DIR__ . '/../config.php';
require __DIR__ . '/../helpers.php';
require __DIR__ . '/../attendance_device.php';
require __DIR__ . '/../attendance.php';
attendanceDeviceRequest(\$pdo);
PHP);
check('request responde "state":"pending"', str_contains($out, '"state":"pending"'));
$c = $pdo->prepare("SELECT COUNT(*) FROM attendance_device_requests WHERE employee_id=? AND status='pending'");
$c->execute([$empId]);
check('request creó 1 pendiente', (int) $c->fetchColumn() === 1);

echo "\n$pass passed, $fail failed\n";
exit($fail === 0 ? 0 : 1);
```

> Nota para el implementador: `request_body()` en `helpers.php` lee `php://input`. Para los child processes, si `helpers.php` no admite inyección, añade en `request_body()` un `if (isset($GLOBALS['__test_body'])) return $GLOBALS['__test_body'];` al inicio **solo si ya existe un patrón de test así en el repo**; si no, prueba estos dos endpoints con `curl` contra el servidor local levantado con `php -S localhost:8765 index.php` y `grep` de la respuesta. Elige el camino que encaje con la infraestructura de tests existente y ajusta este archivo en consecuencia.

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\xampp\php\php.exe scratchpad/test_attendance_device_endpoints.php`
Expected: FAIL — "Call to undefined function attendanceDeviceStatus()".

- [ ] **Step 3: Add the endpoints**

En `hive-backend/attendance.php`, al final de la sección `// ---- endpoints: empleado ----` (antes de `attendanceToday`), añadir:

```php
// GET /attendance/device/status — la app lo llama al abrir "Mi asistencia"
// para pintar el botón de fichar según el estado del dispositivo actual.
function attendanceDeviceStatus(PDO $pdo) {
    $user = require_auth($pdo);
    attendance_require_worker($user);

    $dev = attendance_device_from_body($_GET);
    $state = attendance_device_state_for($pdo, $user['id'], $dev);
    $trusted = attendance_trusted_device_for($pdo, $user['id']);

    json_response([
        'success' => true,
        'state'   => $state,
        'device'  => $trusted ? [
            'model'      => $trusted['model'],
            'osVersion'  => $trusted['os_version'],
            'enrolledAt' => $trusted['enrolled_at'],
            'via'        => $trusted['enrolled_via'],
        ] : null,
    ]);
}

// POST /attendance/device/request — el trabajador pide autorizar el dispositivo
// actual (bloqueado). Idempotente: crea o actualiza la solicitud a 'pending'.
function attendanceDeviceRequest(PDO $pdo) {
    $user = require_auth($pdo);
    attendance_require_worker($user);

    $dev = attendance_device_from_body(request_body());
    if (($dev['key'] ?? $dev['uuid']) === null) {
        attendance_fail('No fue posible identificar este dispositivo. Actualiza la app e inténtalo de nuevo.', 422);
    }
    $trusted = attendance_trusted_device_for($pdo, $user['id']);
    if ($trusted && attendance_device_matches($trusted, $dev)) {
        json_response(['success' => true, 'state' => 'trusted']);
    }
    attendance_device_upsert_request($pdo, $user['id'], $dev);
    json_response([
        'success' => true,
        'state'   => 'pending',
        'message' => 'Solicitud enviada. El director debe autorizar este dispositivo.',
    ]);
}
```

- [ ] **Step 4: Register routes in index.php**

En `hive-backend/index.php`, en la sección `// ---- Asistencia: empleado ----` (junto a `/attendance/entry`, etc.), añadir **antes** de `['GET', '#^/attendance/today/?$#', ...]`:

```php
    ['GET',  '#^/attendance/device/status/?$#',   'attendanceDeviceStatus'],
    ['POST', '#^/attendance/device/request/?$#',  'attendanceDeviceRequest'],
```

- [ ] **Step 5: Run test to verify it passes**

Run: `C:\xampp\php\php.exe scratchpad/test_attendance_device_endpoints.php`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add hive-backend/attendance.php hive-backend/index.php hive-backend/scratchpad/test_attendance_device_endpoints.php
git commit -m "feat(asistencia): endpoints de estado y solicitud de dispositivo del trabajador"
```

---

## Task 5: Endpoints del director (solicitudes, dispositivo por empleado, anomalías)

**Files:**
- Modify: `hive-backend/attendance_admin.php` (añadir 5 funciones al final)
- Modify: `hive-backend/index.php` (5 rutas, **antes** del comodín `/admin/attendance/([^/]+)`)
- Test: `hive-backend/scratchpad/test_attendance_device_admin.php`

**Interfaces:**
- Consumes: `attendance_admin_guard()`, `attendance_admin_target()`, `require_role()`, `attendance_device_enroll()`, `attendance_trusted_device_for()`.
- Produces:
  - `GET /admin/attendance/device-requests?status=pending` → `{success, requests:[{id, employee:{id,name}, platform, model, osVersion, appVersion, attempts, firstSeen, lastSeen, status}]}`
  - `POST /admin/attendance/device-requests/{id}/resolve` — `{decision:'approve'|'reject', note?}` → `{success, status:'approved'|'rejected'}`
  - `GET /admin/attendance/device-anomalies?days=30` → `{success, anomalies:[{type, employeeId, employeeName, detail, at}]}`
  - `GET /admin/attendance/{employeeId}/device` → `{success, device:{model, osVersion, platform, enrolledAt, via}|null}`
  - `POST /admin/attendance/{employeeId}/device/reset` → `{success, message}`
- Todas exigen rol `director` (el `manager` recibe 403).

- [ ] **Step 1: Write the failing test**

Create `hive-backend/scratchpad/test_attendance_device_admin.php`:

```php
<?php
require __DIR__ . '/../config.php';
require __DIR__ . '/../helpers.php';
require __DIR__ . '/../attendance_device.php';
require __DIR__ . '/../attendance.php';
require __DIR__ . '/../attendance_admin.php';

$pass = 0; $fail = 0;
function check(string $n, bool $ok): void {
    global $pass, $fail; echo ($ok ? "  OK   " : "  FAIL ") . $n . "\n"; $ok ? $pass++ : $fail++;
}

$emp = 'tmpadm' . substr(bin2hex(random_bytes(9)), 0, 18);
$dir = 'tmpdir' . substr(bin2hex(random_bytes(9)), 0, 18);
$pdo->prepare("INSERT INTO users (id,name,email,password,role,email_verified_at)
               VALUES (?, 'Emp', ?, 'x', 'employee', NOW())")->execute([$emp, $emp . '@t.local']);
$pdo->prepare("INSERT INTO users (id,name,email,password,role,email_verified_at)
               VALUES (?, 'Dir', ?, 'x', 'director', NOW())")->execute([$dir, $dir . '@t.local']);

function cleanup(PDO $pdo, string $emp, string $dir): void {
    foreach (['attendance_device_requests','attendance_trusted_devices','attendance'] as $t) {
        $pdo->prepare("DELETE FROM $t WHERE employee_id = ?")->execute([$emp]);
    }
    $pdo->prepare('DELETE FROM users WHERE id IN (?, ?)')->execute([$emp, $dir]);
}
register_shutdown_function('cleanup', $pdo, $emp, $dir);

$dirUser = ['id' => $dir, 'role' => 'director', 'email' => $dir . '@t.local'];

// Semilla: una solicitud pendiente.
attendance_device_upsert_request($pdo, $emp, attendance_device_from_body(
    ['deviceKey' => 'NEWKEY', 'deviceUuid' => 'NEWUUID', 'platform' => 'android', 'model' => 'Pixel 8']));
$reqId = (int) $pdo->query("SELECT id FROM attendance_device_requests WHERE employee_id = '$emp'")->fetchColumn();

// resolve approve -> crea/reemplaza dispositivo confiado
attendance_device_admin_resolve($pdo, $dirUser, $reqId, 'approve', null);
$t = attendance_trusted_device_for($pdo, $emp);
check('approve creó el dispositivo confiado', $t !== null && $t['device_key'] === hash('sha256', 'NEWKEY'));
check('approve marcó enrolled_via=director', $t['enrolled_via'] === 'director');
$st = $pdo->query("SELECT status FROM attendance_device_requests WHERE id = $reqId")->fetchColumn();
check('approve dejó la solicitud en approved', $st === 'approved');

// segunda solicitud + reject
attendance_device_upsert_request($pdo, $emp, attendance_device_from_body(
    ['deviceKey' => 'KEY3', 'deviceUuid' => 'U3', 'platform' => 'ios']));
$req2 = (int) $pdo->query("SELECT id FROM attendance_device_requests WHERE employee_id = '$emp' AND device_key = '" . hash('sha256','KEY3') . "'")->fetchColumn();
attendance_device_admin_resolve($pdo, $dirUser, $req2, 'reject', 'no reconozco este equipo');
$st2 = $pdo->query("SELECT status FROM attendance_device_requests WHERE id = $req2")->fetchColumn();
check('reject dejó la solicitud en rejected', $st2 === 'rejected');
check('reject no cambió el dispositivo confiado',
    attendance_trusted_device_for($pdo, $emp)['device_key'] === hash('sha256', 'NEWKEY'));

// reset borra el dispositivo confiado
attendance_device_admin_reset($pdo, $emp, $dir);
check('reset borró el dispositivo confiado', attendance_trusted_device_for($pdo, $emp) === null);

// anomalía frequent_device_change: 2 approved en 30 días
$pdo->prepare("UPDATE attendance_device_requests SET status='approved', resolved_at=NOW() WHERE employee_id=?")->execute([$emp]);
$an = attendance_device_anomalies($pdo, 30);
$hasFreq = false;
foreach ($an as $a) { if ($a['type'] === 'frequent_device_change' && $a['employeeId'] === $emp) $hasFreq = true; }
check('anomalía frequent_device_change detectada', $hasFreq);

echo "\n$pass passed, $fail failed\n";
exit($fail === 0 ? 0 : 1);
```

> Los handlers HTTP (`adminAttendanceDeviceRequests`, etc.) delegan en funciones puras testables (`attendance_device_admin_resolve()`, `attendance_device_admin_reset()`, `attendance_device_anomalies()`). El test ejercita las puras; los cortes 403 del `manager` se verifican en el smoke test manual del Step 6.

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\xampp\php\php.exe scratchpad/test_attendance_device_admin.php`
Expected: FAIL — "Call to undefined function attendance_device_admin_resolve()".

- [ ] **Step 3: Add functions to `attendance_admin.php`**

Al final de `hive-backend/attendance_admin.php`:

```php
// ---- dispositivos de asistencia (solo director) ----------------------

// Núcleo testable: resuelve una solicitud. Devuelve 'approved' | 'rejected'.
function attendance_device_admin_resolve(PDO $pdo, array $admin, int $id, string $decision, ?string $note): string {
    $st = $pdo->prepare('SELECT * FROM attendance_device_requests WHERE id = ?');
    $st->execute([$id]);
    $req = $st->fetch();
    if (!$req) {
        attendance_fail('La solicitud no existe.', 404);
    }
    if ($req['status'] !== 'pending') {
        attendance_fail('Esta solicitud ya fue resuelta.', 409);
    }
    if ($decision === 'approve') {
        attendance_device_enroll($pdo, $req['employee_id'], [
            'key'        => $req['device_key'],
            'uuid'       => $req['device_uuid'],
            'platform'   => $req['platform'],
            'model'      => $req['model'],
            'osVersion'  => $req['os_version'],
            'appVersion' => $req['app_version'],
        ], 'director', $admin['id']);
    }
    $status = $decision === 'approve' ? 'approved' : 'rejected';
    $pdo->prepare(
        'UPDATE attendance_device_requests
         SET status = ?, resolved_by = ?, resolved_at = NOW(), note = ?
         WHERE id = ?'
    )->execute([$status, $admin['id'], $note, $id]);
    return $status;
}

// Núcleo testable: borra el dispositivo confiado del empleado y cierra sus
// solicitudes pendientes.
function attendance_device_admin_reset(PDO $pdo, string $employeeId, string $adminId): void {
    $pdo->prepare('DELETE FROM attendance_trusted_devices WHERE employee_id = ?')->execute([$employeeId]);
    $pdo->prepare(
        "UPDATE attendance_device_requests
         SET status = 'rejected', resolved_by = ?, resolved_at = NOW()
         WHERE employee_id = ? AND status = 'pending'"
    )->execute([$adminId, $employeeId]);
}

// Núcleo testable: lista de anomalías de los últimos $days días.
function attendance_device_anomalies(PDO $pdo, int $days): array {
    $days  = max(1, min(180, $days));
    $since = date('Y-m-d H:i:s', time() - $days * 86400);
    $out   = [];

    $st = $pdo->prepare(
        "SELECT r.employee_id, u.name, r.model, r.attempts, r.last_seen
         FROM attendance_device_requests r JOIN users u ON u.id = r.employee_id
         WHERE r.last_seen >= ? AND r.status IN ('pending','rejected')
         ORDER BY r.last_seen DESC"
    );
    $st->execute([$since]);
    foreach ($st->fetchAll() as $r) {
        $out[] = [
            'type' => 'unknown_device_attempt', 'employeeId' => $r['employee_id'],
            'employeeName' => $r['name'],
            'detail' => trim(($r['model'] ?? 'Dispositivo') . ' · ' . (int) $r['attempts'] . ' intento(s)'),
            'at' => $r['last_seen'],
        ];
    }

    $st = $pdo->prepare(
        "SELECT r.employee_id, u.name, COUNT(*) c
         FROM attendance_device_requests r JOIN users u ON u.id = r.employee_id
         WHERE r.status = 'approved' AND r.resolved_at >= ?
         GROUP BY r.employee_id, u.name HAVING c > 1"
    );
    $st->execute([$since]);
    foreach ($st->fetchAll() as $r) {
        $out[] = [
            'type' => 'frequent_device_change', 'employeeId' => $r['employee_id'],
            'employeeName' => $r['name'],
            'detail' => (int) $r['c'] . ' cambios de dispositivo en ' . $days . ' días',
            'at' => null,
        ];
    }

    $st = $pdo->query(
        "SELECT d.employee_id, u.name, d.enrolled_at, d.device_key
         FROM attendance_trusted_devices d JOIN users u ON u.id = d.employee_id
         WHERE d.enrolled_via = 'first_use'"
    );
    foreach ($st->fetchAll() as $r) {
        $q = $pdo->prepare(
            'SELECT 1 FROM attendance
             WHERE employee_id = ? AND device_key IS NOT NULL AND device_key <> ?
             LIMIT 1'
        );
        $q->execute([$r['employee_id'], $r['device_key']]);
        if ($q->fetch()) {
            $out[] = [
                'type' => 'first_use_after_history', 'employeeId' => $r['employee_id'],
                'employeeName' => $r['name'],
                'detail' => 'Alta por primer uso con historial previo de otro dispositivo',
                'at' => $r['enrolled_at'],
            ];
        }
    }
    return $out;
}

// ---- handlers HTTP ----

function adminAttendanceDeviceRequests(PDO $pdo) {
    $admin = attendance_admin_guard($pdo);
    require_role($admin, ['director']);
    $status = in_array($_GET['status'] ?? '', ['pending', 'approved', 'rejected'], true)
        ? $_GET['status'] : 'pending';
    $st = $pdo->prepare(
        'SELECT r.*, u.name AS employee_name
         FROM attendance_device_requests r JOIN users u ON u.id = r.employee_id
         WHERE r.status = ? ORDER BY r.last_seen DESC'
    );
    $st->execute([$status]);
    $rows = array_map(static fn($r) => [
        'id'         => (int) $r['id'],
        'employee'   => ['id' => $r['employee_id'], 'name' => $r['employee_name']],
        'platform'   => $r['platform'],
        'model'      => $r['model'],
        'osVersion'  => $r['os_version'],
        'appVersion' => $r['app_version'],
        'attempts'   => (int) $r['attempts'],
        'firstSeen'  => $r['first_seen'],
        'lastSeen'   => $r['last_seen'],
        'status'     => $r['status'],
    ], $st->fetchAll());
    json_response(['success' => true, 'requests' => $rows]);
}

function adminAttendanceDeviceRequestResolve(PDO $pdo, string $id) {
    $admin = attendance_admin_guard($pdo);
    require_role($admin, ['director']);
    $body = request_body();
    $decision = $body['decision'] ?? '';
    if (!in_array($decision, ['approve', 'reject'], true)) {
        attendance_fail('Decisión inválida.', 422);
    }
    $note = mb_substr(trim((string) ($body['note'] ?? '')), 0, 255);
    $status = attendance_device_admin_resolve($pdo, $admin, (int) $id, $decision, $note === '' ? null : $note);
    json_response(['success' => true, 'status' => $status]);
}

function adminAttendanceDeviceAnomalies(PDO $pdo) {
    $admin = attendance_admin_guard($pdo);
    require_role($admin, ['director']);
    $days = (int) ($_GET['days'] ?? 30);
    json_response(['success' => true, 'anomalies' => attendance_device_anomalies($pdo, $days)]);
}

function adminAttendanceEmployeeDevice(PDO $pdo, string $employeeId) {
    $admin = attendance_admin_guard($pdo);
    require_role($admin, ['director']);
    $emp = attendance_admin_target($pdo, $admin, $employeeId);
    $d = attendance_trusted_device_for($pdo, $emp['id']);
    json_response(['success' => true, 'device' => $d ? [
        'model'      => $d['model'],
        'osVersion'  => $d['os_version'],
        'platform'   => $d['platform'],
        'enrolledAt' => $d['enrolled_at'],
        'via'        => $d['enrolled_via'],
    ] : null]);
}

function adminAttendanceEmployeeDeviceReset(PDO $pdo, string $employeeId) {
    $admin = attendance_admin_guard($pdo);
    require_role($admin, ['director']);
    $emp = attendance_admin_target($pdo, $admin, $employeeId);
    attendance_device_admin_reset($pdo, $emp['id'], $admin['id']);
    json_response([
        'success' => true,
        'message' => 'Dispositivo restablecido. El siguiente registro vinculará el nuevo dispositivo.',
    ]);
}
```

- [ ] **Step 4: Register routes in index.php**

En `hive-backend/index.php`, en la sección admin de asistencia, **antes** de `['GET', '#^/admin/attendance/([^/]+)/?$#', 'adminAttendanceEmployee']` y junto a las demás rutas específicas:

```php
    ['GET',  '#^/admin/attendance/device-requests/?$#',                 'adminAttendanceDeviceRequests'],
    ['POST', '#^/admin/attendance/device-requests/([^/]+)/resolve/?$#', 'adminAttendanceDeviceRequestResolve'],
    ['GET',  '#^/admin/attendance/device-anomalies/?$#',                'adminAttendanceDeviceAnomalies'],
    ['GET',  '#^/admin/attendance/([^/]+)/device/?$#',                  'adminAttendanceEmployeeDevice'],
    ['POST', '#^/admin/attendance/([^/]+)/device/reset/?$#',            'adminAttendanceEmployeeDeviceReset'],
```

(el orden importa: `device-requests` y `device-anomalies` son literales y deben ir antes del comodín `([^/]+)`; `([^/]+)/device` y `([^/]+)/device/reset` antes de `([^/]+)`).

- [ ] **Step 5: Run test to verify it passes**

Run: `C:\xampp\php\php.exe scratchpad/test_attendance_device_admin.php`
Expected: PASS.

- [ ] **Step 6: Smoke test manual (roles)**

Levantar el backend (`php -S localhost:8765 index.php` desde `hive-backend/`) y, con un token de `manager` válido:
`curl -s -H "Authorization: <token-manager>" localhost:8765/admin/attendance/device-requests`
Expected: HTTP 403 con mensaje de rol. Con token de `director`: `{"success":true,"requests":[...]}`.

- [ ] **Step 7: Commit**

```bash
git add hive-backend/attendance_admin.php hive-backend/index.php hive-backend/scratchpad/test_attendance_device_admin.php
git commit -m "feat(asistencia): panel del director para dispositivos y anomalías"
```

---

## Task 6: Dependencias Flutter + `DeviceIdentity`

**Files:**
- Modify: `pubspec.yaml` (dependencies)
- Create: `lib/core/device/device_identity.dart`
- Test: `test/attendance_device_binding_test.dart` (grupo `DeviceIdentity`)

**Interfaces:**
- Consumes: `secureStorage` (`lib/core/session_keys.dart`), `flutter_secure_storage`.
- Produces:
  - `class DeviceIdentity` con campos `String? key`, `String uuid`, `String platform`, `String? model`, `String? osVersion`, `String? appVersion`.
  - `static Future<DeviceIdentity> current()`
  - `Map<String, String> toBody()` → claves `deviceKey?`, `deviceUuid`, `platform`, `model?`, `osVersion?`, `appVersion?`
  - `static Future<DeviceIdentity> forTest({String? key, required String uuid, String platform})` — constructor de pruebas sin platform channels.

- [ ] **Step 1: Add dependencies**

En `pubspec.yaml`, bajo `dependencies:` (después de `geolocator: ^14.0.3`):

```yaml
  # Identidad estable del dispositivo para la vinculación del fichaje de
  # asistencia (lib/core/device/device_identity.dart). device_info_plus da
  # modelo/SO; android_id da el Settings.Secure.ANDROID_ID (device_info_plus
  # ya no lo expone); package_info_plus da la versión de la app para la
  # evidencia que ve el director.
  device_info_plus: ^11.2.0
  android_id: ^0.4.0
  package_info_plus: ^8.1.1
```

Run: `flutter pub get`
Expected: resuelve sin conflictos. Si `device_info_plus ^11` choca con el SDK, fijar `^10.1.2`; si `package_info_plus ^8` choca, `^5.0.1`. Anotar la versión final en el comentario.

- [ ] **Step 2: Write the failing test**

Create `test/attendance_device_binding_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:doliv_social/core/device/device_identity.dart';

void main() {
  group('DeviceIdentity.toBody', () {
    test('incluye deviceKey solo si no es nulo', () {
      final withKey = DeviceIdentity.forTest(key: 'abc', uuid: 'u1', platform: 'android');
      expect(withKey.toBody()['deviceKey'], 'abc');
      expect(withKey.toBody()['deviceUuid'], 'u1');
      expect(withKey.toBody()['platform'], 'android');

      final noKey = DeviceIdentity.forTest(key: null, uuid: 'u2', platform: 'ios');
      expect(noKey.toBody().containsKey('deviceKey'), false);
      expect(noKey.toBody()['deviceUuid'], 'u2');
    });

    test('omite metadatos nulos', () {
      final d = DeviceIdentity.forTest(key: 'k', uuid: 'u', platform: 'android');
      final body = d.toBody();
      expect(body.containsKey('model'), false);
      expect(body.containsKey('osVersion'), false);
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/attendance_device_binding_test.dart`
Expected: FAIL — no existe `package:doliv_social/core/device/device_identity.dart`.

- [ ] **Step 4: Write `device_identity.dart`**

Create `lib/core/device/device_identity.dart`:

```dart
import 'dart:io' show Platform;
import 'dart:math';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:doliv_social/core/session_keys.dart' show secureStorage;

/// Identidad estable del dispositivo para vincular el fichaje de asistencia a
/// una sola cuenta. `key` es el `ANDROID_ID` (Android) o el
/// `identifierForVendor` (iOS) — puede ser nulo si el SO no lo entrega; en ese
/// caso el backend empareja por `uuid`, un valor aleatorio que la app genera
/// una vez y guarda en el almacén seguro.
class DeviceIdentity {
  const DeviceIdentity({
    required this.key,
    required this.uuid,
    required this.platform,
    this.model,
    this.osVersion,
    this.appVersion,
  });

  final String? key;
  final String uuid;
  final String platform; // 'android' | 'ios'
  final String? model;
  final String? osVersion;
  final String? appVersion;

  static const _uuidStorageKey = 'att_device_uuid';

  /// Constructor sin platform channels, para pruebas.
  static DeviceIdentity forTest({
    required String? key,
    required String uuid,
    required String platform,
    String? model,
    String? osVersion,
    String? appVersion,
  }) =>
      DeviceIdentity(
        key: key,
        uuid: uuid,
        platform: platform,
        model: model,
        osVersion: osVersion,
        appVersion: appVersion,
      );

  static Future<DeviceIdentity> current() async {
    final uuid = await _ensureUuid();
    final info = DeviceInfoPlugin();
    String? appVersion;
    try {
      final pkg = await PackageInfo.fromPlatform();
      appVersion = '${pkg.version}+${pkg.buildNumber}';
    } catch (_) {
      appVersion = null;
    }

    if (Platform.isIOS) {
      final ios = await info.iosInfo;
      return DeviceIdentity(
        key: ios.identifierForVendor,
        uuid: uuid,
        platform: 'ios',
        model: ios.utsname.machine,
        osVersion: '${ios.systemName} ${ios.systemVersion}',
        appVersion: appVersion,
      );
    }

    final android = await info.androidInfo;
    String? androidId;
    try {
      androidId = await const AndroidId().getId();
    } catch (_) {
      androidId = null;
    }
    return DeviceIdentity(
      key: androidId,
      uuid: uuid,
      platform: 'android',
      model: '${android.manufacturer} ${android.model}',
      osVersion: 'Android ${android.version.release} (SDK ${android.version.sdkInt})',
      appVersion: appVersion,
    );
  }

  static Future<String> _ensureUuid() async {
    final existing = await secureStorage.readSecureData(_uuidStorageKey);
    if (existing is String && existing.isNotEmpty) return existing;
    final generated = _randomUuidV4();
    await secureStorage.writeSecureData(_uuidStorageKey, generated);
    return generated;
  }

  static String _randomUuidV4() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
    return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
        '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
  }

  Map<String, String> toBody() => {
        if (key != null && key!.isNotEmpty) 'deviceKey': key!,
        'deviceUuid': uuid,
        'platform': platform,
        if (model != null && model!.isNotEmpty) 'model': model!,
        if (osVersion != null && osVersion!.isNotEmpty) 'osVersion': osVersion!,
        if (appVersion != null && appVersion!.isNotEmpty) 'appVersion': appVersion!,
      };
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/attendance_device_binding_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/device/device_identity.dart test/attendance_device_binding_test.dart
git commit -m "feat(asistencia): módulo de identidad de dispositivo en la app"
```

---

## Task 7: `BiometricGate`

**Files:**
- Create: `lib/core/device/biometric_gate.dart`
- Test: `test/attendance_device_binding_test.dart` (grupo `BiometricGate`)

**Interfaces:**
- Consumes: `local_auth` (`LocalAuthentication`), `local_auth/error_codes.dart`.
- Produces:
  - `enum BiometricOutcome { ok, skipped, failed, noLock }`
  - `class BiometricResult { BiometricOutcome outcome; String? type; bool get passed; String get apiValue; }` — `apiValue` ∈ `'ok'|'skipped'|'failed'`
  - `class BiometricGate { BiometricGate([LocalAuthentication? auth]); Future<BiometricResult> verify(String reason); }`

- [ ] **Step 1: Write the failing test**

Añadir a `test/attendance_device_binding_test.dart`:

```dart
// (arriba, imports)
import 'package:doliv_social/core/device/biometric_gate.dart';

// ... dentro de main():
  group('BiometricResult', () {
    test('apiValue y passed según outcome', () {
      expect(const BiometricResult(BiometricOutcome.ok, 'face').apiValue, 'ok');
      expect(const BiometricResult(BiometricOutcome.ok, 'face').passed, true);
      expect(const BiometricResult(BiometricOutcome.skipped, 'device_credential').apiValue, 'skipped');
      expect(const BiometricResult(BiometricOutcome.skipped, null).passed, true);
      expect(const BiometricResult(BiometricOutcome.failed, null).apiValue, 'failed');
      expect(const BiometricResult(BiometricOutcome.failed, null).passed, false);
      expect(const BiometricResult(BiometricOutcome.noLock, null).passed, false);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/attendance_device_binding_test.dart`
Expected: FAIL — no existe `biometric_gate.dart`.

- [ ] **Step 3: Write `biometric_gate.dart`**

Create `lib/core/device/biometric_gate.dart`:

```dart
import 'package:flutter/services.dart' show PlatformException;
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';

enum BiometricOutcome { ok, skipped, failed, noLock }

/// Resultado de la verificación del sistema operativo antes de fichar.
/// `type` es una pista gruesa de qué factor había disponible
/// ('fingerprint' | 'face' | 'device_credential'), no el factor exacto usado.
class BiometricResult {
  const BiometricResult(this.outcome, this.type);

  final BiometricOutcome outcome;
  final String? type;

  bool get passed =>
      outcome == BiometricOutcome.ok || outcome == BiometricOutcome.skipped;

  String get apiValue => switch (outcome) {
        BiometricOutcome.ok => 'ok',
        BiometricOutcome.skipped => 'skipped',
        _ => 'failed',
      };
}

/// Envuelve `local_auth`. Acepta el PIN/patrón del dispositivo como respaldo
/// (`biometricOnly: false`); si no hay NINGÚN bloqueo de pantalla devuelve
/// `noLock` para que la pantalla de asistencia bloquee el fichaje con una
/// instrucción, en vez de dejar pasar sin verificación (a diferencia del gate
/// más laxo de "Contenido del sitio web").
class BiometricGate {
  BiometricGate([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<BiometricResult> verify(String reason) async {
    try {
      if (!await _auth.isDeviceSupported()) {
        return const BiometricResult(BiometricOutcome.noLock, null);
      }
      final available = await _auth.getAvailableBiometrics();
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (!ok) return const BiometricResult(BiometricOutcome.failed, null);

      if (available.contains(BiometricType.face)) {
        return const BiometricResult(BiometricOutcome.ok, 'face');
      }
      if (available.contains(BiometricType.fingerprint) ||
          available.contains(BiometricType.strong) ||
          available.contains(BiometricType.weak)) {
        return const BiometricResult(BiometricOutcome.ok, 'fingerprint');
      }
      return const BiometricResult(BiometricOutcome.skipped, 'device_credential');
    } on PlatformException catch (e) {
      if (e.code == auth_error.notAvailable ||
          e.code == auth_error.notEnrolled ||
          e.code == auth_error.passcodeNotSet) {
        return const BiometricResult(BiometricOutcome.noLock, null);
      }
      return const BiometricResult(BiometricOutcome.failed, null);
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/attendance_device_binding_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/device/biometric_gate.dart test/attendance_device_binding_test.dart
git commit -m "feat(asistencia): gate biométrico del sistema operativo"
```

---

## Task 8: Modelos + cliente API

**Files:**
- Modify: `lib/models/attendance.dart` (añadir clases al final)
- Modify: `lib/services/attendance_service.dart` (`perform()` + métodos nuevos)
- Test: `test/attendance_device_binding_test.dart` (grupo `modelos de dispositivo`)

**Interfaces:**
- Consumes: `DeviceIdentity` (Task 6), `AttendanceException` (ya existe).
- Produces:
  - En `models/attendance.dart`:
    - `enum AttendanceDeviceState { none, trusted, pending, unknown }` + `AttendanceDeviceState attendanceDeviceStateFrom(String)`
    - `class AttendanceDeviceStatus { AttendanceDeviceState state; String? model; String? osVersion; String? via; factory .fromJson(Map) }`
    - `class DeviceRequestRow { int id; String employeeId; String employeeName; String platform; String? model; String? osVersion; int attempts; String firstSeen; String lastSeen; factory .fromJson(Map) }`
    - `class TrustedDeviceInfo { String? model; String? osVersion; String? platform; String? enrolledAt; String? via; factory .fromJson(Map) }`
    - `class DeviceAnomaly { String type; String employeeId; String employeeName; String detail; String? at; factory .fromJson(Map) }`
  - En `AttendanceApi`:
    - `perform(...)` gana named params `DeviceIdentity? device`, `String? biometricResult`, `String? biometricType`, `double? locationAccuracy`
    - `static Future<AttendanceDeviceStatus> deviceStatus(DeviceIdentity device)`
    - `static Future<AttendanceDeviceState> requestDevice(DeviceIdentity device)`
    - `static Future<List<DeviceRequestRow>> adminDeviceRequests({String status = 'pending'})`
    - `static Future<void> resolveDeviceRequest(int id, {required bool approve, String? note})`
    - `static Future<List<DeviceAnomaly>> adminDeviceAnomalies({int days = 30})`
    - `static Future<TrustedDeviceInfo?> adminEmployeeDevice(String employeeId)`
    - `static Future<void> adminResetEmployeeDevice(String employeeId)`

- [ ] **Step 1: Write the failing test**

Añadir a `test/attendance_device_binding_test.dart`:

```dart
import 'package:doliv_social/models/attendance.dart';

// dentro de main():
  group('modelos de dispositivo', () {
    test('AttendanceDeviceStatus.fromJson', () {
      final s = AttendanceDeviceStatus.fromJson({
        'state': 'pending',
        'device': {'model': 'Pixel 7', 'osVersion': 'Android 14', 'via': 'first_use'},
      });
      expect(s.state, AttendanceDeviceState.pending);
      expect(s.model, 'Pixel 7');
      expect(s.via, 'first_use');
    });

    test('state desconocido cae a unknown', () {
      expect(AttendanceDeviceStatus.fromJson({'state': 'algo-raro'}).state,
          AttendanceDeviceState.unknown);
    });

    test('DeviceRequestRow.fromJson', () {
      final r = DeviceRequestRow.fromJson({
        'id': 4,
        'employee': {'id': 'e1', 'name': 'Ana'},
        'platform': 'android',
        'model': 'Pixel 8',
        'osVersion': 'Android 15',
        'attempts': 3,
        'firstSeen': '2026-09-09 08:00:00',
        'lastSeen': '2026-09-09 09:00:00',
      });
      expect(r.id, 4);
      expect(r.employeeName, 'Ana');
      expect(r.attempts, 3);
    });

    test('DeviceAnomaly.fromJson', () {
      final a = DeviceAnomaly.fromJson({
        'type': 'frequent_device_change',
        'employeeId': 'e1',
        'employeeName': 'Ana',
        'detail': '2 cambios en 30 días',
        'at': null,
      });
      expect(a.type, 'frequent_device_change');
      expect(a.at, isNull);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/attendance_device_binding_test.dart`
Expected: FAIL — `AttendanceDeviceStatus` no definido.

- [ ] **Step 3: Add models to `lib/models/attendance.dart`**

Al final del archivo:

```dart
enum AttendanceDeviceState { none, trusted, pending, unknown }

AttendanceDeviceState attendanceDeviceStateFrom(String? raw) {
  switch (raw) {
    case 'none':
      return AttendanceDeviceState.none;
    case 'trusted':
      return AttendanceDeviceState.trusted;
    case 'pending':
      return AttendanceDeviceState.pending;
    default:
      return AttendanceDeviceState.unknown;
  }
}

/// Estado del dispositivo actual respecto de la cuenta (para pintar el botón
/// de fichar). Ver GET /attendance/device/status.
class AttendanceDeviceStatus {
  const AttendanceDeviceStatus({
    required this.state,
    this.model,
    this.osVersion,
    this.via,
  });

  final AttendanceDeviceState state;
  final String? model;
  final String? osVersion;
  final String? via;

  factory AttendanceDeviceStatus.fromJson(Map<String, dynamic> j) {
    final dev = j['device'];
    final d = dev is Map ? Map<String, dynamic>.from(dev) : const <String, dynamic>{};
    return AttendanceDeviceStatus(
      state: attendanceDeviceStateFrom(j['state'] as String?),
      model: d['model'] as String?,
      osVersion: d['osVersion'] as String?,
      via: d['via'] as String?,
    );
  }
}

/// Fila de la pestaña "Solicitudes pendientes" del panel del director.
class DeviceRequestRow {
  const DeviceRequestRow({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.platform,
    required this.attempts,
    required this.firstSeen,
    required this.lastSeen,
    this.model,
    this.osVersion,
  });

  final int id;
  final String employeeId;
  final String employeeName;
  final String platform;
  final int attempts;
  final String firstSeen;
  final String lastSeen;
  final String? model;
  final String? osVersion;

  factory DeviceRequestRow.fromJson(Map<String, dynamic> j) {
    final emp = j['employee'];
    final e = emp is Map ? Map<String, dynamic>.from(emp) : const <String, dynamic>{};
    return DeviceRequestRow(
      id: (j['id'] as num).toInt(),
      employeeId: (e['id'] ?? '').toString(),
      employeeName: (e['name'] ?? '').toString(),
      platform: (j['platform'] ?? '').toString(),
      attempts: (j['attempts'] as num?)?.toInt() ?? 1,
      firstSeen: (j['firstSeen'] ?? '').toString(),
      lastSeen: (j['lastSeen'] ?? '').toString(),
      model: j['model'] as String?,
      osVersion: j['osVersion'] as String?,
    );
  }
}

/// Dispositivo confiado de un empleado (pestaña "Dispositivos confiados").
class TrustedDeviceInfo {
  const TrustedDeviceInfo({this.model, this.osVersion, this.platform, this.enrolledAt, this.via});

  final String? model;
  final String? osVersion;
  final String? platform;
  final String? enrolledAt;
  final String? via;

  factory TrustedDeviceInfo.fromJson(Map<String, dynamic> j) => TrustedDeviceInfo(
        model: j['model'] as String?,
        osVersion: j['osVersion'] as String?,
        platform: j['platform'] as String?,
        enrolledAt: j['enrolledAt'] as String?,
        via: j['via'] as String?,
      );
}

/// Anomalía de dispositivo para revisión del director.
class DeviceAnomaly {
  const DeviceAnomaly({
    required this.type,
    required this.employeeId,
    required this.employeeName,
    required this.detail,
    this.at,
  });

  final String type;
  final String employeeId;
  final String employeeName;
  final String detail;
  final String? at;

  factory DeviceAnomaly.fromJson(Map<String, dynamic> j) => DeviceAnomaly(
        type: (j['type'] ?? '').toString(),
        employeeId: (j['employeeId'] ?? '').toString(),
        employeeName: (j['employeeName'] ?? '').toString(),
        detail: (j['detail'] ?? '').toString(),
        at: j['at'] as String?,
      );
}
```

- [ ] **Step 4: Run the model test to verify it passes**

Run: `flutter test test/attendance_device_binding_test.dart`
Expected: PASS (grupo `modelos de dispositivo`).

- [ ] **Step 5: Extend `AttendanceApi` in `lib/services/attendance_service.dart`**

1. Import al principio del archivo:

```dart
import 'package:doliv_social/core/device/device_identity.dart';
```

2. Reemplazar la firma y el cuerpo de `perform(...)`:

```dart
  static Future<AttendanceDay> perform(
    AttendanceAction action, {
    double? latitude,
    double? longitude,
    double? locationAccuracy,
    String method = 'gps',
    DeviceIdentity? device,
    String? biometricResult,
    String? biometricType,
  }) async {
    final res = await _post(
      Uri.parse('$kBaseUrl/${action.endpointPath}'),
      {
        'method': method,
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
        if (locationAccuracy != null) 'locationAccuracy': locationAccuracy.toString(),
        'deviceTime': DateTime.now().toIso8601String(),
        if (device != null) ...device.toBody(),
        if (biometricResult != null) 'biometricResult': biometricResult,
        if (biometricType != null) 'biometricType': biometricType,
      },
    );
    return AttendanceDay.fromJson(
      (jsonDecode(res.body) as Map<String, dynamic>)['day'] as Map<String, dynamic>,
    );
  }
```

3. Añadir, en la sección `// ---- empleado ----`:

```dart
  /// Estado del dispositivo actual respecto de la cuenta.
  static Future<AttendanceDeviceStatus> deviceStatus(DeviceIdentity device) async {
    final uri = Uri.parse('$kBaseUrl/attendance/device/status')
        .replace(queryParameters: device.toBody());
    final res = await _get(uri);
    return AttendanceDeviceStatus.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Solicita al director autorizar el dispositivo actual (bloqueado).
  static Future<AttendanceDeviceState> requestDevice(DeviceIdentity device) async {
    final res = await _post(
      Uri.parse('$kBaseUrl/attendance/device/request'),
      device.toBody(),
    );
    final d = jsonDecode(res.body) as Map<String, dynamic>;
    return attendanceDeviceStateFrom(d['state'] as String?);
  }
```

4. Añadir, en la sección `// ---- panel administrativo ----`:

```dart
  static Future<List<DeviceRequestRow>> adminDeviceRequests({String status = 'pending'}) async {
    final uri = Uri.parse('$kBaseUrl/admin/attendance/device-requests')
        .replace(queryParameters: {'status': status});
    final res = await _get(uri);
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return ((decoded['requests'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => DeviceRequestRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> resolveDeviceRequest(int id, {required bool approve, String? note}) async {
    await _post(
      Uri.parse('$kBaseUrl/admin/attendance/device-requests/$id/resolve'),
      {
        'decision': approve ? 'approve' : 'reject',
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  static Future<List<DeviceAnomaly>> adminDeviceAnomalies({int days = 30}) async {
    final uri = Uri.parse('$kBaseUrl/admin/attendance/device-anomalies')
        .replace(queryParameters: {'days': days.toString()});
    final res = await _get(uri);
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return ((decoded['anomalies'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => DeviceAnomaly.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<TrustedDeviceInfo?> adminEmployeeDevice(String employeeId) async {
    final res = await _get(Uri.parse('$kBaseUrl/admin/attendance/$employeeId/device'));
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final d = decoded['device'];
    return d is Map ? TrustedDeviceInfo.fromJson(Map<String, dynamic>.from(d)) : null;
  }

  static Future<void> adminResetEmployeeDevice(String employeeId) async {
    await _post(Uri.parse('$kBaseUrl/admin/attendance/$employeeId/device/reset'), {});
  }
```

- [ ] **Step 6: Run the full test file + analyzer**

Run: `flutter test test/attendance_device_binding_test.dart && flutter analyze lib/services/attendance_service.dart lib/models/attendance.dart`
Expected: tests PASS; analyzer sin errores (warnings preexistentes tolerados).

- [ ] **Step 7: Commit**

```bash
git add lib/models/attendance.dart lib/services/attendance_service.dart test/attendance_device_binding_test.dart
git commit -m "feat(asistencia): modelos y cliente API de dispositivo/biometría"
```

---

## Task 9: Integrar en `attendance_screen.dart`

**Files:**
- Modify: `lib/shared/attendance/attendance_screen.dart`
- Test: `test/attendance_device_screen_test.dart`

**Interfaces:**
- Consumes: `DeviceIdentity.current()`, `BiometricGate`, `AttendanceApi.perform(...)` extendido, `AttendanceApi.deviceStatus()`, `AttendanceApi.requestDevice()`, `AttendanceException.code`.
- Produces: en `_perform()`, para `AttendanceAction.entrada` y `AttendanceAction.salida` se ejecuta `BiometricGate().verify(...)` antes de la red; toda acción envía `DeviceIdentity`; los errores `UNKNOWN_DEVICE` abren un diálogo "Solicitar autorización"; el estado del dispositivo se carga en `_load()` y se muestra un banner cuando es `pending`/`unknown`/`none`.

- [ ] **Step 1: Write the failing test**

Create `test/attendance_device_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doliv_social/shared/attendance/attendance_device_banner.dart';
import 'package:doliv_social/models/attendance.dart';

void main() {
  group('AttendanceDeviceBanner', () {
    Future<void> pump(WidgetTester t, AttendanceDeviceState state) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(body: AttendanceDeviceBanner(state: state, onRequest: () {})),
      ));
    }

    testWidgets('pending: mensaje de espera, sin botón', (t) async {
      await pump(t, AttendanceDeviceState.pending);
      expect(find.textContaining('Esperando'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Solicitar autorización del dispositivo'), findsNothing);
    });

    testWidgets('unknown: botón de solicitud', (t) async {
      await pump(t, AttendanceDeviceState.unknown);
      expect(find.widgetWithText(FilledButton, 'Solicitar autorización del dispositivo'), findsOneWidget);
    });

    testWidgets('none: aviso de que se vinculará', (t) async {
      await pump(t, AttendanceDeviceState.none);
      expect(find.textContaining('se vinculará'), findsOneWidget);
    });

    testWidgets('trusted: no renderiza nada', (t) async {
      await pump(t, AttendanceDeviceState.trusted);
      expect(find.byType(SizedBox), findsWidgets);
      expect(find.textContaining('Esperando'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/attendance_device_screen_test.dart`
Expected: FAIL — no existe `attendance_device_banner.dart`.

- [ ] **Step 3: Create the banner widget**

Create `lib/shared/attendance/attendance_device_banner.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:doliv_social/models/attendance.dart';

/// Aviso sobre el estado del dispositivo encima de los botones de fichaje.
/// No renderiza nada cuando el dispositivo es de confianza.
class AttendanceDeviceBanner extends StatelessWidget {
  const AttendanceDeviceBanner({
    super.key,
    required this.state,
    required this.onRequest,
  });

  final AttendanceDeviceState state;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    switch (state) {
      case AttendanceDeviceState.trusted:
        return const SizedBox.shrink();

      case AttendanceDeviceState.none:
        return _box(
          context,
          icon: Icons.link,
          color: scheme.surfaceContainerHighest,
          child: Text(
            'Este dispositivo se vinculará a tu cuenta la primera vez que fiches.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );

      case AttendanceDeviceState.pending:
        return _box(
          context,
          icon: Icons.hourglass_top,
          color: scheme.secondaryContainer,
          child: Text(
            'Esperando que el director autorice este dispositivo. No podrás fichar hasta entonces.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );

      case AttendanceDeviceState.unknown:
        return _box(
          context,
          icon: Icons.gpp_maybe,
          color: scheme.errorContainer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Este dispositivo no está autorizado para registrar tu asistencia.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: onRequest,
                child: const Text('Solicitar autorización del dispositivo'),
              ),
            ],
          ),
        );
    }
  }

  Widget _box(BuildContext context,
      {required IconData icon, required Color color, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run banner test to verify it passes**

Run: `flutter test test/attendance_device_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Wire the banner + biometric + device identity into `attendance_screen.dart`**

En `lib/shared/attendance/attendance_screen.dart`:

1. Imports:

```dart
import 'package:doliv_social/core/device/device_identity.dart';
import 'package:doliv_social/core/device/biometric_gate.dart';
import 'package:doliv_social/shared/attendance/attendance_device_banner.dart';
```

2. Estado nuevo en el `State`:

```dart
  static const _biometricActions = {AttendanceAction.entrada, AttendanceAction.salida};
  AttendanceDeviceState _deviceState = AttendanceDeviceState.trusted;
  DeviceIdentity? _device;
```

3. En `_load()` (donde ya se llama `AttendanceApi.today()`), tras asignar `_day`, añadir la carga del dispositivo:

```dart
    try {
      _device ??= await DeviceIdentity.current();
      final st = await AttendanceApi.deviceStatus(_device!);
      if (mounted) setState(() => _deviceState = st.state);
    } catch (_) {
      // Si falla, se asume 'trusted' para no bloquear la UI; el backend
      // sigue siendo la capa autoritativa al fichar.
    }
```

4. En `build()`, encima de la fila de botones de fichaje (donde se pasa `onPerform: _perform`), insertar:

```dart
                  AttendanceDeviceBanner(
                    state: _deviceState,
                    onRequest: _requestDevice,
                  ),
```

5. Añadir el método `_requestDevice`:

```dart
  Future<void> _requestDevice() async {
    final device = _device;
    if (device == null) return;
    setState(() => _submitting = true);
    try {
      final state = await AttendanceApi.requestDevice(device);
      if (!mounted) return;
      setState(() {
        _deviceState = state;
        _submitting = false;
      });
      _snack(state == AttendanceDeviceState.trusted
          ? 'Este dispositivo ya está autorizado.'
          : 'Solicitud enviada. El director debe autorizar este dispositivo.');
    } on AttendanceException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(e.message);
    }
  }
```

6. Reemplazar el cuerpo de `_perform(AttendanceAction action)` — tras el `showAppConfirmDialog` y `setState(() => _submitting = true);`, y ANTES del bloque de GPS:

```dart
    // Verificación biométrica del SO para entrada y salida.
    String? bioResult;
    String? bioType;
    if (_biometricActions.contains(action)) {
      final r = await BiometricGate().verify(
        action == AttendanceAction.entrada
            ? 'Confirma tu identidad para registrar tu entrada'
            : 'Confirma tu identidad para registrar tu salida',
      );
      if (r.outcome == BiometricOutcome.noLock) {
        if (!mounted) return;
        setState(() => _submitting = false);
        _snack('Configura una huella, rostro o PIN en tu dispositivo para registrar tu asistencia.');
        return;
      }
      if (!r.passed) {
        if (!mounted) return;
        setState(() => _submitting = false);
        _snack('Verificación cancelada, inténtalo de nuevo.');
        return;
      }
      bioResult = r.apiValue;
      bioType = r.type;
    }

    _device ??= await DeviceIdentity.current();
```

Y en la llamada a `AttendanceApi.perform(...)`, pasar los datos nuevos + accuracy:

```dart
      final pos = _geofenced.contains(action) ? await AttendanceLocation.current() : null;
      final day = await AttendanceApi.perform(
        action,
        latitude: pos?.latitude,
        longitude: pos?.longitude,
        locationAccuracy: pos?.accuracy,
        device: _device,
        biometricResult: bioResult,
        biometricType: bioType,
      );
```

> Ajusta el manejo de `pos` al que ya existe (hoy son `lat`/`lng` locales tomados dentro de un `try`). Mantén el `catch (AttendanceException)` del GPS igual. `Position` de geolocator expone `.accuracy` (double, metros).

7. En el `catch (AttendanceException e)` de `_perform`, tras `_snack(e.message);`, manejar los códigos nuevos:

```dart
      if (e.code == 'UNKNOWN_DEVICE') {
        setState(() => _deviceState = AttendanceDeviceState.unknown);
      }
```

(el `_load()` que ya se llama al final del catch refresca el resto).

- [ ] **Step 6: Run tests + analyze**

Run: `flutter test test/attendance_device_screen_test.dart test/attendance_schedule_tolerance_test.dart && flutter analyze lib/shared/attendance/attendance_screen.dart`
Expected: PASS; analyzer limpio.

- [ ] **Step 7: Commit**

```bash
git add lib/shared/attendance/attendance_screen.dart lib/shared/attendance/attendance_device_banner.dart test/attendance_device_screen_test.dart
git commit -m "feat(asistencia): biometría e identidad de dispositivo en la pantalla de fichaje"
```

---

## Task 10: Pantalla del director + entrada de menú

**Files:**
- Create: `lib/features/dashboard/director/attendance_devices_screen.dart`
- Modify: `lib/shared/widgets/app_menu_sections.dart` (entrada en la sección "Asistencia de empleados" del director, tras "Lugar de asistencia")
- Test: `test/attendance_devices_screen_test.dart`

**Interfaces:**
- Consumes: `AttendanceApi.adminDeviceRequests()`, `resolveDeviceRequest()`, `adminDeviceAnomalies()`; modelos `DeviceRequestRow`, `DeviceAnomaly`.
- Produces: `class AttendanceDevicesScreen extends StatefulWidget` (const constructor), 3 pestañas: "Solicitudes", "Anomalías", (opcional) info. Aprobar muestra `showAppConfirmDialog` con la advertencia de reemplazo.

- [ ] **Step 1: Write the failing test**

Create `test/attendance_devices_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doliv_social/models/attendance.dart';
import 'package:doliv_social/features/dashboard/director/attendance_devices_screen.dart';

void main() {
  testWidgets('DeviceRequestCard muestra empleado, modelo e intentos', (t) async {
    final row = const DeviceRequestRow(
      id: 1, employeeId: 'e1', employeeName: 'Ana Pérez', platform: 'android',
      model: 'Google Pixel 8', osVersion: 'Android 15', attempts: 3,
      firstSeen: '2026-09-09 08:00:00', lastSeen: '2026-09-09 09:00:00',
    );
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DeviceRequestCard(row: row, onApprove: () {}, onReject: () {}),
      ),
    ));
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.textContaining('Google Pixel 8'), findsOneWidget);
    expect(find.textContaining('3'), findsWidgets);
    expect(find.widgetWithText(TextButton, 'Aprobar'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Rechazar'), findsOneWidget);
  });

  testWidgets('AnomalyTile muestra tipo legible y detalle', (t) async {
    final a = const DeviceAnomaly(
      type: 'frequent_device_change', employeeId: 'e1', employeeName: 'Ana',
      detail: '2 cambios de dispositivo en 30 días', at: null,
    );
    await t.pumpWidget(MaterialApp(home: Scaffold(body: AnomalyTile(anomaly: a))));
    expect(find.textContaining('Cambios frecuentes de dispositivo'), findsOneWidget);
    expect(find.textContaining('2 cambios de dispositivo'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/attendance_devices_screen_test.dart`
Expected: FAIL — no existe la pantalla.

- [ ] **Step 3: Create `attendance_devices_screen.dart`**

Create `lib/features/dashboard/director/attendance_devices_screen.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:doliv_social/design/design.dart';
import 'package:doliv_social/models/attendance.dart';
import 'package:doliv_social/services/attendance_service.dart';

/// Panel del director para autorizar el dispositivo de cada empleado y revisar
/// anomalías de vinculación. Solo el director llega aquí (entrada de menú en la
/// sección de asistencia del director).
class AttendanceDevicesScreen extends StatefulWidget {
  const AttendanceDevicesScreen({super.key});

  @override
  State<AttendanceDevicesScreen> createState() => _AttendanceDevicesScreenState();
}

class _AttendanceDevicesScreenState extends State<AttendanceDevicesScreen> {
  late Future<_DevicesData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DevicesData> _load() async {
    final requests = await AttendanceApi.adminDeviceRequests();
    final anomalies = await AttendanceApi.adminDeviceAnomalies();
    return _DevicesData(requests, anomalies);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _resolve(DeviceRequestRow row, {required bool approve}) async {
    if (approve) {
      final ok = await showAppConfirmDialog(
        context,
        title: 'Autorizar dispositivo',
        message:
            'Esto reemplazará el dispositivo actual de ${row.employeeName}. '
            'Solo podrá fichar desde el dispositivo nuevo (${row.model ?? row.platform}).',
        confirmLabel: 'Autorizar',
      );
      if (ok != true) return;
    }
    String? note;
    if (!approve) {
      note = await _askNote();
    }
    try {
      await AttendanceApi.resolveDeviceRequest(row.id, approve: approve, note: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve ? 'Dispositivo autorizado.' : 'Solicitud rechazada.'),
      ));
      _reload();
    } on AttendanceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<String?> _askNote() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Motivo del rechazo (opcional)'),
        content: TextField(controller: ctrl, maxLength: 255, maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AppScaffold(
        appBar: AppBar(
          title: const Text('Dispositivos de asistencia'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Solicitudes'),
            Tab(text: 'Anomalías'),
          ]),
        ),
        body: FutureBuilder<_DevicesData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Text('No se pudo cargar. ${snap.error}',
                    textAlign: TextAlign.center),
              );
            }
            final data = snap.data!;
            return TabBarView(children: [
              _RequestsTab(rows: data.requests, onResolve: _resolve, onRefresh: _reload),
              _AnomaliesTab(items: data.anomalies),
            ]);
          },
        ),
      ),
    );
  }
}

class _DevicesData {
  const _DevicesData(this.requests, this.anomalies);
  final List<DeviceRequestRow> requests;
  final List<DeviceAnomaly> anomalies;
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({required this.rows, required this.onResolve, required this.onRefresh});

  final List<DeviceRequestRow> rows;
  final void Function(DeviceRequestRow, {required bool approve}) onResolve;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text('No hay solicitudes pendientes.'));
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: rows.length,
        itemBuilder: (_, i) => DeviceRequestCard(
          row: rows[i],
          onApprove: () => onResolve(rows[i], approve: true),
          onReject: () => onResolve(rows[i], approve: false),
        ),
      ),
    );
  }
}

class DeviceRequestCard extends StatelessWidget {
  const DeviceRequestCard({
    super.key,
    required this.row,
    required this.onApprove,
    required this.onReject,
  });

  final DeviceRequestRow row;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row.employeeName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('${row.model ?? 'Dispositivo'} · ${row.osVersion ?? row.platform}',
                style: Theme.of(context).textTheme.bodySmall),
            Text('${row.attempts} intento(s) · última vez ${row.lastSeen}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onReject, child: const Text('Rechazar')),
                const SizedBox(width: 8),
                TextButton(onPressed: onApprove, child: const Text('Aprobar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnomaliesTab extends StatelessWidget {
  const _AnomaliesTab({required this.items});
  final List<DeviceAnomaly> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Sin anomalías en los últimos 30 días.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => AnomalyTile(anomaly: items[i]),
    );
  }
}

class AnomalyTile extends StatelessWidget {
  const AnomalyTile({super.key, required this.anomaly});
  final DeviceAnomaly anomaly;

  static const _labels = {
    'unknown_device_attempt': 'Intento desde dispositivo no autorizado',
    'first_use_after_history': 'Primer uso con historial de otro dispositivo',
    'frequent_device_change': 'Cambios frecuentes de dispositivo',
    'biometric_skipped_streak': 'Verificación por PIN varios días seguidos',
  };

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.report_gmailerrorred_outlined),
      title: Text(_labels[anomaly.type] ?? anomaly.type),
      subtitle: Text('${anomaly.employeeName} · ${anomaly.detail}'),
    );
  }
}
```

> Verifica los nombres reales en `lib/design/design.dart` (`AppScaffold`, `showAppConfirmDialog`) — ya se usan en `site_content_auth_gate.dart` y `attendance_screen.dart`. Si `AppScaffold` no acepta `appBar`, usa `Scaffold` como en otras pantallas del director (`admin_schedule_screen.dart` marca el patrón — cópialo).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/attendance_devices_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Add the menu entry**

En `lib/shared/widgets/app_menu_sections.dart`:
1. Import: `import 'package:doliv_social/features/dashboard/director/attendance_devices_screen.dart';`
2. En la sección `AppMenuSection(title: 'Asistencia de empleados', ...)`, justo después de la entrada "Lugar de asistencia" (`onTap: () => push(const AdminLocationScreen())`):

```dart
        AppMenuEntry(
          icon: Icons.devices_outlined,
          title: 'Dispositivos de asistencia',
          subtitle: 'Autorizar el dispositivo de cada empleado y ver anomalías',
          onTap: () => push(const AttendanceDevicesScreen()),
        ),
```

> Confirma que esta sección se construye solo para el `director`. Si `app_menu_sections.dart` la comparte con el `manager`, envuelve la nueva entrada en la condición de rol que ya use el archivo (p. ej. `if (role == 'director') ...`), porque la pantalla de dispositivos es exclusiva del director.

- [ ] **Step 6: Full test sweep + analyze**

Run: `flutter test && flutter analyze`
Expected: toda la suite en verde; analyzer sin errores nuevos.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dashboard/director/attendance_devices_screen.dart lib/shared/widgets/app_menu_sections.dart test/attendance_devices_screen_test.dart
git commit -m "feat(asistencia): pantalla del director para dispositivos y anomalías"
```

---

## Task 11: Aviso de privacidad + verificación end-to-end

**Files:**
- Modify: `App-radio/docs/superpowers/specs/2026-09-09-asistencia-vinculacion-dispositivo-biometria-design.md` (marcar entregado) — opcional
- Create: `App-radio/docs/asistencia-dispositivo-aviso-privacidad.md` (texto para RR. HH.)

- [ ] **Step 1: Write the privacy note**

Create `App-radio/docs/asistencia-dispositivo-aviso-privacidad.md`:

```markdown
# Vinculación de dispositivo en asistencia — texto para el aviso de privacidad

Pendiente de revisión por RR. HH. / legal antes de publicar.

> Para garantizar la integridad del registro de asistencia, la aplicación
> vincula tu cuenta a un dispositivo y solicita la verificación del sistema
> operativo (huella, rostro o código de desbloqueo) al registrar tu entrada y
> tu salida. La empresa **no** accede a tus datos biométricos: el sistema
> operativo solo confirma o niega la verificación. Del dispositivo se conserva
> un identificador cifrado (no reversible), el modelo y la versión del sistema,
> con la única finalidad de detectar registros de asistencia hechos con una
> cuenta o un teléfono ajenos. Puedes solicitar el cambio de dispositivo al
> director en caso de pérdida o reemplazo.

## Retención
- Identificador de dispositivo confiado: mientras dure la relación laboral.
- Solicitudes de cambio de dispositivo resueltas: 180 días (purga automática).
- Evidencia por evento de asistencia (dispositivo, resultado de verificación,
  precisión de ubicación): la misma que el resto del registro de asistencia.
```

- [ ] **Step 2: End-to-end manual verification**

Con backend levantado y dos teléfonos físicos (o un teléfono + un emulador con GPS simulado dentro de la geocerca), una sola cuenta de `employee`:

1. **Primer fichaje (first-use):** entrada desde el teléfono A. Pide biometría → OK. Se registra. En `attendance_trusted_devices` hay 1 fila `enrolled_via='first_use'`. La columna `attendance.device_status` del evento = `first_use`.
2. **Fichaje normal:** salida desde el teléfono A → biometría → OK → `device_status='trusted'`.
3. **Préstamo (fraude):** intenta entrada desde el teléfono B con la misma cuenta → respuesta `409 UNKNOWN_DEVICE`, el fichaje NO se registra, aparece 1 fila `pending` en `attendance_device_requests`. La app muestra el banner rojo con "Solicitar autorización del dispositivo".
4. **Solicitud + aprobación:** pulsa "Solicitar autorización" en B → `pending`. En la app del director, pestaña "Solicitudes" muestra la tarjeta; "Aprobar" con confirmación de reemplazo. Tras aprobar, `attendance_trusted_devices` tiene el dispositivo de B con `enrolled_via='director'`; A queda fuera.
5. **A ahora es desconocido:** intenta fichar desde A → `UNKNOWN_DEVICE`.
6. **Reset:** el director usa "Restablecer" sobre el empleado → siguiente fichaje (desde cualquier teléfono) vuelve a `first_use`.
7. **Biometría cancelada:** en el diálogo de huella, cancelar → "Verificación cancelada, inténtalo de nuevo", sin llamada de red (verificar en logs del backend que no llegó request).
8. **Sin bloqueo de pantalla** (emulador sin PIN): fichar entrada → "Configura una huella, rostro o PIN…", sin registro.

Documentar el resultado de cada paso (✓/✗) en el PR.

- [ ] **Step 3: Commit**

```bash
git add App-radio/docs/asistencia-dispositivo-aviso-privacidad.md
git commit -m "docs(asistencia): texto de aviso de privacidad para vinculación de dispositivo"
```

---

## Self-Review (hecho al escribir el plan)

**1. Cobertura del spec:**
- §1.1 biometría cliente → Task 7 (`BiometricGate`) + Task 9 (integración). ✅
- §1.1 identidad de dispositivo → Task 6 (`DeviceIdentity`). ✅
- §1.2 pipeline backend (first-use / match / mismatch / UNKNOWN_DEVICE / BIOMETRIC_REQUIRED) → Task 2 + Task 3. ✅
- §1.3 estados de UI → Task 4 (`/device/status`) + Task 9 (banner). ✅
- §2 migración + columnas → Task 1. ✅
- §3.1 endpoints trabajador → Task 4. §3.2 endpoints director → Task 5. §3.3 cliente → Task 8. ✅
- §4.1 pantalla director → Task 10. §4.2 anomalías → Task 5 (`attendance_device_anomalies`) + Task 10 (pestaña). §4.3 marca en vista existente → **parcial**: el plan expone las anomalías en pantalla propia; el ícono en `admin_attendance_screen` se deja como mejora opcional no incluida en tareas (bajo impacto, evita tocar una pantalla grande fuera de alcance). Anotado como desviación consciente.
- §5 manejo de errores app → Task 9 (noLock / failed / pending / unknown / offline heredado). ✅
- §6 privacidad → Task 11. ✅
- §7 pruebas → cada task trae su test; E2E en Task 11. ✅

**2. Placeholders:** sin "TBD"/"TODO". Los dos puntos con nota al implementador (inyección de `request_body()` en tests de Task 4; nombres de `design.dart` en Task 10) traen instrucción concreta y alternativa, no son huecos.

**3. Consistencia de tipos:**
- `attendance_verify_device()` devuelve `['status','key']` — usado igual en Task 3.
- `attendance_check_biometric()` devuelve `['result','type']` — usado igual en Task 3.
- `attendance_device_from_body()` → `['key','uuid','platform','model','osVersion','appVersion']` — consumido consistentemente en Tasks 2-5.
- `DeviceIdentity.toBody()` claves `deviceKey/deviceUuid/platform/model/osVersion/appVersion` ↔ `attendance_device_from_body()` lee exactamente esas. ✅
- `AttendanceDeviceState { none, trusted, pending, unknown }` ↔ backend `attendance_device_state_for()` devuelve `'none'|'trusted'|'pending'|'unknown'`. ✅
- `BiometricResult.apiValue` ∈ `'ok'|'skipped'|'failed'` ↔ backend `attendance_check_biometric` acepta `'ok'|'skipped'`, rechaza el resto. ✅
- Códigos `UNKNOWN_DEVICE` / `BIOMETRIC_REQUIRED` idénticos en backend (Task 2) y app (Task 9).

---

## Execution Handoff

Ver más abajo en el chat.
