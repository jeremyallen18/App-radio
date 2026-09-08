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
        // Lugar del evento en texto libre (024), para cualquier evento.
        'locationText'  => $e['location_text'] ?? null,
        // Días de antelación de los recordatorios automáticos (024).
        'reminderOffsets' => event_parse_offsets($e['reminder_offsets'] ?? ''),
        'entryTime'     => $e['entry_time'] ? substr($e['entry_time'], 0, 5) : null,
        'areas'         => array_map(fn($a) => ['id' => $a['id'], 'name' => $a['name']], $areas),
    ];
}

// Antelaciones válidas para los recordatorios de evento.
const EVENT_REMINDER_OFFSETS_ALLOWED = [7, 5, 3, 2];

// Normaliza el CSV/lista de antelaciones: solo valores permitidos, ordenados
// de mayor a menor y sin repetir. Una lista vacía significa "sin recordatorios"
// y se conserva como tal (no se rellena con el conjunto completo). El valor por
// defecto solo se aplica al crear/editar cuando el cliente no manda el campo
// (ver event_body_or_fail()).
function event_parse_offsets($raw): array {
    if (is_string($raw)) {
        $raw = array_map('trim', explode(',', $raw));
    }
    $out = [];
    foreach ((array) $raw as $v) {
        if ($v === '' || $v === null) continue;
        $n = (int) $v;
        if (in_array($n, EVENT_REMINDER_OFFSETS_ALLOWED, true) && !in_array($n, $out, true)) {
            $out[] = $n;
        }
    }
    rsort($out);
    return $out;
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

    // Lugar en texto libre (independiente de la geocerca). Máx. 255.
    $locationText = trim((string) ($body['locationText'] ?? ''));
    if (mb_strlen($locationText) > 255) $locationText = mb_substr($locationText, 0, 255);
    $locationText = $locationText !== '' ? $locationText : null;

    // Antelaciones de los recordatorios. Si el cliente no manda el campo (builds
    // anteriores a la migración 024) se usa el conjunto completo; si lo manda
    // vacío, el director quiere "sin recordatorios" y se respeta tal cual.
    $reminderOffsets = array_key_exists('reminderOffsets', $body)
        ? implode(',', event_parse_offsets($body['reminderOffsets']))
        : implode(',', EVENT_REMINDER_OFFSETS_ALLOWED);

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
        'location_label'   => $label,
        'location_text'    => $locationText,
        'reminder_offsets' => $reminderOffsets,
        'entry_time'  => $entryTime,
        'area_ids'    => $scope === 'areas' ? $areaIds : [],
    ];
}

// Usuarios (id,email) a los que va dirigido un evento: 'general' => toda la
// plantilla (manager/employee); 'areas' => miembros de esos departamentos
// (los managers también, por su department_id).
//
// $onlyUser (fila con id,email,role,department_id): camino perezoso de
// listNotifications, donde la audiencia se reduce de antemano a UN usuario. Se
// evalúa en PHP y devuelve [] o [ese usuario], sin escanear la tabla users por
// cada evento próximo en cada refresco de la campana.
function event_audience_users(PDO $pdo, string $scope, array $areaIds, ?array $onlyUser = null): array {
    if ($onlyUser !== null) {
        if (!in_array($onlyUser['role'], ['manager', 'employee'], true)) return [];
        if ($scope === 'areas'
            && (empty($onlyUser['department_id'])
                || !in_array($onlyUser['department_id'], $areaIds, true))) {
            return [];
        }
        return [['id' => $onlyUser['id'], 'email' => $onlyUser['email']]];
    }
    if ($scope === 'areas') {
        if (!$areaIds) return [];
        $in = implode(',', array_fill(0, count($areaIds), '?'));
        $stmt = $pdo->prepare(
            "SELECT id, email FROM users
             WHERE role IN ('manager','employee') AND department_id IN ($in)"
        );
        $stmt->execute(array_values($areaIds));
        return $stmt->fetchAll();
    }
    return $pdo->query(
        "SELECT id, email FROM users WHERE role IN ('manager','employee')"
    )->fetchAll();
}

// Aviso inmediato "nuevo evento" a la audiencia (general o por áreas). La
// notificación es de tipo `event_created` y lleva a la pantalla de calendario.
function event_notify_new(PDO $pdo, string $eventId, string $scope, array $areaIds, string $title, string $eventDate): void {
    $fecha = date('d/m/Y', strtotime($eventDate));
    foreach (event_audience_users($pdo, $scope, $areaIds) as $u) {
        notify_user($pdo, $u['email'], null, 'event_created',
            'Nuevo evento: ' . mb_substr($title, 0, 120) . ' (' . $fecha . ')',
            'event', $eventId);
    }
}

