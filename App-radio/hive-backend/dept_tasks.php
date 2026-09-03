<?php
// Flujo jerárquico de tareas por departamento/equipo (Radio Doliv).
//
//   Director  -> crea/edita/borra tareas de CUALQUIER departamento.
//   Manager   -> crea/edita/borra tareas y SUBTAREAS de SU departamento.
//   Empleado  -> SOLO cambia el estado de las tareas de su departamento
//                (marcar como completada / reabrir).
//
// Toda la autorización es autoritativa en el backend. Tabla `dept_tasks`
// (migración 008), paralela al sistema viejo `tasks`.
//
// Endpoints (registrados en index.php):
//   GET  /dept-tasks?departmentId=&status=&mine=1
//   POST /dept-tasks                       (director / manager)
//   POST /dept-tasks/{id}                  (editar — director / manager)
//   POST /dept-tasks/{id}/status           (director / manager / empleado)
//   POST /dept-tasks/{id}/delete           (director / manager)
//   POST /department/removeEmployee/{id}   (quitar empleado del departamento)

const DEPT_TASK_STATUSES = ['pendiente', 'en_progreso', 'completada'];
const DEPT_TASK_RECURRENCES = ['none', 'daily', 'weekdays', 'weekly', 'monthly'];

// Evidencia al completar (migración 010). Mismos límites que la evidencia de
// permisos (ver leave_requests.php).
const TASK_EVIDENCE_MAX_BYTES = 8 * 1024 * 1024; // 8 MB
const TASK_EVIDENCE_EXT = ['jpg', 'jpeg', 'png', 'webp', 'pdf'];
const TASK_EVIDENCE_MIME = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];

function dept_task_status_label(string $s): string {
    return [
        'pendiente'   => 'Pendiente',
        'en_progreso' => 'En progreso',
        'completada'  => 'Completada',
    ][$s] ?? $s;
}

function dept_task_review_label(string $s): string {
    return [
        'sin_revision'        => 'Sin revisión',
        'pendiente_revision'  => 'Por revisar',
        'aprobada'            => 'Aprobada',
        'rechazada'           => 'Rechazada',
    ][$s] ?? $s;
}

// Próxima fecha de una tarea recurrente a partir de la anterior (o de hoy si
// no tenía fecha). Devuelve 'Y-m-d'.
function dept_task_next_due(string $recurrence, ?string $from): string {
    $base = ($from && strtotime($from)) ? strtotime($from) : strtotime('today');
    switch ($recurrence) {
        case 'daily':
            return date('Y-m-d', strtotime('+1 day', $base));
        case 'weekly':
            return date('Y-m-d', strtotime('+7 days', $base));
        case 'monthly':
            return date('Y-m-d', strtotime('+1 month', $base));
        case 'weekdays':
            // "Días laborales" de Radio Doliv = lunes a sábado; solo se salta
            // el domingo (N == 7). Ver is_working_day() en helpers.php.
            $next = strtotime('+1 day', $base);
            while ((int) date('N', $next) === 7) {
                $next = strtotime('+1 day', $next);
            }
            return date('Y-m-d', $next);
        default:
            return date('Y-m-d', strtotime('+1 day', $base));
    }
}

function dept_task_fail(string $message, int $status = 409): void {
    json_response(['success' => false, 'message' => $message], $status);
}

// Departamento del usuario, o corta si no tiene uno (managers/empleados).
function dept_task_user_department(array $user): string {
    $dept = $user['department_id'] ?? null;
    if (!$dept) {
        dept_task_fail('Todavía no perteneces a ningún departamento.', 409);
    }
    return $dept;
}

// Resuelve el departamento objetivo según el rol:
//   director -> el que venga en la petición (o null = todos, para listar).
//   manager/empleado -> SIEMPRE el suyo; si piden otro distinto, se rechaza.
function dept_task_scope_department(array $user, ?string $requested): ?string {
    if ($user['role'] === 'director') {
        return ($requested !== null && $requested !== '') ? $requested : null;
    }
    $own = dept_task_user_department($user);
    if ($requested !== null && $requested !== '' && $requested !== $own) {
        error_response('Solo puedes gestionar tareas de tu propio departamento', 403);
    }
    return $own;
}

function dept_task_mini_user(PDO $pdo, ?string $userId): ?array {
    if (!$userId) return null;
    $stmt = $pdo->prepare('SELECT id, name, email, role FROM users WHERE id = ?');
    $stmt->execute([$userId]);
    $u = $stmt->fetch();
    return $u ? ['id' => $u['id'], 'name' => $u['name'], 'email' => $u['email'], 'role' => $u['role']] : null;
}

function dept_task_row(PDO $pdo, string $id): ?array {
    $stmt = $pdo->prepare('SELECT * FROM dept_tasks WHERE id = ?');
    $stmt->execute([$id]);
    return $stmt->fetch() ?: null;
}

