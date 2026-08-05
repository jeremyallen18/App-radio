<?php
require __DIR__ . '/config.php';
require __DIR__ . '/helpers.php';

// ---- routing -------------------------------------------------------

$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$base = APP_BASE_PATH;
if (strpos($uri, $base) === 0) {
    $uri = substr($uri, strlen($base));
}
if ($uri === '' || $uri === false) {
    $uri = '/';
}
$method = $_SERVER['REQUEST_METHOD'];

$routes = [
    ['GET',  '#^/?$#',                                       'home'],
    ['POST', '#^/user/signup/?$#',                            'signup'],
    ['POST', '#^/user/login/?$#',                             'login'],
    ['POST', '#^/user/resetPassword/?$#',                     'resetPassword'],
    ['POST', '#^/user/verifyOTP/([^/]+)/?$#',                 'verifyOTP'],
    ['POST', '#^/user/newPassword/([^/]+)/?$#',               'newPassword'],
    ['GET',  '#^/user/sendName/?$#',                          'sendName'],
    ['POST', '#^/user/sendMessage/([^/]+)/?$#',               'sendMessageToLeader'],
    ['GET',  '#^/googleOAuth/?$#',                            'googleOAuthStub'],
    ['POST', '#^/team/createTeam/?$#',                        'createTeam'],
    ['POST', '#^/team/sendTeamcode/([^/]+)/([^/]+)/?$#',      'sendTeamcode'],
    ['POST', '#^/team/joinTeam/?$#',                          'joinTeam'],
    ['GET',  '#^/team/showTeams/?$#',                         'showTeams'],
    ['POST', '#^/team/task/([^/]+)/?$#',                      'addTask'],
    ['POST', '#^/team/taskDone/?$#',                          'taskDone'],
    ['GET',  '#^/team/incompleteTasks/?$#',                   'incompleteTasks'],
    ['GET',  '#^/team/completedTasks/?$#',                    'completedTasks'],
    ['POST', '#^/team/deleteMember/([^/]+)/?$#',              'deleteMember'],
    ['POST', '#^/team/deleteTeam/([^/]+)/?$#',                'deleteTeam'],
    ['POST', '#^/team/leaderResign/([^/]+)/?$#',              'leaderResign'],
    ['GET',  '#^/chat/getAllChats/?$#',                       'getAllChats'],
    ['POST', '#^/chat/sendMessage/?$#',                       'sendChatMessage'],
    ['GET',  '#^/image/showImage/([^/]+)/?$#',                'showImage'],
    ['POST', '#^/image/addImage/?$#',                         'addImage'],
    ['POST', '#^/text/addText/([^/]+)/?$#',                   'addText'],
    ['GET',  '#^/text/showText/([^/]+)/?$#',                  'showText'],
    ['POST', '#^/leave/applyLeave/([^/]+)/?$#',                'applyLeave'],
    ['POST', '#^/leave/leaveResult/([^/]+)/?$#',               'leaveResult'],
    ['GET',  '#^/notifications/?$#',                          'listNotifications'],
    ['POST', '#^/notifications/([^/]+)/read/?$#',             'markNotificationRead'],
    ['GET',  '#^/user/me/?$#',                                'getMe'],
    ['POST', '#^/user/photo/?$#',                             'updateProfilePhoto'],
    ['POST', '#^/company/create/?$#',                         'createCompany'],
    ['GET',  '#^/company/info/?$#',                           'getCompany'],
    ['POST', '#^/company/update/?$#',                         'updateCompany'],
    ['POST', '#^/department/create/?$#',                      'createDepartment'],
    ['GET',  '#^/department/list/?$#',                        'listDepartments'],
    ['POST', '#^/department/assignManager/([^/]+)/?$#',       'assignDepartmentManager'],
    ['POST', '#^/department/assignEmployee/([^/]+)/?$#',      'assignDepartmentEmployee'],
];

try {
    foreach ($routes as [$routeMethod, $pattern, $handler]) {
        if ($routeMethod !== $method) continue;
        if (preg_match($pattern, $uri, $m)) {
            array_shift($m);
            // REQUEST_URI llega sin decodificar, así que un correo enviado como
            // "a%40b.com" o un área "Machine%20Learning" no coincidirían con lo
            // guardado en la base de datos si se usaran tal cual.
            $m = array_map('urldecode', $m);
            call_user_func($handler, $pdo, ...$m);
            exit;
        }
    }
    error_response('Not found', 404);
} catch (PDOException $e) {
    error_log('DB error: ' . $e->getMessage());
    error_response('Server error', 500);
}

