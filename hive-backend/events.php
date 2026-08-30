<?php
// Eventos del calendario y feed combinado calendario (Radio Doliv).
//
// El DIRECTOR crea/edita/borra eventos. Cualquier usuario autenticado consulta
// los eventos que le corresponden y su feed de calendario (actividades + eventos).
//
// Visibilidad de un evento:
//   - scope='general'            -> lo ve toda la empresa.
//   - scope='areas'              -> lo ven los miembros de los departamentos en
//                                   event_areas (y, por tener department_id,
//                                   también sus managers). El director ve todos.
//
// Ubicación (has_location=1): el evento lleva lat/lng + radio + hora de entrada
// y SOLO tiene sentido con scope='areas'. Ese día, para los miembros de esas
// áreas, la ENTRADA de asistencia se valida contra la ubicación del evento y su
// hora congela el horario del día (ver event_entry_override_for_day, usado por
// attendance.php). La salida y la hora de comida NO cambian. Las áreas no
// incluidas no se enteran (sin notificación) y su asistencia sigue igual.
//
// Endpoints (registrados en index.php):
//   GET  /events?from=&to=
//   POST /events                 (crear — solo director)
//   POST /events/{id}            (editar — solo director)
//   POST /events/{id}/delete     (borrar — solo director)
//   GET  /calendar?from=&to=&scope=&departmentId=

// ---- helpers -------------------------------------------------------

// Rango [from, to] del feed. Por defecto, el mes en curso (± para cubrir la
// vista de mes del cliente, que puede mostrar días de meses vecinos).
function events_range(): array {
    $from = isset($_GET['from']) && $_GET['from'] !== ''
        ? date('Y-m-d', strtotime($_GET['from'])) : date('Y-m-01', strtotime('-1 day'));
    $to = isset($_GET['to']) && $_GET['to'] !== ''
        ? date('Y-m-d', strtotime($_GET['to'])) : date('Y-m-t', strtotime('+1 month'));
    if ($from > $to) [$from, $to] = [$to, $from];
    return [$from, $to];
}

function events_valid_time(?string $value): ?string {
    $value = trim((string) $value);
    if ($value === '') return null;
    if (preg_match('/^([01]\d|2[0-3]):([0-5]\d)$/', $value)) {
        return $value . ':00';
    }
    return null;
}

// Departamentos (ids) asignados a un evento.
function event_area_ids(PDO $pdo, string $eventId): array {
    $stmt = $pdo->prepare('SELECT department_id FROM event_areas WHERE event_id = ?');
    $stmt->execute([$eventId]);
    return array_column($stmt->fetchAll(), 'department_id');
}

// Forma de un evento para el cliente. `areas` = [{id,name}] de los
// departamentos asignados (vacío para scope='general').
function event_payload(PDO $pdo, array $e): array {
    $areas = [];
    if ($e['scope'] === 'areas') {
        $stmt = $pdo->prepare(
            'SELECT d.id, d.name FROM event_areas ea
             JOIN departments d ON d.id = ea.department_id
             WHERE ea.event_id = ? ORDER BY d.name ASC'
        );
        $stmt->execute([$e['id']]);
        $areas = $stmt->fetchAll();
    }
    return [
        'id'            => $e['id'],
        'title'         => $e['title'],
        'description'   => $e['description'],
        'date'          => $e['event_date'],
        'startTime'     => $e['start_time'] ? substr($e['start_time'], 0, 5) : null,
        'endTime'       => $e['end_time'] ? substr($e['end_time'], 0, 5) : null,
        'scope'         => $e['scope'],
        'hasLocation'   => (bool) $e['has_location'],
        'latitude'      => $e['latitude'] !== null ? (float) $e['latitude'] : null,
        'longitude'     => $e['longitude'] !== null ? (float) $e['longitude'] : null,
        'radiusM'       => $e['radius_m'] !== null ? (int) $e['radius_m'] : null,
        'locationLabel' => $e['location_label'],
        'entryTime'     => $e['entry_time'] ? substr($e['entry_time'], 0, 5) : null,
        'areas'         => array_map(fn($a) => ['id' => $a['id'], 'name' => $a['name']], $areas),
    ];
}