function dept_task_payload(PDO $pdo, array $row): array {
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) AS total, SUM(status = 'completada') AS done
         FROM dept_tasks WHERE parent_id = ?"
    );
    $stmt->execute([$row['id']]);
    $sub = $stmt->fetch();

    return [
        'id'              => $row['id'],
        'parentId'        => $row['parent_id'],
        'departmentId'    => $row['department_id'],
        'title'           => $row['title'],
        'description'     => $row['description'],
        'status'          => $row['status'],
        'statusLabel'     => dept_task_status_label($row['status']),
        'assignedTo'      => dept_task_mini_user($pdo, $row['assigned_to']),
        'createdBy'       => dept_task_mini_user($pdo, $row['created_by']),
        'createdByRole'   => $row['created_by_role'],
        'dueDate'         => $row['due_date'],
        'completedBy'     => dept_task_mini_user($pdo, $row['completed_by']),
        'completedAt'     => $row['completed_at'],
        // Entregada fuera de plazo (migración 021). La tarea sigue
        // 'completada'; la app muestra una insignia "Retardo".
        'completedLate'   => (bool) ($row['completed_late'] ?? 0),
        'createdAt'       => $row['created_at'],
        'subtaskCount'    => (int) ($sub['total'] ?? 0),
        'subtaskDoneCount'=> (int) ($sub['done'] ?? 0),
        // Evidencia (010): nunca se expone la ruta interna, solo si la hay.
        'requiresEvidence'=> (bool) ($row['requires_evidence'] ?? 0),
        'hasEvidence'     => !empty($row['evidence_path']),
        // Revisión del manager (011).
        'reviewStatus'    => $row['review_status'] ?? 'sin_revision',
        'reviewStatusLabel'=> dept_task_review_label($row['review_status'] ?? 'sin_revision'),
        'reviewNote'      => $row['review_note'],
        'reviewedBy'      => dept_task_mini_user($pdo, $row['reviewed_by'] ?? null),
        'reviewedAt'      => $row['reviewed_at'] ?? null,
        // Recurrencia (012).
        'recurrence'      => $row['recurrence'] ?? 'none',
        'recurrenceUntil' => $row['recurrence_until'] ?? null,
    ];
}