// ---- handlers: misc --------------------------------------------------

function home(PDO $pdo) {
    json_response(['message' => 'Hello World']);
}

function googleOAuthStub(PDO $pdo) {
    text_response('Google OAuth is not available on this local backend.', 501);
}

// ---- handlers: auth ----------------------------------------------------

function signup(PDO $pdo) {
    $body = request_body();
    $name = trim($body['name'] ?? '');
    $email = trim($body['email'] ?? '');
    $password = $body['password'] ?? '';

    if ($name === '' || $email === '' || $password === '') {
        text_response('All fields are required', 400);
    }

    $stmt = $pdo->prepare('SELECT id FROM users WHERE email = ?');
    $stmt->execute([$email]);
    if ($stmt->fetch()) {
        text_response('Email already registered', 409);
    }

    $stmt = $pdo->prepare('INSERT INTO users (id, name, email, password) VALUES (?, ?, ?, ?)');
    $stmt->execute([generate_id(), $name, $email, password_hash($password, PASSWORD_BCRYPT)]);

    text_response('Signup successful! Please log in.', 200);
}

function login(PDO $pdo) {
    $body = request_body();
    $email = trim($body['email'] ?? '');
    $password = $body['password'] ?? '';

    $stmt = $pdo->prepare('SELECT * FROM users WHERE email = ?');
    $stmt->execute([$email]);
    $user = $stmt->fetch();

    if (!$user || !password_verify($password, $user['password'])) {
        error_response('Invalid email or password', 401);
    }

    $token = generate_token();
    $stmt = $pdo->prepare('UPDATE users SET token = ? WHERE id = ?');
    $stmt->execute([$token, $user['id']]);

    // The client decodes the whole response body as the token value itself.
    raw_json_response($token, 200);
}

function resetPassword(PDO $pdo) {
    $body = request_body();
    $email = trim($body['email'] ?? '');

    $stmt = $pdo->prepare('SELECT id FROM users WHERE email = ?');
    $stmt->execute([$email]);
    $user = $stmt->fetch();
    if (!$user) {
        json_response(['error' => 'No account found for that email'], 404);
    }

    $otp = generate_otp();
    $stmt = $pdo->prepare('UPDATE users SET otp = ?, otp_expires = DATE_ADD(NOW(), INTERVAL 10 MINUTE), otp_verified = 0 WHERE id = ?');
    $stmt->execute([$otp, $user['id']]);

    $sent = send_otp_email($email, $otp);

    // El OTP también se loguea como respaldo: si SMTP no está configurado
    // (desarrollo local) o el envío falla, se puede leer aquí igualmente.
    error_log("[hive-backend] Password reset OTP for $email: $otp" . ($sent ? ' (emailed)' : ' (NOT emailed)'));

    json_response(['message' => $sent
        ? 'OTP enviado a tu correo'
        : 'OTP generado, pero no se pudo enviar el correo (revisa la configuración SMTP o el log del backend)']);
}

function verifyOTP(PDO $pdo, string $email) {
    $body = request_body();
    $otp = trim($body['OTP'] ?? '');

    if ($otp === '') {
        json_response(['error' => 'Invalid or expired OTP'], 400);
    }

    // La caducidad se compara dentro de SQL a propósito: PHP y MySQL pueden
    // estar en zonas horarias distintas, y comparar strtotime() contra un
    // timestamp generado por MySQL daba el OTP por expirado siempre.
    $stmt = $pdo->prepare(
        'SELECT * FROM users
         WHERE email = ? AND otp = ? AND otp IS NOT NULL AND otp_expires > NOW()'
    );
    $stmt->execute([$email, $otp]);
    $user = $stmt->fetch();

    if (!$user) {
        json_response(['error' => 'Invalid or expired OTP'], 400);
    }

    $stmt = $pdo->prepare('UPDATE users SET otp_verified = 1 WHERE id = ?');
    $stmt->execute([$user['id']]);

    json_response(['message' => 'OTP verified']);
}

function newPassword(PDO $pdo, string $email) {
    $body = request_body();
    $newPassword = $body['newPassword'] ?? '';
    $confirmPassword = $body['confirmPassword'] ?? '';

    if ($newPassword === '' || $newPassword !== $confirmPassword) {
        json_response(['error' => 'Passwords do not match'], 400);
    }

    // Misma razón que en verifyOTP: la caducidad se evalúa en SQL.
    $stmt = $pdo->prepare(
        'SELECT * FROM users
         WHERE email = ? AND otp_verified = 1 AND otp_expires > NOW()'
    );
    $stmt->execute([$email]);
    $user = $stmt->fetch();

    if (!$user) {
        json_response(['error' => 'OTP verification required or expired'], 400);
    }

    $stmt = $pdo->prepare('UPDATE users SET password = ?, otp = NULL, otp_expires = NULL, otp_verified = 0 WHERE id = ?');
    $stmt->execute([password_hash($newPassword, PASSWORD_BCRYPT), $user['id']]);

    json_response(['message' => 'Password updated successfully']);
}

