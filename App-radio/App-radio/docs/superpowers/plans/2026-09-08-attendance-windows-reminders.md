# Ventanas de fichaje, tolerancia de retardo y recordatorios de asistencia — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Añadir a la asistencia una tolerancia de retardo configurable por empleado, ventanas horarias para fichar (entrada ≥ 30 min antes, comida y salida solo a partir de su hora) y recordatorios push de entrada/comida/salida.

**Architecture:** El backend PHP (`hive-backend/attendance*.php`) sigue siendo la capa autoritativa: valida las ventanas con la hora del servidor y calcula el retardo respetando la tolerancia congelada en el snapshot diario. Un archivo nuevo `attendance_reminders.php` emite los recordatorios vía `notify_user()` (que ya dispara FCM), llamado por un cron cada 5 min y, como respaldo, de forma perezosa en `GET /attendance/today`. Flutter solo transporta y muestra: nuevo campo en el editor de horario, leyenda informativa y enrutado del nuevo tipo de notificación.

**Tech Stack:** PHP 8 + PDO/MySQL (sin framework de tests: scripts `scratchpad/test_*.php` + `php -l` + curl contra la BD viva), Flutter/Dart + `flutter test`, FCM (pipeline existente `push.php` / `PushService`).

**Spec:** `docs/superpowers/specs/2026-09-08-attendance-windows-reminders-design.md`

## Global Constraints

- Todo el texto visible al usuario es **100% español**.
- Flutter: usar solo tokens de `lib/design/` (`AppColors`, `AppSpacing`, `AppRadius`); nunca `Colors.black`/`Colors.white`/`Color(0x...)` crudos.
- Commits **a nombre del usuario** (`jeremyallen18 <jeremi.narvaez@gmail.com>`), **sin** trailers `Co-Authored-By` / `Claude-Session` (regla permanente del repo, memoria `no-claude-coauthor`).
- No commitear `App-radio/lib/core/api_config.dart` (cambio local de IP de LAN, intencionalmente sin versionar).
- Rango de la tolerancia: entero **0–60** minutos, default **15**.
- Migraciones se aplican a mano: `mysql < migrations/031_...sql`; `schema.sql` se actualiza en el mismo commit.
- El backend corre en tz `America/Mexico_City` (`config.php`); toda hora es hora del servidor.
- Trabajador = rol `employee` o `manager` y correo verificado (`SQL_USER_VERIFIED`). El director nunca ficha.
- `notify_user(PDO, string $email, ?string $teamId, string $type, string $message, ?string $entityType=null, ?string $entityId=null, ?string $pushTitle=null, ?string $pushBody=null): void` — ya inserta en `notifications` y dispara el push best-effort.

**Rutas de trabajo:**
- Backend: `C:\xampp\htdocs\radio-doliv\App-radio\hive-backend\`
- Flutter: `C:\xampp\htdocs\radio-doliv\App-radio\` (comandos `flutter` desde aquí)
- Repo git: `C:\xampp\htdocs\radio-doliv\` (los paths de `git add` llevan el prefijo `App-radio/`)
- MySQL CLI: `"C:\Program Files\MySQL\MySQL Server 9.6\bin\mysql.exe" -u hive_user -pHivePass_2026! hive_db`
- PHP CLI: `C:\xampp\php\php.exe`

---

### Task 1: Migración 031 — columnas de tolerancia + tabla de dedup

**Files:**
- Create: `hive-backend/migrations/031_attendance_windows_reminders.sql`
- Modify: `hive-backend/schema.sql` (bloque `employee_schedules` ~línea 291, `attendance_schedule_snapshots` ~línea 303; añadir la tabla nueva tras `attendance_location` ~línea 366)

**Interfaces:**
- Produces: columna `employee_schedules.late_tolerance_minutes INT NOT NULL DEFAULT 15`; columna `attendance_schedule_snapshots.late_tolerance_minutes INT NOT NULL DEFAULT 15`; tabla `attendance_reminders_sent (employee_id CHAR(24), work_date DATE, kind VARCHAR(16), sent_at DATETIME, PK(employee_id, work_date, kind))`.

- [ ] **Step 1: Escribir la migración**

Crear `hive-backend/migrations/031_attendance_windows_reminders.sql`:

```sql
-- 031: tolerancia de retardo configurable por empleado + tabla de deduplicación
-- de recordatorios de asistencia. Ver
-- docs/superpowers/specs/2026-09-08-attendance-windows-reminders-design.md

ALTER TABLE employee_schedules
  ADD COLUMN late_tolerance_minutes INT NOT NULL DEFAULT 15 AFTER meal_max_minutes;

ALTER TABLE attendance_schedule_snapshots
  ADD COLUMN late_tolerance_minutes INT NOT NULL DEFAULT 15 AFTER meal_max_minutes;