// Sube y valida un archivo de evidencia de tarea. Devuelve
// ['path' => nombre_generado, 'mime' => tipo]. Corta la petición si algo no
// cuadra. Mismo patrón que leave_store_evidence() en leave_requests.php.
function task_store_evidence(array $file): array {
    if (($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
        dept_task_fail('No se pudo subir la evidencia. Inténtalo nuevamente.', 400);
    }
    if ($file['size'] <= 0 || $file['size'] > TASK_EVIDENCE_MAX_BYTES) {
        dept_task_fail('La evidencia supera el tamaño máximo permitido (8 MB).', 400);
    }
    $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    if (!in_array($ext, TASK_EVIDENCE_EXT, true)) {
        dept_task_fail('La evidencia debe ser una imagen (JPG, PNG o WEBP) o un PDF.', 400);
    }
    $mime = null;
    if (function_exists('finfo_open')) {
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mime = finfo_file($finfo, $file['tmp_name']) ?: null;
        finfo_close($finfo);
    }
    if ($mime !== null && !in_array($mime, TASK_EVIDENCE_MIME, true)) {
        dept_task_fail('El tipo de archivo de la evidencia no es válido.', 400);
    }
    if (in_array($ext, ['jpg', 'jpeg', 'png', 'webp'], true) && @getimagesize($file['tmp_name']) === false) {
        dept_task_fail('La imagen de evidencia está dañada o no es válida.', 400);
    }
    if ($mime === null) {
        $mime = $ext === 'pdf' ? 'application/pdf' : 'image/' . ($ext === 'jpg' ? 'jpeg' : $ext);
    }
    $stored = bin2hex(random_bytes(16)) . '.' . $ext;
    if (!move_uploaded_file($file['tmp_name'], TASK_EVIDENCE_DIR . $stored)) {
        dept_task_fail('No se pudo guardar la evidencia en el servidor.', 500);
    }
    return ['path' => $stored, 'mime' => $mime];
}

// Notifica a quien debe enterarse del avance de una tarea: el creador y, si
// existe, el manager del departamento (sin duplicar ni notificarse a sí mismo).
function dept_task_notify_progress(PDO $pdo, array $row, string $actorId, string $message): void {
    $targets = [];
    if ($row['created_by'] && $row['created_by'] !== $actorId) {
        $targets[] = $row['created_by'];
    }
    $stmt = $pdo->prepare('SELECT manager_email FROM departments WHERE id = ?');
    $stmt->execute([$row['department_id']]);
    $managerEmail = $stmt->fetchColumn();

    $emails = [];
    foreach ($targets as $uid) {
        $s = $pdo->prepare('SELECT email FROM users WHERE id = ?');
        $s->execute([$uid]);
        $e = $s->fetchColumn();
        if ($e) $emails[strtolower($e)] = $e;
    }
    if ($managerEmail) $emails[strtolower($managerEmail)] = $managerEmail;

    // No notificar al propio actor.
    $s = $pdo->prepare('SELECT email FROM users WHERE id = ?');
    $s->execute([$actorId]);
    $actorEmail = strtolower((string) $s->fetchColumn());
    unset($emails[$actorEmail]);

    foreach ($emails as $email) {
        notify_user($pdo, $email, null, 'dept_task', $message);
    }
}

// Clona la siguiente ocurrencia de una tarea recurrente ya cerrada, si sigue
// dentro de recurrence_until. Solo para tareas de nivel superior.
function dept_task_spawn_next(PDO $pdo, array $row): void {
    $recurrence = $row['recurrence'] ?? 'none';
    if ($recurrence === 'none' || $row['parent_id'] !== null) {
        return;
    }
    $next = dept_task_next_due($recurrence, $row['due_date']);
    if (!empty($row['recurrence_until']) && $next > $row['recurrence_until']) {
        return;
    }
    $id = generate_id();
    $stmt = $pdo->prepare(
        'INSERT INTO dept_tasks
           (id, parent_id, department_id, title, description, assigned_to,
            created_by, created_by_role, due_date, requires_evidence,
            recurrence, recurrence_until)
         VALUES (?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $id, $row['department_id'], $row['title'], $row['description'],
        $row['assigned_to'], $row['created_by'], $row['created_by_role'],
        $next, (int) ($row['requires_evidence'] ?? 0),
        $recurrence, $row['recurrence_until'] ?: null,
    ]);
    if (!empty($row['assigned_to'])) {
        $stmt = $pdo->prepare('SELECT email FROM users WHERE id = ?');
        $stmt->execute([$row['assigned_to']]);
        $email = $stmt->fetchColumn();
        if ($email) {
            notify_user($pdo, $email, null, 'task_assigned',
                'Nueva tarea recurrente: "' . $row['title'] . '" (vence ' . $next . ')');
        }
    }
}

// Comprueba que el usuario puede ADMINISTRAR (crear/editar/borrar) tareas de
// este departamento: director siempre; manager solo el suyo.
function dept_task_require_admin(PDO $pdo, array $user, string $departmentId): void {
    $stmt = $pdo->prepare('SELECT id FROM departments WHERE id = ?');
    $stmt->execute([$departmentId]);
    if (!$stmt->fetch()) {
        error_response('Departamento no encontrado', 404);
    }
    require_department_manager_or_director($pdo, $user, $departmentId);
}

// Comprueba que el usuario puede VER las tareas de este departamento:
// director; o cualquier manager/empleado de ese mismo departamento.
function dept_task_require_view(array $user, string $departmentId): void {
    if ($user['role'] === 'director') return;
    if (($user['department_id'] ?? null) === $departmentId) return;
    error_response('No tienes acceso a las tareas de este departamento', 403);
}

// ---- GET /dept-tasks/summary -------------------------------------
// Conteos por estado para las gráficas de progreso. `mine` = tareas
// asignadas al usuario; `department` = todas las de su departamento (para
// manager/empleado; el director sin departamento no lo tiene).

function dept_task_counts_payload(array $c): array {
    $done = $c['completada'];
    $pending = $c['pendiente'] + $c['en_progreso'];
    return [
        'pendiente'  => $c['pendiente'],
        'enProgreso' => $c['en_progreso'],
        'completada' => $done,
        'pendientes' => $pending,        // pendiente + en_progreso (gráfica de 2 estados)
        'total'      => $pending + $done,
    ];
}

// $column siempre viene de una llamada fija en este archivo
// ('assigned_to' | 'department_id'), nunca de entrada del cliente.
function dept_task_count_by_status(PDO $pdo, string $column, string $value): array {
    $stmt = $pdo->prepare(
        "SELECT status, COUNT(*) n FROM dept_tasks WHERE `$column` = ? GROUP BY status"
    );
    $stmt->execute([$value]);
    $c = ['pendiente' => 0, 'en_progreso' => 0, 'completada' => 0];
    foreach ($stmt->fetchAll() as $r) {
        $c[$r['status']] = (int) $r['n'];
    }
    return dept_task_counts_payload($c);
}

function deptTasksSummary(PDO $pdo) {
    $user = require_auth($pdo);
    json_response([
        'success'    => true,
        'mine'       => dept_task_count_by_status($pdo, 'assigned_to', $user['id']),
        'department' => !empty($user['department_id'])
            ? dept_task_count_by_status($pdo, 'department_id', $user['department_id'])
            : null,
    ]);
}

// ---- GET /dept-tasks/summary/by-department ----------------------
// Conteos de tareas por estado agrupados por CADA departamento de la
// empresa, mas los totales. Solo el director: le da control del avance
// de todas las areas, no solo la propia (para el manager/empleado ya
// esta /dept-tasks/summary, acotado a su departamento).
//
// Una sola consulta con LEFT JOIN + GROUP BY para no hacer N+1: los
// departamentos sin ninguna tarea salen igual, con los tres contadores
// en 0. Los SUM(condicion) se apoyan en que MySQL evalua un booleano
// como 1/0.

function deptTasksSummaryByDepartment(PDO $pdo) {
    $user = require_auth($pdo);
    require_role($user, ['director']);

    $stmt = $pdo->query(
        "SELECT d.id, d.name,
                COALESCE(SUM(t.status = 'pendiente'), 0)   AS pendiente,
                COALESCE(SUM(t.status = 'en_progreso'), 0) AS en_progreso,
                COALESCE(SUM(t.status = 'completada'), 0)  AS completada
         FROM departments d
         LEFT JOIN dept_tasks t ON t.department_id = d.id
         GROUP BY d.id, d.name
         ORDER BY d.name ASC"
    );

    $departments = [];
    $totals = ['pendiente' => 0, 'en_progreso' => 0, 'completada' => 0];
    foreach ($stmt->fetchAll() as $r) {
        $raw = [
            'pendiente'   => (int) $r['pendiente'],
            'en_progreso' => (int) $r['en_progreso'],
            'completada'  => (int) $r['completada'],
        ];
        foreach ($totals as $k => $_) {
            $totals[$k] += $raw[$k];
        }
        $departments[] = [
            'departmentId'   => $r['id'],
            'departmentName' => $r['name'],
        ] + dept_task_counts_payload($raw);
    }

    json_response([
        'success'     => true,
        'departments' => $departments,
        'totals'      => dept_task_counts_payload($totals),
    ]);
}

// ---- GET /dept-tasks -----------------------------------------------

function deptTasksList(PDO $pdo) {
    $user = require_auth($pdo);

    $departmentId = dept_task_scope_department($user, $_GET['departmentId'] ?? null);

    $where = [];
    $params = [];
    if ($departmentId !== null) {
        dept_task_require_view($user, $departmentId);
        $where[] = 'department_id = ?';
        $params[] = $departmentId;
    }
    $status = $_GET['status'] ?? '';
    if (in_array($status, DEPT_TASK_STATUSES, true)) {
        $where[] = 'status = ?';
        $params[] = $status;
    }
    // ?mine=1 -> solo las asignadas a mí (útil para el empleado).
    if (($_GET['mine'] ?? '') === '1') {
        $where[] = 'assigned_to = ?';
        $params[] = $user['id'];
    }

    $sql = 'SELECT * FROM dept_tasks';
    if ($where) $sql .= ' WHERE ' . implode(' AND ', $where);
    $sql .= " ORDER BY (parent_id IS NOT NULL), COALESCE(parent_id, id), "
          . "FIELD(status,'pendiente','en_progreso','completada'), created_at ASC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $tasks = array_map(fn($r) => dept_task_payload($pdo, $r), $stmt->fetchAll());

    json_response(['success' => true, 'tasks' => $tasks]);
}

// ---- POST /dept-tasks --------------------------------------------

function deptTaskCreate(PDO $pdo) {
    $user = require_auth($pdo);
    require_role($user, ['director', 'manager']);

    $body = request_body();
    $departmentId = dept_task_scope_department($user, $body['departmentId'] ?? null);
    if ($departmentId === null) {
        dept_task_fail('Indica el departamento de la tarea.', 400);
    }
    dept_task_require_admin($pdo, $user, $departmentId);

    $title = trim($body['title'] ?? '');
    if ($title === '') {
        dept_task_fail('El título de la tarea es obligatorio.', 400);
    }
    $description = trim($body['description'] ?? '');
    $dueDate = trim($body['dueDate'] ?? '');
    $dueDate = $dueDate !== '' && strtotime($dueDate) ? date('Y-m-d', strtotime($dueDate)) : null;

    // Subtarea: el padre debe existir y ser del mismo departamento.
    $parentId = trim($body['parentId'] ?? '') ?: null;
    if ($parentId !== null) {
        $parent = dept_task_row($pdo, $parentId);
        if (!$parent || $parent['department_id'] !== $departmentId) {
            dept_task_fail('La tarea principal no es válida.', 400);
        }
        if ($parent['parent_id'] !== null) {
            dept_task_fail('No se pueden crear subtareas de una subtarea.', 400);
        }
    }

    // Empleado asignado (opcional): debe pertenecer a ese departamento.
    $assignedTo = trim($body['assignedTo'] ?? '') ?: null;
    if ($assignedTo !== null) {
        $stmt = $pdo->prepare("SELECT id FROM users WHERE id = ? AND department_id = ? AND role = 'employee'");
        $stmt->execute([$assignedTo, $departmentId]);
        if (!$stmt->fetch()) {
            dept_task_fail('El empleado asignado no pertenece a este departamento.', 400);
        }
    }

    $requiresEvidence = !empty($body['requiresEvidence']) && $body['requiresEvidence'] !== '0' ? 1 : 0;

    // Recurrencia (012): solo tareas de nivel superior.
    $recurrence = trim($body['recurrence'] ?? 'none');
    if (!in_array($recurrence, DEPT_TASK_RECURRENCES, true)) $recurrence = 'none';
    if ($parentId !== null) $recurrence = 'none';
    $recurrenceUntil = trim($body['recurrenceUntil'] ?? '');
    $recurrenceUntil = ($recurrence !== 'none' && $recurrenceUntil !== '' && strtotime($recurrenceUntil))
        ? date('Y-m-d', strtotime($recurrenceUntil)) : null;

    $id = generate_id();
    $stmt = $pdo->prepare(
        'INSERT INTO dept_tasks
           (id, parent_id, department_id, title, description, assigned_to, created_by,
            created_by_role, due_date, requires_evidence, recurrence, recurrence_until)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $id, $parentId, $departmentId, $title,
        $description !== '' ? $description : null,
        $assignedTo, $user['id'], $user['role'], $dueDate,
        $requiresEvidence, $recurrence, $recurrenceUntil,
    ]);

    if ($assignedTo !== null) {
        $stmt = $pdo->prepare('SELECT email FROM users WHERE id = ?');
        $stmt->execute([$assignedTo]);
        $email = $stmt->fetchColumn();
        if ($email) {
            notify_user($pdo, $email, null, 'task_assigned',
                'Se te asignó una nueva tarea: "' . $title . '"');
        }
    }

    json_response([
        'success' => true,
        'message' => $parentId ? 'Subtarea creada.' : 'Tarea creada.',
        'task'    => dept_task_payload($pdo, dept_task_row($pdo, $id)),
    ]);
}

