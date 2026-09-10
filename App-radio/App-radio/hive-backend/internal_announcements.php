<?php
// Anuncios internos de la empresa (Radio Doliv).
//
// El DIRECTOR GENERAL publica un anuncio interno y TODA la audiencia lo recibe
// INMEDIATAMENTE (no hay ventana de vigencia ni límite de duración). Puede ser
// 'general' (toda la empresa) o de 'areas' específicas (departamentos). Lo
// relevante cuando es una reunión es su fecha/hora, `event_at`.
//
// Si requires_confirmation=1, el resto de la plantilla confirma asistencia
// (sí/no). Quien confirma "sí" recibe un RECORDATORIO RECURRENTE (una
// notificación al día) hasta que llegue `event_at`. El recordatorio lo emite
// ia_dispatch_due_reminders(): de forma perezosa cada vez que alguien consulta
// sus notificaciones, y también desde el cron opcional
// cron_announcement_reminders.php. internal_announcement_reminders evita
// repetir el aviso del mismo día.
//
// El director ve el historial de visualizaciones y de confirmaciones, y puede
// editar o eliminar el anuncio.
//
// Endpoints (registrados en index.php):
//   GET  /internal-announcements                  (tablero — todos)
//   POST /internal-announcements                  (crear — solo director)
//   POST /internal-announcements/{id}             (editar — solo director)
//   POST /internal-announcements/{id}/delete      (borrar — solo director)
//   POST /internal-announcements/{id}/confirm     (confirmar asistencia — no director)
//   GET  /internal-announcements/{id}/views       (historial — solo director)

// Cada cuántos días se repite el recordatorio a quien confirmó asistencia.
const IA_REMINDER_EVERY_DAYS = 1;

// ---- helpers ------------------------------------------------------------

function ia_find(PDO $pdo, string $id): ?array {
    $stmt = $pdo->prepare('SELECT * FROM internal_announcements WHERE id = ?');
    $stmt->execute([$id]);
    $row = $stmt->fetch();
    return $row ?: null;
}

// Departamentos (ids) de un anuncio por áreas.
function ia_area_ids(PDO $pdo, string $announcementId): array {
    $stmt = $pdo->prepare('SELECT department_id FROM internal_announcement_areas WHERE announcement_id = ?');
    $stmt->execute([$announcementId]);
    return array_column($stmt->fetchAll(), 'department_id');
}

// ¿$user puede ver este anuncio? El director ve todos; el resto ve los
// 'general' y los de 'areas' que incluyan su departamento.
function ia_visible_to(array $user, array $a, array $areaIds): bool {
    if ($user['role'] === 'director') return true;
    if ($a['scope'] === 'general') return true;
    return !empty($user['department_id']) && in_array($user['department_id'], $areaIds, true);
}

// Un anuncio "terminó" cuando tenía una reunión y ya pasó (más de un día).
function ia_is_finished(array $a): bool {
    if (empty($a['event_at'])) return false;
    return strtotime($a['event_at']) < strtotime('-1 day');
}

// Nº de personas (manager/employee) a las que va dirigido el anuncio.
function ia_audience_count(PDO $pdo, array $a, array $areaIds): int {
    if ($a['scope'] === 'general') {
        return (int) $pdo->query(
            "SELECT COUNT(*) c FROM users WHERE role IN ('manager','employee') AND " . SQL_USER_VERIFIED
        )->fetch()['c'];
    }
    if (!$areaIds) return 0;
    $in = implode(',', array_fill(0, count($areaIds), '?'));
    $stmt = $pdo->prepare(
        "SELECT COUNT(*) c FROM users
         WHERE role IN ('manager','employee') AND department_id IN ($in)
           AND " . SQL_USER_VERIFIED
    );
    $stmt->execute(array_values($areaIds));
    return (int) $stmt->fetch()['c'];
}