-- Un aviso por (trabajador, día, tipo). El INSERT que viole la PK indica
-- "ya enviado" y el despachador lo salta. kind ∈
-- entry_pre | entry_late | meal_pre | exit_due | exit_late
CREATE TABLE IF NOT EXISTS attendance_reminders_sent (
  employee_id CHAR(24)    NOT NULL,
  work_date   DATE        NOT NULL,
  kind        VARCHAR(16) NOT NULL,
  sent_at     DATETIME    NOT NULL,
  PRIMARY KEY (employee_id, work_date, kind),
  FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
```

- [ ] **Step 2: Aplicar a la BD viva**

Run:
```bash
"C:\Program Files\MySQL\MySQL Server 9.6\bin\mysql.exe" -u hive_user -pHivePass_2026! hive_db < "C:/xampp/htdocs/radio-doliv/App-radio/hive-backend/migrations/031_attendance_windows_reminders.sql"
```
Expected: sin error.

- [ ] **Step 3: Verificar el esquema vivo**

Run:
```bash
"C:\Program Files\MySQL\MySQL Server 9.6\bin\mysql.exe" -u hive_user -pHivePass_2026! hive_db -e "SHOW COLUMNS FROM employee_schedules LIKE 'late_tolerance_minutes'; SHOW COLUMNS FROM attendance_schedule_snapshots LIKE 'late_tolerance_minutes'; SHOW CREATE TABLE attendance_reminders_sent\G"
```
Expected: las dos columnas existen con `Default 15`; la tabla `attendance_reminders_sent` existe con PK `(employee_id, work_date, kind)`.

- [ ] **Step 4: Reflejar en schema.sql**

En `hive-backend/schema.sql`, dentro de `CREATE TABLE ... employee_schedules`, añadir tras la línea `meal_max_minutes INT NOT NULL DEFAULT 60,`:
```sql
  late_tolerance_minutes INT NOT NULL DEFAULT 15,
```
Dentro de `CREATE TABLE ... attendance_schedule_snapshots`, añadir tras `meal_max_minutes INT NOT NULL,`:
```sql
  late_tolerance_minutes INT NOT NULL DEFAULT 15,
```
Tras el bloque `CREATE TABLE ... attendance_location (...) ENGINE=InnoDB;`, añadir:
```sql

-- Deduplicación de recordatorios de asistencia (migración 031). Un aviso por
-- (trabajador, día, tipo). Ver hive-backend/attendance_reminders.php.
CREATE TABLE IF NOT EXISTS attendance_reminders_sent (
  employee_id CHAR(24)    NOT NULL,
  work_date   DATE        NOT NULL,
  kind        VARCHAR(16) NOT NULL,
  sent_at     DATETIME    NOT NULL,
  PRIMARY KEY (employee_id, work_date, kind),
  FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
```

- [ ] **Step 5: Commit**

```bash
cd "C:/xampp/htdocs/radio-doliv"
git add App-radio/hive-backend/migrations/031_attendance_windows_reminders.sql App-radio/hive-backend/schema.sql
git commit -m "feat(asistencia): migración 031 — tolerancia de retardo y dedup de recordatorios"
```

---

### Task 2: Backend — tolerancia al guardar y devolver el horario

**Files:**
- Modify: `hive-backend/attendance.php` — `attendance_schedule_payload()` (~línea 147), `attendance_snapshot_schedule()` (~línea 171–205)
- Modify: `hive-backend/attendance_admin.php` — `adminScheduleSave()` (~línea 230–266), `adminScheduleBulkSave()` (~línea 274–342)
- Test: `hive-backend/scratchpad/test_attendance_windows.php` (crear; git-ignored — `scratchpad/` ya está en `.gitignore`)

**Interfaces:**
- Consumes: columna `employee_schedules.late_tolerance_minutes` (Task 1).
- Produces:
  - `attendance_schedule_payload(array $s): array` ahora incluye `'lateToleranceMinutes' => (int)$s['late_tolerance_minutes']`.
  - `adminScheduleSave` / `adminScheduleBulkSave` leen `lateToleranceMinutes` del body (default 15, validan 0–60) y lo persisten.
  - `attendance_snapshot_schedule()` congela `late_tolerance_minutes` en el snapshot.

- [ ] **Step 1: Escribir el test del harness (parte "guardar horario")**

Crear `hive-backend/scratchpad/test_attendance_windows.php`:

```php
<?php
// Harness de ventanas de fichaje + tolerancia + recordatorios.
// Uso: C:\xampp\php\php.exe scratchpad/test_attendance_windows.php
require __DIR__ . '/../config.php';
require __DIR__ . '/../helpers.php';

$pass = 0; $fail = 0;
function check(string $name, bool $ok): void {
    global $pass, $fail;
    if ($ok) { $pass++; echo "  OK   $name\n"; }
    else     { $fail++; echo "  FAIL $name\n"; }
}

// --- fixtures: un trabajador temporal con horario ------------------------
$empId = 'tmpwrk' . substr(bin2hex(random_bytes(9)), 0, 18); // 24 chars
$pdo->prepare(
  "INSERT INTO users (id, name, email, password, role, email_verified_at)
   VALUES (?, 'Tmp Worker', ?, 'x', 'employee', NOW())"
)->execute([$empId, $empId . '@test.local']);

function cleanup(PDO $pdo, string $empId): void {
    $pdo->prepare('DELETE FROM attendance_reminders_sent WHERE employee_id = ?')->execute([$empId]);
    $pdo->prepare('DELETE FROM attendance WHERE employee_id = ?')->execute([$empId]);
    $pdo->prepare('DELETE FROM attendance_schedule_snapshots WHERE employee_id = ?')->execute([$empId]);
    $pdo->prepare('DELETE FROM employee_schedules WHERE employee_id = ?')->execute([$empId]);
    $pdo->prepare('DELETE FROM notifications WHERE email = ?')->execute([$empId . '@test.local']);
    $pdo->prepare('DELETE FROM users WHERE id = ?')->execute([$empId]);
}
register_shutdown_function('cleanup', $pdo, $empId);

// --- Task 2: guardar y leer la tolerancia ------------------------------
$pdo->prepare(
  "INSERT INTO employee_schedules
     (employee_id, entry_time, exit_time, meal_time, meal_max_minutes, late_tolerance_minutes)
   VALUES (?, '09:00:00', '17:00:00', '14:00:00', 60, 20)"
)->execute([$empId]);
$s = attendance_schedule_for($pdo, $empId);
$p = attendance_schedule_payload($s);
check('payload incluye lateToleranceMinutes', ($p['lateToleranceMinutes'] ?? null) === 20);

echo "\n$pass OK / $fail FAIL\n";
exit($fail === 0 ? 0 : 1);
```

- [ ] **Step 2: Correr el test — debe fallar**

Run: `cd hive-backend && C:\xampp\php\php.exe scratchpad/test_attendance_windows.php`
Expected: `FAIL payload incluye lateToleranceMinutes` (la clave aún no existe).

- [ ] **Step 3: Implementar payload + snapshot + guardado**

En `hive-backend/attendance.php`, `attendance_schedule_payload()`, añadir la clave antes de `'updatedAt'`:
```php
        'mealMaxMinutes' => (int) $s['meal_max_minutes'],
        'lateToleranceMinutes' => (int) ($s['late_tolerance_minutes'] ?? 15),
        'updatedAt'      => $s['updated_at'] ?? null,
```

En `attendance_snapshot_schedule()`, tras `$mealMax = $sched['meal_max_minutes'] ?? 60;` añadir:
```php
    $lateTol = $sched['late_tolerance_minutes'] ?? 15;
```
Cambiar el INSERT y el array devuelto para incluir la columna:
```php
    $stmt = $pdo->prepare(
        'INSERT INTO attendance_schedule_snapshots
           (employee_id, work_date, entry_time, exit_time, meal_time, meal_max_minutes, late_tolerance_minutes)
         VALUES (?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([$employeeId, $workDate, $entry, $exit, $meal, $mealMax, $lateTol]);
    return [
        'employee_id'            => $employeeId,
        'work_date'              => $workDate,
        'entry_time'             => $entry,
        'exit_time'              => $exit,
        'meal_time'              => $meal,
        'meal_max_minutes'       => $mealMax,
        'late_tolerance_minutes' => $lateTol,
    ];
```

En `hive-backend/attendance_admin.php`, `adminScheduleSave()`: tras `$max = (int) ($body['mealMaxMinutes'] ?? 0);` añadir:
```php
    $lateTol = (int) ($body['lateToleranceMinutes'] ?? 15);
```
Tras la validación de `$max`:
```php
    if ($lateTol < 0 || $lateTol > 60) {
        error_response('La tolerancia de retardo debe estar entre 0 y 60 minutos.', 400);
    }
```
En el `INSERT ... ON DUPLICATE KEY UPDATE`, añadir la columna:
```php
    $stmt = $pdo->prepare(
        'INSERT INTO employee_schedules
           (employee_id, entry_time, exit_time, meal_time, meal_max_minutes, late_tolerance_minutes, updated_by)
         VALUES (?, ?, ?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
           entry_time = VALUES(entry_time),
           exit_time = VALUES(exit_time),
           meal_time = VALUES(meal_time),
           meal_max_minutes = VALUES(meal_max_minutes),
           late_tolerance_minutes = VALUES(late_tolerance_minutes),
           updated_by = VALUES(updated_by)'
    );
    $stmt->execute([$emp['id'], $entry, $exit, $meal, $max, $lateTol, $admin['id']]);
```

En `adminScheduleBulkSave()`: tras `$max = (int) ($src['mealMaxMinutes'] ?? 0);` añadir:
```php
    $lateTol = (int) ($src['lateToleranceMinutes'] ?? 15);
```
Tras la validación de `$max`:
```php
    if ($lateTol < 0 || $lateTol > 60) {
        error_response('La tolerancia de retardo debe estar entre 0 y 60 minutos.', 400);
    }
```
En el `$up` (INSERT ON DUPLICATE del bucle), añadir la columna igual que arriba y pasar `$lateTol` como 6.º parámetro:
```php
        $up = $pdo->prepare(
            'INSERT INTO employee_schedules
               (employee_id, entry_time, exit_time, meal_time, meal_max_minutes, late_tolerance_minutes, updated_by)
             VALUES (?, ?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE
               entry_time = VALUES(entry_time), exit_time = VALUES(exit_time),
               meal_time = VALUES(meal_time), meal_max_minutes = VALUES(meal_max_minutes),
               late_tolerance_minutes = VALUES(late_tolerance_minutes),
               updated_by = VALUES(updated_by)'
        );
        ...
            $up->execute([$eid, $entry, $exit, $meal, $max, $lateTol, $admin['id']]);
```

- [ ] **Step 4: Correr el test + lint — debe pasar**

Run:
```bash
cd hive-backend
C:\xampp\php\php.exe -l attendance.php && C:\xampp\php\php.exe -l attendance_admin.php
C:\xampp\php\php.exe scratchpad/test_attendance_windows.php
```
Expected: `php -l` sin errores; `1 OK / 0 FAIL`.

- [ ] **Step 5: Commit**

```bash
cd "C:/xampp/htdocs/radio-doliv"
git add App-radio/hive-backend/attendance.php App-radio/hive-backend/attendance_admin.php
git commit -m "feat(asistencia): guardar y congelar la tolerancia de retardo del horario"
```

---

### Task 3: Backend — el retardo respeta la tolerancia

**Files:**
- Modify: `hive-backend/attendance.php` — `attendance_day_summary()` (bloque "Llegada tarde", ~línea 262–271; array de retorno ~línea 284–313)
- Test: `hive-backend/scratchpad/test_attendance_windows.php` (añadir casos)

**Interfaces:**
- Consumes: `late_tolerance_minutes` del snapshot/horario (Task 2).
- Produces: `attendance_day_summary()` devuelve `isLate = (deltaMin > tol)`, `lateMinutes` = delta real desde `entry_time`, y dos claves nuevas: `toleranceMinutes` (int) y `schedule.lateToleranceMinutes` (int). `attendance_reports.php` y `attendance_range_summary()` lo heredan sin cambios porque leen `$sum['isLate']`.

- [ ] **Step 1: Añadir los casos al test**

En `scratchpad/test_attendance_windows.php`, antes de la línea `echo "\n$pass OK / $fail FAIL\n";`, añadir:

```php
// --- Task 3: tolerancia en el cálculo de retardo ----------------------
$today = date('Y-m-d');
// snapshot congelado con tolerancia 15
$pdo->prepare('DELETE FROM attendance_schedule_snapshots WHERE employee_id = ?')->execute([$empId]);
$pdo->prepare(
  "INSERT INTO attendance_schedule_snapshots
     (employee_id, work_date, entry_time, exit_time, meal_time, meal_max_minutes, late_tolerance_minutes)
   VALUES (?, ?, '09:00:00', '17:00:00', '14:00:00', 60, 15)"
)->execute([$empId, $today]);

function set_entry(PDO $pdo, string $empId, string $today, string $hms): void {
    $pdo->prepare('DELETE FROM attendance WHERE employee_id = ? AND type = "entrada"')->execute([$empId]);
    $pdo->prepare(
      "INSERT INTO attendance (employee_id, type, work_date, event_time, method)
       VALUES (?, 'entrada', ?, ?, 'gps')"
    )->execute([$empId, $today, $today . ' ' . $hms]);
}
$emp = ['id' => $empId, 'name' => 'Tmp', 'email' => $empId . '@test.local'];

set_entry($pdo, $empId, $today, '09:15:00'); // +15 exactos
$sum = attendance_day_summary($pdo, $emp, $today, attendance_events_for($pdo, $empId, $today));
check('entrada +15 con tol 15 NO es tarde', $sum['isLate'] === false);
check('toleranceMinutes en el payload', ($sum['toleranceMinutes'] ?? null) === 15);

set_entry($pdo, $empId, $today, '09:16:00'); // +16
$sum = attendance_day_summary($pdo, $emp, $today, attendance_events_for($pdo, $empId, $today));
check('entrada +16 con tol 15 SÍ es tarde', $sum['isLate'] === true);
check('lateMinutes es el delta real (16)', (int) $sum['lateMinutes'] === 16);
```

- [ ] **Step 2: Correr — debe fallar**

Run: `cd hive-backend && C:\xampp\php\php.exe scratchpad/test_attendance_windows.php`
Expected: FAIL en "entrada +15 ... NO es tarde" (hoy cualquier segundo tarde) y en "toleranceMinutes en el payload".

- [ ] **Step 3: Implementar**

En `attendance.php`, `attendance_day_summary()`, reemplazar el bloque de "Llegada tarde":
```php
    // Llegada tarde: hora real de entrada vs. horario asignado ese día, con
    // la tolerancia configurada por el director (congelada en el snapshot).
    $tolMinutes = $schedule ? (int) ($schedule['late_tolerance_minutes'] ?? 15) : 15;
    $isLate = false;
    $lateMinutes = 0;
    if ($entrada && $schedule) {
        $scheduledEntry = strtotime($workDate . ' ' . $schedule['entry_time']);
        $actualEntry = strtotime($entrada['event_time']);
        if ($actualEntry > $scheduledEntry) {
            $lateMinutes = (int) round(($actualEntry - $scheduledEntry) / 60); // delta real
            $isLate = $lateMinutes > $tolMinutes;                              // respeta tolerancia
        }
    }
```
En el array de retorno, tras `'lateMinutes' => $lateMinutes,` añadir:
```php
        'toleranceMinutes'   => $tolMinutes,
```
En el sub-array `'schedule' => $schedule ? [ ... ]`, tras `'mealMaxMinutes' => (int) $schedule['meal_max_minutes'],` añadir:
```php
            'lateToleranceMinutes' => (int) ($schedule['late_tolerance_minutes'] ?? 15),
```

- [ ] **Step 4: Correr test + lint — debe pasar**

Run:
```bash
cd hive-backend
C:\xampp\php\php.exe -l attendance.php
C:\xampp\php\php.exe scratchpad/test_attendance_windows.php
```
Expected: `php -l` limpio; `5 OK / 0 FAIL`.

- [ ] **Step 5: Commit**

```bash
cd "C:/xampp/htdocs/radio-doliv"
git add App-radio/hive-backend/attendance.php
git commit -m "feat(asistencia): el retardo solo se marca pasada la tolerancia"
```

---

### Task 4: Backend — helper de hora efectiva + guard de ventana de ENTRADA

**Files:**
- Modify: `hive-backend/attendance.php` — nuevos helpers tras `attendance_snapshot_schedule()` (~línea 205); `attendanceEntry()` (~línea 434–467)
- Test: `hive-backend/scratchpad/test_attendance_windows.php` (añadir casos)

**Interfaces:**
- Consumes: `attendance_schedule_for()`, `attendance_snapshot_schedule` (solo lectura del snapshot), `event_entry_override_for_day(PDO, ?string $deptId, string $workDate): ?array` (ya existe, usado en `attendanceEntry`).
- Produces:
  - `attendance_effective_time(PDO $pdo, string $employeeId, string $workDate, string $field, ?array $override = null): ?string` — devuelve `'HH:MM:SS'` o `null`. `$field ∈ {'entry_time','meal_time','exit_time'}`. Prioridad: snapshot de hoy → `$override[$field]` (solo `entry_time`) → `employee_schedules`.
  - `attendance_window_fail(string $code, string $message): void` — `json_response(['success'=>false,'code'=>$code,'message'=>$message], 409)`.
  - `attendanceEntry` responde `409 {code:'NO_SCHEDULE'}` si no hay horario ni override, y `409 {code:'TOO_EARLY'}` si `now < entrada − 30 min`.

- [ ] **Step 1: Añadir los casos al test**

En `scratchpad/test_attendance_windows.php`, tras los casos de Task 3, añadir:

```php
// --- Task 4: helper de hora efectiva + ventana de entrada -------------
$pdo->prepare('DELETE FROM attendance WHERE employee_id = ?')->execute([$empId]);
$pdo->prepare('DELETE FROM attendance_schedule_snapshots WHERE employee_id = ?')->execute([$empId]);

check('hora efectiva usa el horario cuando no hay snapshot',
    attendance_effective_time($pdo, $empId, $today, 'entry_time') === '09:00:00');

$pdo->prepare(
  "INSERT INTO attendance_schedule_snapshots
     (employee_id, work_date, entry_time, exit_time, meal_time, meal_max_minutes, late_tolerance_minutes)
   VALUES (?, ?, '08:30:00', '16:30:00', '13:30:00', 60, 15)"
)->execute([$empId, $today]);
check('hora efectiva prefiere el snapshot',
    attendance_effective_time($pdo, $empId, $today, 'meal_time') === '13:30:00');
$pdo->prepare('DELETE FROM attendance_schedule_snapshots WHERE employee_id = ?')->execute([$empId]);

// sin horario -> null
$pdo->prepare('DELETE FROM employee_schedules WHERE employee_id = ?')->execute([$empId]);
check('sin horario, hora efectiva es null',
    attendance_effective_time($pdo, $empId, $today, 'entry_time') === null);

// restaurar horario para el resto de la suite
$pdo->prepare(
  "INSERT INTO employee_schedules
     (employee_id, entry_time, exit_time, meal_time, meal_max_minutes, late_tolerance_minutes)
   VALUES (?, '09:00:00', '17:00:00', '14:00:00', 60, 15)"
)->execute([$empId]);
```

> Nota: la validación HTTP de `attendanceEntry` (NO_SCHEDULE / TOO_EARLY) se comprueba con curl en el Step 4; el harness cubre el helper puro, que es la lógica nueva de riesgo.

- [ ] **Step 2: Correr — debe fallar**

Run: `cd hive-backend && C:\xampp\php\php.exe scratchpad/test_attendance_windows.php`
Expected: `FAIL` con error fatal "Call to undefined function attendance_effective_time()".

- [ ] **Step 3: Implementar helpers + guard**

En `attendance.php`, tras el cierre de `attendance_snapshot_schedule()` (antes del comentario `// ---- helpers: cálculos`), añadir:

```php
// Hora efectiva ('HH:MM:SS') de un campo del horario para $workDate, o null si
// el trabajador no tiene horario ni override. Prioridad:
//   1) snapshot del día (histórico congelado), si existe
//   2) $override[$field] — solo para 'entry_time', cuando un evento con
//      ubicación cubre hoy al trabajador
//   3) employee_schedules del trabajador
// $field ∈ {'entry_time','meal_time','exit_time'}.
function attendance_effective_time(PDO $pdo, string $employeeId, string $workDate, string $field, ?array $override = null): ?string {
    $stmt = $pdo->prepare(
        'SELECT entry_time, meal_time, exit_time
         FROM attendance_schedule_snapshots WHERE employee_id = ? AND work_date = ?'
    );
    $stmt->execute([$employeeId, $workDate]);
    $snap = $stmt->fetch();
    if ($snap && !empty($snap[$field])) {
        return $snap[$field];
    }
    if ($field === 'entry_time' && $override && !empty($override['entry_time'])) {
        $t = (string) $override['entry_time'];
        return strlen($t) === 5 ? $t . ':00' : $t;
    }
    $sched = attendance_schedule_for($pdo, $employeeId);
    return $sched && !empty($sched[$field]) ? $sched[$field] : null;
}

// Corta la petición con la forma {success:false, code, message} y 409.
function attendance_window_fail(string $code, string $message): void {
    json_response(['success' => false, 'code' => $code, 'message' => $message], 409);
}
```

En `attendanceEntry()`, justo después de:
```php
    $override = event_entry_override_for_day($pdo, $user['department_id'] ?? null, $workDate);
    $overrideLoc = ($override && $override['latitude'] !== null && $override['longitude'] !== null)
        ? $override : null;
```
añadir **antes** de `attendance_verify_location(...)`:
```php
    // Ventana de entrada: exige horario (o evento-override) y no permite fichar
    // más de 30 minutos antes de la hora asignada.
    $entryEff = attendance_effective_time($pdo, $user['id'], $workDate, 'entry_time', $override);
    if ($entryEff === null) {
        attendance_window_fail('NO_SCHEDULE',
            'El director aún no te asignó un horario. Pídele que lo configure para poder registrar tu asistencia.');
    }
    $opensAt = strtotime($workDate . ' ' . $entryEff) - 30 * 60;
    if (time() < $opensAt) {
        attendance_window_fail('TOO_EARLY',
            'Todavía es pronto. Podrás registrar tu entrada desde las ' . date('H:i', $opensAt) . '.');
    }
```

- [ ] **Step 4: Correr harness + lint + smoke HTTP**

Run:
```bash
cd hive-backend
C:\xampp\php\php.exe -l attendance.php
C:\xampp\php\php.exe scratchpad/test_attendance_windows.php
```
Expected: `php -l` limpio; `9 OK / 0 FAIL`.

Smoke HTTP (Apache arriba). Obtener un token de trabajador real sin horario y probar:
```bash
# sustituir <TOKEN> por el de un employee/manager verificado SIN horario asignado
curl -s -X POST http://localhost/hive-backend/attendance/entry -H "Authorization: <TOKEN>" -d "method=gps"
```
Expected: JSON con `"code":"NO_SCHEDULE"` y HTTP 409. (Si no hay un trabajador sin horario a mano, borrar temporalmente su fila de `employee_schedules`, probar, y restaurarla — o dejar constancia de que el caso quedó cubierto solo por el harness del helper.)

- [ ] **Step 5: Commit**

```bash
cd "C:/xampp/htdocs/radio-doliv"
git add App-radio/hive-backend/attendance.php
git commit -m "feat(asistencia): exige horario y bloquea la entrada más de 30 min antes"
```

---

### Task 5: Backend — ventanas de COMIDA y SALIDA

**Files:**
- Modify: `hive-backend/attendance.php` — `attendanceMealStart()` (~línea 469–503), `attendanceExit()` (~línea 588–616)
- Test: `hive-backend/scratchpad/test_attendance_windows.php` (añadir casos de helper + smoke HTTP)

**Interfaces:**
- Consumes: `attendance_effective_time()`, `attendance_window_fail()` (Task 4).
- Produces: `attendanceMealStart` responde `409 {code:'MEAL_TOO_EARLY'}` si `now < meal_time`. `attendanceExit` responde `409 {code:'EXIT_TOO_EARLY'}` si `now < exit_time`.

- [ ] **Step 1: Añadir casos al test**

En `scratchpad/test_attendance_windows.php`, tras los de Task 4:

```php
// --- Task 5: ventanas de comida y salida (lógica de frontera) --------
// meal_time efectiva y exit_time efectiva desde el horario restaurado
check('meal_time efectiva = 14:00:00',
    attendance_effective_time($pdo, $empId, $today, 'meal_time') === '14:00:00');
check('exit_time efectiva = 17:00:00',
    attendance_effective_time($pdo, $empId, $today, 'exit_time') === '17:00:00');

// simulación de la comparación que hará el endpoint
$mealTs = strtotime($today . ' 14:00:00');
check('12:00 < meal_time  => bloqueado', strtotime($today . ' 12:00:00') < $mealTs);
check('14:00 >= meal_time => permitido', !(strtotime($today . ' 14:00:00') < $mealTs));
```

- [ ] **Step 2: Correr — debe pasar el helper, sin cambios de endpoint aún**

Run: `cd hive-backend && C:\xampp\php\php.exe scratchpad/test_attendance_windows.php`
Expected: `13 OK / 0 FAIL` (estos casos solo ejercitan el helper y `strtotime`; el gate del endpoint se prueba por curl en el Step 4).

- [ ] **Step 3: Implementar los guards**

En `attendanceMealStart()`, tras el bloque de checks de estado (después de `if (attendance_meal_skipped($events)) { attendance_fail(...); }`) y **antes** de `$ev = attendance_insert_event(...)`:
```php
    // Ventana de comida: no se puede iniciar antes de la hora asignada.
    $mealEff = attendance_effective_time($pdo, $user['id'], $workDate, 'meal_time');
    if ($mealEff !== null && time() < strtotime($workDate . ' ' . $mealEff)) {
        attendance_window_fail('MEAL_TOO_EARLY',
            'Tu hora de comida empieza a las ' . substr($mealEff, 0, 5) . '. Aún no puedes iniciarla.');
    }
```

En `attendanceExit()`, tras los checks de estado (después de `if ($state === 'en_comida') { attendance_fail(...); }`) y **antes** de `$ev = attendance_insert_event(...)`:
```php
    // Ventana de salida: solo a partir de la hora asignada ("justo a la hora").
    $exitEff = attendance_effective_time($pdo, $user['id'], $workDate, 'exit_time');
    if ($exitEff !== null && time() < strtotime($workDate . ' ' . $exitEff)) {
        attendance_window_fail('EXIT_TOO_EARLY',
            'Tu salida es a las ' . substr($exitEff, 0, 5) . '. Aún no puedes registrarla.');
    }
```

- [ ] **Step 4: Correr harness + lint + smoke HTTP**

Run:
```bash
cd hive-backend
C:\xampp\php\php.exe -l attendance.php
C:\xampp\php\php.exe scratchpad/test_attendance_windows.php
```
Expected: `php -l` limpio; `13 OK / 0 FAIL`.

Smoke HTTP con un trabajador real cuyo horario tenga `meal_time`/`exit_time` en el futuro respecto a ahora (ajustar su fila en `employee_schedules` a p. ej. `meal_time='23:00:00'`, `exit_time='23:30:00'`, luego registrar entrada válida y):
```bash
curl -s -X POST http://localhost/hive-backend/attendance/meal/start -H "Authorization: <TOKEN>" -d "method=gps"
curl -s -X POST http://localhost/hive-backend/attendance/exit -H "Authorization: <TOKEN>" -d "method=gps"
```
Expected: `"code":"MEAL_TOO_EARLY"` y `"code":"EXIT_TOO_EARLY"`, ambos HTTP 409. Restaurar el horario del trabajador y borrar la entrada de prueba al terminar.

- [ ] **Step 5: Commit**

```bash
cd "C:/xampp/htdocs/radio-doliv"
git add App-radio/hive-backend/attendance.php
git commit -m "feat(asistencia): comida y salida solo a partir de su hora asignada"
```

---

### Task 6: Backend — despachador de recordatorios

**Files:**
- Create: `hive-backend/attendance_reminders.php`
- Modify: `hive-backend/push.php` — `push_title_for_type()` (~línea 126–162)
- Modify: `hive-backend/index.php` — bloque de `require` (~línea 6–8)
- Test: `hive-backend/scratchpad/test_attendance_windows.php` (añadir casos del despachador)

**Interfaces:**
- Consumes: `is_working_day()`, `SQL_USER_VERIFIED`, `attendance_events_for()`, `attendance_pick()`, `attendance_state()`, `attendance_meal_skipped()`, `leave_absence_for_day()`, `notify_user()`.
- Produces: `attendance_dispatch_due_reminders(PDO $pdo, ?string $onlyUserId = null): int` — emite los avisos vencidos (dentro de la ventana de gracia `ATT_REMINDER_GRACE_MIN = 20`), deduplicados por `attendance_reminders_sent`, y devuelve cuántos emitió. `push_title_for_type('attendance_reminder')` → `'Recordatorio de asistencia'`.

- [ ] **Step 1: Añadir casos al test**

En `scratchpad/test_attendance_windows.php`, tras los de Task 5:

```php
// --- Task 6: despachador de recordatorios ----------------------------
require_once __DIR__ . '/../leave_requests.php';
require_once __DIR__ . '/../attendance_reminders.php';

// horario con entrada = ahora - 10 min  => entry_late vencido y dentro de gracia
$nowT = new DateTimeImmutable();
$entryH = $nowT->modify('-10 minutes')->format('H:i:s');
$pdo->prepare('UPDATE employee_schedules SET entry_time = ?, meal_time = "23:30:00", exit_time = "23:59:00" WHERE employee_id = ?')
    ->execute([$entryH, $empId]);
$pdo->prepare('DELETE FROM attendance WHERE employee_id = ?')->execute([$empId]);
$pdo->prepare('DELETE FROM attendance_reminders_sent WHERE employee_id = ?')->execute([$empId]);
$pdo->prepare('DELETE FROM notifications WHERE email = ?')->execute([$empId . '@test.local']);

if (is_working_day($today)) {
    $n1 = attendance_dispatch_due_reminders($pdo, $empId);
    check('primer pase emite entry_pre + entry_late (2)', $n1 === 2);
    $n2 = attendance_dispatch_due_reminders($pdo, $empId);
    check('segundo pase no repite (dedup)', $n2 === 0);
    $cnt = (int) $pdo->query(
        "SELECT COUNT(*) FROM notifications WHERE email = '" . $empId . "@test.local'
         AND type = 'attendance_reminder'"
    )->fetchColumn();
    check('2 filas notifications attendance_reminder', $cnt === 2);

    // con ausencia aprobada: no dispara
    $pdo->prepare('DELETE FROM attendance_reminders_sent WHERE employee_id = ?')->execute([$empId]);
    $lid = substr(bin2hex(random_bytes(12)), 0, 24);
    $pdo->prepare(
      "INSERT INTO leave_requests
         (id, employee_id, type, requested_start_date, requested_end_date, requested_days,
          approved_start_date, approved_end_date, approved_days, status)
       VALUES (?, ?, 'permiso', ?, ?, 1, ?, ?, 1, 'aprobado')"
    )->execute([$lid, $empId, $today, $today, $today, $today]);
    $n3 = attendance_dispatch_due_reminders($pdo, $empId);
    check('con ausencia aprobada no dispara', $n3 === 0);
    $pdo->prepare('DELETE FROM leave_requests WHERE id = ?')->execute([$lid]);
} else {
    check('(domingo: despachador se salta — no evaluado)', true);
}
```

Añadir a `cleanup()` la línea `$pdo->prepare('DELETE FROM leave_requests WHERE employee_id = ?')->execute([$empId]);`.

- [ ] **Step 2: Correr — debe fallar**

Run: `cd hive-backend && C:\xampp\php\php.exe scratchpad/test_attendance_windows.php`
Expected: error fatal "Failed opening required '.../attendance_reminders.php'".

- [ ] **Step 3: Implementar `attendance_reminders.php`**

Crear `hive-backend/attendance_reminders.php`:

```php
<?php
// Recordatorios de asistencia: avisos push de entrada, hora de comida y salida.
// Se disparan por tiempo desde cron_attendance_reminders.php (cada 5 min) y, como
// respaldo, de forma perezosa por GET /attendance/today (solo el usuario actual).
//
// Esquema "doble aviso":
//   entry_pre  = entry - 10 min   entry_late = entry + 10 min
//   meal_pre   = meal  - 15 min
//   exit_due   = exit             exit_late  = exit  + 15 min
//
// Cada (trabajador, día, kind) se emite UNA vez (attendance_reminders_sent, PK).
// La ventana de gracia evita disparar avisos rancios si el cron se retrasa.

const ATT_REMINDER_GRACE_MIN = 20;

// Idempotente; se puede llamar en cada request. $onlyUserId != null => solo esa
// persona (uso perezoso). Devuelve el nº de avisos emitidos.
function attendance_dispatch_due_reminders(PDO $pdo, ?string $onlyUserId = null): int {
    $workDate = date('Y-m-d');
    if (!is_working_day($workDate)) {
        return 0;
    }
    $now = time();
    $graceSec = ATT_REMINDER_GRACE_MIN * 60;

    $sql = "SELECT es.entry_time, es.meal_time, es.exit_time, u.id AS emp_id, u.email
            FROM employee_schedules es
            JOIN users u ON u.id = es.employee_id
            WHERE u.role IN ('employee','manager') AND " . SQL_USER_VERIFIED;
    $params = [];
    if ($onlyUserId !== null) {
        $sql .= ' AND u.id = ?';
        $params[] = $onlyUserId;
    }
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll();
    if (!$rows) {
        return 0;
    }

    $sent = 0;
    foreach ($rows as $r) {
        $empId = $r['emp_id'];
        $email = $r['email'];

        // Horas efectivas: snapshot del día si ya existe (congelado), si no el horario.
        $entryEff = attendance_effective_time($pdo, $empId, $workDate, 'entry_time');
        $mealEff  = attendance_effective_time($pdo, $empId, $workDate, 'meal_time');
        $exitEff  = attendance_effective_time($pdo, $empId, $workDate, 'exit_time');
        if ($entryEff === null) {
            continue;
        }

        if (leave_absence_for_day($pdo, $empId, $workDate)) {
            continue; // ausencia aprobada: ningún aviso
        }

        $events    = attendance_events_for($pdo, $empId, $workDate);
        $hasEntry  = attendance_pick($events, 'entrada') !== null;
        $hasMeal   = attendance_pick($events, 'inicio_comida') !== null;
        $mealSkip  = attendance_meal_skipped($events);
        $inMeal    = attendance_state($events) === 'en_comida';
        $hasExit   = attendance_pick($events, 'salida') !== null;

        $entryTs = strtotime($workDate . ' ' . $entryEff);
        $mealTs  = $mealEff !== null ? strtotime($workDate . ' ' . $mealEff) : null;
        $exitTs  = $exitEff !== null ? strtotime($workDate . ' ' . $exitEff) : null;

        $due = [];
        if (!$hasEntry) {
            $due['entry_pre']  = ['target' => $entryTs - 10 * 60,
                'msg' => 'Tu entrada es a las ' . substr($entryEff, 0, 5) . '. No olvides registrarla.'];
            $due['entry_late'] = ['target' => $entryTs + 10 * 60,
                'msg' => 'Aún no registras tu entrada de hoy (hora asignada ' . substr($entryEff, 0, 5) . ').'];
        }
        if ($hasEntry && !$hasMeal && !$mealSkip && !$inMeal && $mealTs !== null) {
            $due['meal_pre'] = ['target' => $mealTs - 15 * 60,
                'msg' => 'Tu hora de comida empieza a las ' . substr($mealEff, 0, 5) . ' (en 15 minutos).'];
        }
        if ($hasEntry && !$hasExit && $exitTs !== null) {
            $due['exit_due']  = ['target' => $exitTs,
                'msg' => 'Ya son las ' . substr($exitEff, 0, 5) . '. No olvides registrar tu salida.'];
            $due['exit_late'] = ['target' => $exitTs + 15 * 60,
                'msg' => 'Aún no registras tu salida de hoy.'];
        }

        foreach ($due as $kind => $d) {
            if ($now < $d['target'] || $now > $d['target'] + $graceSec) {
                continue; // aún no vence, o ya se pasó la ventana de gracia
            }
            try {
                $ins = $pdo->prepare(
                    'INSERT INTO attendance_reminders_sent (employee_id, work_date, kind, sent_at)
                     VALUES (?, ?, ?, NOW())'
                );
                $ins->execute([$empId, $workDate, $kind]);
            } catch (PDOException $e) {
                if ($e->getCode() === '23000') {
                    continue; // ya enviado (PK) — carrera con otro pase/cron
                }
                throw $e;
            }
            if ($ins->rowCount() === 0) {
                continue;
            }
            notify_user($pdo, $email, null, 'attendance_reminder', $d['msg'], 'attendance', null);
            $sent++;
        }
    }
    return $sent;
}
```

En `hive-backend/push.php`, `push_title_for_type()`, añadir antes de `case 'absence_justification':`:
```php
        case 'attendance_reminder':
            return 'Recordatorio de asistencia';
```

En `hive-backend/index.php`, en el bloque de `require`, tras `require __DIR__ . '/attendance_reports.php';` añadir:
```php
require __DIR__ . '/attendance_reminders.php';
```

- [ ] **Step 4: Correr harness + lint — debe pasar**

Run:
```bash
cd hive-backend
C:\xampp\php\php.exe -l attendance_reminders.php && C:\xampp\php\php.exe -l push.php && C:\xampp\php\php.exe -l index.php
C:\xampp\php\php.exe scratchpad/test_attendance_windows.php
```
Expected: `php -l` limpio; en día laboral `18 OK / 0 FAIL` (o `14 OK` + el caso "(domingo…)" si hoy es domingo).

- [ ] **Step 5: Commit**

```bash
cd "C:/xampp/htdocs/radio-doliv"
git add App-radio/hive-backend/attendance_reminders.php App-radio/hive-backend/push.php App-radio/hive-backend/index.php
git commit -m "feat(asistencia): despachador de recordatorios de entrada, comida y salida"
```

---

### Task 7: Backend — cron + respaldo perezoso en /attendance/today

**Files:**
- Create: `hive-backend/cron_attendance_reminders.php`
- Modify: `hive-backend/attendance.php` — `attendanceToday()` (~línea 618–640)
- Test: ejecución del cron por CLI + smoke HTTP

**Interfaces:**
- Consumes: `attendance_dispatch_due_reminders()` (Task 6).
- Produces: `cron_attendance_reminders.php` ejecutable por CLI que imprime el nº de avisos. `attendanceToday()` llama `attendance_dispatch_due_reminders($pdo, $user['id'])` antes de responder.

- [ ] **Step 1: Crear el cron**

Crear `hive-backend/cron_attendance_reminders.php`:

```php
<?php
// Cron de recordatorios de asistencia. DEBE ejecutarse cada 5 minutos para que
// los avisos (entrada, hora de comida 15 min antes, salida) lleguen a tiempo.
//
// Hostinger -> Cron Jobs:
//   */5 * * * *  /usr/bin/php /home/USUARIO/domains/.../hive-backend/cron_attendance_reminders.php
//
// En local:  C:\xampp\php\php.exe cron_attendance_reminders.php
//
// Es idempotente: cada (trabajador, día, tipo de aviso) se emite una sola vez
// (attendance_reminders_sent). También se dispara de forma perezosa cuando el
// trabajador abre "Mi asistencia" (GET /attendance/today), así que sin este cron
// los avisos siguen llegando, pero solo si el trabajador abre la app.

require __DIR__ . '/config.php';
require __DIR__ . '/helpers.php';
require __DIR__ . '/leave_requests.php';       // leave_absence_for_day
require __DIR__ . '/attendance.php';           // helpers attendance_*
require __DIR__ . '/attendance_reminders.php';

$n = attendance_dispatch_due_reminders($pdo, null);
fwrite(STDOUT, date('c') . "  recordatorios de asistencia emitidos: $n\n");
```

- [ ] **Step 2: Respaldo perezoso en `attendanceToday()`**

En `attendance.php`, `attendanceToday()`, tras `$events = attendance_events_for($pdo, $user['id'], $workDate);` y **antes** de `json_response([`:
```php
    // Respaldo: al abrir "Mi asistencia" se vacían los recordatorios vencidos
    // de este trabajador aunque el cron no esté configurado.
    attendance_dispatch_due_reminders($pdo, $user['id']);
```

- [ ] **Step 3: Ejecutar el cron por CLI**

Run: `cd hive-backend && C:\xampp\php\php.exe cron_attendance_reminders.php`
Expected: una línea `<fecha ISO>  recordatorios de asistencia emitidos: N` (N ≥ 0), sin warnings ni errores.

- [ ] **Step 4: Lint + smoke HTTP**

Run:
```bash
cd hive-backend
C:\xampp\php\php.exe -l cron_attendance_reminders.php && C:\xampp\php\php.exe -l attendance.php
curl -s http://localhost/hive-backend/attendance/today -H "Authorization: <TOKEN-trabajador>"
```
Expected: `php -l` limpio; el GET devuelve 200 con el JSON de `day`/`location` como antes (el respaldo no cambia la forma de la respuesta).

- [ ] **Step 5: Commit**

```bash
cd "C:/xampp/htdocs/radio-doliv"
git add App-radio/hive-backend/cron_attendance_reminders.php App-radio/hive-backend/attendance.php
git commit -m "feat(asistencia): cron de recordatorios + respaldo perezoso al abrir la pantalla"
```

---

### Task 8: Flutter — modelos

**Files:**
- Modify: `lib/models/attendance.dart` — `EmployeeSchedule` (~línea 153–175), `AttendanceDay` (campos ~178–232, `fromJson` ~234–263)
- Test: `test/attendance_schedule_tolerance_test.dart` (crear)

**Interfaces:**
- Consumes: claves JSON `schedule.lateToleranceMinutes` y `toleranceMinutes` que emite el backend (Tasks 2–3).
- Produces:
  - `EmployeeSchedule.lateToleranceMinutes` (`int`, default 15) + parámetro `required` en el constructor.
  - `AttendanceDay.toleranceMinutes` (`int?`) + parámetro `required` en el constructor.

- [ ] **Step 1: Escribir el test**

Crear `test/attendance_schedule_tolerance_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:doliv_social/models/attendance.dart';

void main() {
  group('EmployeeSchedule.lateToleranceMinutes', () {
    test('toma el valor del JSON', () {
      final s = EmployeeSchedule.fromJson({
        'entryTime': '09:00',
        'exitTime': '17:00',
        'mealTime': '14:00',
        'mealMaxMinutes': 60,
        'lateToleranceMinutes': 25,
      });
      expect(s.lateToleranceMinutes, 25);
    });

    test('default 15 cuando falta la clave', () {
      final s = EmployeeSchedule.fromJson({
        'entryTime': '09:00',
        'exitTime': '17:00',
        'mealTime': '14:00',
        'mealMaxMinutes': 60,
      });
      expect(s.lateToleranceMinutes, 15);
    });
  });

  test('AttendanceDay.toleranceMinutes es null-safe', () {
    final d = AttendanceDay.fromJson({'state': 'sin_entrada'});
    expect(d.toleranceMinutes, isNull);
    final d2 = AttendanceDay.fromJson({'state': 'en_jornada', 'toleranceMinutes': 15});
    expect(d2.toleranceMinutes, 15);
  });
}
```

- [ ] **Step 2: Correr — debe fallar**

Run: `flutter test test/attendance_schedule_tolerance_test.dart`
Expected: FAIL de compilación — `lateToleranceMinutes` / `toleranceMinutes` no existen.

- [ ] **Step 3: Implementar**

En `lib/models/attendance.dart`, `EmployeeSchedule`: añadir el campo tras `mealMaxMinutes`:
```dart
  final int mealMaxMinutes;
  final int lateToleranceMinutes;
```
En el constructor, tras `required this.mealMaxMinutes,`:
```dart
    required this.lateToleranceMinutes,
```
En `fromJson`, tras `mealMaxMinutes: (json['mealMaxMinutes'] as num?)?.toInt() ?? 60,`:
```dart
      lateToleranceMinutes: (json['lateToleranceMinutes'] as num?)?.toInt() ?? 15,
```

En `AttendanceDay`: añadir el campo tras `final int lateMinutes;`:
```dart
  final int lateMinutes;
  final int? toleranceMinutes;
```
En el constructor, tras `required this.lateMinutes,`:
```dart
    required this.toleranceMinutes,
```
En `fromJson`, tras `lateMinutes: (json['lateMinutes'] as num?)?.toInt() ?? 0,`:
```dart
      toleranceMinutes: (json['toleranceMinutes'] as num?)?.toInt(),
```

- [ ] **Step 4: Correr test + analyze**

Run:
```bash
flutter test test/attendance_schedule_tolerance_test.dart
flutter analyze lib/models/attendance.dart
```
Expected: 3 tests PASS; analyze sin issues nuevos.

- [ ] **Step 5: Commit**

```bash
cd "C:/xampp/htdocs/radio-doliv"
git add App-radio/lib/models/attendance.dart App-radio/test/attendance_schedule_tolerance_test.dart
git commit -m "feat(asistencia): campos de tolerancia en los modelos Flutter"
```

---

### Task 9: Flutter — servicio de guardado de horario

**Files:**
- Modify: `lib/services/attendance_service.dart` — `saveSchedule()` (~línea 176–195), `bulkSaveSchedule()` (~línea 199–225)
- Test: cubierto por Task 10 (widget test del editor) + `flutter analyze`

**Interfaces:**
- Consumes: `EmployeeSchedule` (Task 8), endpoints `POST /admin/schedules/{id}` y `/admin/schedules/bulk` que ya aceptan `lateToleranceMinutes` (Task 2).
- Produces:
  - `AttendanceApi.saveSchedule(String employeeId, {required String entryTime, required String exitTime, required String mealTime, required int mealMaxMinutes, required int lateToleranceMinutes})`.
  - `AttendanceApi.bulkSaveSchedule({required List<String> employeeIds, required String entryTime, required String exitTime, required String mealTime, required int mealMaxMinutes, required int lateToleranceMinutes})`.

- [ ] **Step 1: Implementar el parámetro en `saveSchedule`**

En `lib/services/attendance_service.dart`, `saveSchedule`, añadir el parámetro y el campo del body:
```dart
  static Future<EmployeeSchedule> saveSchedule(
    String employeeId, {
    required String entryTime,
    required String exitTime,
    required String mealTime,
    required int mealMaxMinutes,
    required int lateToleranceMinutes,
  }) async {
    final res = await _post(
      Uri.parse('$kBaseUrl/admin/schedules/$employeeId'),
      {
        'entryTime': entryTime,
        'exitTime': exitTime,
        'mealTime': mealTime,
        'mealMaxMinutes': mealMaxMinutes.toString(),
        'lateToleranceMinutes': lateToleranceMinutes.toString(),
      },
    );
```

- [ ] **Step 2: Implementar el parámetro en `bulkSaveSchedule`**

```dart
  static Future<({int applied, List<String> failed, String message})>
      bulkSaveSchedule({
    required List<String> employeeIds,
    required String entryTime,
    required String exitTime,
    required String mealTime,
    required int mealMaxMinutes,
    required int lateToleranceMinutes,
  }) async {
    final res = await _post(
      Uri.parse('$kBaseUrl/admin/schedules/bulk'),
      {
        'employeeIds': employeeIds.join(','),
        'entryTime': entryTime,
        'exitTime': exitTime,
        'mealTime': mealTime,
        'mealMaxMinutes': mealMaxMinutes.toString(),
        'lateToleranceMinutes': lateToleranceMinutes.toString(),
      },
    );
```

- [ ] **Step 3: Verificar que el árbol NO compila todavía (llamadas sin el parámetro)**

Run: `flutter analyze lib/`
Expected: errores en `admin_schedule_screen.dart` — "The named parameter 'lateToleranceMinutes' is required". Se corrigen en Task 10. (No commitear todavía: dejar Task 9 y Task 10 en el mismo commit para no romper la build entre tareas.)

- [ ] **Step 4: (sin commit — continúa en Task 10)**

---

### Task 10: Flutter — campo de tolerancia en el editor de horario

**Files:**
- Modify: `lib/features/dashboard/director/admin_schedule_screen.dart` — `_ScheduleEditorState` (~línea 321–475), `_ScheduleRowCard` (~línea 200–272)
- Test: `test/attendance_schedule_tolerance_test.dart` (añadir grupo de widget)

**Interfaces:**
- Consumes: `AttendanceApi.saveSchedule` / `bulkSaveSchedule` con `lateToleranceMinutes` (Task 9); `EmployeeScheduleRow.schedule.lateToleranceMinutes` (Task 8).
- Produces: el editor recoge y valida la tolerancia (0–60, default 15) y la envía; la tarjeta de fila muestra un chip `±N min`.

- [ ] **Step 1: Escribir el widget test**

En `test/attendance_schedule_tolerance_test.dart`, añadir al final del `main()`:

```dart
  group('editor de horario — campo de tolerancia', () {
    testWidgets('renderiza el campo con el valor precargado y valida el rango',
        (tester) async {
      // El editor es privado; se prueba vía su clave de texto visible.
      // Se monta AdminScheduleScreen y se abre el editor de una fila.
    }, skip: 'cubierto por la verificación manual del Step 4; ver plan');
  });
```

> El `_ScheduleEditor` es una clase privada dentro de `admin_schedule_screen.dart`; montarlo aislado exige exponerlo. Para no ampliar la superficie pública, la validación 0–60 se verifica manualmente en el Step 4. El test de modelos (Task 8) ya cubre el parseo. Si se prefiere cobertura automática, marcar `_ScheduleEditor` como `@visibleForTesting` y sustituir el `skip` por un test que teclee `-1`, `61`, `0`, `60` y compruebe el `SnackBar`/texto de error — decisión del implementador.

- [ ] **Step 2: Implementar el estado del editor**

En `admin_schedule_screen.dart`, `_ScheduleEditorState`:

Campo nuevo tras `late TextEditingController _limit;`:
```dart
  late TextEditingController _tolerance;
```
En `initState()`, tras `_limit = TextEditingController(...)`:
```dart
    _tolerance = TextEditingController(
        text: (s?.lateToleranceMinutes ?? 15).toString());
```
En `dispose()`, tras `_limit.dispose();`:
```dart
    _tolerance.dispose();
```
En `_save()`, tras la validación de `limit`:
```dart
    final tol = int.tryParse(_tolerance.text.trim());
    if (tol == null || tol < 0 || tol > 60) {
      setState(() => _error =
          'La tolerancia de retardo debe estar entre 0 y 60 minutos.');
      return;
    }
```
En la llamada `AttendanceApi.bulkSaveSchedule(...)` añadir `lateToleranceMinutes: tol,` y en `AttendanceApi.saveSchedule(...)` añadir `lateToleranceMinutes: tol,`.

En `build()`, tras el `AppTextField` de `_limit`:
```dart
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _tolerance,
            hintText: 'Tolerancia de retardo (minutos)',
            textInputType: TextInputType.number,
            prefixIcon: const Icon(Icons.hourglass_bottom),
          ),
```

- [ ] **Step 3: Implementar el chip en la tarjeta**

En `_ScheduleRowCard.build()`, dentro del `Wrap` (rama `else` de `s == null`), tras el `_MetaChip` de `mealMaxMinutes`:
```dart
                      _MetaChip(
                        icon: Icons.hourglass_bottom,
                        label: '±${s.lateToleranceMinutes} min',
                      ),
```

- [ ] **Step 4: Correr analyze + tests + verificación manual**

Run:
```bash
flutter analyze lib/ test/
flutter test
```
Expected: analyze limpio (salvo los 2–3 infos preexistentes de `dashb_mem`); toda la suite verde (≥ 105 tests: 102 previos + 3 de modelos).

Verificación manual (build de depuración o `flutter run`): abrir *Perfil director → Horarios de empleados → tocar un empleado*; el editor muestra "Tolerancia de retardo (minutos)" precargado a 15 (o el valor guardado); teclear `-1` o `61` y "Guardar" → mensaje de error en rojo; `20` → guarda y la fila muestra el chip `±20 min`.

- [ ] **Step 5: Commit (Tasks 9 + 10 juntas)**

```bash
cd "C:/xampp/htdocs/radio-doliv"
git add App-radio/lib/services/attendance_service.dart App-radio/lib/features/dashboard/director/admin_schedule_screen.dart App-radio/test/attendance_schedule_tolerance_test.dart
git commit -m "feat(asistencia): el director configura la tolerancia de retardo por empleado"
```

---

### Task 11: Flutter — leyenda de disponibilidad + enrutado del recordatorio

**Files:**
- Modify: `lib/shared/attendance/attendance_time_cards.dart` — `AttendancePrimaryAction.build()` (~línea 236–293)
- Modify: `lib/shared/notifications/notification_router.dart` — `switch (type)` (~línea 32–79); import
- Modify: `lib/design/components/notification_tile.dart` — `_meta` getter (~línea 26–43)
- Test: `test/attendance_schedule_tolerance_test.dart` (añadir grupo de leyenda) + suite completa

**Interfaces:**
- Consumes: `AttendanceDay.schedule` (`EmployeeSchedule` con `entryTime`/`mealTime`/`exitTime`), `AttendanceDay.nextAction`, `AttendanceScreen` (destino de navegación).
- Produces: leyenda `AppColors.textMuted` bajo el botón principal cuando el paso es `entrada` / `inicioComida` / `salida` y hay `schedule`; `case 'attendance_reminder'` en el router → `AttendanceScreen`; `case 'attendance_reminder'` en `NotificationTile._meta` → icono reloj + categoría "Asistencia".

- [ ] **Step 1: Escribir el test de la leyenda**

En `test/attendance_schedule_tolerance_test.dart`, añadir:

```dart
  group('leyenda de disponibilidad', () {
    AttendanceDay dayWith(String next) => AttendanceDay.fromJson({
          'state': next == 'entrada' ? 'sin_entrada' : 'en_jornada',
          'nextAction': next,
          'schedule': {
            'entryTime': '09:00',
            'exitTime': '17:00',
            'mealTime': '14:00',
            'mealMaxMinutes': 60,
            'lateToleranceMinutes': 15,
          },
        });

    testWidgets('entrada: muestra "desde las 08:30"', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AttendancePrimaryAction(
            day: dayWith('entrada'),
            submitting: false,
            onPerform: (_) {},
          ),
        ),
      ));
      expect(find.textContaining('08:30'), findsOneWidget);
    });

    testWidgets('inicio de comida: muestra "desde las 14:00"', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AttendancePrimaryAction(
            day: dayWith('inicio_comida'),
            submitting: false,
            onPerform: (_) {},
          ),
        ),
      ));
      expect(find.textContaining('14:00'), findsOneWidget);
    });
  });
```

Añadir el import necesario al inicio del archivo de test:
```dart
import 'package:flutter/material.dart';
import 'package:doliv_social/shared/attendance/attendance_time_cards.dart';
```

- [ ] **Step 2: Correr — debe fallar**

Run: `flutter test test/attendance_schedule_tolerance_test.dart`
Expected: FAIL — no aparece ningún texto con `08:30` / `14:00`.

- [ ] **Step 3: Implementar la leyenda**

En `lib/shared/attendance/attendance_time_cards.dart`, dentro de `AttendancePrimaryAction.build()`, reemplazar el `return Column(children: [ AppButton(...), if (showSkipMeal) ... ])` final para intercalar la leyenda:

```dart
    final hint = _availabilityHint(action, day.schedule);

    return Column(
      children: [
        AppButton(
          label: action.buttonLabel,
          loading: submitting,
          onPressed: submitting ? null : () => onPerform(action),
        ),
        if (hint != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            hint,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
        if (showSkipMeal) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: submitting
                ? null
                : () => onPerform(AttendanceAction.saltarComida),
            child: const Text('Hoy no tomaré hora de comida'),
          ),
          const Text(
            'No registra tu salida. Tu jornada sigue abierta.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  /// Hora ("HH:MM") a partir de la cual el backend acepta el próximo fichaje:
  /// entrada = hora de entrada − 30 min; inicio de comida = hora de comida;
  /// salida = hora de salida. `null` si no hay horario o el paso no aplica.
  String? _availabilityHint(AttendanceAction action, EmployeeSchedule? s) {
    if (s == null) return null;
    switch (action) {
      case AttendanceAction.entrada:
        final t = _minusMinutes(s.entryTime, 30);
        return t == null ? null : 'Disponible desde las $t.';
      case AttendanceAction.inicioComida:
        return 'Disponible desde las ${s.mealTime}.';
      case AttendanceAction.salida:
        return 'Disponible desde las ${s.exitTime}.';
      case AttendanceAction.finComida:
      case AttendanceAction.saltarComida:
        return null;
    }
  }

  /// Resta [minutes] a una hora "HH:MM"; `null` si el formato no es válido.
  String? _minusMinutes(String hhmm, int minutes) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    var total = h * 60 + m - minutes;
    if (total < 0) total += 24 * 60;
    final nh = (total ~/ 60) % 24;
    final nm = total % 60;
    return '${nh.toString().padLeft(2, '0')}:${nm.toString().padLeft(2, '0')}';
  }
```

Verificar que `attendance_time_cards.dart` ya importa `EmployeeSchedule` vía `package:doliv_social/models/attendance.dart` (lo usa `AttendanceScheduleCard`); si no, añadir el import.

- [ ] **Step 4: Implementar el enrutado del recordatorio**

En `lib/shared/notifications/notification_router.dart`:

Cambiar el import de asistencia para traer también la pantalla principal:
```dart
import 'package:doliv_social/shared/attendance/attendance_history_screen.dart';
import 'package:doliv_social/shared/attendance/attendance_screen.dart';
```
En el `switch (type)`, tras el `case 'attendance_correction':`:
```dart
        case 'attendance_reminder':
          target = const AttendanceScreen();
          break;
```

En `lib/design/components/notification_tile.dart`, `_meta`, antes del `default:`:
```dart
      case 'attendance_correction':
        return (icon: Icons.schedule, color: AppColors.accent, category: 'Asistencia');
      case 'attendance_reminder':
        return (icon: Icons.alarm, color: AppColors.accent, category: 'Asistencia');
```

- [ ] **Step 5: Correr suite completa + analyze**

Run:
```bash
flutter analyze lib/ test/
flutter test
```
Expected: analyze sin issues nuevos; toda la suite verde (≥ 107 tests).

- [ ] **Step 6: Commit**

```bash
cd "C:/xampp/htdocs/radio-doliv"
git add App-radio/lib/shared/attendance/attendance_time_cards.dart App-radio/lib/shared/notifications/notification_router.dart App-radio/lib/design/components/notification_tile.dart App-radio/test/attendance_schedule_tolerance_test.dart
git commit -m "feat(asistencia): leyenda de disponibilidad y enrutado del recordatorio push"
```

---

### Task 12: Verificación integral + documentación de despliegue

**Files:**
- Modify: `App-radio/README.md` (sección de asistencia / cron, si existe una lista de crons) — reflejar el cron nuevo y la tolerancia
- Test: revisión end-to-end

**Interfaces:**
- Consumes: todo lo anterior.

- [ ] **Step 1: Regresión completa backend**

Run:
```bash
cd hive-backend
for f in attendance.php attendance_admin.php attendance_reports.php attendance_reminders.php cron_attendance_reminders.php push.php index.php; do C:\xampp\php\php.exe -l $f; done
C:\xampp\php\php.exe scratchpad/test_attendance_windows.php
C:\xampp\php\php.exe scratchpad/test_push.php   # si existe: no debe romperse
```
Expected: `php -l` limpio en todos; harness `... OK / 0 FAIL`; `test_push.php` sin regresión.

- [ ] **Step 2: Regresión completa Flutter**

Run:
```bash
cd "C:/xampp/htdocs/radio-doliv/App-radio"
flutter analyze
flutter test
```
Expected: analyze sin issues nuevos; 100% de la suite verde.

- [ ] **Step 3: Smoke E2E contra la BD viva**

Con un trabajador real verificado y horario asignado (ajustar horas en `employee_schedules` para provocar cada frontera), verificar por curl:
- `POST /attendance/entry` a −31 min → 409 `TOO_EARLY`; a −30 → 200.
- Borrar `employee_schedules` del trabajador → `POST /attendance/entry` → 409 `NO_SCHEDULE`; restaurar.
- Con entrada válida y `meal_time` futuro → `POST /attendance/meal/start` → 409 `MEAL_TOO_EARLY`.
- `exit_time` futuro → `POST /attendance/exit` → 409 `EXIT_TOO_EARLY`.
- `entry_time` = ahora−10 min, sin entrada → `C:\xampp\php\php.exe cron_attendance_reminders.php` → imprime `emitidos: 2`; `GET /notifications` del trabajador incluye 2 filas `attendance_reminder`; segunda corrida del cron → `emitidos: 0`.
- Limpiar todos los datos de prueba (`attendance`, `attendance_reminders_sent`, `notifications`, snapshot) y restaurar el horario original del trabajador.

- [ ] **Step 4: Actualizar README**

En `App-radio/README.md`, buscar la sección de asistencia y/o la lista de crons. Añadir/ajustar:
- Que el horario del empleado incluye una **tolerancia de retardo** (0–60 min, default 15) configurable por el director; el retardo solo se marca al superarla.
- Que la entrada solo se acepta desde 30 min antes; la comida y la salida, solo a partir de su hora.
- Un nuevo cron **cada 5 minutos**: `cron_attendance_reminders.php` (recordatorios push de entrada/comida/salida); si no se configura, los avisos igual llegan al abrir "Mi asistencia".

Mantener el estilo y la longitud de las entradas vecinas del README.

- [ ] **Step 5: Commit**

```bash
cd "C:/xampp/htdocs/radio-doliv"
git add App-radio/README.md
git commit -m "docs: documenta la tolerancia de retardo y el cron de recordatorios de asistencia"
```

- [ ] **Step 6: Handover — pasos manuales de despliegue**

Confirmar con el usuario (no automatizable desde aquí):
1. `migrations/031_attendance_windows_reminders.sql` aplicada a la BD de producción.
2. Alta del cron `*/5 * * * *` → `cron_attendance_reminders.php` en el panel del hosting.
3. Reconstruir el APK (`flutter build apk` — cambios de modelo, editor y router).
4. Sin cambios en `google-services.json`, `firebase_options.dart` ni claves FCM.

---

## Self-Review

**1. Spec coverage:**

| Requisito del spec | Task |
|---|---|
| §1 Migración 031 (2 columnas + tabla) + schema.sql | Task 1 |
| §2.1 helpers `attendance_effective_time`, `attendance_window_fail` | Task 4 |
| §2.2 guard entrada (NO_SCHEDULE, TOO_EARLY 30 min) | Task 4 |
| §2.2 guard comida (MEAL_TOO_EARLY) | Task 5 |
| §2.2 guard salida (EXIT_TOO_EARLY) | Task 5 |
| §2.3 tolerancia en `attendance_day_summary` + `toleranceMinutes` + snapshot | Tasks 2–3 |
| §2.3 propagación a reportes (sin cambio, vía `$sum['isLate']`) | Task 3 (verificado conceptualmente; sin archivo nuevo) |
| §2.4 `adminScheduleSave` / `adminScheduleBulkSave` + payload | Task 2 |
| §3 despachador `attendance_dispatch_due_reminders` (5 kinds, gracia, dedup, ausencia, día laboral) | Task 6 |
| §3 `push_title_for_type('attendance_reminder')` | Task 6 |
| §3.1 cron `cron_attendance_reminders.php` (cada 5 min, documentado) | Task 7 |
| §3.2 respaldo perezoso en `attendanceToday()` | Task 7 |
| §4.1 modelos Flutter (`lateToleranceMinutes`, `toleranceMinutes`) | Task 8 |
| §4.2 servicio (`saveSchedule`/`bulkSaveSchedule`) | Task 9 |
| §4.3 editor de horario (campo + validación + chip) | Task 10 |
| §4.4 leyenda bajo el botón principal | Task 11 |
| §4.5 router `attendance_reminder` + `NotificationTile._meta` | Task 11 |
| §4.5 sin permisos Android nuevos | (sin trabajo — se confirma en Task 12 Step 6) |
| §5 pruebas backend + Flutter | Tasks 2–11 (incrementales) + Task 12 (regresión) |
| §7 handover / despliegue | Task 12 Step 6 |

Sin huecos.

**2. Placeholder scan:** El único `skip` deliberado es el widget test del `_ScheduleEditor` privado (Task 10 Step 1), con justificación explícita y verificación manual sustituta en el mismo Step 4; no es un placeholder de implementación. Sin `TODO`/`TBD`/"handle edge cases".

**3. Type consistency:**
- `attendance_effective_time(PDO, string, string, string, ?array): ?string` — misma firma en Tasks 4, 5, 6, 7.
- `attendance_window_fail(string $code, string $message): void` — Tasks 4, 5.
- `attendance_dispatch_due_reminders(PDO, ?string): int` — Tasks 6, 7, 12.
- `EmployeeSchedule.lateToleranceMinutes` (int, default 15) — Tasks 8, 9, 10, 11 (misma clave JSON `lateToleranceMinutes` en backend Tasks 2–3).
- `AttendanceDay.toleranceMinutes` (int?) — Tasks 8, 11.
- `notify_user(..., 'attendance_reminder', $msg, 'attendance', null)` — Task 6; router matchea `type == 'attendance_reminder'` — Task 11. Coherente.
- kinds `entry_pre|entry_late|meal_pre|exit_due|exit_late` — idénticos en migración (Task 1), despachador (Task 6) y test.

Sin inconsistencias.