// ---- POST /dept-tasks/{id} (editar) ----------------------------

function deptTaskUpdate(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    require_role($user, ['director', 'manager']);

    $row = dept_task_row($pdo, $id);
    if (!$row) error_response('Tarea no encontrada', 404);
    dept_task_require_admin($pdo, $user, $row['department_id']);

    $body = request_body();
    $title = array_key_exists('title', $body) ? trim($body['title']) : $row['title'];
    if ($title === '') {
        dept_task_fail('El título de la tarea es obligatorio.', 400);
    }
    $description = array_key_exists('description', $body)
        ? (trim($body['description']) ?: null) : $row['description'];

    $dueDate = $row['due_date'];
    if (array_key_exists('dueDate', $body)) {
        $d = trim($body['dueDate']);
        $dueDate = $d !== '' && strtotime($d) ? date('Y-m-d', strtotime($d)) : null;
    }

    $assignedTo = $row['assigned_to'];
    if (array_key_exists('assignedTo', $body)) {
        $assignedTo = trim($body['assignedTo']) ?: null;
        if ($assignedTo !== null) {
            $stmt = $pdo->prepare("SELECT id FROM users WHERE id = ? AND department_id = ? AND role = 'employee'");
            $stmt->execute([$assignedTo, $row['department_id']]);
            if (!$stmt->fetch()) {
                dept_task_fail('El empleado asignado no pertenece a este departamento.', 400);
            }
        }
    }

    $requiresEvidence = array_key_exists('requiresEvidence', $body)
        ? (!empty($body['requiresEvidence']) && $body['requiresEvidence'] !== '0' ? 1 : 0)
        : (int) ($row['requires_evidence'] ?? 0);

    $recurrence = $row['recurrence'] ?? 'none';
    $recurrenceUntil = $row['recurrence_until'] ?? null;
    if (array_key_exists('recurrence', $body) && $row['parent_id'] === null) {
        $recurrence = trim($body['recurrence']);
        if (!in_array($recurrence, DEPT_TASK_RECURRENCES, true)) $recurrence = 'none';
        $u = trim($body['recurrenceUntil'] ?? '');
        $recurrenceUntil = ($recurrence !== 'none' && $u !== '' && strtotime($u))
            ? date('Y-m-d', strtotime($u)) : null;
    }

    $stmt = $pdo->prepare(
        'UPDATE dept_tasks SET title = ?, description = ?, assigned_to = ?, due_date = ?,
           requires_evidence = ?, recurrence = ?, recurrence_until = ? WHERE id = ?'
    );
    $stmt->execute([$title, $description, $assignedTo, $dueDate,
        $requiresEvidence, $recurrence, $recurrenceUntil, $id]);

    json_response([
        'success' => true,
        'message' => 'Tarea actualizada.',
        'task'    => dept_task_payload($pdo, dept_task_row($pdo, $id)),
    ]);
}

