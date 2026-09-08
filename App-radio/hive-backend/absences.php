<?php
// Justificación de faltas pasadas (Radio Doliv).
//
// Una "falta" es un día laboral (lunes a sábado) ya pasado en el que el
// trabajador NO registró asistencia y NO tenía un permiso aprobado
// (attendance.php la cuenta como `faltaInjustificada`). Aquí el trabajador la
// justifica con un motivo y evidencia OBLIGATORIA (foto/PDF), y el director la
// aprueba o la rechaza. Una justificación APROBADA hace que esos días dejen de
// contar como falta injustificada (ver absence_is_justified(), consultada
// desde attendance.php).
//
// Endpoints (registrados en index.php):
//   GET  /absences/mine                                (faltas + justificaciones propias)
//   POST /absences/justify                             (multipart; evidencia OBLIGATORIA)
//   GET  /absences/justifications/{id}/evidence        (dueño o director)
//   GET  /admin/absences?status=&employeeId=           (director)
//   POST /admin/absences/{id}/approve                  (director)
//   POST /admin/absences/{id}/reject                   (director; motivo obligatorio)

// Cuántos días hacia atrás se pueden revisar/justificar: solo la última
// semana. Una falta más antigua que esto ya no se puede justificar.
const ABSENCE_LOOKBACK_DAYS = 7;

// ---- helpers --------------------------------------------------------

function absence_require_requester(PDO $pdo): array {
    $user = require_auth($pdo);
    if (!in_array($user['role'] ?? '', ['employee', 'manager'], true)) {
        json_response(['success' => false, 'message' => 'Esta sección no está disponible para tu rol.'], 403);
    }
    return $user;
}

function absence_row(PDO $pdo, string $id): ?array {
    $stmt = $pdo->prepare('SELECT * FROM absence_justifications WHERE id = ?');
    $stmt->execute([$id]);
    return $stmt->fetch() ?: null;
}

function absence_status_label(string $s): string {
    return ['pendiente' => 'Pendiente', 'aprobada' => 'Aprobada', 'rechazada' => 'Rechazada'][$s] ?? $s;
}

// ¿Ese día laboral cuenta como falta (sin asistencia y sin permiso aprobado)?
function absence_day_is_falta(PDO $pdo, string $employeeId, string $date): bool {
    if (!is_working_day($date)) return false;
    if ($date >= date('Y-m-d')) return false; // solo días ya pasados
    if (leave_absence_for_day($pdo, $employeeId, $date)) return false; // permiso aprobado
    $stmt = $pdo->prepare(
        "SELECT 1 FROM attendance WHERE employee_id = ? AND work_date = ? AND type = 'entrada' LIMIT 1"
    );
    $stmt->execute([$employeeId, $date]);
    return !$stmt->fetch();
}

// ¿Hay una justificación APROBADA que cubre ese día? La usa attendance.php
// para no contar el día como falta injustificada.
function absence_is_justified(PDO $pdo, string $employeeId, string $date): bool {
    $stmt = $pdo->prepare(
        "SELECT 1 FROM absence_justifications
          WHERE employee_id = ? AND status = 'aprobada'
            AND start_date <= ? AND end_date >= ? LIMIT 1"
    );
    $stmt->execute([$employeeId, $date, $date]);
    return (bool) $stmt->fetch();
}

// Rangos [inicio,fin] de las justificaciones APROBADAS del empleado, para
// resolver "¿está justificado el día X?" en memoria dentro de un bucle de
// fechas — una consulta en vez de una por día (N+1). Combinar con
// date_in_ranges().
function absence_approved_ranges(PDO $pdo, string $employeeId): array {
    $stmt = $pdo->prepare(
        "SELECT start_date, end_date FROM absence_justifications
          WHERE employee_id = ? AND status = 'aprobada'"
    );
    $stmt->execute([$employeeId]);
    return $stmt->fetchAll(PDO::FETCH_NUM);
}

// ¿Alguno de esos rangos [inicio,fin] (fechas 'Y-m-d') cubre $date?
function date_in_ranges(array $ranges, string $date): bool {
    foreach ($ranges as $r) {
        if ($r[0] <= $date && $date <= $r[1]) return true;
    }
    return false;
}