// Publica (o actualiza) el anuncio interno enlazado a un evento. Todo evento
// aparece así en el tablero de anuncios; al editar el evento se actualiza el
// mismo anuncio (uq_ia_event), al borrarlo la FK ON DELETE CASCADE lo elimina.
function event_sync_announcement(PDO $pdo, string $eventId): void {
    $stmt = $pdo->prepare('SELECT * FROM events WHERE id = ?');
    $stmt->execute([$eventId]);
    $e = $stmt->fetch();
    if (!$e) return;

    $areaIds = $e['scope'] === 'areas' ? event_area_ids($pdo, $eventId) : [];

    // Cuerpo del anuncio: descripción del evento + fecha/hora + lugar.
    $lines = [];
    if (trim((string) $e['description']) !== '') $lines[] = trim((string) $e['description']);
    $when = date('d/m/Y', strtotime($e['event_date']));
    if ($e['start_time']) {
        $when .= ' · ' . substr($e['start_time'], 0, 5)
            . ($e['end_time'] ? '–' . substr($e['end_time'], 0, 5) : '');
    }
    $lines[] = '📅 ' . $when;
    if (!empty($e['location_text'])) $lines[] = '📍 ' . $e['location_text'];
    $body = implode("\n", $lines);

    // event_at: fecha del evento + hora de inicio (o mediodía si no hay), para
    // que el anuncio desaparezca de los tableros un día después del evento.
    $eventAt = $e['event_date'] . ' ' . ($e['start_time'] ?: '12:00:00');

    $existing = $pdo->prepare('SELECT id FROM internal_announcements WHERE event_id = ?');
    $existing->execute([$eventId]);
    $iaId = $existing->fetchColumn();

    if ($iaId) {
        $pdo->prepare(
            'UPDATE internal_announcements
                SET title = ?, body = ?, scope = ?, event_at = ?, location_label = ?
              WHERE id = ?'
        )->execute([$e['title'], $body, $e['scope'], $eventAt, $e['location_text'], $iaId]);
        $pdo->prepare('DELETE FROM internal_announcement_areas WHERE announcement_id = ?')->execute([$iaId]);
    } else {
        $iaId = generate_id();
        $pdo->prepare(
            'INSERT INTO internal_announcements
               (id, title, body, scope, requires_confirmation, event_at, location_label, created_by, event_id)
             VALUES (?, ?, ?, ?, 0, ?, ?, ?, ?)'
        )->execute([$iaId, $e['title'], $body, $e['scope'], $eventAt, $e['location_text'], $e['created_by'], $eventId]);
    }

    foreach ($areaIds as $deptId) {
        $pdo->prepare(
            'INSERT IGNORE INTO internal_announcement_areas (announcement_id, department_id) VALUES (?, ?)'
        )->execute([$iaId, $deptId]);
    }
}