// Eventos visibles para $user en el rango [$from,$to].
function events_visible_for(PDO $pdo, array $user, string $from, string $to): array {
    $params = [$from, $to];
    $visClause = "e.scope = 'general'";
    if ($user['role'] === 'director') {
        $visClause = '1'; // el director ve todos
    } elseif (!empty($user['department_id'])) {
        $visClause .= ' OR EXISTS (SELECT 1 FROM event_areas ea
                        WHERE ea.event_id = e.id AND ea.department_id = ?)';
        $params[] = $user['department_id'];
    }
    $stmt = $pdo->prepare(
        "SELECT e.* FROM events e
         WHERE e.event_date BETWEEN ? AND ? AND ($visClause)
         ORDER BY e.event_date ASC, e.start_time ASC, e.id ASC"
    );
    $stmt->execute($params);
    return array_map(fn($e) => event_payload($pdo, $e), $stmt->fetchAll());
}

// Override de ENTRADA para un departamento en un día concreto, o null.
// Lo consume attendance.php (attendanceEntry / attendanceToday). Se elige el
// evento con ubicación más reciente si hubiera varios ese día para el área.
function event_entry_override_for_day(PDO $pdo, ?string $departmentId, string $workDate): ?array {
    if (empty($departmentId)) return null;
    $stmt = $pdo->prepare(
        "SELECT e.id, e.title, e.latitude, e.longitude, e.radius_m, e.location_label, e.entry_time
         FROM events e
         JOIN event_areas ea ON ea.event_id = e.id
         WHERE e.has_location = 1 AND e.event_date = ? AND ea.department_id = ?
           AND e.latitude IS NOT NULL AND e.longitude IS NOT NULL
         ORDER BY e.created_at DESC, e.id DESC
         LIMIT 1"
    );
    $stmt->execute([$workDate, $departmentId]);
    $row = $stmt->fetch();
    return $row ?: null;
}

// Payload del override para el cliente (pantalla "Mi asistencia").
function event_entry_override_payload(?array $row): ?array {
    if (!$row) return null;
    return [
        'title'     => $row['title'],
        'entryTime' => $row['entry_time'] ? substr($row['entry_time'], 0, 5) : null,
        'location'  => [
            'latitude'  => (float) $row['latitude'],
            'longitude' => (float) $row['longitude'],
            'radiusM'   => $row['radius_m'] !== null ? (int) $row['radius_m'] : 50,
            'label'     => $row['location_label'],
        ],
    ];
}

// ---- endpoints: eventos -----------------------------------------

function eventsList(PDO $pdo) {
    $user = require_auth($pdo);
    [$from, $to] = events_range();
    json_response([
        'success' => true,
        'from'    => $from,
        'to'      => $to,
        'events'  => events_visible_for($pdo, $user, $from, $to),
        'canManage' => $user['role'] === 'director',
    ]);
}