// Forma de un anuncio para el cliente. `$user` decide qué campos extra van:
// el director recibe los agregados (viewCount / confirmedYes / …); el resto
// recibe su estado personal (viewedByMe / myConfirmation).
function ia_payload(PDO $pdo, array $user, array $a): array {
    $areaIds = $a['scope'] === 'areas' ? ia_area_ids($pdo, $a['id']) : [];
    $areas = [];
    if ($areaIds) {
        $in = implode(',', array_fill(0, count($areaIds), '?'));
        $stmt = $pdo->prepare("SELECT id, name FROM departments WHERE id IN ($in) ORDER BY name ASC");
        $stmt->execute(array_values($areaIds));
        $areas = $stmt->fetchAll();
    }

    $out = [
        'id'                   => $a['id'],
        'title'                => $a['title'],
        'body'                 => $a['body'],
        'scope'                => $a['scope'],
        'requiresConfirmation' => (bool) $a['requires_confirmation'],
        'eventAt'              => $a['event_at'] ? date('c', strtotime($a['event_at'])) : null,
        'locationLabel'        => $a['location_label'],
        'active'               => !ia_is_finished($a),
        'createdAt'            => $a['created_at'] ? date('c', strtotime($a['created_at'])) : null,
        'areas'                => array_map(fn($x) => ['id' => $x['id'], 'name' => $x['name']], $areas),
    ];

    if ($user['role'] === 'director') {
        $stmt = $pdo->prepare('SELECT COUNT(*) c FROM internal_announcement_views WHERE announcement_id = ?');
        $stmt->execute([$a['id']]);
        $out['viewCount'] = (int) $stmt->fetch()['c'];

        $stmt = $pdo->prepare(
            "SELECT
               SUM(status = 'si') si_count,
               SUM(status = 'no') no_count
             FROM internal_announcement_confirmations WHERE announcement_id = ?"
        );
        $stmt->execute([$a['id']]);
        $c = $stmt->fetch();
        $out['confirmedYes']  = (int) ($c['si_count'] ?? 0);
        $out['confirmedNo']   = (int) ($c['no_count'] ?? 0);
        $out['audienceCount'] = ia_audience_count($pdo, $a, $areaIds);
    } else {
        $stmt = $pdo->prepare(
            'SELECT 1 FROM internal_announcement_views WHERE announcement_id = ? AND user_id = ?'
        );
        $stmt->execute([$a['id'], $user['id']]);
        $out['viewedByMe'] = (bool) $stmt->fetch();

        $stmt = $pdo->prepare(
            'SELECT status FROM internal_announcement_confirmations WHERE announcement_id = ? AND user_id = ?'
        );
        $stmt->execute([$a['id'], $user['id']]);
        $mine = $stmt->fetch();
        $out['myConfirmation'] = $mine ? $mine['status'] : null;
    }

    return $out;
}

// Marca como visto (idempotente) el anuncio para este usuario.
function ia_mark_viewed(PDO $pdo, string $announcementId, string $userId): void {
    $stmt = $pdo->prepare(
        'INSERT IGNORE INTO internal_announcement_views (announcement_id, user_id) VALUES (?, ?)'
    );
    $stmt->execute([$announcementId, $userId]);
}

// Valida y normaliza el cuerpo de crear/editar. Corta con 4xx.
function ia_body_or_fail(PDO $pdo): array {
    $body  = request_body();
    $title = trim((string) ($body['title'] ?? ''));
    $text  = trim((string) ($body['body'] ?? ''));

    if ($title === '' || $text === '') {
        error_response('El título y el contenido del anuncio son obligatorios.', 400);
    }

    $scope = ($body['scope'] ?? 'general') === 'areas' ? 'areas' : 'general';

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
        error_response('Un anuncio por áreas necesita al menos un departamento válido.', 400);
    }

    $requiresConfirmation = !empty($body['requiresConfirmation'])
        && $body['requiresConfirmation'] !== 'false' && $body['requiresConfirmation'] !== '0';

    $eventAt = null;
    $rawEventAt = trim((string) ($body['eventAt'] ?? ''));
    if ($rawEventAt !== '') {
        $ts = strtotime($rawEventAt);
        if ($ts === false) {
            error_response('La fecha y hora de la reunión no es válida.', 400);
        }
        $eventAt = date('Y-m-d H:i:s', $ts);
    }

    $locationLabel = trim((string) ($body['locationLabel'] ?? '')) ?: null;

    return [
        'title'                 => $title,
        'body'                  => $text,
        'scope'                 => $scope,
        'requires_confirmation' => $requiresConfirmation ? 1 : 0,
        'event_at'              => $eventAt,
        'location_label'        => $locationLabel,
        'area_ids'              => $scope === 'areas' ? $areaIds : [],
    ];
}