// Emite los recordatorios automáticos de eventos próximos (7/5/3/2 días
// antes, según reminder_offsets de cada evento). Mismo patrón perezoso que
// ia_dispatch_due_reminders(): se llama al consultar notificaciones (con
// $onlyUserId) y desde el cron (sin él). Idempotente: event_reminders_sent
// garantiza un aviso por (evento, antelación, usuario). Los eventos borrados
// o pasados no generan nada; los creados/editados después del umbral solo
// disparan las antelaciones cuyo día objetivo no es anterior a su creación.
function event_dispatch_due_reminders(PDO $pdo, ?string $onlyUserId = null): int {
    $today = date('Y-m-d');

    // Camino perezoso (listNotifications): se resuelve el usuario UNA vez y la
    // audiencia de cada evento se evalúa en PHP, en vez de escanear la tabla
    // users por cada evento próximo en cada refresco de la campana.
    $onlyUser = null;
    if ($onlyUserId !== null) {
        $stmt = $pdo->prepare('SELECT id, email, role, department_id FROM users WHERE id = ?');
        $stmt->execute([$onlyUserId]);
        $onlyUser = $stmt->fetch() ?: null;
        if (!$onlyUser) return 0;
    }

    // Solo los eventos que YA pueden tener un recordatorio pendiente: la
    // antelación máxima posible es max(EVENT_REMINDER_OFFSETS_ALLOWED) días, así
    // que nada más allá de esa ventana entra en juego.
    $maxOffset = max(EVENT_REMINDER_OFFSETS_ALLOWED);
    $horizon = date('Y-m-d', strtotime($today . " +$maxOffset days"));
    $stmt = $pdo->prepare(
        "SELECT id, title, event_date, start_time, scope, reminder_offsets,
                location_text, DATE(created_at) AS created_date
           FROM events WHERE event_date >= ? AND event_date <= ?"
    );
    $stmt->execute([$today, $horizon]);
    $events = $stmt->fetchAll();
    if (!$events) return 0;

    $ins = $pdo->prepare(
        'INSERT IGNORE INTO event_reminders_sent (event_id, offset_days, user_id) VALUES (?, ?, ?)'
    );
    $sent = 0;

    foreach ($events as $e) {
        $areaIds = $e['scope'] === 'areas' ? event_area_ids($pdo, $e['id']) : [];
        $audience = event_audience_users($pdo, $e['scope'], $areaIds, $onlyUser);
        if (!$audience) continue;

        $daysLeft = (int) floor((strtotime($e['event_date']) - strtotime($today)) / 86400);
        $whenTxt = $daysLeft <= 0 ? 'hoy' : ($daysLeft === 1 ? 'mañana' : "en $daysLeft días");
        $fecha = date('d/m/Y', strtotime($e['event_date']));

        foreach (event_parse_offsets($e['reminder_offsets']) as $off) {
            $target = date('Y-m-d', strtotime($e['event_date'] . " -$off days"));
            if ($target > $today) continue;                 // aún no toca
            if ($target < $e['created_date']) continue;      // el evento no existía entonces

            foreach ($audience as $u) {
                $ins->execute([$e['id'], $off, $u['id']]);
                if ($ins->rowCount() === 0) continue;        // ya avisado (o carrera)
                $msg = 'Recordatorio: ' . mb_substr($e['title'], 0, 100)
                    . ' — ' . $whenTxt . ' (' . $fecha . ')';
                if (!empty($e['location_text'])) $msg .= ' · ' . $e['location_text'];
                notify_user($pdo, $u['email'], null, 'event_reminder', $msg, 'event', $e['id']);
                $sent++;
            }
        }
    }
    return $sent;
}

function eventCreate(PDO $pdo) {
    $user = require_auth($pdo);
    require_role($user, ['director']);
    $data = event_body_or_fail($pdo);

    $id = generate_id();
    $stmt = $pdo->prepare(
        'INSERT INTO events
           (id, title, description, event_date, start_time, end_time, scope,
            has_location, latitude, longitude, radius_m, location_label, location_text,
            reminder_offsets, entry_time, created_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $id, $data['title'], $data['description'], $data['event_date'],
        $data['start_time'], $data['end_time'], $data['scope'], $data['has_location'],
        $data['latitude'], $data['longitude'], $data['radius_m'],
        $data['location_label'], $data['location_text'], $data['reminder_offsets'],
        $data['entry_time'], $user['id'],
    ]);

    foreach ($data['area_ids'] as $deptId) {
        $stmt = $pdo->prepare('INSERT IGNORE INTO event_areas (event_id, department_id) VALUES (?, ?)');
        $stmt->execute([$id, $deptId]);
    }

    // Todo evento se publica también como anuncio interno y avisa a su
    // audiencia (general = toda la empresa; areas = los departamentos).
    event_sync_announcement($pdo, $id);
    event_notify_new($pdo, $id, $data['scope'], $data['area_ids'], $data['title'], $data['event_date']);

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
           scope=?, has_location=?, latitude=?, longitude=?, radius_m=?, location_label=?,
           location_text=?, reminder_offsets=?, entry_time=?
         WHERE id=?'
    );
    $stmt->execute([
        $data['title'], $data['description'], $data['event_date'],
        $data['start_time'], $data['end_time'], $data['scope'], $data['has_location'],
        $data['latitude'], $data['longitude'], $data['radius_m'],
        $data['location_label'], $data['location_text'], $data['reminder_offsets'],
        $data['entry_time'], $id,
    ]);

    $pdo->prepare('DELETE FROM event_areas WHERE event_id = ?')->execute([$id]);
    foreach ($data['area_ids'] as $deptId) {
        $stmt = $pdo->prepare('INSERT IGNORE INTO event_areas (event_id, department_id) VALUES (?, ?)');
        $stmt->execute([$id, $deptId]);
    }

    // Mantiene el anuncio interno enlazado al día con los datos nuevos (no
    // vuelve a notificar; eso solo pasa al crear).
    event_sync_announcement($pdo, $id);

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
