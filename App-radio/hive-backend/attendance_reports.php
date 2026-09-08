<?php
// Asistencia — Fase 2: reportes, resumen mensual y solicitudes de corrección
// (Radio Doliv). Extraído de attendance.php (demasiado grande); usa sus
// helpers `attendance_*` y los guards de attendance_admin.php
// (attendance_admin_guard / _employees / _target), todo cargado por el
// require de index.php.
//
// Endpoints (registrados en index.php):
//   GET  /attendance/summary?month=YYYY-MM                 (trabajador)
//   POST /attendance/corrections | GET /attendance/corrections/my   (trabajador)
//   GET  /admin/attendance/summary?month=&departmentId=    (director/manager)
//   GET  /admin/attendance/report?month=&departmentId=&format=csv|pdf
//   GET  /admin/attendance/corrections?status=             (director/manager)
//   POST /admin/attendance/corrections/{id}/resolve        (director/manager)

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
    $firstRecord = attendance_first_record_date($pdo, $employee['id']);

    $business = $worked = $lateCount = $lateMin = $absent = $totalWorked = 0;
    $vac = $inc = $perm = 0;

    // Permisos aprobados que solapan el rango (con tipo, orden por inicio como
    // leave_absence_for_day) y justificaciones aprobadas: una consulta cada uno
    // en vez de una por día (N+1). El detalle del día sigue en
    // attendance_day_summary().
    $leaveStmt = $pdo->prepare(
        "SELECT type, approved_start_date AS s, approved_end_date AS e FROM leave_requests
          WHERE employee_id = ? AND status = 'aprobado'
            AND approved_start_date <= ? AND approved_end_date >= ?
          ORDER BY approved_start_date ASC"
    );
    $leaveStmt->execute([$employee['id'], $to, $from]);
    $leaves = $leaveStmt->fetchAll();

    $justRanges = absence_approved_ranges($pdo, $employee['id']);

    for ($d = $start; $d <= $end; $d = $d->modify('+1 day')) {
        if ((int) $d->format('N') === 7) continue; // domingo (único día no laboral)
        $wd = $d->format('Y-m-d');
        $business++;

        $absType = null;
        foreach ($leaves as $lv) {
            if ($lv['s'] <= $wd && $wd <= $lv['e']) { $absType = $lv['type']; break; }
        }
        if ($absType !== null) {
            match ($absType) {
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
        } elseif ($wd < $today && $firstRecord !== null && $wd >= $firstRecord) {
            // Solo a partir del primer fichaje del empleado. Una falta
            // justificada y aprobada no cuenta como ausencia.
            if (date_in_ranges($justRanges, $wd)) {
                $perm++;
            } else {
                $absent++;
            }
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