// Valida y normaliza el cuerpo de crear/editar un evento. Corta con 4xx.
function event_body_or_fail(PDO $pdo): array {
    $body = request_body();
    $title = trim((string) ($body['title'] ?? ''));
    $date  = trim((string) ($body['date'] ?? $body['event_date'] ?? ''));
    if ($title === '' || $date === '') {
        error_response('El título y la fecha del evento son obligatorios.', 400);
    }
    $eventDate = date('Y-m-d', strtotime($date));

    $scope = ($body['scope'] ?? 'general') === 'areas' ? 'areas' : 'general';
    $startTime = events_valid_time($body['startTime'] ?? null);
    $endTime   = events_valid_time($body['endTime'] ?? null);

    // Áreas: acepta lista JSON o CSV. Se validan contra departments.
    $rawAreas = $body['areas'] ?? [];
    if (is_string($rawAreas)) {
        $rawAreas = array_filter(array_map('trim', explode(',', $rawAreas)));
    }
    $areaIds = [];
    if (is_array($rawAreas) && $rawAreas) {
        $in = implode(',', array_fill(0, count($rawAreas), '?'));
        $stmt = $pdo->prepare("SELECT id FROM departments WHERE id IN ($in)");
        $stmt->execute(array_values($rawAreas));
        $areaIds = array_column($stmt->fetchAll(), 'id');
    }

    if ($scope === 'areas' && !$areaIds) {
        error_response('Un evento por áreas necesita al menos un departamento válido.', 400);
    }

    $hasLocation = !empty($body['hasLocation']) && $body['hasLocation'] !== 'false' && $body['hasLocation'] !== '0';
    $lat = $lng = $radius = $entryTime = null;
    $label = trim((string) ($body['locationLabel'] ?? '')) ?: null;

    if ($hasLocation) {
        if ($scope !== 'areas' || !$areaIds) {
            error_response('Un evento con ubicación debe especificar las áreas que asistirán.', 400);
        }
        $lat = isset($body['latitude']) && $body['latitude'] !== '' ? (float) $body['latitude'] : null;
        $lng = isset($body['longitude']) && $body['longitude'] !== '' ? (float) $body['longitude'] : null;
        if ($lat === null || $lng === null || $lat < -90 || $lat > 90 || $lng < -180 || $lng > 180) {
            error_response('La ubicación del evento no es válida.', 400);
        }
        $radius = (int) ($body['radiusM'] ?? 50);
        if ($radius < 5 || $radius > 1000) {
            error_response('El radio del evento debe estar entre 5 y 1000 metros.', 400);
        }
        $entryTime = events_valid_time($body['entryTime'] ?? null);
        if ($entryTime === null) {
            error_response('Indica la hora de entrada del evento en formato HH:MM.', 400);
        }
    }

    return [
        'title'       => $title,
        'description' => trim((string) ($body['description'] ?? '')) ?: null,
        'event_date'  => $eventDate,
        'start_time'  => $startTime,
        'end_time'    => $endTime,
        'scope'       => $scope,
        'has_location'=> $hasLocation ? 1 : 0,
        'latitude'    => $lat,
        'longitude'   => $lng,
        'radius_m'    => $radius,
        'location_label' => $label,
        'entry_time'  => $entryTime,
        'area_ids'    => $scope === 'areas' ? $areaIds : [],
    ];
}

// Notifica a los miembros de las áreas asignadas (incluye a sus managers, que
// también tienen department_id). Solo para eventos por áreas.
function event_notify_areas(PDO $pdo, array $areaIds, string $title, string $eventDate): void {
    if (!$areaIds) return;
    $in = implode(',', array_fill(0, count($areaIds), '?'));
    $stmt = $pdo->prepare("SELECT email FROM users WHERE department_id IN ($in)");
    $stmt->execute(array_values($areaIds));
    $fecha = date('d/m/Y', strtotime($eventDate));
    foreach ($stmt->fetchAll() as $r) {
        notify_user($pdo, $r['email'], null, 'event_created',
            'Nuevo evento: ' . mb_substr($title, 0, 120) . ' (' . $fecha . ')');
    }
}

function eventCreate(PDO $pdo) {
    $user = require_auth($pdo);
    require_role($user, ['director']);
    $data = event_body_or_fail($pdo);

    $id = generate_id();
    $stmt = $pdo->prepare(
        'INSERT INTO events
           (id, title, description, event_date, start_time, end_time, scope,
            has_location, latitude, longitude, radius_m, location_label, entry_time, created_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $id, $data['title'], $data['description'], $data['event_date'],
        $data['start_time'], $data['end_time'], $data['scope'], $data['has_location'],
        $data['latitude'], $data['longitude'], $data['radius_m'],
        $data['location_label'], $data['entry_time'], $user['id'],
    ]);

    foreach ($data['area_ids'] as $deptId) {
        $stmt = $pdo->prepare('INSERT IGNORE INTO event_areas (event_id, department_id) VALUES (?, ?)');
        $stmt->execute([$id, $deptId]);
    }
    if ($data['scope'] === 'areas') {
        event_notify_areas($pdo, $data['area_ids'], $data['title'], $data['event_date']);
    }

    $stmt = $pdo->prepare('SELECT * FROM events WHERE id = ?');
    $stmt->execute([$id]);
    json_response(['success' => true, 'message' => 'Evento creado', 'event' => event_payload($pdo, $stmt->fetch())]);
}