// Notifica a la audiencia del anuncio (managers incluidos por department_id).
function ia_notify_audience(PDO $pdo, string $scope, array $areaIds, string $title): void {
    if ($scope === 'areas') {
        if (!$areaIds) return;
        $in = implode(',', array_fill(0, count($areaIds), '?'));
        $stmt = $pdo->prepare(
            "SELECT email FROM users WHERE role IN ('manager','employee') AND department_id IN ($in)
               AND " . SQL_USER_VERIFIED
        );
        $stmt->execute(array_values($areaIds));
    } else {
        $stmt = $pdo->query(
            "SELECT email FROM users WHERE role IN ('manager','employee') AND " . SQL_USER_VERIFIED
        );
    }
    foreach ($stmt->fetchAll() as $r) {
        notify_user($pdo, $r['email'], null, 'internal_announcement',
            'Nuevo anuncio interno: ' . mb_substr($title, 0, 120));
    }
}

// Emite el recordatorio recurrente a quien confirmó asistencia ("sí") a una
// reunión que todavía no ha ocurrido. Una notificación por día como máximo
// (IA_REMINDER_EVERY_DAYS). Idempotente: se puede llamar en cada request.
// Si $onlyUserId != null, solo procesa a esa persona (uso perezoso).
function ia_dispatch_due_reminders(PDO $pdo, ?string $onlyUserId = null): int {
    $announcements = $pdo->query(
        "SELECT id, title, event_at, location_label
         FROM internal_announcements
         WHERE requires_confirmation = 1 AND event_at IS NOT NULL AND event_at > NOW()"
    )->fetchAll();
    if (!$announcements) return 0;

    $today = date('Y-m-d');
    $sent = 0;

    foreach ($announcements as $a) {
        $sql = "SELECT u.id, u.email
                FROM internal_announcement_confirmations c
                JOIN users u ON u.id = c.user_id
                WHERE c.announcement_id = ? AND c.status = 'si'";
        $params = [$a['id']];
        if ($onlyUserId !== null) {
            $sql .= ' AND u.id = ?';
            $params[] = $onlyUserId;
        }
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);

        foreach ($stmt->fetchAll() as $u) {
            // ¿Ya se le mandó un recordatorio dentro del periodo?
            $chk = $pdo->prepare(
                'SELECT 1 FROM internal_announcement_reminders
                 WHERE announcement_id = ? AND user_id = ?
                   AND reminder_date > (CURDATE() - INTERVAL ? DAY)'
            );
            $chk->execute([$a['id'], $u['id'], IA_REMINDER_EVERY_DAYS]);
            if ($chk->fetch()) continue;

            $ins = $pdo->prepare(
                'INSERT IGNORE INTO internal_announcement_reminders
                   (announcement_id, user_id, reminder_date) VALUES (?, ?, ?)'
            );
            $ins->execute([$a['id'], $u['id'], $today]);
            if ($ins->rowCount() === 0) continue; // carrera: otro request lo insertó

            $when = date('d/m/Y H:i', strtotime($a['event_at']));
            $msg = 'Recordatorio: ' . mb_substr($a['title'], 0, 100) . ' — ' . $when;
            if (!empty($a['location_label'])) {
                $msg .= ' · ' . $a['location_label'];
            }
            notify_user($pdo, $u['email'], null, 'internal_announcement_reminder', $msg);
            $sent++;
        }
    }
    return $sent;
}

// ---- endpoints --------------------------------------------------------

function internalAnnouncementsList(PDO $pdo) {
    $user = require_auth($pdo);
    $isDirector = $user['role'] === 'director';

    if ($isDirector) {
        // Todos, los más recientes primero.
        $rows = $pdo->query(
            'SELECT * FROM internal_announcements ORDER BY created_at DESC'
        )->fetchAll();
    } else {
        // Todos los que le corresponden; se ocultan las reuniones ya pasadas.
        $rows = $pdo->query(
            "SELECT * FROM internal_announcements
             WHERE event_at IS NULL OR event_at > (NOW() - INTERVAL 1 DAY)
             ORDER BY created_at DESC"
        )->fetchAll();
        // Al consultar, se procesan los recordatorios pendientes de esta persona.
        ia_dispatch_due_reminders($pdo, $user['id']);
    }

    $items = [];
    foreach ($rows as $a) {
        $areaIds = $a['scope'] === 'areas' ? ia_area_ids($pdo, $a['id']) : [];
        if (!ia_visible_to($user, $a, $areaIds)) continue;
        // Abrir el tablero cuenta como visualización (solo para el resto).
        if (!$isDirector) {
            ia_mark_viewed($pdo, $a['id'], $user['id']);
        }
        $items[] = ia_payload($pdo, $user, $a);
    }

    json_response([
        'success'   => true,
        'canManage' => $isDirector,
        'items'     => $items,
    ]);
}

