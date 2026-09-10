<?php
// Permisos, vacaciones e incapacidades de empleados (Radio Doliv).
//
// Solicitan EMPLEADOS y MANAGERS (ambos registran asistencia y por tanto
// pueden necesitar ausentarse). El DIRECTOR revisa/aprueba/rechaza/revoca y
// nunca es tratado como solicitante (no puede crear solicitudes). El manager
// solicita como cualquier trabajador: NO aprueba nada (eso es solo del
// director), así que no hay riesgo de autoaprobación. Toda la autorización y
// validación es autoritativa en el backend.
//
// Integración con asistencia: un permiso `aprobado` cuyo rango APROBADO cubre
// un día laboral hace que ese día no requiera registro de asistencia
// (attendance.php consulta leave_absence_for_day()). Nunca se borran eventos
// de asistencia ni se borran solicitudes: todo el historial se conserva.
//
// Endpoints (registrados en index.php):
//   POST /leave-requests                          (multipart; evidencia opcional/obligatoria)
//   GET  /leave-requests/my
//   GET  /leave-requests/{id}
//   POST /leave-requests/{id}/cancel              (el empleado cancela su solicitud pendiente)
//   GET  /leave-requests/{id}/evidence            (empleado dueño o director)
//   GET  /admin/leave-requests
//   GET  /admin/leave-requests/calendar           (ausencias del equipo en un rango)
//   GET  /admin/leave-requests/{id}               (incluye `deptOverlaps`)
//   POST /admin/leave-requests/{id}/approve
//   POST /admin/leave-requests/{id}/reject
//   POST /admin/leave-requests/{id}/cancel        (revocar un permiso aprobado)

const LEAVE_TYPES = ['vacaciones', 'incapacidad', 'permiso'];
const LEAVE_EVIDENCE_MAX_BYTES = 8 * 1024 * 1024; // 8 MB
const LEAVE_EVIDENCE_EXT = ['jpg', 'jpeg', 'png', 'webp', 'pdf'];
const LEAVE_EVIDENCE_MIME = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];

// ---- helpers: seguridad --------------------------------------------

// Quien puede SOLICITAR permisos: empleados y managers. El director no (revisa,
// no solicita). Misma regla que attendance_require_worker() en attendance.php.
function leave_require_requester(PDO $pdo): array {
    $user = require_auth($pdo);
    if (!in_array($user['role'] ?? '', ['employee', 'manager'], true)) {
        json_response([
            'success' => false,
            'message' => 'Esta sección no está disponible para tu rol.',
        ], 403);
    }
    return $user;
}

function leave_require_director(PDO $pdo): array {
    $user = require_auth($pdo);
    require_role($user, ['director']);
    return $user;
}

function leave_fail(string $message, int $status = 409, ?string $code = null): void {
    $body = ['success' => false, 'message' => $message];
    if ($code !== null) $body['code'] = $code;
    json_response($body, $status);
}

// ---- helpers: fechas y días hábiles -------------------------------

function leave_valid_date(?string $value): ?string {
    $value = trim((string) $value);
    if ($value === '') return null;
    $ts = strtotime($value);
    if ($ts === false) return null;
    $d = date('Y-m-d', $ts);
    // Rechaza fechas absurdas fuera de un rango razonable.
    if ($d < '2000-01-01' || $d > '2100-12-31') return null;
    return $d;
}

// Cuenta los días laborales del rango, ambos inclusive. La semana laboral de
// Radio Doliv es LUNES A SÁBADO (solo el domingo no cuenta); ver
// is_working_day()/working_days_between() en helpers.php.
function leave_business_days(string $start, string $end): int {
    return working_days_between($start, $end);
}