function eventUpdate(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    require_role($user, ['director']);

    $stmt = $pdo->prepare('SELECT * FROM events WHERE id = ?');
    $stmt->execute([$id]);
    if (!$stmt->fetch()) {
        error_response('Evento no encontrado', 404);
    }

    $data = event_body_or_fail($pdo);
    $stmt = $pdo->prepare(
        'UPDATE events SET title=?, description=?, event_date=?, start_time=?, end_time=?,
           scope=?, has_location=?, latitude=?, longitude=?, radius_m=?, location_label=?, entry_time=?
         WHERE id=?'
    );
    $stmt->execute([
        $data['title'], $data['description'], $data['event_date'],
        $data['start_time'], $data['end_time'], $data['scope'], $data['has_location'],
        $data['latitude'], $data['longitude'], $data['radius_m'],
        $data['location_label'], $data['entry_time'], $id,
    ]);

    $pdo->prepare('DELETE FROM event_areas WHERE event_id = ?')->execute([$id]);
    foreach ($data['area_ids'] as $deptId) {
        $stmt = $pdo->prepare('INSERT IGNORE INTO event_areas (event_id, department_id) VALUES (?, ?)');
        $stmt->execute([$id, $deptId]);
    }

    $stmt = $pdo->prepare('SELECT * FROM events WHERE id = ?');
    $stmt->execute([$id]);
    json_response(['success' => true, 'message' => 'Evento actualizado', 'event' => event_payload($pdo, $stmt->fetch())]);
}

function eventDelete(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    require_role($user, ['director']);
    $stmt = $pdo->prepare('DELETE FROM events WHERE id = ?');
    $stmt->execute([$id]);
    if ($stmt->rowCount() === 0) {
        error_response('Evento no encontrado', 404);
    }
    json_response(['success' => true, 'message' => 'Evento eliminado']);
}

// ---- endpoint: feed de calendario -----------------------------

// Actividades a entregar = tareas (tabla `tasks`) con fecha límite dentro del
// rango. `tasks.deadline` es texto libre: se parsea con strtotime y se descarta
// lo que no sea una fecha. Alcance:
//   - empleado / scope=me       -> solo las tareas asignadas al usuario.
//   - manager  / scope=department-> tareas de los usuarios de su departamento.
//   - director / scope=company   -> todas; o departmentId=X para uno concreto.
function calendarFeed(PDO $pdo) {
    $user = require_auth($pdo);
    [$from, $to] = events_range();

    $scope = trim($_GET['scope'] ?? '');
    $departmentId = trim($_GET['departmentId'] ?? '');

    $sql = "SELECT tk.description, tk.deadline, tk.completed, tk.email,
                   tk.team_code AS teamCode, tk.domain_name AS domainName,
                   t.team_name AS teamName
            FROM tasks tk
            LEFT JOIN teams t ON t.team_code = tk.team_code
            WHERE tk.deadline <> ''";
    $params = [];

    if ($user['role'] === 'director') {
        if ($departmentId !== '') {
            $sql .= ' AND tk.email IN (SELECT email FROM users WHERE department_id = ?)';
            $params[] = $departmentId;
        } elseif ($scope !== 'company') {
            $sql .= ' AND tk.email = ?';
            $params[] = $user['email'];
        }
    } elseif ($user['role'] === 'manager' && $scope === 'department' && !empty($user['department_id'])) {
        $sql .= ' AND tk.email IN (SELECT email FROM users WHERE department_id = ?)';
        $params[] = $user['department_id'];
    } else {
        // empleado, o manager en "mi calendario": solo lo propio.
        $sql .= ' AND tk.email = ?';
        $params[] = $user['email'];
    }
    $sql .= ' ORDER BY tk.deadline ASC, tk.id ASC';

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    $activities = [];
    foreach ($stmt->fetchAll() as $r) {
        $ts = strtotime((string) $r['deadline']);
        if ($ts === false) continue;
        $d = date('Y-m-d', $ts);
        if ($d < $from || $d > $to) continue;
        $activities[] = [
            'description' => $r['description'],
            'deadline'    => $d,
            'completed'   => (bool) $r['completed'],
            'assignedTo'  => $r['email'],
            'teamCode'    => $r['teamCode'],
            'teamName'    => $r['teamName'],
            'domainName'  => $r['domainName'],
        ];
    }

    json_response([
        'success'    => true,
        'from'       => $from,
        'to'         => $to,
        'activities' => $activities,
        'events'     => events_visible_for($pdo, $user, $from, $to),
        'canManage'  => $user['role'] === 'director',
    ]);
}