// Estado de justificación de un día concreto: 'ninguna' | 'pendiente' |
// 'aprobada' | 'rechazada' (la más relevante si hay varias).
function absence_day_justification_status(PDO $pdo, string $employeeId, string $date): string {
    $stmt = $pdo->prepare(
        "SELECT status FROM absence_justifications
          WHERE employee_id = ? AND start_date <= ? AND end_date >= ?
          ORDER BY FIELD(status,'aprobada','pendiente','rechazada') LIMIT 1"
    );
    $stmt->execute([$employeeId, $date, $date]);
    return $stmt->fetchColumn() ?: 'ninguna';
}

function absence_justification_payload(PDO $pdo, array $row, bool $includeEmployee = false): array {
    $out = [
        'id'          => $row['id'],
        'startDate'   => $row['start_date'],
        'endDate'     => $row['end_date'],
        'reason'      => db_decrypt($row['reason']),
        'status'      => $row['status'],
        'statusLabel' => absence_status_label($row['status']),
        'hasEvidence' => !empty($row['evidence_path']),
        'reviewNote'  => db_decrypt($row['review_note']),
        'reviewedAt'  => $row['reviewed_at'],
        'createdAt'   => $row['created_at'],
    ];
    if ($includeEmployee) {
        $stmt = $pdo->prepare('SELECT id, name, email, position FROM users WHERE id = ?');
        $stmt->execute([$row['employee_id']]);
        $emp = $stmt->fetch() ?: null;
        $out['employee'] = $emp ? [
            'id' => $emp['id'], 'name' => $emp['name'],
            'email' => $emp['email'], 'position' => $emp['position'],
        ] : null;
    }
    return $out;
}

// Agrupa los días falta del rango de revisión en periodos consecutivos
// (lunes a sábado; el domingo no rompe la racha pero tampoco cuenta). Cada
// periodo trae su estado de justificación.
function absence_unjustified_runs(PDO $pdo, string $employeeId): array {
    $today = new DateTimeImmutable(date('Y-m-d'));
    $from  = $today->modify('-' . ABSENCE_LOOKBACK_DAYS . ' days');
    $fromStr = $from->format('Y-m-d');
    $todayStr = $today->format('Y-m-d');

    $runs = [];
    $curStart = null;
    $curEnd = null;
    // Nada anterior al primer fichaje del empleado cuenta como falta.
    $firstRecord = attendance_first_record_date($pdo, $employeeId);

    // Todo lo que necesita el bucle, precargado en 3 consultas en vez de ~3 por
    // día (N+1): días con 'entrada', permisos aprobados que solapan la ventana y
    // justificaciones aprobadas.
    $attStmt = $pdo->prepare(
        "SELECT DISTINCT work_date FROM attendance
          WHERE employee_id = ? AND type = 'entrada' AND work_date BETWEEN ? AND ?"
    );
    $attStmt->execute([$employeeId, $fromStr, $todayStr]);
    $attended = array_fill_keys(array_column($attStmt->fetchAll(), 'work_date'), true);

    $leaveStmt = $pdo->prepare(
        "SELECT approved_start_date, approved_end_date FROM leave_requests
          WHERE employee_id = ? AND status = 'aprobado'
            AND approved_start_date <= ? AND approved_end_date >= ?"
    );
    $leaveStmt->execute([$employeeId, $todayStr, $fromStr]);
    $leaveRanges = $leaveStmt->fetchAll(PDO::FETCH_NUM);

    $justRanges = absence_approved_ranges($pdo, $employeeId);

    for ($d = $from; $d < $today; $d = $d->modify('+1 day')) {
        $wd = $d->format('Y-m-d');
        if ((int) $d->format('N') === 7) continue; // domingo: no rompe la racha
        // Equivale a absence_day_is_falta() + !absence_is_justified(), resuelto
        // en memoria: día laboral pasado, sin 'entrada', sin permiso aprobado y
        // sin justificación aprobada, a partir del primer fichaje del empleado.
        $isFalta = $firstRecord !== null && $wd >= $firstRecord
            && !isset($attended[$wd])
            && !date_in_ranges($leaveRanges, $wd)
            && !date_in_ranges($justRanges, $wd);
        if ($isFalta) {
            $curStart = $curStart ?? $wd;
            $curEnd = $wd;
        } elseif ($curStart !== null) {
            $runs[] = absence_run_payload($pdo, $employeeId, $curStart, $curEnd);
            $curStart = $curEnd = null;
        }
    }
    if ($curStart !== null) {
        $runs[] = absence_run_payload($pdo, $employeeId, $curStart, $curEnd);
    }
    // Más recientes primero.
    return array_reverse($runs);
}

