<?php
// Asistencia — panel administrativo (director / manager). Extraído de
// attendance.php (demasiado grande); comparte con él, vía el require de
// index.php, todos los helpers `attendance_*` (estado, resumen del día,
// snapshot de horario, geocerca). Aquí solo van los endpoints que consulta
// o edita un admin, nunca el propio trabajador.
//
// Endpoints (registrados en index.php):
//   GET  /admin/attendance | /admin/attendance/{employeeId}
//   GET  /admin/schedules | /admin/schedules/{employeeId}
//   POST /admin/schedules/{employeeId} (solo director) | /admin/schedules/bulk
//   GET  /admin/attendance-location (director/manager) | POST (solo director)

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
    // Las cuentas sin verificar el correo no fichan ni aparecen en la empresa.
    if ($admin['role'] === 'director') {
        return $pdo->query(
            "SELECT * FROM users WHERE role IN ('employee','manager') AND " . SQL_USER_VERIFIED
            . " ORDER BY FIELD(role,'manager','employee'), name ASC"
        )->fetchAll();
    }
    $stmt = $pdo->prepare(
        "SELECT * FROM users WHERE role = 'employee' AND department_id = ? AND " . SQL_USER_VERIFIED
        . " ORDER BY name ASC"
    );
    $stmt->execute([$admin['department_id']]);
    return $stmt->fetchAll();
}

