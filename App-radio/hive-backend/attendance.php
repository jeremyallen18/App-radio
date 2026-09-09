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
// Este archivo (demasiado grande) se dividió en tres, cargados en orden por
// index.php y compartiendo los helpers `attendance_*` de aquí:
//   attendance.php          — helpers + endpoints del propio trabajador (abajo)
//   attendance_admin.php    — panel del director / manager (monitoreo, horarios, lugar)
//   attendance_reports.php  — Fase 2: resumen mensual, reportes CSV/PDF, correcciones
//
// Endpoints de este archivo (registrados en index.php):
//   POST /attendance/entry | /attendance/meal/start | /attendance/meal/skip | /attendance/meal/end | /attendance/exit
//        (meal/skip: "hoy no tomaré hora de comida" — solo constancia, NO cierra la jornada)
//   GET  /attendance/today | /attendance/status | /attendance/history

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

// En Radio Doliv NO se trabaja los domingos: no puede registrarse ninguna
// marca de asistencia (entrada, comida, salida) ese día. Se corta con
// code=NON_WORKING_DAY para que la app lo trate como estado, no como error.
function attendance_block_if_non_working(string $workDate): void {
    if (!is_working_day($workDate)) {
        json_response([
            'success' => false,
            'code'    => 'NON_WORKING_DAY',
            'message' => 'El domingo no es día laboral: no se registra asistencia.',
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
        'lateToleranceMinutes' => (int) ($s['late_tolerance_minutes'] ?? 15),
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
    $lateTol = $sched['late_tolerance_minutes'] ?? 15;

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
}

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
        'toleranceMinutes'   => $tolMinutes,
        'mealLimitMinutes'   => $mealLimit,
        'mealExceeded'       => $mealExceeded,
        'mealExcessMinutes'  => $mealExcessMinutes,
        'schedule'           => $schedule ? [
            'entryTime'      => substr($schedule['entry_time'], 0, 5),
            'exitTime'       => substr($schedule['exit_time'], 0, 5),
            'mealTime'       => substr($schedule['meal_time'], 0, 5),
            'mealMaxMinutes' => (int) $schedule['meal_max_minutes'],
            'lateToleranceMinutes' => (int) ($schedule['late_tolerance_minutes'] ?? 15),
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
    attendance_block_if_non_working($workDate);
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
    attendance_block_if_non_working($workDate);
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

    // Ventana de comida: no se puede iniciar antes de la hora asignada.
    $mealEff = attendance_effective_time($pdo, $user['id'], $workDate, 'meal_time');
    if ($mealEff !== null && time() < strtotime($workDate . ' ' . $mealEff)) {
        attendance_window_fail('MEAL_TOO_EARLY',
            'Tu hora de comida empieza a las ' . substr($mealEff, 0, 5) . '. Aún no puedes iniciarla.');
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
    attendance_block_if_non_working($workDate);
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
    attendance_block_if_non_working($workDate);
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
    attendance_block_if_non_working($workDate);
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

    // Ventana de salida: solo a partir de la hora asignada ("justo a la hora").
    $exitEff = attendance_effective_time($pdo, $user['id'], $workDate, 'exit_time');
    if ($exitEff !== null && time() < strtotime($workDate . ' ' . $exitEff)) {
        attendance_window_fail('EXIT_TOO_EARLY',
            'Tu salida es a las ' . substr($exitEff, 0, 5) . '. Aún no puedes registrarla.');
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

    // Respaldo: al abrir "Mi asistencia" se vacían los recordatorios vencidos
    // de este trabajador aunque el cron no esté configurado.
    attendance_dispatch_due_reminders($pdo, $user['id']);

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