function absence_run_payload(PDO $pdo, string $employeeId, string $start, string $end): array {
    // Nº de días laborales del periodo.
    $days = working_days_between($start, $end);
    $status = absence_day_justification_status($pdo, $employeeId, $start);
    return [
        'startDate'       => $start,
        'endDate'         => $end,
        'days'            => $days,
        // La evidencia SIEMPRE es obligatoria para justificar una falta
        // (una racha de 1, 2, 3 o más días consecutivos).
        'requiresEvidence'=> true,
        'consecutive'     => $days >= 2,
        'justificationStatus' => $status, // ninguna | pendiente | aprobada | rechazada
    ];
}

// ---- endpoints: trabajador ----------------------------------------

// GET /absences/mine
function absencesMine(PDO $pdo) {
    $user = absence_require_requester($pdo);

    $stmt = $pdo->prepare(
        'SELECT * FROM absence_justifications WHERE employee_id = ? ORDER BY created_at DESC, id DESC'
    );
    $stmt->execute([$user['id']]);
    $justifications = array_map(
        fn($r) => absence_justification_payload($pdo, $r),
        $stmt->fetchAll()
    );

    json_response([
        'success'        => true,
        'lookbackDays'   => ABSENCE_LOOKBACK_DAYS,
        'unjustified'    => absence_unjustified_runs($pdo, $user['id']),
        'justifications' => $justifications,
    ]);
}

