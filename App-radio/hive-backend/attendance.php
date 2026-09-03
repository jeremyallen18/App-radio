<?php
// Sistema de asistencia y hora de comida — para EMPLEADOS y MANAGERS.
//
// El DIRECTOR nunca registra asistencia: attendance_require_worker() corta con
// 403 cualquier operación cuyo rol no sea 'employee' ni 'manager', aunque la
// petición llegue por HTTP directo saltándose la app. El backend es la capa de
// seguridad autoritativa; Flutter solo replica la UX.
//
// Todos los cálculos (duración de comida, tiempo trabajado, llegada tarde,
// exceso de comida) se hacen aquí, con la hora del servidor. El horario
// asignado se congela por día (attendance_schedule_snapshots) al registrar
// la entrada, así un cambio de horario posterior no altera el histórico.
//
// Geocerca: el director define UN lugar de asistencia (lat/lng + radio) en
// `attendance_location`. `entrada` y `fin_comida` se rechazan si el GPS del
// trabajador cae fuera de ese radio (por defecto 10 m).
//
// Endpoints (registrados en index.php):
//   POST /attendance/entry | /attendance/meal/start | /attendance/meal/skip | /attendance/meal/end | /attendance/exit
//        (meal/skip: "hoy no tomaré hora de comida" — solo constancia, NO cierra la jornada)
//   GET  /attendance/today | /attendance/status | /attendance/history
//   GET  /attendance/summary?month=YYYY-MM                 (resumen del mes)
//   POST /attendance/corrections                           (solicitar corrección)
//   GET  /attendance/corrections/my
//   GET  /admin/attendance | /admin/attendance/{employeeId}
//   GET  /admin/attendance/summary?month=&departmentId=
//   GET  /admin/attendance/report?month=&departmentId=&format=csv|pdf
//   GET  /admin/attendance/corrections?status=             (director / manager)
//   POST /admin/attendance/corrections/{id}/resolve        (director / manager)
//   GET  /admin/schedules | /admin/schedules/{employeeId}
//   POST /admin/schedules/{employeeId}   (crear/modificar horario — solo director)
//   GET  /admin/attendance-location      (director / manager)
//   POST /admin/attendance-location      (solo director)

const ATT_MSG_NOT_EMPLOYEE = 'El registro de asistencia no está disponible para este usuario.';

// Tipos de evento que exigen estar físicamente en el lugar de asistencia.
const ATT_GEOFENCED_TYPES = ['entrada', 'fin_comida'];

// ---- helpers: seguridad y estado ---------------------------------------

// Corta la petición si el usuario autenticado no puede registrar asistencia.
// Pueden: 'employee' y 'manager'. No puede: 'director' (nunca es rastreado).
function attendance_require_worker(array $user): void {
    if (!in_array($user['role'] ?? '', ['employee', 'manager'], true)) {
        json_response(['success' => false, 'message' => ATT_MSG_NOT_EMPLOYEE], 403);
    }
}

// Respuesta de error de negocio con la forma que espera la app:
// {success:false, message:"..."} — nunca expone detalles técnicos.
function attendance_fail(string $message, int $status = 409): void {
    json_response(['success' => false, 'message' => $message], $status);
}

// Si el trabajador tiene un permiso APROBADO que cubre este día, no debe (ni
// puede) registrar asistencia: se corta con code=APPROVED_ABSENCE para que la
// app lo maneje como un estado, no como un error. Ver leave_requests.php.
function attendance_block_if_absent(PDO $pdo, array $user, string $workDate): void {
    $absence = leave_absence_for_day($pdo, $user['id'], $workDate);
    if ($absence) {
        json_response([
            'success' => false,
            'code'    => 'APPROVED_ABSENCE',
            'message' => 'No necesitas registrar asistencia porque tienes una ausencia autorizada para este día.',
            'absence' => leave_absence_payload($absence),
        ], 409);
    }
}

// Fecha de la jornada según el reloj del servidor.
function attendance_workday(): string {
    return date('Y-m-d');
}

function attendance_events_for(PDO $pdo, string $employeeId, string $workDate): array {
    $stmt = $pdo->prepare(
        'SELECT id, type, event_time, device_time, latitude, longitude, method
         FROM attendance WHERE employee_id = ? AND work_date = ?
         ORDER BY event_time ASC, id ASC'
    );
    $stmt->execute([$employeeId, $workDate]);
    return $stmt->fetchAll();
}

function attendance_pick(array $events, string $type): ?array {
    foreach ($events as $e) {
        if ($e['type'] === $type) return $e;
    }
    return null;
}

// Estado derivado SOLO de los eventos, siguiendo el ciclo de vida:
// sin_entrada -> en_jornada -> en_comida -> en_jornada -> jornada_terminada
function attendance_state(array $events): string {
    $has = fn($t) => attendance_pick($events, $t) !== null;
    if (!$has('entrada')) return 'sin_entrada';
    if ($has('salida')) return 'jornada_terminada';
    if ($has('inicio_comida') && !$has('fin_comida')) return 'en_comida';
    return 'en_jornada';
}

function attendance_state_label(string $state): string {
    return [
        'sin_entrada'       => 'Sin entrada',
        'en_jornada'        => 'En jornada',
        'en_comida'         => 'En hora de comida',
        'jornada_terminada' => 'Jornada terminada',
    ][$state] ?? $state;
}

// Acción válida según el estado. En jornada, si el empleado ya tomó su hora
// de comida —o declaró que hoy no la tomará (`sin_comida`)— el siguiente paso
// es la salida; si no, iniciar la comida. `sin_comida` NUNCA implica salida:
// el trabajador sigue en jornada hasta que registre la salida explícitamente.
function attendance_primary_action(array $events): ?string {
    $state = attendance_state($events);
    if ($state === 'sin_entrada') return 'entrada';
    if ($state === 'en_comida') return 'fin_comida';
    if ($state === 'jornada_terminada') return null;
    $mealSettled = attendance_pick($events, 'fin_comida') || attendance_pick($events, 'sin_comida');
    return $mealSettled ? 'salida' : 'inicio_comida';
}

// ¿El trabajador declaró hoy que no tomará hora de comida?
function attendance_meal_skipped(array $events): bool {
    return attendance_pick($events, 'sin_comida') !== null;
}

// ---- helpers: horario y snapshot -------------------------------------

function attendance_valid_time(string $value): ?string {
    $value = trim($value);
    if (preg_match('/^([01]\d|2[0-3]):([0-5]\d)$/', $value)) {
        return $value . ':00';
    }
    return null;
}

function attendance_schedule_payload(array $s): array {
    return [
        'entryTime'      => substr($s['entry_time'], 0, 5),
        'exitTime'       => substr($s['exit_time'], 0, 5),
        'mealTime'       => substr($s['meal_time'], 0, 5),
        'mealMaxMinutes' => (int) $s['meal_max_minutes'],
        'updatedAt'      => $s['updated_at'] ?? null,
    ];
}

function attendance_schedule_for(PDO $pdo, string $employeeId): ?array {
    $stmt = $pdo->prepare('SELECT * FROM employee_schedules WHERE employee_id = ?');
    $stmt->execute([$employeeId]);
    return $stmt->fetch() ?: null;
}

