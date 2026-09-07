<?php
// SISTEMA LEGACY anterior a la estructura por departamentos: equipos con
// líder y código de invitación, tareas de equipo, la tabla `leaves`
// (permisos viejos), y los blobs de imagen/texto por equipo. Se mantiene por
// compatibilidad; el trabajo nuevo va en dept_tasks.php / leave_requests.php /
// la estructura org de org.php. No construir aquí.

function sendMessageToLeader(PDO $pdo, string $teamId) {
    $user = require_auth($pdo);
    require_team_member($pdo, $teamId, $user);
    $body = request_body();
    $email = $body['Correo'] ?? $body['Email'] ?? $body['email'] ?? $user['email'];
    $message = trim($body['message'] ?? '');

    if ($message === '') {
        text_response('Message is required', 400);
    }

    $stmt = $pdo->prepare('INSERT INTO leader_messages (team_id, email, message) VALUES (?, ?, ?)');
    $stmt->execute([$teamId, $email, $message]);

    text_response('Message sent', 200);
}

// ---- handlers: team ----------------------------------------------------

// teamDetail.dart espera el equipo anidado: domains[] -> members[] (correos)
// y tasks[] (description/assignedTo/deadline/completed). 'completed' tiene que
// ser un booleano de verdad porque Dart compara con `== false` y no convierte
// 0/1 automáticamente.
function build_team_payload(PDO $pdo, array $team): array {
    $stmt = $pdo->prepare('SELECT id, name FROM domains WHERE team_id = ? ORDER BY id ASC');
    $stmt->execute([$team['id']]);
    $domains = $stmt->fetchAll();

    $stmt = $pdo->prepare('SELECT domain_name, email, description, deadline, completed FROM tasks WHERE team_code = ? ORDER BY id ASC');
    $stmt->execute([$team['team_code']]);
    $tasksByDomain = [];
    foreach ($stmt->fetchAll() as $t) {
        $tasksByDomain[$t['domain_name']][] = [
            'description' => $t['description'],
            'assignedTo'  => $t['email'],
            'deadline'    => $t['deadline'],
            'completed'   => (bool) $t['completed'],
        ];
    }

    $out = [];
    foreach ($domains as $d) {
        $stmt = $pdo->prepare('SELECT email FROM domain_members WHERE domain_id = ? ORDER BY id ASC');
        $stmt->execute([$d['id']]);
        $out[] = [
            '_id'     => (string) $d['id'],
            'name'    => $d['name'],
            'members' => array_column($stmt->fetchAll(), 'email'),
            'tasks'   => $tasksByDomain[$d['name']] ?? [],
        ];
    }

    return [
        '_id'         => $team['id'],
        'teamName'    => $team['team_name'],
        'teamCode'    => $team['team_code'],
        'leaderEmail' => $team['leader_email'],
        'domains'     => $out,
    ];
}

function createTeam(PDO $pdo) {
    $user = require_auth($pdo);
    $body = request_body();
    $teamName = trim($body['teamName'] ?? '');
    $domains = $body['domains'] ?? [];

    if ($teamName === '') {
        error_response('teamName is required', 400);
    }

    do {
        $teamCode = generate_team_code();
        $stmt = $pdo->prepare('SELECT id FROM teams WHERE team_code = ?');
        $stmt->execute([$teamCode]);
    } while ($stmt->fetch());

    $teamId = generate_id();
    $stmt = $pdo->prepare('INSERT INTO teams (id, team_name, team_code, leader_email) VALUES (?, ?, ?, ?)');
    $stmt->execute([$teamId, $teamName, $teamCode, $user['email']]);

    $stmt = $pdo->prepare('INSERT INTO team_members (team_id, email) VALUES (?, ?)');
    $stmt->execute([$teamId, $user['email']]);

    if (is_array($domains)) {
        foreach ($domains as $domain) {
            $domainName = trim($domain['name'] ?? '');
            if ($domainName === '') continue;
            $stmt = $pdo->prepare('INSERT INTO domains (team_id, name) VALUES (?, ?)');
            $stmt->execute([$teamId, $domainName]);
            $domainId = $pdo->lastInsertId();

            $members = $domain['members'] ?? [];
            if (is_array($members)) {
                foreach ($members as $memberEmail) {
                    if (!is_string($memberEmail) || $memberEmail === '') continue;
                    $stmt = $pdo->prepare('INSERT INTO domain_members (domain_id, email) VALUES (?, ?)');
                    $stmt->execute([$domainId, $memberEmail]);
                    $stmt = $pdo->prepare('INSERT IGNORE INTO team_members (team_id, email) VALUES (?, ?)');
                    $stmt->execute([$teamId, $memberEmail]);
                }
            }
        }
    }

    $stmt = $pdo->prepare('SELECT * FROM teams WHERE id = ?');
    $stmt->execute([$teamId]);
    json_response(['team' => build_team_payload($pdo, $stmt->fetch())]);
}