// POST /absences/justify  (multipart/form-data)
// Campos: startDate, endDate, reason (opcional), evidence (archivo OBLIGATORIO).
function absenceJustify(PDO $pdo) {
    $user = absence_require_requester($pdo);
    require_verified_email($user); // justificar faltas exige correo verificado

    $start = leave_valid_date($_POST['startDate'] ?? '');
    $end   = leave_valid_date($_POST['endDate'] ?? '');
    if ($start === null || $end === null) {
        leave_fail('Indica el periodo de la falta que quieres justificar.', 400);
    }
    if ($end < $start) {
        leave_fail('La fecha de término no puede ser anterior a la de inicio.', 400);
    }
    $today = date('Y-m-d');
    if ($end >= $today) {
        leave_fail('Solo puedes justificar faltas de días que ya pasaron.', 400);
    }
    $limit = (new DateTimeImmutable($today))->modify('-' . ABSENCE_LOOKBACK_DAYS . ' days')->format('Y-m-d');
    if ($start < $limit) {
        leave_fail('Solo puedes justificar faltas de los últimos ' . ABSENCE_LOOKBACK_DAYS . ' días.', 400);
    }
    // No hay faltas antes del primer fichaje del trabajador (mismo criterio que
    // absence_unjustified_runs y los resúmenes de asistencia).
    $firstRecord = attendance_first_record_date($pdo, $user['id']);
    if ($firstRecord === null || $start < $firstRecord) {
        leave_fail('Ese periodo es anterior a tu primer registro de asistencia; no hay faltas que justificar.', 400);
    }

    // Todo día laboral del rango tiene que ser realmente una falta sin
    // justificar. Si algún día tiene asistencia o permiso aprobado, se rechaza.
    $hayFalta = false;
    for ($d = new DateTimeImmutable($start); $d <= new DateTimeImmutable($end); $d = $d->modify('+1 day')) {
        $wd = $d->format('Y-m-d');
        if ((int) $d->format('N') === 7) continue; // domingo
        if (absence_is_justified($pdo, $user['id'], $wd)) {
            leave_fail('Ese periodo ya tiene una justificación aprobada.', 409);
        }
        if (!absence_day_is_falta($pdo, $user['id'], $wd)) {
            leave_fail('El ' . $wd . ' no consta como falta (tiene asistencia o un permiso). Ajusta el periodo.', 400);
        }
        $hayFalta = true;
    }
    if (!$hayFalta) {
        leave_fail('El periodo seleccionado no contiene días laborales con falta.', 400);
    }

    // Evidencia OBLIGATORIA para cualquier justificación de falta.
    $hasFile = !empty($_FILES['evidence']) && $_FILES['evidence']['error'] !== UPLOAD_ERR_NO_FILE;
    if (!$hasFile) {
        leave_fail('Debes adjuntar evidencia (foto o PDF) para justificar una falta.', 400);
    }

    $reason = trim($_POST['reason'] ?? '');
    if (mb_strlen($reason) > 1000) $reason = mb_substr($reason, 0, 1000);

    $id = generate_id();
    $evidence = null;

    $pdo->beginTransaction();
    try {
        // Serializa envíos simultáneos del propio trabajador.
        $pdo->prepare('SELECT id FROM users WHERE id = ? FOR UPDATE')->execute([$user['id']]);

        // Solape con otra justificación NO rechazada del mismo trabajador.
        $ov = $pdo->prepare(
            "SELECT id FROM absence_justifications
              WHERE employee_id = ? AND status <> 'rechazada'
                AND start_date <= ? AND end_date >= ? LIMIT 1"
        );
        $ov->execute([$user['id'], $end, $start]);
        if ($ov->fetch()) {
            $pdo->rollBack();
            leave_fail('Ya enviaste una justificación que cubre parte de ese periodo.', 409);
        }

        $evidence = leave_store_evidence($_FILES['evidence']); // EVIDENCE_DIR privado

        $pdo->prepare(
            'INSERT INTO absence_justifications
               (id, employee_id, start_date, end_date, reason, evidence_path, evidence_mime, status)
             VALUES (?, ?, ?, ?, ?, ?, ?, "pendiente")'
        )->execute([
            $id, $user['id'], $start, $end,
            db_encrypt($reason !== '' ? $reason : null),
            $evidence['path'], $evidence['mime'],
        ]);

        $pdo->commit();
    } catch (PDOException $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        if ($evidence && !empty($evidence['path'])) {
            @unlink(EVIDENCE_DIR . basename($evidence['path']));
        }
        if ($e->getCode() === '23000') {
            leave_fail('Ya enviaste una justificación para ese mismo periodo.', 409);
        }
        throw $e;
    }

    // Aviso al director (a todos los que tengan rol director).
    $dirs = $pdo->query("SELECT email FROM users WHERE role = 'director'")->fetchAll(PDO::FETCH_COLUMN);
    foreach ($dirs as $dirEmail) {
        notify_user($pdo, $dirEmail, null, 'absence_justification',
            $user['name'] . ' envió una justificación de falta (' . leave_human_range($start, $end) . ').',
            'absence_justification', $id);
    }

    json_response([
        'success' => true,
        'message' => 'Justificación enviada. Queda pendiente de revisión del director.',
        'justification' => absence_justification_payload($pdo, absence_row($pdo, $id)),
    ]);
}

// GET /absences/justifications/{id}/evidence — dueño o director.
function absenceEvidence(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    $row = absence_row($pdo, $id);
    if (!$row) error_response('No se pudo cargar la evidencia.', 404);

    $isOwner = $row['employee_id'] === $user['id']
        && in_array($user['role'], ['employee', 'manager'], true);
    if (!$isOwner && $user['role'] !== 'director') {
        error_response('No tienes permiso para realizar esta acción.', 403);
    }
    if (empty($row['evidence_path'])) {
        error_response('Esta justificación no tiene evidencia adjunta.', 404);
    }
    $file = EVIDENCE_DIR . basename($row['evidence_path']);
    if (!is_file($file)) error_response('No se pudo cargar la evidencia.', 404);

    header('Content-Type: ' . ($row['evidence_mime'] ?: 'application/octet-stream'));
    header('Content-Length: ' . filesize($file));
    header('Content-Disposition: inline; filename="evidencia"');
    header('X-Content-Type-Options: nosniff');
    header('Cache-Control: private, no-store');
    readfile($file);
    exit;
}