function sendName(PDO $pdo) {
    $user = require_auth($pdo);
    raw_json_response($user['name']);
}

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

function addTask(PDO $pdo, string $teamcode) {
    $user = require_auth($pdo);
    $body = request_body();
    $domainName = trim($body['domainName'] ?? '');
    $email = trim($body['email'] ?? '');
    $task = trim($body['task'] ?? '');
    $deadline = trim($body['deadline'] ?? '');

    if ($domainName === '' || $email === '' || $task === '') {
        text_response('domainName, email and task are required', 400);
    }

    $team = team_from_code($pdo, $teamcode);
    if (!$team) {
        text_response('Team not found', 404);
    }
    require_team_member($pdo, $team['id'], $user);

    $stmt = $pdo->prepare('INSERT INTO tasks (team_code, domain_name, email, description, deadline) VALUES (?, ?, ?, ?, ?)');
    $stmt->execute([$teamcode, $domainName, $email, $task, $deadline]);

    text_response('Task Added', 200);
}

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
        $pdo->rollBack();
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

// ---- handlers: chat ----------------------------------------------------

function getAllChats(PDO $pdo) {
    require_auth($pdo);
    $stmt = $pdo->query('SELECT username, message FROM chat_messages ORDER BY id ASC');
    json_response(['chats' => $stmt->fetchAll()]);
}

function sendChatMessage(PDO $pdo) {
    // El username se toma del token, nunca del body, para que nadie pueda
    // publicar en el chat haciéndose pasar por otra persona.
    $user = require_auth($pdo);
    $body = request_body();
    $message = trim($body['message'] ?? '');

    if ($message === '') {
        text_response('message is required', 400);
    }

    $stmt = $pdo->prepare('INSERT INTO chat_messages (username, message) VALUES (?, ?)');
    $stmt->execute([$user['email'], $message]);

    text_response('Message sent', 200);
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
        $leave['reason'] ?? '',
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

// ---- handlers: notifications --------------------------------------------

function listNotifications(PDO $pdo) {
    $user = require_auth($pdo);
    $stmt = $pdo->prepare(
        'SELECT id, team_id AS teamId, type, message, read_at AS readAt, created_at AS createdAt
         FROM notifications WHERE email = ? ORDER BY created_at DESC, id DESC LIMIT 100'
    );
    $stmt->execute([$user['email']]);
    json_response(['notifications' => $stmt->fetchAll()]);
}

function markNotificationRead(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    $stmt = $pdo->prepare('UPDATE notifications SET read_at = NOW() WHERE id = ? AND email = ? AND read_at IS NULL');
    $stmt->execute([$id, $user['email']]);
    if ($stmt->rowCount() === 0) {
        json_response(['error' => 'Notification not found'], 404);
    }
    json_response(['message' => 'Notification marked as read']);
}

// ---- handlers: organizational structure (companies/departments/roles) --
// Base RBAC para Radio Doliv: un único registro en `companies`, N
// `departments` colgando de él, y cada usuario con role/position/department_id.
// El resto de módulos (dashboards por rol, anuncios, reportes, workflow de
// tareas director->manager->employee) se construyen sobre esta base — ver
// Actualizacion.md para el resto del alcance, todavía pendiente.

function build_department_payload(PDO $pdo, array $dept): array {
    $stmt = $pdo->prepare('SELECT COUNT(*) AS n FROM users WHERE department_id = ?');
    $stmt->execute([$dept['id']]);
    $count = (int) $stmt->fetch()['n'];

    return [
        'id'            => $dept['id'],
        'companyId'     => $dept['company_id'],
        'name'          => $dept['name'],
        'description'   => $dept['description'],
        'managerEmail'  => $dept['manager_email'],
        'employeeCount' => $count,
    ];
}

function build_user_profile_payload(PDO $pdo, array $user): array {
    $department = null;
    if ($user['department_id']) {
        $stmt = $pdo->prepare('SELECT * FROM departments WHERE id = ?');
        $stmt->execute([$user['department_id']]);
        $dept = $stmt->fetch();
        if ($dept) {
            $department = build_department_payload($pdo, $dept);
        }
    }

    return [
        'id'         => $user['id'],
        'name'       => $user['name'],
        'email'      => $user['email'],
        'role'       => $user['role'],
        'position'   => $user['position'],
        'photoUrl'   => $user['photo_path'] ? UPLOAD_URL_BASE . $user['photo_path'] : null,
        'department' => $department,
    ];
}

// La app llama esto justo después de login para saber qué dashboard mostrar
// (Director / Manager / Employee) — el token en sí no lleva el rol.
function getMe(PDO $pdo) {
    $user = require_auth($pdo);
    json_response(build_user_profile_payload($pdo, $user));
}

// Sube/reemplaza la foto de perfil del usuario autenticado. Misma validación
// de tipo de archivo que addImage(); a diferencia de esa, aquí se borra el
// archivo anterior porque solo tiene sentido conservar una foto por usuario.
function updateProfilePhoto(PDO $pdo) {
    $user = require_auth($pdo);

    if (empty($_FILES['photo']) || $_FILES['photo']['error'] !== UPLOAD_ERR_OK) {
        error_response('photo is required', 400);
    }

    $tmpPath = $_FILES['photo']['tmp_name'];
    $originalName = $_FILES['photo']['name'];
    $ext = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));
    $allowed = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

    if (!in_array($ext, $allowed, true) || @getimagesize($tmpPath) === false) {
        error_response('Only image files are allowed', 400);
    }

    $storedName = bin2hex(random_bytes(16)) . '.' . $ext;
    if (!move_uploaded_file($tmpPath, UPLOAD_DIR . $storedName)) {
        error_response('Failed to save the uploaded image', 500);
    }

    $oldPath = $user['photo_path'];
    $stmt = $pdo->prepare('UPDATE users SET photo_path = ? WHERE id = ?');
    $stmt->execute([$storedName, $user['id']]);

    if ($oldPath) {
        $oldFile = UPLOAD_DIR . basename($oldPath);
        if (is_file($oldFile)) {
            @unlink($oldFile);
        }
    }

    $user['photo_path'] = $storedName;
    json_response(build_user_profile_payload($pdo, $user));
}