// Congela el horario vigente para el día de la entrada. Si ya hay snapshot
// (el empleado ya registró entrada hoy) lo devuelve tal cual: nunca se
// reescribe, aunque el director cambie el horario más tarde.
//
// $entryOverride (HH:MM o HH:MM:SS): si un evento con ubicación cubre a este
// trabajador hoy, su hora de entrada reemplaza la del horario asignado al
// congelar el día — así el cálculo de llegada tarde se hace contra la hora del
// evento. La salida, la comida y el límite no se tocan.
function attendance_snapshot_schedule(PDO $pdo, string $employeeId, string $workDate, ?string $entryOverride = null): ?array {
    $stmt = $pdo->prepare(
        'SELECT * FROM attendance_schedule_snapshots WHERE employee_id = ? AND work_date = ?'
    );
    $stmt->execute([$employeeId, $workDate]);
    $snap = $stmt->fetch();
    if ($snap) return $snap;

    $sched = attendance_schedule_for($pdo, $employeeId);
    if (!$sched && $entryOverride === null) return null;

    // Sin horario asignado pero con override de evento: se congela con la hora
    // del evento y valores por defecto para el resto.
    $entry = $entryOverride !== null
        ? (strlen($entryOverride) === 5 ? $entryOverride . ':00' : $entryOverride)
        : $sched['entry_time'];
    $exit    = $sched['exit_time'] ?? '17:00:00';
    $meal    = $sched['meal_time'] ?? '14:00:00';
    $mealMax = $sched['meal_max_minutes'] ?? 60;

    $stmt = $pdo->prepare(
        'INSERT INTO attendance_schedule_snapshots
           (employee_id, work_date, entry_time, exit_time, meal_time, meal_max_minutes)
         VALUES (?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([$employeeId, $workDate, $entry, $exit, $meal, $mealMax]);
    return [
        'employee_id'      => $employeeId,
        'work_date'        => $workDate,
        'entry_time'       => $entry,
        'exit_time'        => $exit,
        'meal_time'        => $meal,
        'meal_max_minutes' => $mealMax,
    ];
}

// ---- helpers: cálculos -----------------------------------------------

function attendance_minutes_between(string $a, string $b): int {
    return (int) round((strtotime($b) - strtotime($a)) / 60);
}

function attendance_fmt_hm(int $minutes): string {
    if ($minutes < 0) $minutes = 0;
    $h = intdiv($minutes, 60);
    $m = $minutes % 60;
    if ($h > 0 && $m > 0) return "{$h} h {$m} min";
    if ($h > 0) return "{$h} h";
    return "{$m} min";
}

// Resumen completo de un día de asistencia de un empleado. Usa el snapshot
// del horario si existe (histórico congelado); si no, el horario actual.
function attendance_day_summary(PDO $pdo, array $employee, string $workDate, array $events): array {
    $entrada      = attendance_pick($events, 'entrada');
    $inicioComida = attendance_pick($events, 'inicio_comida');
    $finComida    = attendance_pick($events, 'fin_comida');
    $salida       = attendance_pick($events, 'salida');
    $state        = attendance_state($events);
    $mealSkipped  = attendance_meal_skipped($events);

    $stmt = $pdo->prepare(
        'SELECT * FROM attendance_schedule_snapshots WHERE employee_id = ? AND work_date = ?'
    );
    $stmt->execute([$employee['id'], $workDate]);
    $schedule = $stmt->fetch() ?: attendance_schedule_for($pdo, $employee['id']);

    $now = date('Y-m-d H:i:s');

    // Duración de la comida: solo cuando está COMPLETA.
    $mealMinutes = ($inicioComida && $finComida)
        ? attendance_minutes_between($inicioComida['event_time'], $finComida['event_time'])
        : null;

    // Comida en curso (para el temporizador de la app).
    $mealElapsedMinutes = ($inicioComida && !$finComida)
        ? max(0, attendance_minutes_between($inicioComida['event_time'], $now))
        : null;

    // Tiempo trabajado efectivo = (salida - entrada) - comida completada.
    // Si aún no hay salida, se calcula hasta "ahora" y se marca en curso.
    $workedMinutes = null;
    $workedInProgress = false;
    if ($entrada) {
        $end = $salida ? $salida['event_time'] : $now;
        $gross = attendance_minutes_between($entrada['event_time'], $end);
        $workedMinutes = max(0, $gross - ($mealMinutes ?? 0));
        $workedInProgress = $salida === null;
    }

    // Llegada tarde: hora real de entrada vs. horario asignado ese día.
    $isLate = false;
    $lateMinutes = 0;
    if ($entrada && $schedule) {
        $scheduledEntry = strtotime($workDate . ' ' . $schedule['entry_time']);
        $actualEntry = strtotime($entrada['event_time']);
        if ($actualEntry > $scheduledEntry) {
            $lateMinutes = (int) round(($actualEntry - $scheduledEntry) / 60);
            $isLate = $lateMinutes > 0;
        }
    }

    // Exceso de hora de comida (no impide terminar, solo se registra).
    $mealLimit = $schedule ? (int) $schedule['meal_max_minutes'] : null;
    $mealExceeded = false;
    $mealExcessMinutes = 0;
    if ($mealMinutes !== null && $mealLimit !== null && $mealMinutes > $mealLimit) {
        $mealExceeded = true;
        $mealExcessMinutes = $mealMinutes - $mealLimit;
    }

    $hm = fn($e) => $e ? date('H:i', strtotime($e['event_time'])) : null;

    return [
        'workDate'           => $workDate,
        'state'              => $state,
        'stateLabel'         => attendance_state_label($state),
        'nextAction'         => attendance_primary_action($events),
        'entrada'            => $hm($entrada),
        'inicioComida'       => $hm($inicioComida),
        'finComida'          => $hm($finComida),
        'salida'             => $hm($salida),
        // El trabajador declaró que hoy no tomará hora de comida. Es solo
        // constancia: NO hay salida ni cierre de jornada por esto.
        'mealSkipped'        => $mealSkipped,
        'mealMinutes'        => $mealMinutes,
        'mealMinutesLabel'   => $mealMinutes !== null ? attendance_fmt_hm($mealMinutes) : null,
        'mealElapsedMinutes' => $mealElapsedMinutes,
        'workedMinutes'      => $workedMinutes,
        'workedLabel'        => $workedMinutes !== null ? attendance_fmt_hm($workedMinutes) : null,
        'workedInProgress'   => $workedInProgress,
        'isLate'             => $isLate,
        'lateMinutes'        => $lateMinutes,
        'mealLimitMinutes'   => $mealLimit,
        'mealExceeded'       => $mealExceeded,
        'mealExcessMinutes'  => $mealExcessMinutes,
        'schedule'           => $schedule ? [
            'entryTime'      => substr($schedule['entry_time'], 0, 5),
            'exitTime'       => substr($schedule['exit_time'], 0, 5),
            'mealTime'       => substr($schedule['meal_time'], 0, 5),
            'mealMaxMinutes' => (int) $schedule['meal_max_minutes'],
        ] : null,
    ];
}

// ---- helpers: geocerca (lugar de asistencia) ----------------------

// Extrae latitude/longitude del cuerpo de la petición, o [null, null].
function attendance_coords_from_body(array $body): array {
    $lat = isset($body['latitude']) && $body['latitude'] !== ''
        ? (float) $body['latitude'] : null;
    $lng = isset($body['longitude']) && $body['longitude'] !== ''
        ? (float) $body['longitude'] : null;
    return [$lat, $lng];
}

// Distancia en metros entre dos coordenadas (haversine).
function attendance_distance_m(float $lat1, float $lng1, float $lat2, float $lng2): float {
    $R = 6371000.0; // radio terrestre en metros
    $dLat = deg2rad($lat2 - $lat1);
    $dLng = deg2rad($lng2 - $lng1);
    $x = sin($dLat / 2) ** 2
        + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;
    return 2 * $R * asin(min(1.0, sqrt($x)));
}

function attendance_location_row(PDO $pdo): ?array {
    $row = $pdo->query('SELECT * FROM attendance_location WHERE id = 1')->fetch();
    return $row ?: null;
}

function attendance_location_payload(?array $row): ?array {
    if (!$row) return null;
    return [
        'latitude'  => (float) $row['latitude'],
        'longitude' => (float) $row['longitude'],
        'radiusM'   => (int) $row['radius_m'],
        'label'     => $row['label'],
        'updatedAt' => $row['updated_at'] ?? null,
    ];
}

// Verifica la ubicación para los eventos que exigen presencia física
// (entrada y fin_comida). Corta la petición con un mensaje en español si:
//   - el director aún no configuró el lugar de asistencia,
//   - el trabajador no mandó coordenadas,
//   - o está fuera del radio configurado.
// Para el resto de eventos (inicio_comida, salida) no bloquea.
// $overrideLoc: si llega (array con latitude/longitude/radius_m, misma forma que
// la fila de attendance_location), se valida contra ese punto en vez del lugar
// de asistencia global. Lo usa la ENTRADA cuando un evento con ubicación cubre
// al trabajador ese día.
function attendance_verify_location(PDO $pdo, string $type, ?float $lat, ?float $lng, ?array $overrideLoc = null): void {
    if (!in_array($type, ATT_GEOFENCED_TYPES, true)) {
        return;
    }
    $loc = $overrideLoc ?: attendance_location_row($pdo);
    if (!$loc) {
        attendance_fail('El lugar de asistencia aún no ha sido configurado por el director.', 409);
    }
    if ($lat === null || $lng === null) {
        attendance_fail('No fue posible verificar tu ubicación. Activa el GPS e inténtalo de nuevo.', 422);
    }
    $dist = attendance_distance_m((float) $loc['latitude'], (float) $loc['longitude'], $lat, $lng);
    if ($dist > (float) $loc['radius_m']) {
        attendance_fail('Estás fuera de la zona autorizada para registrar asistencia.', 422);
    }
}

// ---- helpers: inserción de eventos --------------------------------

// Mensaje de negocio cuando un evento ya existe para hoy. Se usa tanto en las
// comprobaciones previas de cada handler como en el backstop de concurrencia
// (violación del índice único uq_attendance_evento).
function attendance_duplicate_message(string $type): string {
    return [
        'entrada'       => 'Ya tienes una entrada registrada para hoy.',
        'inicio_comida' => 'Ya registraste tu hora de comida hoy.',
        'fin_comida'    => 'Ya registraste el fin de tu hora de comida hoy.',
        'salida'        => 'Ya registraste tu salida hoy.',
        'sin_comida'    => 'Ya indicaste que hoy no tomarás hora de comida.',
    ][$type] ?? 'Esa acción de asistencia ya está registrada para hoy.';
}

// Inserta un evento inmutable. La marca oficial es SIEMPRE la hora del
// servidor; device_time (si llega) se guarda solo como diagnóstico. La
// verificación de ubicación ya se hizo antes (attendance_verify_location).
//
// Concurrencia: las comprobaciones previas de cada handler (SELECT + if) NO son
// atómicas frente a dos peticiones simultáneas del mismo trabajador (doble
// toque, reintento de red, dos dispositivos). El índice único
// uq_attendance_evento (employee_id, work_date, type) cierra esa ventana a
// nivel de motor: la segunda inserción lanza SQLSTATE 23000 y aquí se traduce
// al mismo mensaje de negocio en vez de crear un evento duplicado o un 500.
function attendance_insert_event(PDO $pdo, string $employeeId, string $workDate, string $type, array $body): array {
    [$lat, $lng] = attendance_coords_from_body($body);
    $method = $body['method'] ?? 'gps';
    if (!in_array($method, ['gps', 'qr', 'gps_qr'], true)) {
        $method = 'gps';
    }
    $deviceTime = isset($body['deviceTime']) && $body['deviceTime'] !== ''
        ? date('Y-m-d H:i:s', strtotime((string) $body['deviceTime'])) : null;

    $now = date('Y-m-d H:i:s');
    $stmt = $pdo->prepare(
        'INSERT INTO attendance
           (employee_id, type, work_date, event_time, device_time, latitude, longitude, method)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    );
    try {
        $stmt->execute([$employeeId, $type, $workDate, $now, $deviceTime, $lat, $lng, $method]);
    } catch (PDOException $e) {
        if ($e->getCode() === '23000') {
            attendance_fail(attendance_duplicate_message($type), 409);
        }
        throw $e;
    }

    return ['type' => $type, 'timestamp' => $now];
}

// ---- endpoints: empleado -------------------------------------------

function attendanceEntry(PDO $pdo) {
    $user = require_auth($pdo);
    attendance_require_worker($user);

    $workDate = attendance_workday();
    attendance_block_if_absent($pdo, $user, $workDate);
    $events = attendance_events_for($pdo, $user['id'], $workDate);
    if (attendance_pick($events, 'entrada')) {
        attendance_fail('Ya tienes una entrada registrada para hoy.');
    }

    // La entrada exige estar en el lugar de asistencia. Si un evento con
    // ubicación cubre hoy al departamento del trabajador, la geocerca y la hora
    // de entrada del evento reemplazan a las habituales (solo para la entrada).
    $body = request_body();
    [$lat, $lng] = attendance_coords_from_body($body);
    $override = event_entry_override_for_day($pdo, $user['department_id'] ?? null, $workDate);
    $overrideLoc = ($override && $override['latitude'] !== null && $override['longitude'] !== null)
        ? $override : null;
    attendance_verify_location($pdo, 'entrada', $lat, $lng, $overrideLoc);

    // Congela el horario del día ANTES de crear la entrada.
    attendance_snapshot_schedule($pdo, $user['id'], $workDate, $override['entry_time'] ?? null);
    $ev = attendance_insert_event($pdo, $user['id'], $workDate, 'entrada', $body);

    $events = attendance_events_for($pdo, $user['id'], $workDate);
    json_response([
        'success'    => true,
        'message'    => 'Entrada registrada correctamente',
        'attendance' => $ev,
        'day'        => attendance_day_summary($pdo, $user, $workDate, $events),
    ]);
}

function attendanceMealStart(PDO $pdo) {
    $user = require_auth($pdo);
    attendance_require_worker($user);

    $workDate = attendance_workday();
    attendance_block_if_absent($pdo, $user, $workDate);
    $events = attendance_events_for($pdo, $user['id'], $workDate);
    $state = attendance_state($events);

    if ($state === 'sin_entrada') {
        attendance_fail('No puedes iniciar la hora de comida porque no tienes una entrada registrada.');
    }
    if ($state === 'jornada_terminada') {
        attendance_fail('No puedes iniciar la hora de comida porque ya registraste tu salida.');
    }
    if ($state === 'en_comida') {
        attendance_fail('No puedes iniciar la hora de comida porque ya tienes una comida activa.');
    }
    if (attendance_pick($events, 'inicio_comida')) {
        attendance_fail('Ya registraste tu hora de comida hoy.');
    }
    if (attendance_meal_skipped($events)) {
        attendance_fail('Ya indicaste que hoy no tomarás hora de comida.');
    }

    $ev = attendance_insert_event($pdo, $user['id'], $workDate, 'inicio_comida', request_body());
    $events = attendance_events_for($pdo, $user['id'], $workDate);
    json_response([
        'success'    => true,
        'message'    => 'Hora de comida iniciada',
        'attendance' => $ev,
        'day'        => attendance_day_summary($pdo, $user, $workDate, $events),
    ]);
}

// POST /attendance/meal/skip — el trabajador declara que HOY no tomará hora de
// comida. Deja constancia de esa decisión y nada más: NO registra salida, NO
// cierra la jornada, NO crea ni modifica ninguna marca de salida. El trabajador
// sigue "en jornada" y el siguiente paso disponible pasa a ser la salida, que
// debe registrar él mismo cuando de verdad se vaya. Operación independiente del
// checkout, por diseño. No exige ubicación.
function attendanceMealSkip(PDO $pdo) {
    $user = require_auth($pdo);
    attendance_require_worker($user);

    $workDate = attendance_workday();
    attendance_block_if_absent($pdo, $user, $workDate);
    $events = attendance_events_for($pdo, $user['id'], $workDate);
    $state = attendance_state($events);

    if ($state === 'sin_entrada') {
        attendance_fail('No puedes indicar que no tomarás hora de comida porque no tienes una entrada registrada.');
    }
    if ($state === 'jornada_terminada') {
        attendance_fail('No puedes cambiar tu hora de comida porque ya registraste tu salida.');
    }
    if ($state === 'en_comida') {
        attendance_fail('No puedes indicar que no tomarás hora de comida porque ya tienes una comida activa.');
    }
    if (attendance_pick($events, 'inicio_comida')) {
        attendance_fail('Ya registraste tu hora de comida hoy.');
    }
    if (attendance_meal_skipped($events)) {
        attendance_fail('Ya indicaste que hoy no tomarás hora de comida.');
    }

    $ev = attendance_insert_event($pdo, $user['id'], $workDate, 'sin_comida', request_body());
    $events = attendance_events_for($pdo, $user['id'], $workDate);
    json_response([
        'success'    => true,
        'message'    => 'Registrado: hoy no tomarás hora de comida. Tu jornada sigue abierta; registra tu salida cuando termines.',
        'attendance' => $ev,
        'day'        => attendance_day_summary($pdo, $user, $workDate, $events),
    ]);
}

function attendanceMealEnd(PDO $pdo) {
    $user = require_auth($pdo);
    attendance_require_worker($user);

    $workDate = attendance_workday();
    attendance_block_if_absent($pdo, $user, $workDate);
    $events = attendance_events_for($pdo, $user['id'], $workDate);
    $state = attendance_state($events);

    if (!attendance_pick($events, 'entrada')) {
        attendance_fail('No puedes terminar la hora de comida porque no tienes una entrada registrada.');
    }
    if ($state === 'jornada_terminada') {
        attendance_fail('No puedes terminar la hora de comida porque ya registraste tu salida.');
    }
    if ($state !== 'en_comida') {
        attendance_fail('No puedes terminar la hora de comida porque no hay una comida activa.');
    }

    // Terminar la hora de comida exige estar de vuelta en el lugar de asistencia.
    $body = request_body();
    [$lat, $lng] = attendance_coords_from_body($body);
    attendance_verify_location($pdo, 'fin_comida', $lat, $lng);

    $ev = attendance_insert_event($pdo, $user['id'], $workDate, 'fin_comida', $body);
    $events = attendance_events_for($pdo, $user['id'], $workDate);
    $day = attendance_day_summary($pdo, $user, $workDate, $events);

    $message = $day['mealExceeded']
        ? 'Hora de comida terminada. Excediste el límite por ' . attendance_fmt_hm($day['mealExcessMinutes']) . '.'
        : 'Hora de comida terminada';

    json_response([
        'success'    => true,
        'message'    => $message,
        'attendance' => $ev,
        'day'        => $day,
    ]);
}

function attendanceExit(PDO $pdo) {
    $user = require_auth($pdo);
    attendance_require_worker($user);

    $workDate = attendance_workday();
    attendance_block_if_absent($pdo, $user, $workDate);
    $events = attendance_events_for($pdo, $user['id'], $workDate);
    $state = attendance_state($events);

    if (!attendance_pick($events, 'entrada')) {
        attendance_fail('No puedes registrar tu salida porque no tienes una entrada registrada.');
    }
    if ($state === 'jornada_terminada') {
        attendance_fail('Ya registraste tu salida hoy.');
    }
    if ($state === 'en_comida') {
        attendance_fail('No puedes registrar tu salida mientras estás en hora de comida.');
    }

    $ev = attendance_insert_event($pdo, $user['id'], $workDate, 'salida', request_body());
    $events = attendance_events_for($pdo, $user['id'], $workDate);
    json_response([
        'success'    => true,
        'message'    => 'Salida registrada correctamente',
        'attendance' => $ev,
        'day'        => attendance_day_summary($pdo, $user, $workDate, $events),
    ]);
}

function attendanceToday(PDO $pdo) {
    $user = require_auth($pdo);
    attendance_require_worker($user);

    $workDate = attendance_workday();
    $events = attendance_events_for($pdo, $user['id'], $workDate);
    json_response([
        'success'  => true,
        'day'      => attendance_day_summary($pdo, $user, $workDate, $events),
        // El lugar de asistencia: la app lo usa para pedir GPS y avisar dónde
        // hay que estar. `entrada` y `fin_comida` lo exigen.
        'location' => attendance_location_payload(attendance_location_row($pdo)),
        // Si hay un permiso aprobado para hoy, la app muestra "asistencia no
        // requerida" en vez del botón de registro.
        'absence'  => leave_absence_payload(leave_absence_for_day($pdo, $user['id'], $workDate)),
        // Si un evento con ubicación cubre hoy al departamento del trabajador:
        // la ENTRADA se registra en el lugar y a la hora del evento, no en la
        // geocerca habitual. La app lo muestra en "Mi asistencia".
        'entryOverrideEvent' => event_entry_override_payload(
            event_entry_override_for_day($pdo, $user['department_id'] ?? null, $workDate)
        ),
    ]);
}

// ?from=YYYY-MM-DD&to=YYYY-MM-DD — por defecto, los últimos 30 días.
function attendanceHistory(PDO $pdo) {
    $user = require_auth($pdo);
    attendance_require_worker($user);

    [$from, $to] = attendance_history_range();
    $stmt = $pdo->prepare(
        'SELECT DISTINCT work_date FROM attendance
         WHERE employee_id = ? AND work_date BETWEEN ? AND ?
         ORDER BY work_date DESC'
    );
    $stmt->execute([$user['id'], $from, $to]);

    $days = [];
    foreach ($stmt->fetchAll() as $r) {
        $wd = $r['work_date'];
        $days[] = attendance_day_summary($pdo, $user, $wd, attendance_events_for($pdo, $user['id'], $wd));
    }

    json_response(['success' => true, 'from' => $from, 'to' => $to, 'days' => $days]);
}

function attendance_history_range(): array {
    $to = isset($_GET['to']) && $_GET['to'] !== ''
        ? date('Y-m-d', strtotime($_GET['to'])) : date('Y-m-d');
    $from = isset($_GET['from']) && $_GET['from'] !== ''
        ? date('Y-m-d', strtotime($_GET['from'])) : date('Y-m-d', strtotime('-30 days'));
    if ($from > $to) [$from, $to] = [$to, $from];
    return [$from, $to];
}

// ---- endpoints: panel administrativo (director / manager) ---------

function attendance_admin_guard(PDO $pdo): array {
    $user = require_auth($pdo);
    require_role($user, ['director', 'manager']);
    return $user;
}

// Trabajadores visibles para este admin. El director ve a TODOS los que
// registran asistencia (empleados y managers); el manager, solo a los
// empleados de su departamento. El director NUNCA aparece en la lista.
function attendance_admin_employees(PDO $pdo, array $admin): array {
    if ($admin['role'] === 'director') {
        return $pdo->query(
            "SELECT * FROM users WHERE role IN ('employee','manager') ORDER BY FIELD(role,'manager','employee'), name ASC"
        )->fetchAll();
    }
    $stmt = $pdo->prepare(
        "SELECT * FROM users WHERE role = 'employee' AND department_id = ? ORDER BY name ASC"
    );
    $stmt->execute([$admin['department_id']]);
    return $stmt->fetchAll();
}

// Resuelve un trabajador destino comprobando que el admin puede verlo.
function attendance_admin_target(PDO $pdo, array $admin, string $employeeId): array {
    $stmt = $pdo->prepare('SELECT * FROM users WHERE id = ?');
    $stmt->execute([$employeeId]);
    $emp = $stmt->fetch();
    if (!$emp || !in_array($emp['role'], ['employee', 'manager'], true)) {
        error_response('Trabajador no encontrado', 404);
    }
    if ($admin['role'] === 'manager'
        && ($emp['role'] !== 'employee' || $emp['department_id'] !== $admin['department_id'])) {
        error_response('Este trabajador no pertenece a tu departamento', 403);
    }
    return $emp;
}

function adminAttendanceList(PDO $pdo) {
    $admin = attendance_admin_guard($pdo);
    $workDate = isset($_GET['date']) && $_GET['date'] !== ''
        ? date('Y-m-d', strtotime($_GET['date'])) : attendance_workday();

    $rows = [];
    foreach (attendance_admin_employees($pdo, $admin) as $emp) {
        $events = attendance_events_for($pdo, $emp['id'], $workDate);
        $rows[] = array_merge([
            'employeeId'  => $emp['id'],
            'name'        => $emp['name'],
            'email'       => $emp['email'],
            'position'    => $emp['position'],
            'departmentId'=> $emp['department_id'],
            'hasSchedule' => attendance_schedule_for($pdo, $emp['id']) !== null,
            // Permiso aprobado para ese día: el panel lo muestra como
            // "Vacaciones / Incapacidad / Permiso", nunca como falta.
            'absence'     => leave_absence_payload(leave_absence_for_day($pdo, $emp['id'], $workDate)),
        ], attendance_day_summary($pdo, $emp, $workDate, $events));
    }

    json_response(['success' => true, 'date' => $workDate, 'employees' => $rows]);
}

function adminAttendanceEmployee(PDO $pdo, string $employeeId) {
    $admin = attendance_admin_guard($pdo);
    $emp = attendance_admin_target($pdo, $admin, $employeeId);

    [$from, $to] = attendance_history_range();
    $stmt = $pdo->prepare(
        'SELECT DISTINCT work_date FROM attendance
         WHERE employee_id = ? AND work_date BETWEEN ? AND ?
         ORDER BY work_date DESC'
    );
    $stmt->execute([$emp['id'], $from, $to]);

    $days = [];
    foreach ($stmt->fetchAll() as $r) {
        $wd = $r['work_date'];
        $days[] = attendance_day_summary($pdo, $emp, $wd, attendance_events_for($pdo, $emp['id'], $wd));
    }

    $sched = attendance_schedule_for($pdo, $emp['id']);
    json_response([
        'success'  => true,
        'employee' => [
            'employeeId' => $emp['id'],
            'name'       => $emp['name'],
            'email'      => $emp['email'],
            'position'   => $emp['position'],
        ],
        'schedule' => $sched ? attendance_schedule_payload($sched) : null,
        'from'     => $from,
        'to'       => $to,
        'days'     => $days,
        // Resumen del rango: distingue asistencia / vacaciones / incapacidad /
        // permiso / falta injustificada. Un permiso aprobado NUNCA es falta.
        'summary'  => attendance_range_summary($pdo, $emp['id'], $from, $to),
    ]);
}

// Recuento por tipo de día en [from, to]. Días laborales = lunes a viernes
// (mismo calendario que leave_business_days).
function attendance_range_summary(PDO $pdo, string $employeeId, string $from, string $to): array {
    $start = new DateTimeImmutable($from);
    $end = new DateTimeImmutable($to);
    $laborales = $asistencias = $vacaciones = $incapacidades = $permisos = $faltas = 0;

    for ($d = $start; $d <= $end; $d = $d->modify('+1 day')) {
        if ((int) $d->format('N') > 5) continue; // fin de semana
        $wd = $d->format('Y-m-d');
        $laborales++;

        $absence = leave_absence_for_day($pdo, $employeeId, $wd);
        if ($absence) {
            match ($absence['type']) {
                'vacaciones'  => $vacaciones++,
                'incapacidad' => $incapacidades++,
                default       => $permisos++,
            };
            continue;
        }

        $stmt = $pdo->prepare(
            "SELECT 1 FROM attendance WHERE employee_id = ? AND work_date = ? AND type = 'entrada' LIMIT 1"
        );
        $stmt->execute([$employeeId, $wd]);
        if ($stmt->fetch()) {
            $asistencias++;
        } elseif ($wd < date('Y-m-d')) {
            // Solo cuenta como falta un día laboral ya pasado sin asistencia
            // ni permiso.
            $faltas++;
        }
    }

    return [
        'diasLaborales'        => $laborales,
        'asistencias'          => $asistencias,
        'vacaciones'           => $vacaciones,
        'incapacidades'        => $incapacidades,
        'permisos'             => $permisos,
        'faltasInjustificadas' => $faltas,
    ];
}

function adminSchedulesList(PDO $pdo) {
    $admin = attendance_admin_guard($pdo);

    $out = [];
    foreach (attendance_admin_employees($pdo, $admin) as $emp) {
        $s = attendance_schedule_for($pdo, $emp['id']);
        $out[] = [
            'employeeId' => $emp['id'],
            'name'       => $emp['name'],
            'email'      => $emp['email'],
            'position'   => $emp['position'],
            'schedule'   => $s ? attendance_schedule_payload($s) : null,
        ];
    }

    json_response([
        'success'    => true,
        // El manager solo consulta; crear/modificar horarios es del director.
        'canEdit'    => $admin['role'] === 'director',
        'employees'  => $out,
    ]);
}

function adminScheduleGet(PDO $pdo, string $employeeId) {
    $admin = attendance_admin_guard($pdo);
    $emp = attendance_admin_target($pdo, $admin, $employeeId);
    $s = attendance_schedule_for($pdo, $emp['id']);

    json_response([
        'success'    => true,
        'canEdit'    => $admin['role'] === 'director',
        'employeeId' => $emp['id'],
        'name'       => $emp['name'],
        'schedule'   => $s ? attendance_schedule_payload($s) : null,
    ]);
}

// Crea o modifica el horario asignado a un empleado. Solo el director.
// No toca los snapshots ya congelados: el histórico permanece inmutable.
function adminScheduleSave(PDO $pdo, string $employeeId) {
    $admin = attendance_admin_guard($pdo);
    require_role($admin, ['director']);
    $emp = attendance_admin_target($pdo, $admin, $employeeId);

    $body = request_body();
    $entry = attendance_valid_time((string) ($body['entryTime'] ?? ''));
    $exit  = attendance_valid_time((string) ($body['exitTime'] ?? ''));
    $meal  = attendance_valid_time((string) ($body['mealTime'] ?? ''));
    $max   = (int) ($body['mealMaxMinutes'] ?? 0);

    if (!$entry || !$exit || !$meal) {
        error_response('Horario inválido: usa el formato HH:MM (por ejemplo 09:00).', 400);
    }
    if ($max < 1 || $max > 240) {
        error_response('El límite de comida debe estar entre 1 y 240 minutos.', 400);
    }

    $stmt = $pdo->prepare(
        'INSERT INTO employee_schedules
           (employee_id, entry_time, exit_time, meal_time, meal_max_minutes, updated_by)
         VALUES (?, ?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
           entry_time = VALUES(entry_time),
           exit_time = VALUES(exit_time),
           meal_time = VALUES(meal_time),
           meal_max_minutes = VALUES(meal_max_minutes),
           updated_by = VALUES(updated_by)'
    );
    $stmt->execute([$emp['id'], $entry, $exit, $meal, $max, $admin['id']]);

    json_response([
        'success'  => true,
        'message'  => 'Horario guardado correctamente',
        'schedule' => attendance_schedule_payload(attendance_schedule_for($pdo, $emp['id'])),
    ]);
}

// ---- endpoints: lugar de asistencia (geocerca) -------------------

// GET /admin/attendance-location — director y manager pueden consultarlo.
function adminLocationGet(PDO $pdo) {
    $admin = attendance_admin_guard($pdo);
    json_response([
        'success'  => true,
        'canEdit'  => $admin['role'] === 'director',
        'location' => attendance_location_payload(attendance_location_row($pdo)),
    ]);
}

// POST /admin/attendance-location — solo el director define/mueve el lugar.
// body: latitude, longitude, radiusM (opcional, por defecto 10), label (opcional).
function adminLocationSave(PDO $pdo) {
    $admin = attendance_admin_guard($pdo);
    require_role($admin, ['director']);

    $body = request_body();
    $lat = isset($body['latitude']) && $body['latitude'] !== '' ? (float) $body['latitude'] : null;
    $lng = isset($body['longitude']) && $body['longitude'] !== '' ? (float) $body['longitude'] : null;
    $radius = (int) ($body['radiusM'] ?? 10);
    $label = trim((string) ($body['label'] ?? '')) ?: null;

    if ($lat === null || $lng === null || $lat < -90 || $lat > 90 || $lng < -180 || $lng > 180) {
        error_response('Coordenadas inválidas.', 400);
    }
    if ($radius < 5 || $radius > 1000) {
        error_response('El radio debe estar entre 5 y 1000 metros.', 400);
    }

    $stmt = $pdo->prepare(
        'INSERT INTO attendance_location (id, latitude, longitude, radius_m, label, updated_by)
         VALUES (1, ?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
           latitude = VALUES(latitude), longitude = VALUES(longitude),
           radius_m = VALUES(radius_m), label = VALUES(label), updated_by = VALUES(updated_by)'
    );
    $stmt->execute([$lat, $lng, $radius, $label, $admin['id']]);

    json_response([
        'success'  => true,
        'message'  => 'Lugar de asistencia guardado correctamente',
        'location' => attendance_location_payload(attendance_location_row($pdo)),
    ]);
}

// ============================================================================
// Fase 2 — Reportes, resumen y solicitudes de corrección (Radio Doliv).
//   GET  /attendance/summary?month=YYYY-MM                      (trabajador)
//   POST /attendance/corrections                                (trabajador)
//   GET  /attendance/corrections/my                             (trabajador)
//   GET  /admin/attendance/summary?month=&departmentId=         (director/manager)
//   GET  /admin/attendance/report?month=&departmentId=&format=csv|pdf
//   GET  /admin/attendance/corrections?status=                  (director/manager)
//   POST /admin/attendance/corrections/{id}/resolve             (director/manager)
// ============================================================================

const ATT_CORRECTION_KINDS = ['entrada', 'inicio_comida', 'fin_comida', 'salida'];

function attendance_correction_kind_label(string $k): string {
    return [
        'entrada'      => 'Entrada',
        'inicio_comida'=> 'Inicio de comida',
        'fin_comida'   => 'Fin de comida',
        'salida'       => 'Salida',
    ][$k] ?? $k;
}

// month = 'YYYY-MM'; por defecto el mes en curso. Devuelve [from, to, month].
function attendance_month_bounds(?string $month): array {
    $m = (is_string($month) && preg_match('/^\d{4}-\d{2}$/', $month)) ? $month : date('Y-m');
    $from = $m . '-01';
    $to = date('Y-m-t', strtotime($from));
    return [$from, $to, $m];
}

// Estadisticas de un trabajador en [from, to]: dias laborales, dias
// trabajados, minutos trabajados, tardanzas, faltas injustificadas y dias de
// permiso por tipo. Reutiliza attendance_day_summary() (mismo calculo de
// llegada tarde y tiempo trabajado que ve el empleado).
function attendance_period_stats(PDO $pdo, array $employee, string $from, string $to): array {
    $start = new DateTimeImmutable($from);
    $end = new DateTimeImmutable($to);
    $today = date('Y-m-d');

    $business = $worked = $lateCount = $lateMin = $absent = $totalWorked = 0;
    $vac = $inc = $perm = 0;

    for ($d = $start; $d <= $end; $d = $d->modify('+1 day')) {
        if ((int) $d->format('N') > 5) continue; // fin de semana
        $wd = $d->format('Y-m-d');
        $business++;

        $absence = leave_absence_for_day($pdo, $employee['id'], $wd);
        if ($absence) {
            match ($absence['type']) {
                'vacaciones'  => $vac++,
                'incapacidad' => $inc++,
                default       => $perm++,
            };
            continue;
        }

        $sum = attendance_day_summary(
            $pdo, $employee, $wd, attendance_events_for($pdo, $employee['id'], $wd)
        );
        if ($sum['entrada'] !== null) {
            $worked++;
            if ($sum['workedMinutes'] !== null) $totalWorked += (int) $sum['workedMinutes'];
            if (!empty($sum['isLate'])) {
                $lateCount++;
                $lateMin += (int) $sum['lateMinutes'];
            }
        } elseif ($wd < $today) {
            $absent++;
        }
    }

    $onTime = $worked > 0 ? (int) round(($worked - $lateCount) / $worked * 100) : null;

    return [
        'from'           => $from,
        'to'             => $to,
        'businessDays'   => $business,
        'workedDays'     => $worked,
        'totalMinutes'   => $totalWorked,
        'totalLabel'     => attendance_fmt_hm($totalWorked),
        'totalHours'     => round($totalWorked / 60, 2),
        'lateCount'      => $lateCount,
        'lateMinutes'    => $lateMin,
        'absentDays'     => $absent,
        'vacationDays'   => $vac,
        'incapacityDays' => $inc,
        'permissionDays' => $perm,
        'onTimeRate'     => $onTime,
    ];
}

// GET /attendance/summary — resumen del mes del trabajador autenticado.
function attendanceSummary(PDO $pdo) {
    $user = require_auth($pdo);
    attendance_require_worker($user);
    [$from, $to, $m] = attendance_month_bounds($_GET['month'] ?? null);
    json_response([
        'success' => true,
        'month'   => $m,
        'summary' => attendance_period_stats($pdo, $user, $from, $to),
    ]);
}

// GET /admin/attendance/summary — por empleado + totales (dashboard del
// manager y vista previa del reporte).
function adminAttendanceSummary(PDO $pdo) {
    $admin = attendance_admin_guard($pdo);
    [$from, $to, $m] = attendance_month_bounds($_GET['month'] ?? null);
    $deptFilter = trim((string) ($_GET['departmentId'] ?? ''));

    $rows = [];
    $totKeys = ['businessDays', 'workedDays', 'totalMinutes', 'lateCount', 'lateMinutes',
        'absentDays', 'vacationDays', 'incapacityDays', 'permissionDays'];
    $tot = array_fill_keys($totKeys, 0);

    foreach (attendance_admin_employees($pdo, $admin) as $emp) {
        if ($deptFilter !== '' && $emp['department_id'] !== $deptFilter) continue;
        $s = attendance_period_stats($pdo, $emp, $from, $to);
        $rows[] = array_merge([
            'employeeId'   => $emp['id'],
            'name'         => $emp['name'],
            'email'        => $emp['email'],
            'position'     => $emp['position'],
            'departmentId' => $emp['department_id'],
        ], $s);
        foreach ($totKeys as $k) $tot[$k] += (int) ($s[$k] ?? 0);
    }
    $tot['totalLabel'] = attendance_fmt_hm($tot['totalMinutes']);

    json_response([
        'success'   => true,
        'month'     => $m,
        'from'      => $from,
        'to'        => $to,
        'employees' => $rows,
        'totals'    => $tot,
    ]);
}

// GET /admin/attendance/report?format=csv|pdf — descarga del reporte mensual.
function attendanceReport(PDO $pdo) {
    $admin = attendance_admin_guard($pdo);
    [$from, $to, $m] = attendance_month_bounds($_GET['month'] ?? null);
    $deptFilter = trim((string) ($_GET['departmentId'] ?? ''));
    $format = strtolower(trim((string) ($_GET['format'] ?? 'csv')));
    if (!in_array($format, ['csv', 'pdf'], true)) $format = 'csv';

    $rows = [];
    foreach (attendance_admin_employees($pdo, $admin) as $emp) {
        if ($deptFilter !== '' && $emp['department_id'] !== $deptFilter) continue;
        $rows[] = array_merge(
            ['name' => $emp['name'], 'email' => $emp['email'], 'position' => $emp['position'] ?: ''],
            attendance_period_stats($pdo, $emp, $from, $to)
        );
    }

    if ($format === 'pdf') {
        attendance_report_pdf($m, $rows);
    } else {
        attendance_report_csv($m, $rows);
    }
    exit;
}

function attendance_report_csv(string $month, array $rows): void {
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="asistencia_' . $month . '.csv"');
    header('Cache-Control: private, no-store');
    echo "\xEF\xBB\xBF"; // BOM: que Excel abra los acentos bien
    $out = fopen('php://output', 'w');
    fputcsv($out, [
        'Empleado', 'Correo', 'Puesto', 'Dias laborales', 'Dias trabajados',
        'Horas trabajadas', 'Horas (decimal)', 'Tardanzas', 'Min. tardanza',
        'Faltas injustificadas', 'Vacaciones', 'Incapacidad', 'Permiso', 'Puntualidad %',
    ]);
    foreach ($rows as $r) {
        fputcsv($out, [
            $r['name'], $r['email'], $r['position'],
            $r['businessDays'], $r['workedDays'], $r['totalLabel'], $r['totalHours'],
            $r['lateCount'], $r['lateMinutes'], $r['absentDays'],
            $r['vacationDays'], $r['incapacityDays'], $r['permissionDays'],
            $r['onTimeRate'] ?? '',
        ]);
    }
    fclose($out);
}

// FPDF con fuentes core usa cp1252; convertir el texto en espanol.
function attendance_pdf_txt(string $s): string {
    $c = @iconv('UTF-8', 'windows-1252//TRANSLIT//IGNORE', $s);
    return $c !== false ? $c : $s;
}

function attendance_report_pdf(string $month, array $rows): void {
    require_once __DIR__ . '/lib/fpdf/fpdf.php';
    $pdf = new FPDF('L', 'mm', 'A4');
    $pdf->SetTitle('Reporte de asistencia ' . $month);
    $pdf->SetAutoPageBreak(true, 15);
    $pdf->AddPage();

    $pdf->SetFont('Helvetica', 'B', 14);
    $pdf->Cell(0, 8, attendance_pdf_txt('Reporte de asistencia - ' . $month), 0, 1);
    $pdf->SetFont('Helvetica', '', 9);
    $pdf->Cell(0, 6, attendance_pdf_txt('Generado el ' . date('Y-m-d H:i')), 0, 1);
    $pdf->Ln(2);

    $headers = ['Empleado', 'Puesto', 'Dias lab.', 'Dias trab.', 'Horas', 'Tard.',
        'Min tard.', 'Faltas', 'Vac.', 'Incap.', 'Perm.', 'Punt.%'];
    $w = [50, 42, 17, 17, 18, 13, 17, 15, 13, 15, 15, 15];

    $pdf->SetFont('Helvetica', 'B', 8);
    $pdf->SetFillColor(230, 230, 230);
    foreach ($headers as $i => $h) {
        $pdf->Cell($w[$i], 7, attendance_pdf_txt($h), 1, 0, 'C', true);
    }
    $pdf->Ln();

    $pdf->SetFont('Helvetica', '', 8);
    if (!$rows) {
        $pdf->Cell(array_sum($w), 7, attendance_pdf_txt('Sin trabajadores en el alcance.'), 1, 1, 'C');
    }
    foreach ($rows as $r) {
        $cells = [
            $r['name'], $r['position'], $r['businessDays'], $r['workedDays'], $r['totalLabel'],
            $r['lateCount'], $r['lateMinutes'], $r['absentDays'], $r['vacationDays'],
            $r['incapacityDays'], $r['permissionDays'],
            $r['onTimeRate'] !== null ? $r['onTimeRate'] : '-',
        ];
        foreach ($cells as $i => $c) {
            $pdf->Cell($w[$i], 6, attendance_pdf_txt((string) $c), 1, 0, $i < 2 ? 'L' : 'C');
        }
        $pdf->Ln();
    }

    $body = $pdf->Output('S');
    header('Content-Type: application/pdf');
    header('Content-Disposition: attachment; filename="asistencia_' . $month . '.pdf"');
    header('Content-Length: ' . strlen($body));
    header('Cache-Control: private, no-store');
    echo $body;
}

// ---- solicitudes de correccion --------------------------------------

function attendance_correction_payload(array $r): array {
    return [
        'id'            => (int) $r['id'],
        'employeeId'    => $r['employee_id'],
        'employeeName'  => $r['employee_name'] ?? null,
        'workDate'      => $r['work_date'],
        'kind'          => $r['kind'],
        'kindLabel'     => attendance_correction_kind_label($r['kind']),
        'requestedTime' => substr($r['requested_time'], 0, 5),
        'reason'        => $r['reason'],
        'status'        => $r['status'],
        'reviewNote'    => $r['review_note'],
        'createdAt'     => $r['created_at'],
        'resolvedAt'    => $r['resolved_at'],
    ];
}

// Notifica al manager del departamento del trabajador y al director general.
function attendance_notify_dept_managers(PDO $pdo, array $employee, string $type, string $message): void {
    $emails = [];
    if (!empty($employee['department_id'])) {
        $stmt = $pdo->prepare('SELECT manager_email FROM departments WHERE id = ?');
        $stmt->execute([$employee['department_id']]);
        $me = $stmt->fetchColumn();
        if ($me) $emails[strtolower($me)] = $me;
    }
    foreach ($pdo->query("SELECT email FROM users WHERE role = 'director'") as $row) {
        $emails[strtolower($row['email'])] = $row['email'];
    }
    unset($emails[strtolower($employee['email'])]);
    foreach ($emails as $e) {
        notify_user($pdo, $e, null, $type, $message);
    }
}

// POST /attendance/corrections
function attendanceCorrectionCreate(PDO $pdo) {
    $user = require_auth($pdo);
    attendance_require_worker($user);

    $body = request_body();
    $rawDate = trim((string) ($body['workDate'] ?? ''));
    $workDate = $rawDate !== '' && strtotime($rawDate) ? date('Y-m-d', strtotime($rawDate)) : null;
    if ($workDate === null) attendance_fail('Indica la fecha del fichaje.', 400);
    if ($workDate > date('Y-m-d')) attendance_fail('No puedes corregir un dia que aun no ocurre.', 400);

    $kind = trim((string) ($body['kind'] ?? ''));
    if (!in_array($kind, ATT_CORRECTION_KINDS, true)) attendance_fail('Tipo de fichaje invalido.', 400);

    $time = attendance_valid_time((string) ($body['requestedTime'] ?? ''));
    if ($time === null) attendance_fail('Hora invalida (usa el formato HH:MM).', 400);

    $reason = trim((string) ($body['reason'] ?? ''));
    if ($reason === '') attendance_fail('Explica brevemente que paso.', 400);
    if (mb_strlen($reason) > 1000) $reason = mb_substr($reason, 0, 1000);

    // Comprobación previa para el caso normal (mensaje claro sin tocar la BD).
    $stmt = $pdo->prepare(
        "SELECT id FROM attendance_correction_requests
          WHERE employee_id = ? AND work_date = ? AND kind = ? AND status = 'pendiente'"
    );
    $stmt->execute([$user['id'], $workDate, $kind]);
    if ($stmt->fetch()) {
        attendance_fail('Ya tienes una solicitud pendiente para ese mismo fichaje.', 409);
    }

    // Backstop de concurrencia: el índice único uq_acr_pendiente
    // (employee_id, work_date, kind, pending_slot) impide dos solicitudes
    // PENDIENTES iguales creadas a la vez (doble toque / reintento). Tras
    // resolverse (aprobada/rechazada) pending_slot pasa a NULL y se puede
    // volver a solicitar.
    try {
        $stmt = $pdo->prepare(
            'INSERT INTO attendance_correction_requests
               (employee_id, work_date, kind, requested_time, reason)
             VALUES (?, ?, ?, ?, ?)'
        );
        $stmt->execute([$user['id'], $workDate, $kind, $time, $reason]);
    } catch (PDOException $e) {
        if ($e->getCode() === '23000') {
            attendance_fail('Ya tienes una solicitud pendiente para ese mismo fichaje.', 409);
        }
        throw $e;
    }
    $id = (int) $pdo->lastInsertId();

    attendance_notify_dept_managers($pdo, $user, 'attendance_correction',
        $user['name'] . ' solicito corregir su ' .
        mb_strtolower(attendance_correction_kind_label($kind)) . ' del ' . $workDate . '.');

    $stmt = $pdo->prepare('SELECT * FROM attendance_correction_requests WHERE id = ?');
    $stmt->execute([$id]);
    json_response([
        'success' => true,
        'message' => 'Solicitud enviada. Tu manager la revisara.',
        'request' => attendance_correction_payload($stmt->fetch()),
    ]);
}

// GET /attendance/corrections/my
function attendanceCorrectionsMine(PDO $pdo) {
    $user = require_auth($pdo);
    attendance_require_worker($user);
    $stmt = $pdo->prepare(
        'SELECT * FROM attendance_correction_requests WHERE employee_id = ? ORDER BY created_at DESC'
    );
    $stmt->execute([$user['id']]);
    json_response([
        'success'  => true,
        'requests' => array_map('attendance_correction_payload', $stmt->fetchAll()),
    ]);
}

// GET /admin/attendance/corrections?status=
function adminAttendanceCorrections(PDO $pdo) {
    $admin = attendance_admin_guard($pdo);
    $status = trim((string) ($_GET['status'] ?? ''));
    $hasStatus = in_array($status, ['pendiente', 'aprobado', 'rechazado'], true);

    $where = [];
    $params = [];
    if ($hasStatus) {
        $where[] = 'r.status = ?';
        $params[] = $status;
    }
    if ($admin['role'] === 'manager') {
        $where[] = "u.role = 'employee'";
        $where[] = 'u.department_id = ?';
        $params[] = $admin['department_id'];
    } else {
        $where[] = "u.role IN ('employee', 'manager')";
    }

    $sql = 'SELECT r.*, u.name AS employee_name
              FROM attendance_correction_requests r
              JOIN users u ON u.id = r.employee_id';
    if ($where) $sql .= ' WHERE ' . implode(' AND ', $where);
    $sql .= " ORDER BY (r.status = 'pendiente') DESC, r.created_at DESC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    json_response([
        'success'  => true,
        'requests' => array_map('attendance_correction_payload', $stmt->fetchAll()),
    ]);
}

// POST /admin/attendance/corrections/{id}/resolve  body: {decision, note}
function adminAttendanceCorrectionResolve(PDO $pdo, string $id) {
    $admin = attendance_admin_guard($pdo);

    $stmt = $pdo->prepare('SELECT * FROM attendance_correction_requests WHERE id = ?');
    $stmt->execute([(int) $id]);
    $req = $stmt->fetch();
    if (!$req) error_response('Solicitud no encontrada', 404);

    // Comprueba que el admin puede gestionar a ese trabajador.
    $emp = attendance_admin_target($pdo, $admin, $req['employee_id']);
    if ($req['status'] !== 'pendiente') {
        attendance_fail('Esta solicitud ya fue resuelta.', 409);
    }

    $body = request_body();
    $decision = trim((string) ($body['decision'] ?? ''));
    $note = trim((string) ($body['note'] ?? ''));
    if (!in_array($decision, ['approve', 'reject'], true)) {
        attendance_fail('Decision invalida.', 400);
    }

    if ($decision === 'reject') {
        if ($note === '') attendance_fail('Indica el motivo del rechazo.', 400);
        $pdo->prepare(
            "UPDATE attendance_correction_requests
                SET status = 'rechazado', review_note = ?, reviewed_by = ?, resolved_at = NOW()
              WHERE id = ?"
        )->execute([$note, $admin['id'], $req['id']]);
        notify_user($pdo, $emp['email'], null, 'attendance_correction',
            'Tu solicitud de correccion del ' . $req['work_date'] . ' fue rechazada: ' . $note);
        $message = 'Solicitud rechazada.';
    } else {
        // Aplica: ajusta el evento existente de ese tipo/dia, o inserta el que
        // faltaba. Nunca se borra un evento.
        $newDt = $req['work_date'] . ' ' . $req['requested_time'];
        $stmt = $pdo->prepare(
            'SELECT id, event_time FROM attendance
              WHERE employee_id = ? AND work_date = ? AND type = ?
              ORDER BY event_time ASC LIMIT 1'
        );
        $stmt->execute([$req['employee_id'], $req['work_date'], $req['kind']]);
        $existing = $stmt->fetch();

        if ($existing) {
            $pdo->prepare("UPDATE attendance SET event_time = ?, method = 'manual' WHERE id = ?")
                ->execute([$newDt, $existing['id']]);
            $attId = (int) $existing['id'];
            $pdo->prepare(
                'INSERT INTO attendance_corrections
                   (attendance_id, corrected_by, old_event_time, new_event_time, reason)
                 VALUES (?, ?, ?, ?, ?)'
            )->execute([
                $attId, $admin['id'], $existing['event_time'], $newDt,
                mb_substr('Solicitud #' . $req['id'] . ': ' . $req['reason'], 0, 255),
            ]);
        } else {
            try {
                $pdo->prepare(
                    "INSERT INTO attendance (employee_id, type, work_date, event_time, method)
                     VALUES (?, ?, ?, ?, 'manual')"
                )->execute([$req['employee_id'], $req['kind'], $req['work_date'], $newDt]);
                $attId = (int) $pdo->lastInsertId();
            } catch (PDOException $e) {
                if ($e->getCode() !== '23000') throw $e;
                // uq_attendance_evento: otra resolución simultánea ya creó ese
                // evento. Se ajusta el existente en vez de duplicarlo — el
                // resultado converge al mismo estado.
                $stmt = $pdo->prepare(
                    'SELECT id FROM attendance
                      WHERE employee_id = ? AND work_date = ? AND type = ?
                      ORDER BY event_time ASC LIMIT 1'
                );
                $stmt->execute([$req['employee_id'], $req['work_date'], $req['kind']]);
                $attId = (int) $stmt->fetchColumn();
                $pdo->prepare("UPDATE attendance SET event_time = ?, method = 'manual' WHERE id = ?")
                    ->execute([$newDt, $attId]);
            }
        }

        $pdo->prepare(
            "UPDATE attendance_correction_requests
                SET status = 'aprobado', review_note = ?, reviewed_by = ?, resolved_at = NOW(), attendance_id = ?
              WHERE id = ?"
        )->execute([$note !== '' ? $note : null, $admin['id'], $attId, $req['id']]);

        notify_user($pdo, $emp['email'], null, 'attendance_correction',
            'Se corrigio tu ' . mb_strtolower(attendance_correction_kind_label($req['kind'])) .
            ' del ' . $req['work_date'] . ' a las ' . substr($req['requested_time'], 0, 5) . '.');
        $message = 'Correccion aplicada.';
    }

    $stmt = $pdo->prepare(
        'SELECT r.*, u.name AS employee_name
           FROM attendance_correction_requests r JOIN users u ON u.id = r.employee_id
          WHERE r.id = ?'
    );
    $stmt->execute([$req['id']]);
    json_response([
        'success' => true,
        'message' => $message,
        'request' => attendance_correction_payload($stmt->fetch()),
    ]);
}