// ---- endpoints: director ----------------------------------------

// GET /admin/absences?status=&employeeId=
function adminAbsencesList(PDO $pdo) {
    $user = require_auth($pdo);
    require_role($user, ['director']);

    $where = [];
    $params = [];
    $status = $_GET['status'] ?? '';
    if (in_array($status, ['pendiente', 'aprobada', 'rechazada'], true)) {
        $where[] = 'status = ?';
        $params[] = $status;
    }
    $employeeId = trim($_GET['employeeId'] ?? '');
    if ($employeeId !== '') {
        $where[] = 'employee_id = ?';
        $params[] = $employeeId;
    }
    $sql = 'SELECT * FROM absence_justifications';
    if ($where) $sql .= ' WHERE ' . implode(' AND ', $where);
    $sql .= " ORDER BY FIELD(status,'pendiente','aprobada','rechazada'), created_at DESC";
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    json_response([
        'success' => true,
        'justifications' => array_map(
            fn($r) => absence_justification_payload($pdo, $r, true),
            $stmt->fetchAll()
        ),
    ]);
}

function absence_admin_decide(PDO $pdo, string $id, string $decision): void {
    $user = require_auth($pdo);
    require_role($user, ['director']);
    $row = absence_row($pdo, $id);
    if (!$row) error_response('No encontramos esa justificación.', 404);
    if ($row['status'] !== 'pendiente') {
        leave_fail('Esta justificación ya fue procesada.', 409);
    }

    $body = request_body();
    $note = trim($body['reason'] ?? $body['note'] ?? '');
    if ($decision === 'rechazada' && $note === '') {
        leave_fail('Debes indicar el motivo del rechazo.', 400);
    }

    // Transición atómica: solo la aplica quien encuentra la justificación aún
    // pendiente. Con dos peticiones simultáneas (o un doble toque que esquiva la
    // comprobación previa) una gana y la otra recibe rowCount()===0, así no se
    // notifica dos veces ni se envían mensajes contradictorios.
    $upd = $pdo->prepare(
        'UPDATE absence_justifications
            SET status = ?, review_note = ?, reviewed_by = ?, reviewed_at = NOW()
          WHERE id = ? AND status = "pendiente"'
    );
    $upd->execute([$decision, db_encrypt($note !== '' ? mb_substr($note, 0, 1000) : null), $user['id'], $id]);
    if ($upd->rowCount() === 0) {
        leave_fail('Esta justificación ya fue procesada.', 409);
    }

    $stmt = $pdo->prepare('SELECT name, email FROM users WHERE id = ?');
    $stmt->execute([$row['employee_id']]);
    $emp = $stmt->fetch();
    if ($emp) {
        $msg = $decision === 'aprobada'
            ? '✅ Tu justificación de falta ' . leave_human_range($row['start_date'], $row['end_date']) . ' fue aprobada.'
            : '❌ Tu justificación de falta ' . leave_human_range($row['start_date'], $row['end_date']) . ' fue rechazada. Motivo: ' . $note;
        notify_user($pdo, $emp['email'], null,
            $decision === 'aprobada' ? 'absence_approved' : 'absence_rejected', $msg,
            'absence_justification', $id);
    }

    json_response([
        'success' => true,
        'message' => $decision === 'aprobada' ? 'Justificación aprobada.' : 'Justificación rechazada.',
        'justification' => absence_justification_payload($pdo, absence_row($pdo, $id), true),
    ]);
}

// POST /admin/absences/{id}/approve
function adminAbsenceApprove(PDO $pdo, string $id) {
    absence_admin_decide($pdo, $id, 'aprobada');
}

// POST /admin/absences/{id}/reject   body: reason (obligatorio)
function adminAbsenceReject(PDO $pdo, string $id) {
    absence_admin_decide($pdo, $id, 'rechazada');
}