function sendTeamcode(PDO $pdo, string $teamId, string $domainName) {
    $user = require_auth($pdo);
    require_team_member($pdo, $teamId, $user);
    $body = request_body();
    $recipients = $body['recipients'] ?? [];

    $stmt = $pdo->prepare('SELECT * FROM teams WHERE id = ?');
    $stmt->execute([$teamId]);
    $team = $stmt->fetch();
    if (!$team) {
        json_response(['success' => false, 'message' => 'Team not found'], 404);
    }

    $stmt = $pdo->prepare('SELECT id FROM domains WHERE team_id = ? AND name = ?');
    $stmt->execute([$teamId, $domainName]);
    $domain = $stmt->fetch();
    if (!$domain) {
        $stmt = $pdo->prepare('INSERT INTO domains (team_id, name) VALUES (?, ?)');
        $stmt->execute([$teamId, $domainName]);
        $domainId = $pdo->lastInsertId();
    } else {
        $domainId = $domain['id'];
    }

    if (is_array($recipients)) {
        foreach ($recipients as $email) {
            if (!is_string($email) || $email === '') continue;
            $stmt = $pdo->prepare('INSERT INTO domain_members (domain_id, email) VALUES (?, ?)');
            $stmt->execute([$domainId, $email]);
            $stmt = $pdo->prepare('INSERT IGNORE INTO team_members (team_id, email) VALUES (?, ?)');
            $stmt->execute([$teamId, $email]);
        }
    }

    // No mail server is configured locally, so the code is logged instead
    // of emailed to the recipient.
    error_log('[hive-backend] Team code for ' . $teamId . ' (' . $team['team_name'] . '): ' . $team['team_code']);

    json_response(['success' => true, 'message' => 'Invitation recorded. Team code: ' . $team['team_code']]);
}

function joinTeam(PDO $pdo) {
    $user = require_auth($pdo);
    $body = request_body();
    $teamCode = trim($body['teamCode'] ?? '');

    $stmt = $pdo->prepare('SELECT id FROM teams WHERE team_code = ?');
    $stmt->execute([$teamCode]);
    $team = $stmt->fetch();
    if (!$team) {
        text_response('Invalid team code', 404);
    }

    $stmt = $pdo->prepare('INSERT IGNORE INTO team_members (team_id, email) VALUES (?, ?)');
    $stmt->execute([$team['id'], $user['email']]);

    text_response('Joined team successfully', 200);
}

function showTeams(PDO $pdo) {
    $user = require_auth($pdo);

    $stmt = $pdo->prepare(
        'SELECT t.id, t.team_name, t.team_code, t.leader_email
         FROM teams t
         JOIN team_members tm ON tm.team_id = t.id
         WHERE tm.email = ?'
    );
    $stmt->execute([$user['email']]);
    $rows = $stmt->fetchAll();

    $teams = array_map(fn($r) => build_team_payload($pdo, $r), $rows);

    json_response(['teams' => $teams, 'email' => $user['email']]);
}

// La creación de tareas del sistema viejo (por team_code + domain) se retiró:
// ahora todo pasa por el flujo jerárquico por departamento (dept_tasks.php,
// POST /dept-tasks). `taskDone` se conserva solo para marcar como hechas las
// tareas antiguas que ya existieran.

function taskDone(PDO $pdo) {
    $user = require_auth($pdo);
    $body = request_body();
    $teamCode = trim($body['teamCode'] ?? '');
    $domainName = trim($body['domainName'] ?? '');
    $email = trim($body['email'] ?? '');
    $task = trim($body['task'] ?? '');

    $team = team_from_code($pdo, $teamCode);
    if (!$team) {
        text_response('Team not found', 404);
    }
    require_team_member($pdo, $team['id'], $user);

    $stmt = $pdo->prepare(
        'UPDATE tasks SET completed = 1
         WHERE team_code = ? AND domain_name = ? AND email = ? AND description = ? AND completed = 0
         LIMIT 1'
    );
    $stmt->execute([$teamCode, $domainName, $email, $task]);

    if ($stmt->rowCount() === 0) {
        text_response('Task not found', 404);
    }

    text_response('Task marked as done', 200);
}

