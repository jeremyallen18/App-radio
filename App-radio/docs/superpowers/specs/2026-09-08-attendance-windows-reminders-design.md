# Ventanas de fichaje, tolerancia de retardo y recordatorios de asistencia — diseño

Fecha: 2026-09-08
Estado: aprobado para implementación (decisiones tomadas en la sesión de
brainstorming del 2026-09-08).

## Problema

El módulo de asistencia (`hive-backend/attendance.php` + `attendance_admin.php`,
Flutter `lib/shared/attendance/*`) hoy:

- Marca **retardo** con cualquier segundo pasada la hora de entrada del horario
  (`attendance_day_summary()`: `actualEntry > scheduledEntry` ⇒ `isLate`).
- **No valida ninguna ventana horaria** al fichar: `attendanceEntry`,
  `attendanceMealStart` y `attendanceExit` aceptan la marca a cualquier hora.
- **No recuerda** al trabajador que debe registrar entrada/salida ni que su hora
  de comida está por empezar. El único disparo por tiempo en todo el backend son
  los crons "una vez al día" de recordatorios de reuniones.

Se quiere: (1) tolerancia configurable antes de marcar retardo; (2) impedir
iniciar la hora de comida antes de tiempo; (3) aviso push 15 min antes de la
comida; (4) recordatorios push de entrada y salida; (5) permitir registrar
entrada solo desde 30 min antes; (6) permitir registrar salida solo a partir de
la hora.

## Decisiones (sesión de brainstorming)

| Tema | Decisión |
|------|----------|
| Dónde vive la tolerancia | **Por empleado**, columna `late_tolerance_minutes` en `employee_schedules`, junto a `meal_max_minutes`. El director la edita por persona y en bloque. Se **congela por día** en `attendance_schedule_snapshots`. Default 15, rango 0–60. |
| Entrega de recordatorios | **Push FCM**, reutilizando `notify_user()` → `push_send_to_user()`. Disparo por tiempo con un **cron cada 5 min** + fallback perezoso en `GET /attendance/today`. |
| Esquema de tiempos | **Doble aviso.** Entrada: `entry − 10 min` y de nuevo `entry + 10 min` si sigue sin fichar. Comida: `meal − 15 min`. Salida: `exit` y de nuevo `exit + 15 min` si sigue sin fichar salida. |
| Trabajador sin horario | **Bloquear el fichaje de entrada** (409 `NO_SCHEDULE`), salvo que un evento con ubicación cubra su departamento hoy (ese evento aporta hora + geocerca). |
| `lateMinutes` vs tolerancia | `lateMinutes` sigue siendo el delta real desde `entry_time` (el director ve el atraso verdadero). Solo `isLate` / la insignia "Tardanza" / el `lateCount` mensual respetan la tolerancia. |
| Salida anticipada con permiso | Fuera de alcance: sigue por correcciones del director. |

## 1. Base de datos — migración `031_attendance_windows_reminders.sql`

```sql
ALTER TABLE employee_schedules
  ADD COLUMN late_tolerance_minutes INT NOT NULL DEFAULT 15 AFTER meal_max_minutes;

ALTER TABLE attendance_schedule_snapshots
  ADD COLUMN late_tolerance_minutes INT NOT NULL DEFAULT 15 AFTER meal_max_minutes;

CREATE TABLE IF NOT EXISTS attendance_reminders_sent (
  employee_id CHAR(24)    NOT NULL,
  work_date   DATE        NOT NULL,
  kind        VARCHAR(16) NOT NULL,   -- entry_pre | entry_late | meal_pre | exit_due | exit_late
  sent_at     DATETIME    NOT NULL,
  PRIMARY KEY (employee_id, work_date, kind),
  FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
```

- `schema.sql` se actualiza a mano para reflejar las 2 columnas nuevas y la
  tabla nueva (patrón del repo: las migraciones se aplican con
  `mysql < migrations/031_...sql`).
- Las filas de `employee_schedules` y `attendance_schedule_snapshots` que ya
  existan toman el default 15 sin intervención.