// "del 1 al 5 de septiembre" / "el 20 de septiembre de 2026".
function leave_human_range(string $start, string $end): string {
    $meses = [1 => 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
              'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    $s = new DateTimeImmutable($start);
    $e = new DateTimeImmutable($end);
    if ($start === $end) {
        return 'el ' . (int) $s->format('j') . ' de ' . $meses[(int) $s->format('n')] . ' de ' . $s->format('Y');
    }
    if ($s->format('Y-n') === $e->format('Y-n')) {
        return 'del ' . (int) $s->format('j') . ' al ' . (int) $e->format('j')
            . ' de ' . $meses[(int) $s->format('n')] . ' de ' . $s->format('Y');
    }
    return 'del ' . (int) $s->format('j') . ' de ' . $meses[(int) $s->format('n')]
        . ' al ' . (int) $e->format('j') . ' de ' . $meses[(int) $e->format('n')]
        . ' de ' . $e->format('Y');
}

// ---- helpers: datos y payload -----------------------------------

function leave_row(PDO $pdo, string $id): ?array {
    $stmt = $pdo->prepare('SELECT * FROM leave_requests WHERE id = ?');
    $stmt->execute([$id]);
    return $stmt->fetch() ?: null;
}

function leave_type_label(string $type): string {
    return ['vacaciones' => 'Vacaciones', 'incapacidad' => 'Incapacidad', 'permiso' => 'Permiso'][$type] ?? $type;
}

function leave_status_label(string $status): string {
    return [
        'pendiente'  => 'Pendiente',
        'aprobado'   => 'Aprobado',
        'rechazado'  => 'Rechazado',
        'cancelado'  => 'Cancelado',
    ][$status] ?? $status;
}

// Forma pública de una solicitud. NUNCA expone evidence_path ni rutas
// internas: solo `hasEvidence`. `includeEmployee` agrega los datos del
// empleado (para el panel del director).
function leave_request_payload(PDO $pdo, array $row, bool $includeEmployee = false): array {
    $out = [
        'id'                  => $row['id'],
        'type'                => $row['type'],
        'typeLabel'           => leave_type_label($row['type']),
        'status'              => $row['status'],
        'statusLabel'         => leave_status_label($row['status']),
        'requestedStartDate'  => $row['requested_start_date'],
        'requestedEndDate'    => $row['requested_end_date'],
        'requestedDays'       => (int) $row['requested_days'],
        'approvedStartDate'   => $row['approved_start_date'],
        'approvedEndDate'     => $row['approved_end_date'],
        'approvedDays'        => $row['approved_days'] !== null ? (int) $row['approved_days'] : null,
        'reason'              => db_decrypt($row['reason']),
        'rejectionReason'     => db_decrypt($row['rejection_reason']),
        'cancellationReason'  => db_decrypt($row['cancellation_reason']),
        'hasEvidence'         => !empty($row['evidence_path']),
        'createdAt'           => $row['created_at'],
        'approvedAt'          => $row['approved_at'],
        'cancelledAt'         => $row['cancelled_at'],
    ];

    if ($includeEmployee) {
        $stmt = $pdo->prepare('SELECT id, name, email, position FROM users WHERE id = ?');
        $stmt->execute([$row['employee_id']]);
        $emp = $stmt->fetch() ?: null;
        $out['employee'] = $emp ? [
            'id'       => $emp['id'],
            'name'     => $emp['name'],
            'email'    => $emp['email'],
            'position' => $emp['position'],
        ] : null;
    }

    return $out;
}

// Solapamiento entre el rango dado y algún permiso YA APROBADO del empleado.
function leave_has_overlap(PDO $pdo, string $employeeId, string $start, string $end, ?string $excludeId = null): bool {
    $sql = "SELECT 1 FROM leave_requests
            WHERE employee_id = ? AND status = 'aprobado'
              AND approved_start_date <= ? AND approved_end_date >= ?";
    $params = [$employeeId, $end, $start];
    if ($excludeId !== null) {
        $sql .= ' AND id <> ?';
        $params[] = $excludeId;
    }
    $sql .= ' LIMIT 1';
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    return (bool) $stmt->fetch();
}

// Primera solicitud ACTIVA (pendiente o aprobada) del empleado cuyo rango
// efectivo (el aprobado si existe, si no el solicitado) se cruza con
// [start, end]. Devuelve la fila o null. A diferencia de leave_has_overlap(),
// esta cuenta también las PENDIENTES: se usa al CREAR para no dejar apilar
// dos ausencias que se pisan (permiso/vacaciones/incapacidad). Dos días
// adyacentes que NO se tocan (fin = inicio-1) no son solape.
function leave_first_conflict(PDO $pdo, string $employeeId, string $start, string $end, ?string $excludeId = null): ?array {
    $sql = "SELECT * FROM leave_requests
            WHERE employee_id = ?
              AND status IN ('pendiente','aprobado')
              AND COALESCE(approved_start_date, requested_start_date) <= ?
              AND COALESCE(approved_end_date, requested_end_date) >= ?";
    $params = [$employeeId, $end, $start];
    if ($excludeId !== null) {
        $sql .= ' AND id <> ?';
        $params[] = $excludeId;
    }
    $sql .= ' ORDER BY COALESCE(approved_start_date, requested_start_date) ASC LIMIT 1';
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    return $stmt->fetch() ?: null;
}

// ---- integración con asistencia -------------------------------------
// Usadas desde attendance.php. Un permiso `aprobado` cuyo rango aprobado
// cubre $date exime del registro de asistencia ese día.

function leave_absence_for_day(PDO $pdo, string $employeeId, string $date): ?array {
    $stmt = $pdo->prepare(
        "SELECT * FROM leave_requests
         WHERE employee_id = ? AND status = 'aprobado'
           AND approved_start_date <= ? AND approved_end_date >= ?
         ORDER BY approved_start_date ASC LIMIT 1"
    );
    $stmt->execute([$employeeId, $date, $date]);
    return $stmt->fetch() ?: null;
}

function leave_absence_payload(?array $row): ?array {
    if (!$row) return null;
    return [
        'type'       => $row['type'],
        'typeLabel'  => leave_type_label($row['type']),
        'startDate'  => $row['approved_start_date'],
        'endDate'    => $row['approved_end_date'],
    ];
}

// ---- helpers: evidencia -------------------------------------------

function leave_store_evidence(array $file): array {
    if ($file['error'] !== UPLOAD_ERR_OK) {
        leave_fail('No se pudo subir la evidencia. Inténtalo nuevamente.', 400);
    }
    if ($file['size'] <= 0 || $file['size'] > LEAVE_EVIDENCE_MAX_BYTES) {
        leave_fail('La evidencia supera el tamaño máximo permitido (8 MB).', 400);
    }

    $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    if (!in_array($ext, LEAVE_EVIDENCE_EXT, true)) {
        leave_fail('La evidencia debe ser una imagen (JPG, PNG o WEBP) o un PDF.', 400);
    }

    $mime = null;
    if (function_exists('finfo_open')) {
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mime = finfo_file($finfo, $file['tmp_name']) ?: null;
        finfo_close($finfo);
    }
    if ($mime !== null && !in_array($mime, LEAVE_EVIDENCE_MIME, true)) {
        leave_fail('El tipo de archivo de la evidencia no es válido.', 400);
    }
    // Refuerzo para imágenes: debe abrir como imagen real.
    if (in_array($ext, ['jpg', 'jpeg', 'png', 'webp'], true) && @getimagesize($file['tmp_name']) === false) {
        leave_fail('La imagen de evidencia está dañada o no es válida.', 400);
    }
    if ($mime === null) {
        $mime = $ext === 'pdf' ? 'application/pdf' : 'image/' . ($ext === 'jpg' ? 'jpeg' : $ext);
    }

    // Nombre generado por el servidor: nunca se confía en el original.
    $stored = bin2hex(random_bytes(16)) . '.' . $ext;
    if (!move_uploaded_file($file['tmp_name'], EVIDENCE_DIR . $stored)) {
        leave_fail('No se pudo guardar la evidencia en el servidor.', 500);
    }
    return ['path' => $stored, 'mime' => $mime];
}

// ---- endpoints: empleado -----------------------------------------

// POST /leave-requests  (multipart/form-data)
// Campos: type, requestedStartDate, requestedEndDate, reason (opcional),
//         evidence (archivo; OBLIGATORIO si type = incapacidad).
function leaveRequestCreate(PDO $pdo) {
    $user = leave_require_requester($pdo);
    require_verified_email($user); // crear solicitudes exige correo verificado

    $type = trim($_POST['type'] ?? '');
    if (!in_array($type, LEAVE_TYPES, true)) {
        leave_fail('Selecciona un tipo de permiso válido.', 400);
    }
    // Las vacaciones ya no se solicitan por la app (el tipo se conserva solo
    // para leer/mostrar el historial anterior).
    if ($type === 'vacaciones') {
        leave_fail('Las solicitudes de vacaciones no están disponibles.', 400);
    }

    $start = leave_valid_date($_POST['requestedStartDate'] ?? '');
    $end = leave_valid_date($_POST['requestedEndDate'] ?? '');
    if ($start === null) leave_fail('Debes seleccionar una fecha de inicio.', 400);
    if ($end === null) leave_fail('Debes seleccionar una fecha de término.', 400);
    if ($end < $start) {
        leave_fail('La fecha de término no puede ser anterior a la fecha de inicio.', 400);
    }

    // El inicio y el término deben caer en un día laboral (lunes a sábado);
    // el domingo no es laboral. Un rango de varios días puede ABARCAR un
    // domingo, pero no empezar ni terminar en él.
    if (!is_working_day($start) || !is_working_day($end)) {
        leave_fail('El inicio y el término deben ser un día laboral (lunes a sábado).', 400);
    }

    // Ventanas de fecha por tipo (todo relativo a HOY, zona del servidor
    // -06:00 México). La justificación de faltas pasadas va por su módulo propio.
    //   vacaciones : inicio de hoy en adelante; el rango no pasa de un mes de
    //                calendario desde el inicio (15-ene→15-feb sí, →16-feb no).
    //   permiso    : TODO el permiso cae en [hoy, hoy + 1 mes de calendario].
    //   incapacidad: el inicio puede ser hasta 3 días hacia atrás (la evidencia
    //                médica lo respalda); el término no pasa de un año desde hoy.
    $today = date('Y-m-d');
    if ($type === 'vacaciones') {
        if ($start < $today) {
            leave_fail('No puedes solicitar vacaciones para una fecha que ya pasó.', 400);
        }
        $maxEnd = one_calendar_month_max_end($start);
        if ($end > $maxEnd) {
            leave_fail('Las vacaciones no pueden abarcar más de un mes. '
                . 'Con este inicio, la última fecha posible es el ' . $maxEnd . '.', 400);
        }
    } elseif ($type === 'permiso') {
        if ($start < $today) {
            leave_fail('No puedes solicitar un permiso para una fecha que ya pasó.', 400);
        }
        $maxEnd = one_calendar_month_max_end($today);
        if ($end > $maxEnd) {
            leave_fail('Un permiso solo puede solicitarse hasta un mes a partir de hoy '
                . '(última fecha posible: ' . $maxEnd . ').', 400);
        }
    } elseif ($type === 'incapacidad') {
        $minStart = date('Y-m-d', strtotime($today . ' -3 days'));
        if ($start < $minStart) {
            leave_fail('La incapacidad puede iniciar como máximo 3 días antes de hoy.', 400);
        }
        $maxEnd = date('Y-m-d', strtotime($today . ' +1 year'));
        if ($end > $maxEnd) {
            leave_fail('Una incapacidad no puede extenderse más de un año a partir de hoy '
                . '(última fecha posible: ' . $maxEnd . ').', 400);
        }
    }

    $reason = trim($_POST['reason'] ?? '');
    if (mb_strlen($reason) > 1000) $reason = mb_substr($reason, 0, 1000);

    // Incapacidad: la evidencia es obligatoria ANTES de poder enviar.
    $hasFile = !empty($_FILES['evidence']) && $_FILES['evidence']['error'] !== UPLOAD_ERR_NO_FILE;
    if ($type === 'incapacidad' && !$hasFile) {
        leave_fail('Debes adjuntar evidencia para solicitar una incapacidad.', 400);
    }

    $days = leave_business_days($start, $end);
    $id = generate_id();
    $evidence = null;

    // Sección crítica: se bloquea la fila del propio empleado para serializar
    // dos envíos simultáneos suyos (doble toque, dos dispositivos) y así el
    // control de solape y de duplicado no se pueda esquivar por carrera.
    $pdo->beginTransaction();
    try {
        $lock = $pdo->prepare('SELECT id FROM users WHERE id = ? FOR UPDATE');
        $lock->execute([$user['id']]);

        // Reenvío accidental de una solicitud idéntica que sigue pendiente.
        $dup = $pdo->prepare(
            "SELECT id FROM leave_requests
              WHERE employee_id = ? AND type = ? AND requested_start_date = ?
                AND requested_end_date = ? AND status = 'pendiente'"
        );
        $dup->execute([$user['id'], $type, $start, $end]);
        if ($dup->fetch()) {
            $pdo->rollBack();
            leave_fail('Ya enviaste una solicitud igual (mismo tipo y fechas) que sigue pendiente de revisión.', 409);
        }

        // Solape con otra ausencia activa (pendiente o aprobada) del empleado:
        // no se pueden tener vacaciones/permiso/incapacidad encimados.
        $conflict = leave_first_conflict($pdo, $user['id'], $start, $end);
        if ($conflict) {
            $pdo->rollBack();
            $cs = $conflict['approved_start_date'] ?: $conflict['requested_start_date'];
            $ce = $conflict['approved_end_date'] ?: $conflict['requested_end_date'];
            leave_fail('Estas fechas se cruzan con tu ' . leave_type_label($conflict['type'])
                . ' ' . leave_human_range($cs, $ce)
                . ' (' . leave_status_label($conflict['status']) . ').', 409,
                'OVERLAP');
        }

        // Evidencia: se procesa ya dentro de la sección crítica, después de
        // pasar todas las validaciones, para no mover el archivo en balde.
        if ($hasFile) {
            $evidence = leave_store_evidence($_FILES['evidence']);
        }

        $stmt = $pdo->prepare(
            'INSERT INTO leave_requests
               (id, employee_id, type, requested_start_date, requested_end_date, requested_days,
                reason, status, evidence_path, evidence_mime)
             VALUES (?, ?, ?, ?, ?, ?, ?, "pendiente", ?, ?)'
        );
        $stmt->execute([
            $id, $user['id'], $type, $start, $end, $days,
            db_encrypt($reason !== '' ? $reason : null),
            $evidence['path'] ?? null,
            $evidence['mime'] ?? null,
        ]);

        $pdo->commit();
    } catch (PDOException $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        if ($evidence && !empty($evidence['path'])) {
            @unlink(EVIDENCE_DIR . basename($evidence['path']));
        }
        if ($e->getCode() === '23000') {
            leave_fail('Ya enviaste una solicitud igual (mismo tipo y fechas) que sigue pendiente de revisión.', 409);
        }
        throw $e;
    }

    json_response([
        'success' => true,
        'message' => 'Solicitud enviada correctamente. Tu solicitud está pendiente de revisión.',
        'request' => leave_request_payload($pdo, leave_row($pdo, $id)),
    ]);
}

// GET /leave-requests/my
function leaveRequestsMine(PDO $pdo) {
    $user = leave_require_requester($pdo);
    $stmt = $pdo->prepare(
        'SELECT * FROM leave_requests WHERE employee_id = ? ORDER BY created_at DESC, id DESC'
    );
    $stmt->execute([$user['id']]);
    $items = array_map(fn($r) => leave_request_payload($pdo, $r), $stmt->fetchAll());
    json_response(['success' => true, 'requests' => $items]);
}

// GET /leave-requests/{id}  — solo el dueño.
function leaveRequestGet(PDO $pdo, string $id) {
    $user = leave_require_requester($pdo);
    $row = leave_row($pdo, $id);
    if (!$row || $row['employee_id'] !== $user['id']) {
        error_response('No encontramos esa solicitud.', 404);
    }
    json_response(['success' => true, 'request' => leave_request_payload($pdo, $row)]);
}

// POST /leave-requests/{id}/cancel — el empleado cancela su propia solicitud
// mientras siga pendiente. Un permiso ya aprobado solo lo revoca el director.
function leaveRequestCancelByEmployee(PDO $pdo, string $id) {
    $user = leave_require_requester($pdo);
    $row = leave_row($pdo, $id);
    if (!$row || $row['employee_id'] !== $user['id']) {
        error_response('No encontramos esa solicitud.', 404);
    }
    if ($row['status'] !== 'pendiente') {
        leave_fail('Solo puedes cancelar una solicitud que sigue pendiente.', 409);
    }
    $reason = trim($_POST['reason'] ?? '') ?: 'Cancelada por el empleado';
    $stmt = $pdo->prepare(
        'UPDATE leave_requests
         SET status = "cancelado", cancellation_reason = ?, cancelled_by = ?, cancelled_at = NOW()
         WHERE id = ?'
    );
    $stmt->execute([db_encrypt(mb_substr($reason, 0, 1000)), $user['id'], $id]);
    json_response([
        'success' => true,
        'message' => 'Solicitud cancelada.',
        'request' => leave_request_payload($pdo, leave_row($pdo, $id)),
    ]);
}

// GET /leave-requests/{id}/evidence — sirve el archivo privado. Autorizado
// para el empleado dueño y para el director. Nunca expone la ruta interna.
function leaveRequestEvidence(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    $row = leave_row($pdo, $id);
    if (!$row) {
        error_response('No se pudo cargar la evidencia.', 404);
    }
    $isOwner = $row['employee_id'] === $user['id']
        && in_array($user['role'], ['employee', 'manager'], true);
    $isDirector = $user['role'] === 'director';
    if (!$isOwner && !$isDirector) {
        error_response('No tienes permiso para realizar esta acción.', 403);
    }
    if (empty($row['evidence_path'])) {
        error_response('Esta solicitud no tiene evidencia adjunta.', 404);
    }
    $file = EVIDENCE_DIR . basename($row['evidence_path']);
    if (!is_file($file)) {
        error_response('No se pudo cargar la evidencia.', 404);
    }

    $mime = $row['evidence_mime'] ?: 'application/octet-stream';
    header('Content-Type: ' . $mime);
    header('Content-Length: ' . filesize($file));
    header('Content-Disposition: inline; filename="evidencia"');
    header('X-Content-Type-Options: nosniff');
    header('Cache-Control: private, no-store');
    readfile($file);
    exit;
}

// ---- endpoints: director ---------------------------------------

// GET /admin/leave-requests?status=&type=&employeeId=&from=&to=
function adminLeaveRequestsList(PDO $pdo) {
    leave_require_director($pdo);

    $where = [];
    $params = [];

    $status = $_GET['status'] ?? '';
    if (in_array($status, ['pendiente', 'aprobado', 'rechazado', 'cancelado'], true)) {
        $where[] = 'lr.status = ?';
        $params[] = $status;
    }
    $type = $_GET['type'] ?? '';
    if (in_array($type, LEAVE_TYPES, true)) {
        $where[] = 'lr.type = ?';
        $params[] = $type;
    }
    $employeeId = trim($_GET['employeeId'] ?? '');
    if ($employeeId !== '') {
        $where[] = 'lr.employee_id = ?';
        $params[] = $employeeId;
    }
    $from = leave_valid_date($_GET['from'] ?? '');
    $to = leave_valid_date($_GET['to'] ?? '');
    if ($from !== null && $to !== null) {
        // Solicitudes cuyo rango solicitado se cruza con [from, to].
        $where[] = 'lr.requested_start_date <= ? AND lr.requested_end_date >= ?';
        $params[] = $to;
        $params[] = $from;
    }

    $sql = 'SELECT lr.* FROM leave_requests lr';
    if ($where) $sql .= ' WHERE ' . implode(' AND ', $where);
    // Pendientes primero, luego por fecha de creación descendente.
    $sql .= " ORDER BY FIELD(lr.status,'pendiente','aprobado','rechazado','cancelado'), lr.created_at DESC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $items = array_map(fn($r) => leave_request_payload($pdo, $r, true), $stmt->fetchAll());
    json_response(['success' => true, 'requests' => $items]);
}

// GET /admin/leave-requests/{id}
function adminLeaveRequestGet(PDO $pdo, string $id) {
    leave_require_director($pdo);
    $row = leave_row($pdo, $id);
    if (!$row) {
        error_response('No encontramos esa solicitud.', 404);
    }
    $payload = leave_request_payload($pdo, $row, true);
    // Aviso de planificación: otras ausencias del mismo departamento que se
    // cruzan con estas fechas (para no dejar el área descubierta).
    $payload['deptOverlaps'] = leave_dept_overlaps($pdo, $row);
    json_response(['success' => true, 'request' => $payload]);
}

// Valida que el solicitante siga siendo un trabajador válido (empleado o
// manager: ambos pueden pedir permisos).
function leave_admin_employee(PDO $pdo, array $row): array {
    $stmt = $pdo->prepare('SELECT * FROM users WHERE id = ?');
    $stmt->execute([$row['employee_id']]);
    $emp = $stmt->fetch();
    if (!$emp || !in_array($emp['role'], ['employee', 'manager'], true)) {
        leave_fail('El solicitante ya no está activo.', 409);
    }
    return $emp;
}

// POST /admin/leave-requests/{id}/approve
// body: approvedStartDate, approvedEndDate (por defecto, el rango solicitado).
function adminLeaveRequestApprove(PDO $pdo, string $id) {
    $director = leave_require_director($pdo);
    $row = leave_row($pdo, $id);
    if (!$row) error_response('No encontramos esa solicitud.', 404);
    if ($row['status'] !== 'pendiente') {
        leave_fail('La solicitud ya fue procesada.', 409);
    }
    $emp = leave_admin_employee($pdo, $row);

    $body = request_body();
    $start = leave_valid_date($body['approvedStartDate'] ?? '') ?? $row['requested_start_date'];
    $end = leave_valid_date($body['approvedEndDate'] ?? '') ?? $row['requested_end_date'];
    if ($end < $start) {
        leave_fail('La fecha de término aprobada no puede ser anterior a la fecha de inicio.', 400);
    }
    if (!is_working_day($start) || !is_working_day($end)) {
        leave_fail('El inicio y el término autorizados deben ser un día laboral (lunes a sábado).', 400);
    }
    // El periodo autorizado respeta el mismo tope que la solicitud:
    // vacaciones y permiso ≤ un mes de calendario; incapacidad ≤ un año.
    if ($row['type'] === 'vacaciones' || $row['type'] === 'permiso') {
        $maxEnd = one_calendar_month_max_end($start);
        if ($end > $maxEnd) {
            $etq = $row['type'] === 'vacaciones' ? 'Las vacaciones' : 'El permiso';
            leave_fail($etq . ' no pueden abarcar más de un mes (última fecha posible: ' . $maxEnd . ').', 400);
        }
    } elseif ($row['type'] === 'incapacidad') {
        $maxEnd = date('Y-m-d', strtotime($start . ' +1 year'));
        if ($end > $maxEnd) {
            leave_fail('Una incapacidad no puede abarcar más de un año (última fecha posible: ' . $maxEnd . ').', 400);
        }
    }
    if (leave_has_overlap($pdo, $emp['id'], $start, $end, $id)) {
        leave_fail('Ya existe una ausencia autorizada durante este periodo.', 409);
    }

    $days = leave_business_days($start, $end);
    $stmt = $pdo->prepare(
        'UPDATE leave_requests
         SET status = "aprobado", approved_start_date = ?, approved_end_date = ?, approved_days = ?,
             approved_by = ?, approved_at = NOW()
         WHERE id = ?'
    );
    $stmt->execute([$start, $end, $days, $director['id'], $id]);

    $icon = $row['type'] === 'incapacidad' ? '🏥' : ($row['type'] === 'vacaciones' ? '🏖️' : '📝');
    $tipo = $row['type'] === 'incapacidad' ? 'incapacidad' : ($row['type'] === 'vacaciones' ? 'vacaciones' : 'permiso');
    notify_user($pdo, $emp['email'], null, 'leave_approved',
        "$icon Tu solicitud de $tipo " . leave_human_range($start, $end) . ' fue aprobada.');

    json_response([
        'success' => true,
        'message' => 'Solicitud aprobada.',
        'request' => leave_request_payload($pdo, leave_row($pdo, $id), true),
    ]);
}

// POST /admin/leave-requests/{id}/reject  — body: reason (obligatorio).
function adminLeaveRequestReject(PDO $pdo, string $id) {
    $director = leave_require_director($pdo);
    $row = leave_row($pdo, $id);
    if (!$row) error_response('No encontramos esa solicitud.', 404);
    if ($row['status'] !== 'pendiente') {
        leave_fail('La solicitud ya fue procesada.', 409);
    }
    $emp = leave_admin_employee($pdo, $row);

    $body = request_body();
    $reason = trim($body['reason'] ?? '');
    if ($reason === '') {
        leave_fail('Debes indicar el motivo del rechazo.', 400);
    }

    $stmt = $pdo->prepare(
        'UPDATE leave_requests
         SET status = "rechazado", rejection_reason = ?, approved_by = ?, approved_at = NOW()
         WHERE id = ?'
    );
    $stmt->execute([db_encrypt(mb_substr($reason, 0, 1000)), $director['id'], $id]);

    notify_user($pdo, $emp['email'], null, 'leave_rejected',
        '❌ Tu solicitud de ' . leave_type_label($row['type']) . ' fue rechazada. Motivo: ' . $reason);

    json_response([
        'success' => true,
        'message' => 'Solicitud rechazada.',
        'request' => leave_request_payload($pdo, leave_row($pdo, $id), true),
    ]);
}

// POST /admin/leave-requests/{id}/cancel — revoca un permiso APROBADO.
// body: reason (obligatorio). Conserva todo el historial de la aprobación.
function adminLeaveRequestCancel(PDO $pdo, string $id) {
    $director = leave_require_director($pdo);
    $row = leave_row($pdo, $id);
    if (!$row) error_response('No encontramos esa solicitud.', 404);
    if ($row['status'] !== 'aprobado') {
        leave_fail('Solo se puede revocar un permiso que está aprobado.', 409);
    }
    $emp = leave_admin_employee($pdo, $row);

    $body = request_body();
    $reason = trim($body['reason'] ?? '');
    if ($reason === '') {
        leave_fail('Debes indicar el motivo de la revocación.', 400);
    }

    // Conserva approved_* y approved_by/at; solo marca la cancelación.
    $stmt = $pdo->prepare(
        'UPDATE leave_requests
         SET status = "cancelado", cancellation_reason = ?, cancelled_by = ?, cancelled_at = NOW()
         WHERE id = ?'
    );
    $stmt->execute([db_encrypt(mb_substr($reason, 0, 1000)), $director['id'], $id]);

    notify_user($pdo, $emp['email'], null, 'leave_cancelled',
        '⚠️ Tu permiso de ' . leave_type_label($row['type']) . ' '
        . leave_human_range($row['approved_start_date'], $row['approved_end_date'])
        . ' fue revocado. Motivo: ' . $reason);

    json_response([
        'success' => true,
        'message' => 'Permiso revocado.',
        'request' => leave_request_payload($pdo, leave_row($pdo, $id), true),
    ]);
}

// ============================================================================
// Fase 3 — Calendario de ausencias del equipo (Radio Doliv). Solo director,
// como el resto del panel de permisos.
//   GET /admin/leave-requests/calendar?from=&to=&departmentId=&status=
// Y un extra `deptOverlaps` en GET /admin/leave-requests/{id} para avisar de
// solapamientos antes de aprobar.
// ============================================================================

// Item plano para el calendario: rango efectivo (aprobado si existe, si no el
// solicitado) + a quién y de qué tipo.
function leave_calendar_item(array $r): array {
    $start = $r['approved_start_date'] ?: $r['requested_start_date'];
    $end   = $r['approved_end_date'] ?: $r['requested_end_date'];
    return [
        'id'             => $r['id'],
        'employeeId'     => $r['employee_id'],
        'employeeName'   => $r['emp_name'] ?? null,
        'departmentId'   => $r['dept_id'] ?? null,
        'departmentName' => $r['dept_name'] ?? null,
        'type'           => $r['type'],
        'typeLabel'      => leave_type_label($r['type']),
        'status'         => $r['status'],
        'statusLabel'    => leave_status_label($r['status']),
        'startDate'      => $start,
        'endDate'        => $end,
    ];
}

// GET /admin/leave-requests/calendar
function adminLeaveCalendar(PDO $pdo) {
    leave_require_director($pdo);

    $from = leave_valid_date($_GET['from'] ?? '') ?? date('Y-m-01');
    $to   = leave_valid_date($_GET['to'] ?? '') ?? date('Y-m-t');
    if ($to < $from) { [$from, $to] = [$to, $from]; }

    $deptFilter = trim($_GET['departmentId'] ?? '');

    // Por defecto: aprobados + pendientes (los que "cuentan" para planificar).
    $statuses = ['aprobado', 'pendiente'];
    $s = $_GET['status'] ?? '';
    if (in_array($s, ['pendiente', 'aprobado', 'rechazado', 'cancelado'], true)) {
        $statuses = [$s];
    }

    $ph = implode(',', array_fill(0, count($statuses), '?'));
    $sql = "SELECT lr.*, u.name AS emp_name, u.department_id AS dept_id, d.name AS dept_name
              FROM leave_requests lr
              JOIN users u ON u.id = lr.employee_id
         LEFT JOIN departments d ON d.id = u.department_id
             WHERE lr.status IN ($ph)
               AND COALESCE(lr.approved_start_date, lr.requested_start_date) <= ?
               AND COALESCE(lr.approved_end_date, lr.requested_end_date) >= ?";
    $params = array_merge($statuses, [$to, $from]);
    if ($deptFilter !== '') {
        $sql .= ' AND u.department_id = ?';
        $params[] = $deptFilter;
    }
    $sql .= ' ORDER BY COALESCE(lr.approved_start_date, lr.requested_start_date) ASC, u.name ASC';

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $items = array_map('leave_calendar_item', $stmt->fetchAll());

    json_response(['success' => true, 'from' => $from, 'to' => $to, 'items' => $items]);
}

// Otras ausencias (aprobadas o pendientes) del MISMO departamento que se
// cruzan con el rango de esta solicitud. Sirve para avisar al director antes
// de aprobar. Excluye la propia solicitud.
function leave_dept_overlaps(PDO $pdo, array $row): array {
    $stmt = $pdo->prepare('SELECT department_id FROM users WHERE id = ?');
    $stmt->execute([$row['employee_id']]);
    $deptId = $stmt->fetchColumn();
    if (!$deptId) return [];

    $start = $row['approved_start_date'] ?: $row['requested_start_date'];
    $end   = $row['approved_end_date'] ?: $row['requested_end_date'];

    $stmt = $pdo->prepare(
        "SELECT lr.*, u.name AS emp_name, u.department_id AS dept_id, d.name AS dept_name
           FROM leave_requests lr
           JOIN users u ON u.id = lr.employee_id
      LEFT JOIN departments d ON d.id = u.department_id
          WHERE u.department_id = ? AND lr.id <> ?
            AND lr.status IN ('aprobado', 'pendiente')
            AND COALESCE(lr.approved_start_date, lr.requested_start_date) <= ?
            AND COALESCE(lr.approved_end_date, lr.requested_end_date) >= ?
       ORDER BY COALESCE(lr.approved_start_date, lr.requested_start_date) ASC"
    );
    $stmt->execute([$deptId, $row['id'], $end, $start]);
    return array_map('leave_calendar_item', $stmt->fetchAll());
}