// Resuelve un trabajador destino comprobando que el admin puede verlo.
function attendance_admin_target(PDO $pdo, array $admin, string $employeeId): array {
    $stmt = $pdo->prepare('SELECT * FROM users WHERE id = ?');
    $stmt->execute([$employeeId]);
    $emp = $stmt->fetch();
    if (!$emp || !in_array($emp['role'], ['employee', 'manager'], true)
        || !user_email_verified($emp)) {
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

// Recuento por tipo de día en [from, to]. Días laborales = lunes a sábado
// (mismo calendario que leave_business_days / is_working_day; solo el
// domingo no cuenta).
function attendance_range_summary(PDO $pdo, string $employeeId, string $from, string $to): array {
    $start = new DateTimeImmutable($from);
    $end = new DateTimeImmutable($to);
    $today = date('Y-m-d');
    $firstRecord = attendance_first_record_date($pdo, $employeeId);
    $laborales = $asistencias = $vacaciones = $incapacidades = $permisos = $faltas = 0;

    // Precarga en 3 consultas lo que el bucle miraba día a día (N+1): días con
    // 'entrada', permisos aprobados que solapan el rango (con su tipo, orden por
    // inicio como leave_absence_for_day) y justificaciones aprobadas.
    $attStmt = $pdo->prepare(
        "SELECT DISTINCT work_date FROM attendance
          WHERE employee_id = ? AND type = 'entrada' AND work_date BETWEEN ? AND ?"
    );
    $attStmt->execute([$employeeId, $from, $to]);
    $attended = array_fill_keys(array_column($attStmt->fetchAll(), 'work_date'), true);

    $leaveStmt = $pdo->prepare(
        "SELECT type, approved_start_date AS s, approved_end_date AS e FROM leave_requests
          WHERE employee_id = ? AND status = 'aprobado'
            AND approved_start_date <= ? AND approved_end_date >= ?
          ORDER BY approved_start_date ASC"
    );
    $leaveStmt->execute([$employeeId, $to, $from]);
    $leaves = $leaveStmt->fetchAll();

    $justRanges = absence_approved_ranges($pdo, $employeeId);

    for ($d = $start; $d <= $end; $d = $d->modify('+1 day')) {
        if ((int) $d->format('N') === 7) continue; // domingo (único día no laboral)
        $wd = $d->format('Y-m-d');
        $laborales++;

        $absType = null;
        foreach ($leaves as $lv) {
            if ($lv['s'] <= $wd && $wd <= $lv['e']) { $absType = $lv['type']; break; }
        }
        if ($absType !== null) {
            match ($absType) {
                'vacaciones'  => $vacaciones++,
                'incapacidad' => $incapacidades++,
                default       => $permisos++,
            };
            continue;
        }

        if (isset($attended[$wd])) {
            $asistencias++;
        } elseif ($wd < $today && $firstRecord !== null && $wd >= $firstRecord) {
            // Día laboral ya pasado (y a partir del primer fichaje del empleado)
            // sin asistencia ni permiso: es falta, SALVO que el trabajador la
            // haya justificado y el director la aprobara.
            if (date_in_ranges($justRanges, $wd)) {
                $permisos++;
            } else {
                $faltas++;
            }
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
// Los snapshots de días PASADOS quedan inmutables; el de HOY sí se sincroniza
// (attendance_apply_schedule_change_to_today) para que un cambio de última hora
// — p. ej. autorizar salida temprana — surta efecto en el acto.
function adminScheduleSave(PDO $pdo, string $employeeId) {
    $admin = attendance_admin_guard($pdo);
    require_role($admin, ['director']);
    $emp = attendance_admin_target($pdo, $admin, $employeeId);

    $body = request_body();
    $entry = attendance_valid_time((string) ($body['entryTime'] ?? ''));
    $exit  = attendance_valid_time((string) ($body['exitTime'] ?? ''));
    $meal  = attendance_valid_time((string) ($body['mealTime'] ?? ''));
    $max   = (int) ($body['mealMaxMinutes'] ?? 0);
    $lateTol = (int) ($body['lateToleranceMinutes'] ?? 15);

    if (!$entry || !$exit || !$meal) {
        error_response('Horario inválido: usa el formato HH:MM (por ejemplo 09:00).', 400);
    }
    if ($max < 1 || $max > 240) {
        error_response('El límite de comida debe estar entre 1 y 240 minutos.', 400);
    }
    if ($lateTol < 0 || $lateTol > 60) {
        error_response('La tolerancia de retardo debe estar entre 0 y 60 minutos.', 400);
    }

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

    // Aplica el cambio también al día en curso (salida temprana autorizada,
    // etc.). No afecta a los días pasados.
    attendance_apply_schedule_change_to_today($pdo, $emp['id']);

    json_response([
        'success'  => true,
        'message'  => 'Horario guardado correctamente',
        'schedule' => attendance_schedule_payload(attendance_schedule_for($pdo, $emp['id'])),
    ]);
}

// POST /admin/schedules/bulk — asigna EL MISMO horario a varios trabajadores
// en una sola operación (solo director). body:
//   { employeeIds: [...], entryTime, exitTime, mealTime, mealMaxMinutes }
// Idempotente (upsert), atómico para errores de BD; los ids inexistentes se
// devuelven en `failed` sin bloquear al resto. Cambiar el horario NO altera
// la asistencia ya registrada (el backend congela el horario por día).
function adminScheduleBulkSave(PDO $pdo) {
    $admin = attendance_admin_guard($pdo);
    require_role($admin, ['director']);

    $body = request_body();
    $ids = $body['employeeIds'] ?? [];
    if (is_string($ids)) {
        $ids = array_filter(array_map('trim', explode(',', $ids)));
    }
    if (!is_array($ids) || !$ids) {
        error_response('Selecciona al menos un trabajador.', 400);
    }
    $ids = array_values(array_unique(array_map('strval', $ids)));
    if (count($ids) > 200) {
        error_response('Demasiados trabajadores en una sola operación (máx. 200).', 400);
    }

    $src = is_array($body['schedule'] ?? null) ? $body['schedule'] : $body;
    $entry = attendance_valid_time((string) ($src['entryTime'] ?? ''));
    $exit  = attendance_valid_time((string) ($src['exitTime'] ?? ''));
    $meal  = attendance_valid_time((string) ($src['mealTime'] ?? ''));
    $max   = (int) ($src['mealMaxMinutes'] ?? 0);
    $lateTol = (int) ($src['lateToleranceMinutes'] ?? 15);
    if (!$entry || !$exit || !$meal) {
        error_response('Horario inválido: usa el formato HH:MM (por ejemplo 09:00).', 400);
    }
    if ($max < 1 || $max > 240) {
        error_response('El límite de comida debe estar entre 1 y 240 minutos.', 400);
    }
    if ($lateTol < 0 || $lateTol > 60) {
        error_response('La tolerancia de retardo debe estar entre 0 y 60 minutos.', 400);
    }

    $applied = [];
    $failed = [];
    $pdo->beginTransaction();
    try {
        $chk = $pdo->prepare("SELECT id, role, email_verified_at FROM users WHERE id = ?");
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
        foreach ($ids as $eid) {
            $chk->execute([$eid]);
            $u = $chk->fetch();
            if (!$u || !in_array($u['role'], ['employee', 'manager'], true)
                || !user_email_verified($u)) {
                $failed[] = $eid;
                continue;
            }
            $up->execute([$eid, $entry, $exit, $meal, $max, $lateTol, $admin['id']]);
            // El cambio aplica también al día en curso de cada trabajador
            // (los días pasados no se tocan).
            attendance_apply_schedule_change_to_today($pdo, $eid);
            $applied[] = $eid;
        }
        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $e;
    }

    json_response([
        'success' => true,
        'message' => count($applied) . ' de ' . count($ids) . ' horarios asignados'
            . (count($failed) ? ' (' . count($failed) . ' sin asignar).' : '.'),
        'appliedCount' => count($applied),
        'applied' => $applied,
        'failed'  => $failed,
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

    // Verificación por credencial del dispositivo (PIN/patrón) en vez de huella
    // o rostro, de forma repetida. La spec habla de "≥3 días laborales
    // CONSECUTIVOS"; aquí se aproxima con ≥3 días DISTINTOS dentro de la
    // ventana, que es suficiente para levantar la bandera de revisión y evita
    // recorrer el calendario laboral en SQL.
    $st = $pdo->prepare(
        "SELECT a.employee_id, u.name, COUNT(DISTINCT a.work_date) c
         FROM attendance a JOIN users u ON u.id = a.employee_id
         WHERE a.biometric_result = 'skipped' AND a.event_time >= ?
         GROUP BY a.employee_id, u.name HAVING c >= 3"
    );
    $st->execute([$since]);
    foreach ($st->fetchAll() as $r) {
        $out[] = [
            'type' => 'biometric_skipped_streak', 'employeeId' => $r['employee_id'],
            'employeeName' => $r['name'],
            'detail' => (int) $r['c'] . ' días con verificación por PIN',
            'at' => null,
        ];
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

// GET /admin/attendance/trusted-devices — pestaña "Dispositivos" del director:
// quién tiene qué dispositivo vinculado y desde cuándo (spec §4.1).
function adminAttendanceTrustedDevices(PDO $pdo) {
    $admin = attendance_admin_guard($pdo);
    require_role($admin, ['director']);
    $st = $pdo->query(
        "SELECT d.employee_id, u.name AS employee_name, d.model, d.os_version,
                d.platform, d.enrolled_at, d.enrolled_via
         FROM attendance_trusted_devices d JOIN users u ON u.id = d.employee_id
         ORDER BY u.name ASC"
    );
    $rows = array_map(static fn($r) => [
        'employeeId'   => $r['employee_id'],
        'employeeName' => $r['employee_name'],
        'model'        => $r['model'],
        'osVersion'    => $r['os_version'],
        'platform'     => $r['platform'],
        'enrolledAt'   => $r['enrolled_at'],
        'via'          => $r['enrolled_via'],
    ], $st->fetchAll());
    json_response(['success' => true, 'devices' => $rows]);
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