## 2. Reglas de validación (backend, autoritativas)

Todas resuelven el **horario efectivo del día** con esta prioridad:

1. `attendance_schedule_snapshots` de hoy, si existe (histórico congelado).
2. Si no hay snapshot: `event_entry_override_for_day(...).entry_time` (solo para
   la entrada) **??** `employee_schedules` del trabajador.
3. Si nada de lo anterior aporta la hora requerida ⇒ no hay horario.

### 2.1 `attendance.php` — nuevos helpers

```php
// Hora efectiva ('HH:MM:SS') de un campo del horario para hoy, o null si no hay
// horario ni override. $field ∈ {'entry_time','meal_time','exit_time'}.
function attendance_effective_time(PDO $pdo, array $user, string $workDate,
                                   string $field, ?array $override = null): ?string;

// Corta con 409 {success:false, code, message} usando la forma que ya espera la
// app (misma que attendance_fail()).
function attendance_window_fail(string $code, string $message): void;
```

### 2.2 Cambios en los endpoints

| Endpoint | Regla añadida (antes de insertar el evento) |
|---|---|
| `attendanceEntry` | Si no hay horario **ni** override ⇒ `attendance_window_fail('NO_SCHEDULE', 'El director aún no te asignó un horario. Pídele que lo configure para poder registrar tu asistencia.')`. Si `now < entry_efectiva − 30 min` ⇒ `attendance_window_fail('TOO_EARLY', "Todavía es pronto. Podrás registrar tu entrada desde las HH:MM.")` (HH:MM = `entry − 30 min`). Sin tope superior (llegar tarde se resuelve con la tolerancia/retardo). Se ejecuta **antes** de `attendance_verify_location()` y de `attendance_snapshot_schedule()`. |
| `attendanceMealStart` | Tras las comprobaciones de estado actuales: si `now < meal_efectiva` (del snapshot, que ya existe porque hubo entrada) ⇒ `attendance_window_fail('MEAL_TOO_EARLY', "Tu hora de comida empieza a las HH:MM. Aún no puedes iniciarla.")`. Sin gracia: ni un minuto antes. |
| `attendanceExit` | Tras las comprobaciones de estado actuales: si `now < exit_efectiva` (del snapshot) ⇒ `attendance_window_fail('EXIT_TOO_EARLY', "Tu salida es a las HH:MM. Aún no puedes registrarla.")`. "Justo a la hora": a partir de `exit` inclusive; quedarse de más está permitido. |

`attendanceMealSkip` (declarar "hoy no como") **no** cambia: se puede declarar
en cualquier momento de la jornada.

Fallback defensivo: si por cualquier motivo un evento post-entrada no tiene
snapshot, se cae a `employee_schedules`; si tampoco hay, la regla de ventana no
aplica (no hay hora de referencia) y se permite la marca — no debería ocurrir
porque la entrada ya crea el snapshot.

### 2.3 Tolerancia de retardo