// teamCode y domainName viajan además de la descripción porque la lista de
// tareas (home_page/tasks.dart) los necesita para poder marcar una tarea como
// hecha sin tener que entrar al detalle del equipo.
function tasks_for_user(PDO $pdo, string $email, int $completed): array {
    $stmt = $pdo->prepare(
        'SELECT tk.description, tk.email AS assignedTo, tk.deadline,
                tk.team_code AS teamCode, tk.domain_name AS domainName,
                t.team_name AS teamName
         FROM tasks tk
         LEFT JOIN teams t ON t.team_code = tk.team_code
         WHERE tk.email = ? AND tk.completed = ?
         ORDER BY tk.deadline ASC, tk.id ASC'
    );
    $stmt->execute([$email, $completed]);
    return $stmt->fetchAll();
}

function incompleteTasks(PDO $pdo) {
    $user = require_auth($pdo);
    json_response(['incompleteTasks' => tasks_for_user($pdo, $user['email'], 0)]);
}

function completedTasks(PDO $pdo) {
    $user = require_auth($pdo);
    json_response(['completedTasks' => tasks_for_user($pdo, $user['email'], 1)]);
}

function deleteMember(PDO $pdo, string $teamId) {
    $user = require_auth($pdo);
    require_team_leader($pdo, $teamId, $user);
    $body = request_body();
    $memberEmail = trim($body['memberEmail'] ?? '');

    if ($memberEmail === '') {
        text_response('memberEmail is required', 400);
    }
    if (strcasecmp($memberEmail, $user['email']) === 0) {
        text_response('The leader cannot remove themselves; transfer leadership first', 400);
    }

    $stmt = $pdo->prepare('DELETE FROM team_members WHERE team_id = ? AND email = ?');
    $stmt->execute([$teamId, $memberEmail]);
    $removed = $stmt->rowCount();

    $stmt = $pdo->prepare('DELETE dm FROM domain_members dm JOIN domains d ON d.id = dm.domain_id WHERE d.team_id = ? AND dm.email = ?');
    $stmt->execute([$teamId, $memberEmail]);

    if ($removed > 0) {
        $stmt = $pdo->prepare('SELECT team_name FROM teams WHERE id = ?');
        $stmt->execute([$teamId]);
        $team = $stmt->fetch();
        notify_user($pdo, $memberEmail, $teamId, 'member_removed',
            'Fuiste eliminado del equipo "' . ($team['team_name'] ?? '') . '"');
    }

    text_response('Member removed', 200);
}

// Borra el equipo y todo lo que cuelga de él. Solo el líder puede hacerlo.
function deleteTeam(PDO $pdo, string $teamId) {
    $user = require_auth($pdo);
    require_team_leader($pdo, $teamId, $user);

    $stmt = $pdo->prepare('SELECT * FROM teams WHERE id = ?');
    $stmt->execute([$teamId]);
    $team = $stmt->fetch();
    if (!$team) {
        text_response('Team not found', 404);
    }

    // Se leen antes de borrar: los miembros para avisarles y las imágenes para
    // poder limpiar los archivos subidos una vez confirmado el borrado.
    $stmt = $pdo->prepare('SELECT email FROM team_members WHERE team_id = ? AND email <> ?');
    $stmt->execute([$teamId, $user['email']]);
    $members = array_column($stmt->fetchAll(), 'email');

    $stmt = $pdo->prepare('SELECT img_path FROM images WHERE team_id = ?');
    $stmt->execute([$teamId]);
    $imagePaths = array_column($stmt->fetchAll(), 'img_path');

    $pdo->beginTransaction();
    try {
        // tasks se referencia por team_code, no por team_id.
        $stmt = $pdo->prepare('DELETE FROM tasks WHERE team_code = ?');
        $stmt->execute([$team['team_code']]);

        $stmt = $pdo->prepare('DELETE dm FROM domain_members dm JOIN domains d ON d.id = dm.domain_id WHERE d.team_id = ?');
        $stmt->execute([$teamId]);

        foreach (['domains', 'team_members', 'texts', 'images', 'leaves', 'leader_messages'] as $table) {
            $stmt = $pdo->prepare("DELETE FROM $table WHERE team_id = ?");
            $stmt->execute([$teamId]);
        }

        // Las notificaciones ya emitidas se conservan, pero pierden la
        // referencia al equipo porque este deja de existir.
        $stmt = $pdo->prepare('UPDATE notifications SET team_id = NULL WHERE team_id = ?');
        $stmt->execute([$teamId]);

        $stmt = $pdo->prepare('DELETE FROM teams WHERE id = ?');
        $stmt->execute([$teamId]);

        $pdo->commit();
    } catch (Throwable $e) {
        // Guard: si falló el propio commit() no queda transacción que revertir
        // y un rollBack() a secas taparía la excepción original con otra.
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $e;
    }

    foreach ($members as $memberEmail) {
        notify_user($pdo, $memberEmail, null, 'team_deleted',
            'El equipo "' . $team['team_name'] . '" fue eliminado');
    }

    foreach ($imagePaths as $p) {
        $file = UPLOAD_DIR . basename($p);
        if (is_file($file)) {
            @unlink($file);
        }
    }

    text_response('Team deleted', 200);
}