// ---- POST /dept-tasks/{id}/status -----------------------------

function deptTaskSetStatus(PDO $pdo, string $id) {
    $user = require_auth($pdo);

    $row = dept_task_row($pdo, $id);
    if (!$row) error_response('Tarea no encontrada', 404);

    // Ver la tarea: director; o manager/empleado del mismo departamento.
    dept_task_require_view($user, $row['department_id']);

    // El empleado SOLO puede tocar el estado de una tarea asignada a él.
    // (una tarea sin responsable, o de otra persona, no la puede completar).
    if ($user['role'] === 'employee' && $row['assigned_to'] !== $user['id']) {
        dept_task_fail('Solo puedes completar tareas asignadas a ti.', 403);
    }

    // Puede llegar como multipart/form-data (con archivo de evidencia) o como
    // JSON/urlencoded normal.
    $body = !empty($_POST) ? $_POST : request_body();
    $status = trim($body['status'] ?? '');
    if (!in_array($status, DEPT_TASK_STATUSES, true)) {
        dept_task_fail('Estado inválido.', 400);
    }

    if ($status !== 'completada') {
        // Reabrir / mover a en_progreso: limpia el cierre y la revisión.
        $stmt = $pdo->prepare(
            "UPDATE dept_tasks SET status = ?, completed_by = NULL, completed_at = NULL,
               completed_late = 0,
               review_status = 'sin_revision', review_note = NULL,
               reviewed_by = NULL, reviewed_at = NULL
             WHERE id = ?"
        );
        $stmt->execute([$status, $id]);
        json_response([
            'success' => true,
            'message' => 'Estado actualizado.',
            'task'    => dept_task_payload($pdo, dept_task_row($pdo, $id)),
        ]);
        return;
    }

    // ---- status === 'completada' ----
    // Comprobación previa para el doble toque normal: si ya está completada, no
    // se procesa el archivo ni se vuelve a notificar / generar la recurrencia.
    if ($row['status'] === 'completada') {
        dept_task_fail('Esta tarea ya está marcada como completada.', 409);
    }

    $hasFile = !empty($_FILES['evidence']) && $_FILES['evidence']['error'] !== UPLOAD_ERR_NO_FILE;
    if (!empty($row['requires_evidence']) && !$hasFile && empty($row['evidence_path'])) {
        dept_task_fail('Esta tarea requiere adjuntar evidencia para marcarse como completada.', 400);
    }
    $evidencePath = $row['evidence_path'];
    $evidenceMime = $row['evidence_mime'];
    if ($hasFile) {
        $stored = task_store_evidence($_FILES['evidence']);
        $evidencePath = $stored['path'];
        $evidenceMime = $stored['mime'];
    }

    // Un empleado NO cierra la tarea: queda pendiente de revisión del manager.
    $reviewStatus = $user['role'] === 'employee' ? 'pendiente_revision' : 'sin_revision';

    // Transición atómica: solo la aplica quien encuentra la tarea aún sin
    // completar. Con dos peticiones simultáneas (o un doble toque que esquiva
    // la comprobación previa) una gana y la otra recibe rowCount()===0, así no
    // se dispara dos veces dept_task_spawn_next() / la notificación ni se
    // pisan evidencias.
    // `completed_late` lo decide el servidor: 1 si se cierra pasada la fecha
    // límite (due_date es una fecha; el plazo vence al final de ese día).
    // Nunca se toma un valor del cliente.
    $stmt = $pdo->prepare(
        "UPDATE dept_tasks
            SET status = 'completada', completed_by = ?, completed_at = NOW(),
                completed_late = (due_date IS NOT NULL AND NOW() > CONCAT(due_date, ' 23:59:59')),
                evidence_path = ?, evidence_mime = ?, review_status = ?,
                review_note = NULL, reviewed_by = NULL, reviewed_at = NULL
          WHERE id = ? AND status <> 'completada'"
    );
    $stmt->execute([$user['id'], $evidencePath, $evidenceMime, $reviewStatus, $id]);

    if ($stmt->rowCount() === 0) {
        // Otra petición simultánea ya la completó: limpia la evidencia recién
        // subida por esta y responde de forma idempotente.
        if ($hasFile && !empty($stored['path'])) {
            @unlink(TASK_EVIDENCE_DIR . basename($stored['path']));
        }
        dept_task_fail('Esta tarea ya está marcada como completada.', 409);
    }

    $fresh = dept_task_row($pdo, $id);
    if ($reviewStatus === 'pendiente_revision') {
        dept_task_notify_progress($pdo, $row, $user['id'],
            $user['name'] . ' completó la tarea "' . $row['title'] . '" y está pendiente de tu revisión.');
        $message = 'Tarea enviada para revisión.';
    } else {
        // Manager/director la cierra directamente: si es recurrente, ya se
        // genera la siguiente ocurrencia.
        dept_task_spawn_next($pdo, $fresh);
        $message = 'Tarea marcada como completada.';
    }

    json_response([
        'success' => true,
        'message' => $message,
        'task'    => dept_task_payload($pdo, dept_task_row($pdo, $id)),
    ]);
}