function get_the_company(PDO $pdo): ?array {
    $stmt = $pdo->query('SELECT * FROM companies ORDER BY created_at ASC LIMIT 1');
    $company = $stmt->fetch();
    return $company ?: null;
}

// Solo existe una empresa (Radio Doliv). El primer usuario autenticado que
// la crea queda promovido a director; llamadas posteriores fallan con 409
// porque ya existe — para editarla está POST /company/update.
function createCompany(PDO $pdo) {
    $user = require_auth($pdo);
    if (get_the_company($pdo) !== null) {
        error_response('La empresa ya fue creada', 409);
    }

    $body = request_body();
    $name = trim($body['name'] ?? '');
    if ($name === '') {
        error_response('name es requerido', 400);
    }

    $companyId = generate_id();
    $stmt = $pdo->prepare('INSERT INTO companies (id, name, description, logo) VALUES (?, ?, ?, ?)');
    $stmt->execute([$companyId, $name, trim($body['description'] ?? '') ?: null, trim($body['logo'] ?? '') ?: null]);

    $stmt = $pdo->prepare("UPDATE users SET role = 'director' WHERE id = ?");
    $stmt->execute([$user['id']]);

    $stmt = $pdo->prepare('SELECT * FROM companies WHERE id = ?');
    $stmt->execute([$companyId]);
    json_response(['company' => $stmt->fetch()]);
}

function getCompany(PDO $pdo) {
    require_auth($pdo);
    $company = get_the_company($pdo);
    if (!$company) {
        error_response('La empresa aún no ha sido creada', 404);
    }
    json_response(['company' => $company]);
}

function updateCompany(PDO $pdo) {
    $user = require_auth($pdo);
    require_role($user, ['director']);
    $company = get_the_company($pdo);
    if (!$company) {
        error_response('La empresa aún no ha sido creada', 404);
    }

    $body = request_body();
    $name = trim($body['name'] ?? $company['name']);
    if ($name === '') {
        error_response('name no puede estar vacío', 400);
    }

    $stmt = $pdo->prepare('UPDATE companies SET name = ?, description = ?, logo = ? WHERE id = ?');
    $stmt->execute([
        $name,
        array_key_exists('description', $body) ? (trim($body['description']) ?: null) : $company['description'],
        array_key_exists('logo', $body) ? (trim($body['logo']) ?: null) : $company['logo'],
        $company['id'],
    ]);

    $stmt = $pdo->prepare('SELECT * FROM companies WHERE id = ?');
    $stmt->execute([$company['id']]);
    json_response(['company' => $stmt->fetch()]);
}