function leaderResign(PDO $pdo, string $teamId) {
    $user = require_auth($pdo);
    require_team_leader($pdo, $teamId, $user);
    $body = request_body();
    // La pantalla LResign.dart manda el campo como "Correo"; se aceptan las
    // tres grafías para no depender de cuál pantalla haga la llamada.
    $newLeaderEmail = trim($body['Correo'] ?? $body['Email'] ?? $body['email'] ?? '');

    if ($newLeaderEmail === '') {
        text_response('Email of the new leader is required', 400);
    }

    $stmt = $pdo->prepare('SELECT id FROM team_members WHERE team_id = ? AND email = ?');
    $stmt->execute([$teamId, $newLeaderEmail]);
    if (!$stmt->fetch()) {
        text_response('The new leader must already be a team member', 400);
    }

    $stmt = $pdo->prepare('UPDATE teams SET leader_email = ? WHERE id = ?');
    $stmt->execute([$newLeaderEmail, $teamId]);

    $stmt = $pdo->prepare('SELECT team_name FROM teams WHERE id = ?');
    $stmt->execute([$teamId]);
    $team = $stmt->fetch();
    notify_user($pdo, $newLeaderEmail, $teamId, 'leader_assigned',
        'Ahora eres el líder del equipo "' . ($team['team_name'] ?? '') . '"');

    text_response('Leadership transferred', 200);
}

// ---- handlers: resources ------------------------------------------------

function showImage(PDO $pdo, string $teamId) {
    $user = require_auth($pdo);
    require_team_member($pdo, $teamId, $user);
    $stmt = $pdo->prepare('SELECT img_name, img_path FROM images WHERE team_id = ? ORDER BY id DESC');
    $stmt->execute([$teamId]);
    $rows = $stmt->fetchAll();

    $images = array_map(fn($r) => [
        'imgURL' => UPLOAD_URL_BASE . $r['img_path'],
        'imgName' => $r['img_name'],
    ], $rows);

    // The client expects a bare JSON array, not wrapped in an object.
    raw_json_response($images);
}

function addImage(PDO $pdo) {
    $user = require_auth($pdo);
    $teamId = trim($_POST['teamId'] ?? '');
    $imgName = trim($_POST['imgName'] ?? '');

    if ($teamId === '' || empty($_FILES['photo']) || $_FILES['photo']['error'] !== UPLOAD_ERR_OK) {
        text_response('teamId and photo are required', 400);
    }
    require_team_member($pdo, $teamId, $user);

    $tmpPath = $_FILES['photo']['tmp_name'];
    $originalName = $_FILES['photo']['name'];
    $ext = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));
    $allowed = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

    if (!in_array($ext, $allowed, true) || @getimagesize($tmpPath) === false) {
        text_response('Only image files are allowed', 400);
    }

    $storedName = bin2hex(random_bytes(16)) . '.' . $ext;
    if (!move_uploaded_file($tmpPath, UPLOAD_DIR . $storedName)) {
        text_response('Failed to save the uploaded image', 500);
    }

    $stmt = $pdo->prepare('INSERT INTO images (team_id, img_name, img_path) VALUES (?, ?, ?)');
    $stmt->execute([$teamId, $imgName !== '' ? $imgName : $originalName, $storedName]);

    text_response('Image uploaded successfully', 200);
}