// ---- POST /dept-tasks/{id}/review ----------------------------
// El director o el manager del departamento aprueba o rechaza una tarea que
// un empleado marcó como completada.

function deptTaskReview(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    require_role($user, ['director', 'manager']);

    $row = dept_task_row($pdo, $id);
    if (!$row) error_response('Tarea no encontrada', 404);
    dept_task_require_admin($pdo, $user, $row['department_id']);

    if (($row['review_status'] ?? 'sin_revision') !== 'pendiente_revision') {
        dept_task_fail('Esta tarea no está pendiente de revisión.', 409);
    }

    $body = request_body();
    $decision = trim($body['decision'] ?? '');
    $note = trim($body['note'] ?? '');
    if (!in_array($decision, ['approve', 'reject'], true)) {
        dept_task_fail('Decisión inválida.', 400);
    }

    if ($decision === 'approve') {
        $stmt = $pdo->prepare(
            "UPDATE dept_tasks SET review_status = 'aprobada', review_note = ?,
               reviewed_by = ?, reviewed_at = NOW() WHERE id = ?"
        );
        $stmt->execute([$note !== '' ? $note : null, $user['id'], $id]);
        dept_task_spawn_next($pdo, dept_task_row($pdo, $id));
        if ($row['assigned_to']) {
            $s = $pdo->prepare('SELECT email FROM users WHERE id = ?');
            $s->execute([$row['assigned_to']]);
            $email = $s->fetchColumn();
            if ($email) {
                notify_user($pdo, $email, null, 'dept_task',
                    'Tu tarea "' . $row['title'] . '" fue aprobada.');
            }
        }
        $message = 'Tarea aprobada.';
    } else {
        if ($note === '') {
            dept_task_fail('Indica el motivo del rechazo.', 400);
        }
        $stmt = $pdo->prepare(
            "UPDATE dept_tasks SET status = 'en_progreso', review_status = 'rechazada',
               review_note = ?, reviewed_by = ?, reviewed_at = NOW(),
               completed_by = NULL, completed_at = NULL WHERE id = ?"
        );
        $stmt->execute([$note, $user['id'], $id]);
        if ($row['assigned_to']) {
            $s = $pdo->prepare('SELECT email FROM users WHERE id = ?');
            $s->execute([$row['assigned_to']]);
            $email = $s->fetchColumn();
            if ($email) {
                notify_user($pdo, $email, null, 'dept_task',
                    'Tu tarea "' . $row['title'] . '" fue devuelta: ' . $note);
            }
        }
        $message = 'Tarea devuelta al empleado.';
    }

    json_response([
        'success' => true,
        'message' => $message,
        'task'    => dept_task_payload($pdo, dept_task_row($pdo, $id)),
    ]);
}