function internalAnnouncementCreate(PDO $pdo) {
    $user = require_auth($pdo);
    require_role($user, ['director']);
    $data = ia_body_or_fail($pdo);

    $id = generate_id();
    $stmt = $pdo->prepare(
        'INSERT INTO internal_announcements
           (id, title, body, scope, requires_confirmation, event_at, location_label, created_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $id, $data['title'], $data['body'], $data['scope'],
        $data['requires_confirmation'], $data['event_at'],
        $data['location_label'], $user['id'],
    ]);

    foreach ($data['area_ids'] as $deptId) {
        $stmt = $pdo->prepare(
            'INSERT IGNORE INTO internal_announcement_areas (announcement_id, department_id) VALUES (?, ?)'
        );
        $stmt->execute([$id, $deptId]);
    }
    ia_notify_audience($pdo, $data['scope'], $data['area_ids'], $data['title']);

    json_response([
        'success'      => true,
        'message'      => 'Anuncio publicado',
        'announcement' => ia_payload($pdo, $user, ia_find($pdo, $id)),
    ]);
}

function internalAnnouncementUpdate(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    require_role($user, ['director']);
    if (!ia_find($pdo, $id)) {
        error_response('Anuncio no encontrado', 404);
    }

    $data = ia_body_or_fail($pdo);
    $stmt = $pdo->prepare(
        'UPDATE internal_announcements SET
           title=?, body=?, scope=?, requires_confirmation=?, event_at=?, location_label=?
         WHERE id=?'
    );
    $stmt->execute([
        $data['title'], $data['body'], $data['scope'],
        $data['requires_confirmation'], $data['event_at'],
        $data['location_label'], $id,
    ]);

    $pdo->prepare('DELETE FROM internal_announcement_areas WHERE announcement_id = ?')->execute([$id]);
    foreach ($data['area_ids'] as $deptId) {
        $stmt = $pdo->prepare(
            'INSERT IGNORE INTO internal_announcement_areas (announcement_id, department_id) VALUES (?, ?)'
        );
        $stmt->execute([$id, $deptId]);
    }
    // Si dejó de requerir confirmación, se descartan respuestas y recordatorios.
    if (!$data['requires_confirmation']) {
        $pdo->prepare('DELETE FROM internal_announcement_confirmations WHERE announcement_id = ?')->execute([$id]);
        $pdo->prepare('DELETE FROM internal_announcement_reminders WHERE announcement_id = ?')->execute([$id]);
    }

    json_response([
        'success'      => true,
        'message'      => 'Anuncio actualizado',
        'announcement' => ia_payload($pdo, $user, ia_find($pdo, $id)),
    ]);
}

function internalAnnouncementDelete(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    require_role($user, ['director']);
    $stmt = $pdo->prepare('DELETE FROM internal_announcements WHERE id = ?');
    $stmt->execute([$id]);
    if ($stmt->rowCount() === 0) {
        error_response('Anuncio no encontrado', 404);
    }
    json_response(['success' => true, 'message' => 'Anuncio eliminado']);
}