function addText(PDO $pdo, string $teamId) {
    $user = require_auth($pdo);
    require_team_member($pdo, $teamId, $user);
    $body = request_body();
    $text = trim($body['text'] ?? '');

    if ($text === '') {
        json_response(['error' => 'text is required'], 400);
    }

    $stmt = $pdo->prepare('INSERT INTO texts (team_id, email, text) VALUES (?, ?, ?)');
    $stmt->execute([$teamId, $user['email'], $text]);

    json_response(['message' => 'Text added successfully'], 201);
}

function showText(PDO $pdo, string $teamId) {
    $user = require_auth($pdo);
    require_team_member($pdo, $teamId, $user);
    $stmt = $pdo->prepare('SELECT email, text FROM texts WHERE team_id = ? ORDER BY created_at ASC');
    $stmt->execute([$teamId]);
    $rows = $stmt->fetchAll();

    $grouped = [];
    foreach ($rows as $row) {
        $email = $row['email'];
        if (!isset($grouped[$email])) {
            $grouped[$email] = ['email' => $email, 'texts' => []];
        }
        $grouped[$email]['texts'][] = ['text' => $row['text']];
    }

    json_response(['data' => array_values($grouped)]);
}

// ---- handlers: leave ----------------------------------------------------

function applyLeave(PDO $pdo, string $teamId) {
    $user = require_auth($pdo);
    require_team_member($pdo, $teamId, $user);
    $body = request_body();
    $leaves = $body['leaves'] ?? [];
    $leave = is_array($leaves) && count($leaves) > 0 ? $leaves[0] : null;

    if (!$leave || empty($leave['startDate']) || empty($leave['endDate'])) {
        json_response(['error' => 'startDate and endDate are required'], 400);
    }

    // Mismas reglas de negocio que el flujo nuevo (/leave-requests):
    // no se piden permisos para fechas ya pasadas y las fechas deben caer en
    // un día laboral (lunes a sábado; el domingo no).
    $ls = date('Y-m-d', strtotime((string) $leave['startDate']));
    $le = date('Y-m-d', strtotime((string) $leave['endDate']));
    if ($le < $ls) {
        json_response(['error' => 'La fecha de término no puede ser anterior a la de inicio.'], 400);
    }
    if ($ls < date('Y-m-d')) {
        json_response(['error' => 'No puedes solicitar un permiso para una fecha que ya pasó.'], 400);
    }
    if (!is_working_day($ls) || !is_working_day($le)) {
        json_response(['error' => 'El inicio y el término deben ser un día laboral (lunes a sábado).'], 400);
    }

    $leaveId = generate_id();
    $stmt = $pdo->prepare(
        'INSERT INTO leaves (id, team_id, email, start_date, end_date, reason, status) VALUES (?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $leaveId,
        $teamId,
        $user['email'],
        $leave['startDate'],
        $leave['endDate'],
        db_encrypt($leave['reason'] ?? ''),
        'pending',
    ]);

    json_response([
        '_id' => $leaveId,
        'teamId' => $teamId,
        'email' => $user['email'],
        'startDate' => $leave['startDate'],
        'endDate' => $leave['endDate'],
        'reason' => $leave['reason'] ?? '',
        'status' => 'pending',
    ]);
}

function leaveResult(PDO $pdo, string $leaveId) {
    $user = require_auth($pdo);

    $stmt = $pdo->prepare(
        'SELECT l.email, t.leader_email FROM leaves l
         LEFT JOIN teams t ON t.id = l.team_id
         WHERE l.id = ?'
    );
    $stmt->execute([$leaveId]);
    $leave = $stmt->fetch();
    if (!$leave) {
        json_response(['error' => 'Leave request not found'], 404);
    }
    if ($leave['email'] !== $user['email'] && $leave['leader_email'] !== $user['email']) {
        error_response('You cannot access this leave request', 403);
    }

    $stmt = $pdo->prepare("UPDATE leaves SET status = 'submitted' WHERE id = ?");
    $stmt->execute([$leaveId]);
    json_response(['message' => 'Leave application submitted']);
}