`attendance_snapshot_schedule()` incluye `late_tolerance_minutes` en el INSERT
del snapshot (desde `employee_schedules`, o `15` en la rama "solo override sin
horario asignado").

`attendance_day_summary()`:

```php
$tol = (int) ($schedule['late_tolerance_minutes'] ?? 15);
if ($actualEntry > $scheduledEntry) {
    $lateMinutes = (int) round(($actualEntry - $scheduledEntry) / 60); // delta real
    $isLate = $lateMinutes > $tol;                                     // respeta tolerancia
}
```

Payload nuevo: `toleranceMinutes` (int) a nivel del día y
`schedule.lateToleranceMinutes` (int) dentro del bloque `schedule`.

`attendance_schedule_payload()` añade `'lateToleranceMinutes' => (int) $s['late_tolerance_minutes']`.

**Propagación a reportes sin más cambios:** `attendance_reports.php`
(`attendance_period_stats`) y `attendance_range_summary()` leen `$sum['isLate']`
/ `$sum['lateMinutes']` directamente de `attendance_day_summary()`. Con el
cambio anterior, `lateCount` mensual y `onTimeRate` pasan a respetar la
tolerancia automáticamente. No se toca ningún otro archivo de reportes.

### 2.4 Guardar el horario — `attendance_admin.php`

`adminScheduleSave` y `adminScheduleBulkSave`:

- Leen `lateToleranceMinutes` del body: `(int) ($src['lateToleranceMinutes'] ?? 15)`.
- Validan `>= 0 && <= 60`, si no ⇒ `error_response('La tolerancia de retardo debe estar entre 0 y 60 minutos.', 400)`.
- Lo añaden al `INSERT ... ON DUPLICATE KEY UPDATE` de `employee_schedules`
  (`late_tolerance_minutes = VALUES(late_tolerance_minutes)`).

## 3. Recordatorios — `hive-backend/attendance_reminders.php` (nuevo)

`require`-ado por `index.php` justo después de `attendance_reports.php`.

```php
const ATT_REMINDER_GRACE_MIN = 20; // tolera un cron que se retrasa; no dispara avisos rancios

// Idempotente; se puede llamar en cada request. $onlyUserId != null ⇒ solo esa
// persona (uso perezoso desde GET /attendance/today). Devuelve nº de avisos emitidos.
function attendance_dispatch_due_reminders(PDO $pdo, ?string $onlyUserId = null): int;
```

Algoritmo:

1. `if (!is_working_day(date('Y-m-d'))) return 0;` (domingo: nada).
2. `now = new DateTimeImmutable()` (hora del servidor, tz `America/Mexico_City`).
3. Trae los trabajadores con horario:
   `SELECT es.*, u.id, u.email FROM employee_schedules es JOIN users u ON u.id = es.employee_id
    WHERE u.role IN ('employee','manager') AND <SQL_USER_VERIFIED>` (+ `AND u.id = ?` si `$onlyUserId`).
4. Para cada trabajador: si hay snapshot de hoy, usa sus horas (congeladas); si
   no, las de `employee_schedules`. Carga los eventos del día una vez
   (`attendance_events_for`) y la ausencia (`leave_absence_for_day`).
   Los días con evento-override de entrada (feature de nicho): mientras no haya
   snapshot, el aviso `entry_pre`/`entry_late` se calcula sobre la hora del
   horario normal, no la del evento. Aceptado como limitación menor.
5. Para cada `kind` con su `target` (DateTime de hoy) y su precondición:
   - `now >= target` y `now <= target + ATT_REMINDER_GRACE_MIN min`,
   - precondición verdadera,
   - `INSERT INTO attendance_reminders_sent (employee_id, work_date, kind, sent_at) VALUES (?,?,?,?)`
     — si viola la PK (ya enviado) o `rowCount() === 0` (carrera) ⇒ `continue`,
   - `notify_user($pdo, $email, null, 'attendance_reminder', $msg, 'attendance', null)`.

| kind | target | precondición | mensaje |
|---|---|---|---|
| `entry_pre`  | `entry − 10 min` | sin evento `entrada`, sin ausencia aprobada | `Tu entrada es a las HH:MM. No olvides registrarla.` |
| `entry_late` | `entry + 10 min` | sin evento `entrada`, sin ausencia | `Aún no registras tu entrada de hoy (hora asignada HH:MM).` |
| `meal_pre`   | `meal − 15 min`  | con `entrada`; sin `inicio_comida`; sin `sin_comida`; estado ≠ `en_comida`; sin ausencia | `Tu hora de comida empieza a las HH:MM (en 15 minutos).` |
| `exit_due`   | `exit`           | con `entrada`; sin `salida`; sin ausencia | `Ya son las HH:MM. No olvides registrar tu salida.` |
| `exit_late`  | `exit + 15 min`  | con `entrada`; sin `salida`; sin ausencia | `Aún no registras tu salida de hoy.` |

Notas:

- `notify_user()` ya inserta la fila en `notifications` (campana in-app) **y**
  dispara el push FCM best-effort. `collapse_key` queda `null` (no es chat).
- `push_title_for_type()` gana `case 'attendance_reminder': return 'Recordatorio de asistencia';`.
- Si el trabajador tiene una **ausencia aprobada** hoy, ningún kind dispara.
- Si `entry_pre` no llegó a dispararse dentro de su ventana de gracia (cron
  caído 25 min), simplemente se pierde ese kind; `entry_late` cubre el caso.

### 3.1 Cron — `hive-backend/cron_attendance_reminders.php` (nuevo)

Espejo de `cron_announcement_reminders.php`:

```php
require __DIR__ . '/config.php';
require __DIR__ . '/helpers.php';
require __DIR__ . '/leave_requests.php';       // leave_absence_for_day
require __DIR__ . '/attendance.php';           // helpers attendance_*
require __DIR__ . '/attendance_reminders.php';

$n = attendance_dispatch_due_reminders($pdo, null);
fwrite(STDOUT, date('c') . "  recordatorios de asistencia emitidos: $n\n");
```

**Requisito de despliegue (documentado en la cabecera del archivo):** este cron
**debe** ejecutarse cada 5 minutos —

```
*/5 * * * *  /usr/bin/php /home/USUARIO/domains/.../hive-backend/cron_attendance_reminders.php
```

Es la única dependencia de infraestructura de haber elegido FCM para los
recordatorios. En local: `C:\xampp\php\php.exe cron_attendance_reminders.php`.

### 3.2 Fallback perezoso

`attendanceToday()` (endpoint `GET /attendance/today`) llama al final, antes del
`json_response`, `attendance_dispatch_due_reminders($pdo, $user['id'])` (una
sola persona, barato — mismo patrón que `ia_dispatch_due_reminders` en
`internalAnnouncementsList`). Así, si el trabajador abre "Mi asistencia", se
vacía lo que tenga pendiente aunque el cron no exista todavía.

## 4. Flutter

### 4.1 Modelos — `lib/models/attendance.dart`

- `EmployeeSchedule`: `+ final int lateToleranceMinutes;`
  `fromJson`: `lateToleranceMinutes: (json['lateToleranceMinutes'] as num?)?.toInt() ?? 15`.
- `AttendanceDay`: `+ final int? toleranceMinutes;`
  `fromJson`: `toleranceMinutes: (json['toleranceMinutes'] as num?)?.toInt()`.

### 4.2 Servicio — `lib/services/attendance_service.dart`

`saveSchedule(...)` y `bulkSaveSchedule(...)` ganan un parámetro
`required int lateToleranceMinutes`, incluido en el body POST como
`lateToleranceMinutes`.

### 4.3 Editor de horario — `lib/features/dashboard/director/admin_schedule_screen.dart`

- `_ScheduleEditorState`: `late TextEditingController _tolerance;` inicializado a
  `(s?.lateToleranceMinutes ?? 15).toString()`. `dispose()` lo libera.
- Nuevo `AppTextField` bajo el de "Límite de comida":
  `hintText: 'Tolerancia de retardo (minutos)'`, `TextInputType.number`,
  `prefixIcon: Icon(Icons.hourglass_bottom)`.
- Validación en `_save()`: `int? tol = int.tryParse(...)`; si `null || tol < 0 || tol > 60`
  ⇒ `_error = 'La tolerancia de retardo debe estar entre 0 y 60 minutos.'`.
- Se pasa `lateToleranceMinutes: tol` a `saveSchedule` y `bulkSaveSchedule`.
- `_ScheduleRowCard`: nuevo `_MetaChip(icon: Icons.hourglass_bottom, label: '±${s.lateToleranceMinutes} min')`
  en el `Wrap`.

### 4.4 Pantalla del trabajador — `lib/shared/attendance/attendance_screen.dart`

Sin cambio estructural: `_perform()` ya muestra `e.message` en un `SnackBar` y
llama `_load()` tras un `AttendanceException`. Los mensajes de
`NO_SCHEDULE` / `TOO_EARLY` / `MEAL_TOO_EARLY` / `EXIT_TOO_EARLY` llegan legibles
desde el backend.

Mejora de UX (una línea): bajo `AttendancePrimaryAction`, cuando
`day.schedule != null` y el siguiente paso es `entrada` / `inicioComida` /
`salida`, mostrar una leyenda `AppColors.textMuted` con la hora a partir de la
cual estará disponible (`entry − 30 min`, `meal`, `exit` respectivamente),
calculada del `schedule` que ya viaja en `AttendanceDay`. Es informativa; el
gate real es el backend (igual que hoy con la geocerca).

### 4.5 Enrutado del push — sin código de render nuevo

- `lib/shared/notifications/notification_router.dart`: `case 'attendance_reminder':`
  → navega a `AttendanceScreen` (misma ruta que usa `attendance_correction`).
- `NotificationTile` (meta de la campana): `case 'attendance_reminder':`
  → etiqueta "Asistencia" + `Icons.schedule`.
- Los data-messages `attendance_reminder` ya se dibujan por
  `PushService.handleRemoteMessage` (ruta genérica con `BigTextStyleInformation`).
- **Android**: sin permisos nuevos. No se usa `zonedSchedule`; se reutiliza el
  canal `doliv_default` y el pipeline FCM existente.

## 5. Pruebas y verificación

### Backend — `scratchpad/test_attendance_windows.php` (git-ignored)

Contra la BD viva con un trabajador temporal + horario:

- `entrada` sin horario ni override ⇒ 409 `NO_SCHEDULE`.
- `entrada` a `entry − 31 min` ⇒ 409 `TOO_EARLY`; a `entry − 30 min` ⇒ OK.
- `inicio_comida` a `meal − 1 min` ⇒ 409 `MEAL_TOO_EARLY`; a `meal` ⇒ OK.
- `salida` a `exit − 1 min` ⇒ 409 `EXIT_TOO_EARLY`; a `exit` ⇒ OK.
- Tolerancia: entrada a `entry + 15` con `tol=15` ⇒ `isLate=false`;
  a `entry + 16` ⇒ `isLate=true`, `lateMinutes=16`.
- `attendance_dispatch_due_reminders`: cada kind dispara **una vez**
  (segunda llamada ⇒ 0); no dispara con ausencia aprobada; no dispara en domingo;
  respeta la ventana de gracia.
- `php -l` limpio en los archivos nuevos y modificados.

Manipulación del reloj: se insertan los eventos de `attendance` con `event_time`
explícito vía SQL directo para simular las fronteras, o se ajustan las horas del
horario relativas a `NOW()` — lo que resulte más simple por caso.

### Flutter — `test/attendance_schedule_tolerance_test.dart`

- `EmployeeSchedule.fromJson`: default 15 cuando falta la clave; parseo correcto.
- `AttendanceDay.fromJson`: `toleranceMinutes` null-safe.
- `_ScheduleEditor`: renderiza el campo de tolerancia con el valor precargado;
  `_save` rechaza `-1` y `61`, acepta `0` y `60`.

Las 102 pruebas actuales siguen verdes; `flutter analyze` limpio.

## 6. Fuera de alcance

- Salida anticipada autorizada (sigue por el flujo de correcciones del director).
- Reescribir snapshots ya congelados.
- Que los recordatorios lleguen sin cron frecuente **y** sin que el trabajador
  abra la app (imposible; el fallback perezoso de §3.2 es el máximo alcanzable).
- Recordatorios configurables por el trabajador (silenciar/reprogramar).
- Zona horaria por trabajador: el servidor es mono-tz, como todo el resto.

## 7. Handover / despliegue

1. Aplicar `migrations/031_attendance_windows_reminders.sql` a la BD viva.
2. Alta del cron `*/5 * * * *` → `cron_attendance_reminders.php` en el panel del
   hosting.
3. Reconstruir el APK (cambios de modelo + editor de horario + router).
4. Sin cambios en `google-services.json`, `firebase_options.dart` ni claves FCM.