function createDepartment(PDO $pdo) {
    $user = require_auth($pdo);
    require_role($user, ['director']);
    $company = get_the_company($pdo);
    if (!$company) {
        error_response('Crea la empresa antes de agregar departamentos', 400);
    }

    $body = request_body();
    $name = trim($body['name'] ?? '');
    if ($name === '') {
        error_response('name es requerido', 400);
    }

    $stmt = $pdo->prepare('SELECT id FROM departments WHERE company_id = ? AND name = ?');
    $stmt->execute([$company['id'], $name]);
    if ($stmt->fetch()) {
        error_response('Ya existe un departamento con ese nombre', 409);
    }

    $deptId = generate_id();
    $stmt = $pdo->prepare('INSERT INTO departments (id, company_id, name, description) VALUES (?, ?, ?, ?)');
    $stmt->execute([$deptId, $company['id'], $name, trim($body['description'] ?? '') ?: null]);

    $stmt = $pdo->prepare('SELECT * FROM departments WHERE id = ?');
    $stmt->execute([$deptId]);
    json_response(['department' => build_department_payload($pdo, $stmt->fetch())]);
}

function listDepartments(PDO $pdo) {
    require_auth($pdo);
    $stmt = $pdo->query('SELECT * FROM departments ORDER BY name ASC');
    $departments = array_map(fn($d) => build_department_payload($pdo, $d), $stmt->fetchAll());
    json_response(['departments' => $departments]);
}

// Asigna (o reemplaza) el manager de un departamento. El usuario destino
// debe existir; queda con role='manager' y department_id apuntando a este
// departamento. Solo el director puede hacerlo.
function assignDepartmentManager(PDO $pdo, string $departmentId) {
    $user = require_auth($pdo);
    require_role($user, ['director']);

    $stmt = $pdo->prepare('SELECT * FROM departments WHERE id = ?');
    $stmt->execute([$departmentId]);
    $dept = $stmt->fetch();
    if (!$dept) {
        error_response('Departamento no encontrado', 404);
    }

    $body = request_body();
    $email = trim($body['email'] ?? '');
    if ($email === '') {
        error_response('email es requerido', 400);
    }

    $stmt = $pdo->prepare('SELECT * FROM users WHERE email = ?');
    $stmt->execute([$email]);
    $target = $stmt->fetch();
    if (!$target) {
        error_response('No existe un usuario con ese correo', 404);
    }
    if ($target['role'] === 'director') {
        error_response('No se puede reasignar al director general', 400);
    }

    $stmt = $pdo->prepare('UPDATE departments SET manager_email = ? WHERE id = ?');
    $stmt->execute([$email, $departmentId]);

    $stmt = $pdo->prepare("UPDATE users SET role = 'manager', department_id = ? WHERE id = ?");
    $stmt->execute([$departmentId, $target['id']]);

    notify_user($pdo, $email, null, 'department_manager_assigned',
        'Ahora eres el manager del departamento "' . $dept['name'] . '"');

    $stmt = $pdo->prepare('SELECT * FROM departments WHERE id = ?');
    $stmt->execute([$departmentId]);
    json_response(['department' => build_department_payload($pdo, $stmt->fetch())]);
}

// Agrega (o mueve) a un empleado dentro de un departamento. El director
// puede hacerlo sobre cualquier departamento; el manager, solo sobre el
// suyo. No permite tocar a un director ni a otro manager por esta vía.
function assignDepartmentEmployee(PDO $pdo, string $departmentId) {
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
    $position = trim($body['position'] ?? '');
    if ($email === '') {
        error_response('email es requerido', 400);
    }

    $stmt = $pdo->prepare('SELECT * FROM users WHERE email = ?');
    $stmt->execute([$email]);
    $target = $stmt->fetch();
    if (!$target) {
        error_response('No existe un usuario con ese correo', 404);
    }
    if (in_array($target['role'], ['director', 'manager'], true)) {
        error_response('No se puede reasignar a un director o manager por esta vía', 400);
    }

    $stmt = $pdo->prepare('UPDATE users SET department_id = ?, position = ? WHERE id = ?');
    $stmt->execute([$departmentId, $position ?: null, $target['id']]);

    notify_user($pdo, $email, null, 'department_assigned',
        'Fuiste asignado al departamento "' . $dept['name'] . '"');

    $stmt = $pdo->prepare('SELECT * FROM departments WHERE id = ?');
    $stmt->execute([$departmentId]);
    json_response(['department' => build_department_payload($pdo, $stmt->fetch())]);
}
