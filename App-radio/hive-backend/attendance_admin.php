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
    if (!$entry || !$exit || !$meal) {
        error_response('Horario inválido: usa el formato HH:MM (por ejemplo 09:00).', 400);
    }
    if ($max < 1 || $max > 240) {
        error_response('El límite de comida debe estar entre 1 y 240 minutos.', 400);
    }

    $applied = [];
    $failed = [];
    $pdo->beginTransaction();
    try {
        $chk = $pdo->prepare("SELECT id, role FROM users WHERE id = ?");
        $up = $pdo->prepare(
            'INSERT INTO employee_schedules
               (employee_id, entry_time, exit_time, meal_time, meal_max_minutes, updated_by)
             VALUES (?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE
               entry_time = VALUES(entry_time), exit_time = VALUES(exit_time),
               meal_time = VALUES(meal_time), meal_max_minutes = VALUES(meal_max_minutes),
               updated_by = VALUES(updated_by)'
        );
        foreach ($ids as $eid) {
            $chk->execute([$eid]);
            $u = $chk->fetch();
            if (!$u || !in_array($u['role'], ['employee', 'manager'], true)) {
                $failed[] = $eid;
                continue;
            }
            $up->execute([$eid, $entry, $exit, $meal, $max, $admin['id']]);
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