// ---- GET /dept-tasks/{id}/evidence --------------------------
// Sirve el archivo privado de evidencia. Autorizado para director, el
// manager del departamento y el empleado asignado a la tarea.

function deptTaskEvidence(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    $row = dept_task_row($pdo, $id);
    if (!$row) error_response('No se pudo cargar la evidencia.', 404);

    dept_task_require_view($user, $row['department_id']);
    $canManage = $user['role'] === 'director'
        || ($user['role'] === 'manager' && ($user['department_id'] ?? null) === $row['department_id']);
    if (!$canManage && $row['assigned_to'] !== $user['id']) {
        error_response('No tienes permiso para ver esta evidencia.', 403);
    }
    if (empty($row['evidence_path'])) {
        error_response('Esta tarea no tiene evidencia adjunta.', 404);
    }
    $file = TASK_EVIDENCE_DIR . basename($row['evidence_path']);
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

// ---- GET/POST /dept-tasks/{id}/comments --------------------
// Hilo de comentarios. Leen todos los que pueden ver la tarea; escriben el
// director, el manager del departamento y el empleado asignado.

function dept_task_comment_payload(PDO $pdo, array $row): array {
    return [
        'id'        => $row['id'],
        'body'      => $row['body'],
        'createdAt' => $row['created_at'],
        'author'    => dept_task_mini_user($pdo, $row['author_id']),
    ];
}

function deptTaskComments(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    $row = dept_task_row($pdo, $id);
    if (!$row) error_response('Tarea no encontrada', 404);
    dept_task_require_view($user, $row['department_id']);

    $stmt = $pdo->prepare(
        'SELECT * FROM dept_task_comments WHERE task_id = ? ORDER BY created_at ASC'
    );
    $stmt->execute([$id]);
    $comments = array_map(fn($r) => dept_task_comment_payload($pdo, $r), $stmt->fetchAll());
    json_response(['success' => true, 'comments' => $comments]);
}

function deptTaskCommentCreate(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    $row = dept_task_row($pdo, $id);
    if (!$row) error_response('Tarea no encontrada', 404);
    dept_task_require_view($user, $row['department_id']);

    $canManage = $user['role'] === 'director'
        || ($user['role'] === 'manager' && ($user['department_id'] ?? null) === $row['department_id']);
    if (!$canManage && $row['assigned_to'] !== $user['id']) {
        dept_task_fail('Solo el manager o el empleado asignado pueden comentar esta tarea.', 403);
    }

    $body = request_body();
    $text = trim($body['body'] ?? '');
    if ($text === '') {
        dept_task_fail('El comentario no puede estar vacío.', 400);
    }
    if (mb_strlen($text) > 2000) {
        dept_task_fail('El comentario es demasiado largo (máx. 2000 caracteres).', 400);
    }

    $commentId = generate_id();
    $stmt = $pdo->prepare(
        'INSERT INTO dept_task_comments (id, task_id, author_id, body) VALUES (?, ?, ?, ?)'
    );
    $stmt->execute([$commentId, $id, $user['id'], $text]);

    // Notifica a la otra parte (creador/manager <-> empleado asignado).
    dept_task_notify_progress($pdo, $row, $user['id'],
        $user['name'] . ' comentó en la tarea "' . $row['title'] . '".');
    if ($row['assigned_to'] && $row['assigned_to'] !== $user['id']) {
        $s = $pdo->prepare('SELECT email FROM users WHERE id = ?');
        $s->execute([$row['assigned_to']]);
        $email = $s->fetchColumn();
        if ($email) {
            notify_user($pdo, $email, null, 'dept_task',
                $user['name'] . ' comentó en tu tarea "' . $row['title'] . '".');
        }
    }

    $stmt = $pdo->prepare('SELECT * FROM dept_task_comments WHERE id = ?');
    $stmt->execute([$commentId]);
    json_response([
        'success' => true,
        'comment' => dept_task_comment_payload($pdo, $stmt->fetch()),
    ]);
}

// ---- POST /dept-tasks/{id}/delete ----------------------------

function deptTaskDelete(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    require_role($user, ['director', 'manager']);

    $row = dept_task_row($pdo, $id);
    if (!$row) error_response('Tarea no encontrada', 404);
    dept_task_require_admin($pdo, $user, $row['department_id']);

    // La FK ON DELETE CASCADE se lleva las subtareas.
    $stmt = $pdo->prepare('DELETE FROM dept_tasks WHERE id = ?');
    $stmt->execute([$id]);

    json_response(['success' => true, 'message' => 'Tarea eliminada.']);
}

// ---- POST /department/removeEmployee/{deptId} -----------------
// Quita a un empleado de un departamento (director, o el manager de ese
// departamento). No borra al usuario: solo limpia department_id/position.

function removeDepartmentEmployee(PDO $pdo, string $departmentId) {
    $user = require_auth($pdo);

    $stmt = $pdo->prepare('SELECT * FROM departments WHERE id = ?');
    $stmt->execute([$departmentId]);
    $dept = $stmt->fetch();
    if (!$dept) {
        error_response('Departamento no encontrado', 404);
    }
    require_department_manager_or_director($pdo, $user, $departmentId);

    $body = request_body();
    $email = trim($body['email'] ?? '');
    if ($email === '') {
        error_response('email es requerido', 400);
    }

    $stmt = $pdo->prepare('SELECT * FROM users WHERE email = ?');
    $stmt->execute([$email]);
    $target = $stmt->fetch();
    if (!$target || $target['department_id'] !== $departmentId) {
        error_response('Ese empleado no pertenece a este departamento', 404);
    }
    if ($target['role'] !== 'employee') {
        error_response('Solo se puede quitar a un empleado por esta vía', 400);
    }

    $stmt = $pdo->prepare('UPDATE users SET department_id = NULL, position = NULL WHERE id = ?');
    $stmt->execute([$target['id']]);
    // Las tareas que tenía asignadas quedan sin responsable (FK SET NULL).
    $stmt = $pdo->prepare('UPDATE dept_tasks SET assigned_to = NULL WHERE assigned_to = ? AND department_id = ?');
    $stmt->execute([$target['id'], $departmentId]);

    notify_user($pdo, $email, null, 'department_removed',
        'Fuiste removido del departamento "' . $dept['name'] . '"');

    json_response(['success' => true, 'message' => 'Empleado removido del departamento.']);
}