function internalAnnouncementConfirm(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    if ($user['role'] === 'director') {
        error_response('El director no confirma asistencia a sus propios anuncios.', 403);
    }

    $a = ia_find($pdo, $id);
    if (!$a) {
        error_response('Anuncio no encontrado', 404);
    }
    $areaIds = $a['scope'] === 'areas' ? ia_area_ids($pdo, $id) : [];
    if (!ia_visible_to($user, $a, $areaIds)) {
        error_response('Este anuncio no está dirigido a ti.', 403);
    }
    if (!$a['requires_confirmation']) {
        error_response('Este anuncio no pide confirmación de asistencia.', 400);
    }

    $body = request_body();
    $status = ($body['status'] ?? '') === 'no' ? 'no' : 'si';

    $stmt = $pdo->prepare(
        'INSERT INTO internal_announcement_confirmations (announcement_id, user_id, status)
         VALUES (?, ?, ?)
         ON DUPLICATE KEY UPDATE status = VALUES(status), responded_at = CURRENT_TIMESTAMP'
    );
    $stmt->execute([$id, $user['id'], $status]);
    ia_mark_viewed($pdo, $id, $user['id']);

    if ($status === 'si') {
        // Arranca el recordatorio recurrente ya mismo (el de hoy).
        ia_dispatch_due_reminders($pdo, $user['id']);
    } else {
        // Cambió a "no": deja de recibir recordatorios.
        $pdo->prepare(
            'DELETE FROM internal_announcement_reminders WHERE announcement_id = ? AND user_id = ?'
        )->execute([$id, $user['id']]);
    }

    json_response([
        'success'      => true,
        'message'      => $status === 'si'
            ? 'Asistencia confirmada. Recibirás recordatorios hasta la reunión.'
            : 'Registrado: no asistirás',
        'announcement' => ia_payload($pdo, $user, ia_find($pdo, $id)),
    ]);
}

// Historial de visualizaciones + confirmaciones (solo director). Devuelve una
// fila por persona de la audiencia: si abrió el anuncio y, si aplica, qué
// confirmó.
function internalAnnouncementViews(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    require_role($user, ['director']);

    $a = ia_find($pdo, $id);
    if (!$a) {
        error_response('Anuncio no encontrado', 404);
    }
    $areaIds = $a['scope'] === 'areas' ? ia_area_ids($pdo, $id) : [];

    $params = [$id, $id];
    $where = "u.role IN ('manager','employee')";
    if ($a['scope'] === 'areas') {
        if (!$areaIds) {
            json_response(['success' => true, 'announcementId' => $id, 'viewers' => [],
                'viewCount' => 0, 'confirmedYes' => 0, 'confirmedNo' => 0, 'audienceCount' => 0]);
        }
        $in = implode(',', array_fill(0, count($areaIds), '?'));
        $where .= " AND u.department_id IN ($in)";
        $params = array_merge($params, array_values($areaIds));
    }

    $stmt = $pdo->prepare(
        "SELECT u.id, u.name, u.email, d.name AS department_name,
                v.viewed_at, c.status AS confirmation, c.responded_at
         FROM users u
         LEFT JOIN departments d ON d.id = u.department_id
         LEFT JOIN internal_announcement_views v
                ON v.announcement_id = ? AND v.user_id = u.id
         LEFT JOIN internal_announcement_confirmations c
                ON c.announcement_id = ? AND c.user_id = u.id
         WHERE $where
         ORDER BY (v.viewed_at IS NULL) ASC, v.viewed_at DESC, u.name ASC"
    );
    $stmt->execute($params);
    $rows = $stmt->fetchAll();

    $viewers = array_map(fn($r) => [
        'userId'         => $r['id'],
        'name'           => $r['name'],
        'email'          => $r['email'],
        'departmentName' => $r['department_name'],
        'viewedAt'       => $r['viewed_at'] ? date('c', strtotime($r['viewed_at'])) : null,
        'confirmation'   => $r['confirmation'], // 'si' | 'no' | null
        'respondedAt'    => $r['responded_at'] ? date('c', strtotime($r['responded_at'])) : null,
    ], $rows);

    $viewCount = 0; $yes = 0; $no = 0;
    foreach ($rows as $r) {
        if ($r['viewed_at'] !== null) $viewCount++;
        if ($r['confirmation'] === 'si') $yes++;
        if ($r['confirmation'] === 'no') $no++;
    }

    json_response([
        'success'              => true,
        'announcementId'       => $id,
        'title'                => $a['title'],
        'requiresConfirmation' => (bool) $a['requires_confirmation'],
        'viewers'              => $viewers,
        'viewCount'            => $viewCount,
        'confirmedYes'         => $yes,
        'confirmedNo'          => $no,
        'audienceCount'        => count($rows),
    ]);
}
