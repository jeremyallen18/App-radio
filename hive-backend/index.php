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
    ['POST', '#^/team/taskUpdate/([^/]+)/?$#',                'updateTeamTask'],
    ['POST', '#^/team/taskDone/?$#',                          'taskDone'],
    ['GET',  '#^/team/incompleteTasks/?$#',                   'incompleteTasks'],
    ['GET',  '#^/team/completedTasks/?$#',                    'completedTasks'],
    ['POST', '#^/team/addMember/([^/]+)/?$#',                 'addMember'],
    ['POST', '#^/team/deleteMember/([^/]+)/?$#',              'deleteMember'],
    ['POST', '#^/team/resign/([^/]+)/?$#',                    'resignFromTeam'],
    ['POST', '#^/team/deleteTeam/([^/]+)/?$#',                'deleteTeam'],
    ['POST', '#^/team/leaderResign/([^/]+)/?$#',              'leaderResign'],
    ['GET',  '#^/chat/getAllChats/([^/]+)/?$#',               'getAllChats'],
    ['POST', '#^/chat/sendMessage/([^/]+)/?$#',               'sendChatMessage'],
    // Chat privado 1 a 1 (p.ej. al tocar el correo de un integrante de un
    // área en teamDetail.dart). El destinatario va en el body/query en vez
    // de la URL para no lidiar con el @ y los puntos del correo al
    // matchear la ruta (mismo criterio que memberEmail en addMember/
    // deleteMember).
    ['GET',  '#^/chat/direct/?$#',                            'getDirectChat'],
    ['POST', '#^/chat/direct/?$#',                            'sendDirectMessage'],
    // Lista combinada de "chats" (equipos + conversaciones directas) para
    // el dashboard tipo WhatsApp de la pantalla "Mensajes". Cada entrada
    // trae el último mensaje para poder armar la vista previa.
    ['GET',  '#^/chat/list/?$#',                              'listChats'],
    // Marca un chat (de equipo o directo) como leído hasta ahora, para que
    // deje de contar en 'unreadCount' (GET /chat/list). Se llama al entrar
    // a ChatScreen/DirectChatScreen.
    ['POST', '#^/chat/read/?$#',                              'markChatRead'],
    ['GET',  '#^/image/showImage/([^/]+)/?$#',                'showImage'],
    ['POST', '#^/image/addImage/?$#',                         'addImage'],
    // Documentos "de verdad" (PDF, Word, Excel, etc.) del apartado
    // Documentos de Resource Manager. La descarga pasa por PHP (en vez de
    // un enlace estático a /uploads/) para forzar Content-Disposition y
    // devolver el nombre original del archivo.
    ['GET',  '#^/document/showDocuments/([^/]+)/?$#',         'showDocuments'],
    ['POST', '#^/document/addDocument/?$#',                   'addDocument'],
    ['GET',  '#^/document/download/([^/]+)/?$#',              'downloadDocument'],
    ['DELETE', '#^/document/([^/]+)/?$#',                     'deleteDocument'],
    ['POST', '#^/text/addText/([^/]+)/?$#',                   'addText'],
    ['GET',  '#^/text/showText/([^/]+)/?$#',                  'showText'],
    ['POST', '#^/leave/applyLeave/([^/]+)/?$#',                'applyLeave'],
    ['POST', '#^/leave/leaveResult/([^/]+)/?$#',               'leaveResult'],
    ['GET',  '#^/notifications/?$#',                          'listNotifications'],
    ['POST', '#^/notifications/([^/]+)/read/?$#',             'markNotificationRead'],
    ['DELETE', '#^/notifications/?$#',                        'deleteAllNotifications'],
    ['DELETE', '#^/notifications/([^/]+)/?$#',                'deleteNotification'],
    ['GET',  '#^/user/me/?$#',                                'getMe'],
    ['POST', '#^/user/updatePhoto/?$#',                       'updateProfilePhoto'],
    ['POST', '#^/company/create/?$#',                         'createCompany'],
    ['GET',  '#^/company/info/?$#',                           'getCompany'],
    ['POST', '#^/company/update/?$#',                         'updateCompany'],
    ['POST', '#^/department/create/?$#',                      'createDepartment'],
    ['GET',  '#^/department/list/?$#',                        'listDepartments'],
    ['POST', '#^/department/assignManager/([^/]+)/?$#',       'assignDepartmentManager'],
    ['POST', '#^/department/assignEmployee/([^/]+)/?$#',      'assignDepartmentEmployee'],
    // Workflow jerárquico de tareas: Director -> Departamento -> Manager ->
    // Empleado -> completa -> Manager valida -> Director ve estadísticas.
    ['POST', '#^/department/task/([^/]+)/?$#',                'createDepartmentTask'],
    ['GET',  '#^/department/task/([^/]+)/list/?$#',           'listDepartmentTasks'],
    ['POST', '#^/department/task/([^/]+)/assign/?$#',         'assignDepartmentTask'],
    ['POST', '#^/department/task/([^/]+)/complete/?$#',       'completeDepartmentTask'],
    ['POST', '#^/department/task/([^/]+)/approve/?$#',        'approveDepartmentTask'],
    ['GET',  '#^/department/stats/?$#',                       'departmentTaskStats'],
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

    // No mail server is configured on this local backend, so the OTP is
    // logged instead of emailed -- check Apache's error log to read it.
    error_log("[hive-backend] Password reset OTP for $email: $otp");

    json_response(['message' => 'OTP generated (check the backend log, no mail server is configured)']);
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
    $email = trim($body['Correo'] ?? $body['Email'] ?? $body['email'] ?? $user['email']);
    $message = trim($body['message'] ?? '');

    if ($message === '') {
        text_response('Message is required', 400);
    }

    $stmt = $pdo->prepare('INSERT INTO leader_messages (team_id, email, message) VALUES (?, ?, ?)');
    $stmt->execute([$teamId, $email, $message]);

    // A quien reciba el mensaje (normalmente el líder) le debe llegar una
    // notificación avisando que le escribieron.
    if ($email !== '' && strcasecmp($email, $user['email']) !== 0) {
        $preview = text_preview($message);
        notify_user($pdo, $email, $teamId, 'message_received',
            $user['name'] . ' te envió un mensaje: "' . $preview . '"');
    }

    text_response('Message sent', 200);
}

// ---- handlers: team ----------------------------------------------------

// teamDetail.dart espera el equipo anidado: domains[] -> members[] (correos)
// y tasks[] (description/assignedTo/deadline/completed). 'completed' tiene que
// ser un booleano de verdad porque Dart compara con `== false` y no convierte
// 0/1 automáticamente.
// $viewerEmail, si se pasa, filtra las tareas de cada área para que un
// miembro normal solo vea las que tiene asignadas a sí mismo; el líder
// siempre ve todas. Si no se pasa (por ejemplo justo al crear el equipo,
// donde el creador siempre es el líder), no se filtra nada.
function build_team_payload(PDO $pdo, array $team, ?string $viewerEmail = null): array {
    $stmt = $pdo->prepare('SELECT id, name FROM domains WHERE team_id = ? ORDER BY id ASC');
    $stmt->execute([$team['id']]);
    $domains = $stmt->fetchAll();

    $stmt = $pdo->prepare('SELECT id, domain_name, email, description, deadline, completed FROM tasks WHERE team_code = ? ORDER BY id ASC');
    $stmt->execute([$team['team_code']]);
    $tasksByDomain = [];
    foreach ($stmt->fetchAll() as $t) {
        $tasksByDomain[$t['domain_name']][] = [
            'id'          => (string) $t['id'],
            'description' => $t['description'],
            'assignedTo'  => $t['email'],
            'deadline'    => $t['deadline'],
            'completed'   => (bool) $t['completed'],
        ];
    }

    $isLeader = $viewerEmail !== null && strcasecmp($viewerEmail, $team['leader_email']) === 0;

    // Se busca el nombre del líder para mostrarlo en teamDetail.dart en vez
    // del correo (o de la parte antes de la @); si la cuenta ya no existe
    // se cae de vuelta a null y el front-end usa el correo como respaldo.
    $stmt = $pdo->prepare('SELECT name FROM users WHERE email = ?');
    $stmt->execute([$team['leader_email']]);
    $leaderName = $stmt->fetchColumn() ?: null;

    $out = [];
    foreach ($domains as $d) {
        $stmt = $pdo->prepare('SELECT email FROM domain_members WHERE domain_id = ? ORDER BY id ASC');
        $stmt->execute([$d['id']]);
        $domainTasks = $tasksByDomain[$d['name']] ?? [];
        // Solo el líder del equipo y la persona asignada pueden ver una
        // tarea; cualquier otro miembro no la ve en absoluto.
        if ($viewerEmail !== null && !$isLeader) {
            $domainTasks = array_values(array_filter(
                $domainTasks,
                fn($t) => strcasecmp((string) $t['assignedTo'], $viewerEmail) === 0
            ));
        }
        $out[] = [
            '_id'     => (string) $d['id'],
            'name'    => $d['name'],
            'members' => array_column($stmt->fetchAll(), 'email'),
            'tasks'   => $domainTasks,
        ];
    }

    // Lista de miembros a nivel de equipo (independiente de las áreas), para
    // la pantalla de "Gestionar miembros" (agregar por correo / sacar del
    // grupo).
    $stmt = $pdo->prepare('SELECT email FROM team_members WHERE team_id = ? ORDER BY id ASC');
    $stmt->execute([$team['id']]);
    $teamMembers = array_column($stmt->fetchAll(), 'email');

    return [
        '_id'         => $team['id'],
        'teamName'    => $team['team_name'],
        'teamCode'    => $team['team_code'],
        'leaderEmail' => $team['leader_email'],
        'leaderName'  => $leaderName,
        'domains'     => $out,
        'teamMembers' => $teamMembers,
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
                    if ($stmt->rowCount() > 0 && strcasecmp($memberEmail, $user['email']) !== 0) {
                        notify_user($pdo, $memberEmail, $teamId, 'member_added',
                            'Fuiste agregado al equipo "' . $teamName . '"');
                    }
                }
            }
        }
    }

    $stmt = $pdo->prepare('SELECT * FROM teams WHERE id = ?');
    $stmt->execute([$teamId]);
    json_response(['team' => build_team_payload($pdo, $stmt->fetch(), $user['email'])]);
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
            if ($stmt->rowCount() > 0 && strcasecmp($email, $user['email']) !== 0) {
                notify_user($pdo, $email, $teamId, 'member_added',
                    'Fuiste agregado al equipo "' . $team['team_name'] . '"');
            }
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

    // Mismo motivo que en addMember(): sin esto, quien se une por código
    // queda "en el equipo" pero invisible para que le asignen tareas en
    // cualquier área (addTask.dart arma el selector desde domain_members).
    $stmt = $pdo->prepare('SELECT id FROM domains WHERE team_id = ?');
    $stmt->execute([$team['id']]);
    foreach ($stmt->fetchAll() as $domain) {
        $check = $pdo->prepare('SELECT 1 FROM domain_members WHERE domain_id = ? AND email = ? LIMIT 1');
        $check->execute([$domain['id'], $user['email']]);
        if (!$check->fetch()) {
            $insert = $pdo->prepare('INSERT INTO domain_members (domain_id, email) VALUES (?, ?)');
            $insert->execute([$domain['id'], $user['email']]);
        }
    }

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

    $teams = array_map(fn($r) => build_team_payload($pdo, $r, $user['email']), $rows);

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
    // Solo el admin/líder del equipo puede crear tareas. El front-end ya
    // ocultaba el botón "Agregar tarea" a quien no fuera líder, pero el
    // endpoint no lo exigía; ahora también se valida aquí.
    require_team_leader($pdo, $team['id'], $user);

    // La persona asignada debe pertenecer a esa área del equipo (el
    // front-end ya solo deja elegir miembros del área, esto lo respalda
    // por si alguien llama al endpoint directamente).
    $stmt = $pdo->prepare('SELECT id FROM domains WHERE team_id = ? AND name = ?');
    $stmt->execute([$team['id'], $domainName]);
    $domain = $stmt->fetch();
    if (!$domain) {
        text_response('Domain not found in this team', 404);
    }
    $stmt = $pdo->prepare('SELECT 1 FROM domain_members WHERE domain_id = ? AND email = ? LIMIT 1');
    $stmt->execute([$domain['id'], $email]);
    if (!$stmt->fetch()) {
        text_response('That person does not belong to this domain', 403);
    }

    // Una fila por cada persona asignada: la app permite marcar varios
    // miembros a la vez y llama a este endpoint una vez por cada uno, así
    // que aquí sigue insertando una sola tarea/asignación por llamada.
    $stmt = $pdo->prepare('INSERT INTO tasks (team_code, domain_name, email, description, deadline) VALUES (?, ?, ?, ?, ?)');
    $stmt->execute([$teamcode, $domainName, $email, $task, $deadline]);

    notify_user($pdo, $email, $team['id'], 'task_assigned',
        'Se te asignó la tarea "' . $task . '" en "' . $domainName . '"');

    text_response('Task Added', 200);
}

function taskDone(PDO $pdo) {
    $user = require_auth($pdo);
    $body = request_body();
    $teamCode = trim($body['teamCode'] ?? '');
    $domainName = trim($body['domainName'] ?? '');
    $email = trim($body['email'] ?? '');
    $task = trim($body['task'] ?? '');
    // Nuevo: si el cliente manda taskId (tasks_for_user() ahora lo incluye),
    // se usa para identificar la fila sin ambigüedad. Antes solo se
    // matcheaba por team_code+domain_name+email+description con LIMIT 1,
    // así que si la misma persona tenía dos tareas con el mismo texto (p.
    // ej. una tarea recurrente asignada de nuevo), no había forma de saber
    // cuál de las dos se estaba completando — se completaba una al azar.
    // Se mantiene el matcheo por contenido como respaldo para builds viejos
    // del app que todavía no mandan taskId.
    $taskId = trim((string) ($body['taskId'] ?? ''));

    $team = team_from_code($pdo, $teamCode);
    if (!$team) {
        text_response('Team not found', 404);
    }
    require_team_member($pdo, $team['id'], $user);

    if ($taskId !== '') {
        // Solo la persona asignada puede completar su propia tarea por id
        // (misma regla que ya aplicaba el matcheo por contenido: email debe
        // coincidir).
        $stmt = $pdo->prepare(
            'UPDATE tasks SET completed = 1
             WHERE id = ? AND team_code = ? AND email = ? AND completed = 0'
        );
        $stmt->execute([$taskId, $teamCode, $email]);
    } else {
        $stmt = $pdo->prepare(
            'UPDATE tasks SET completed = 1
             WHERE team_code = ? AND domain_name = ? AND email = ? AND description = ? AND completed = 0
             LIMIT 1'
        );
        $stmt->execute([$teamCode, $domainName, $email, $task]);
    }

    if ($stmt->rowCount() === 0) {
        text_response('Task not found', 404);
    }

    // Avisa al líder/admin del equipo de que alguien completó una tarea,
    // igual que ya hace completeDepartmentTask() con el manager. No se
    // notifica si el propio líder es quien la completó (p. ej. una tarea
    // que se autoasignó).
    if (!empty($team['leader_email']) && $team['leader_email'] !== $email) {
        notify_user($pdo, $team['leader_email'], $team['id'], 'task_completed',
            $user['name'] . ' completó la tarea "' . $task . '" en "' . $domainName . '"');
    }

    text_response('Task marked as done', 200);
}

// Edita una tarea de equipo ya creada, identificada por su id (a diferencia
// de taskDone(), que la matchea por team_code+domain_name+email+description
// — eso deja de servir en cuanto se edita la descripción). Usada desde el
// menú de acciones de "Elige la tarea a completar" en teamDetail.dart para:
//   - Reasignar: cambia `email` a otro miembro de la misma área.
//   - Reprogramar: cambia `description` y/o `deadline`.
//   - Marcar como completa: cambia `completed`.
// Cualquier combinación de esos campos puede llegar en el mismo request;
// solo se actualiza lo que venga presente en el body.
function updateTeamTask(PDO $pdo, string $taskId) {
    $user = require_auth($pdo);

    $stmt = $pdo->prepare('SELECT * FROM tasks WHERE id = ?');
    $stmt->execute([$taskId]);
    $task = $stmt->fetch();
    if (!$task) {
        text_response('Task not found', 404);
    }

    $team = team_from_code($pdo, $task['team_code']);
    if (!$team) {
        text_response('Team not found', 404);
    }
    // Solo el líder del equipo puede reasignar, reprogramar, editar o
    // completar tareas desde este menú (misma regla que addTask()).
    require_team_leader($pdo, $team['id'], $user);

    $body = request_body();
    // `emails` (lista, separada por comas) es el campo nuevo que permite
    // reasignar "Volver a asignar tarea" a una o varias personas a la vez
    // desde teamDetail.dart. Se sigue aceptando `email` (uno solo) por
    // compatibilidad con clientes/builds viejos que todavía lo manden así.
    $newEmails = [];
    if (array_key_exists('emails', $body) && trim((string) $body['emails']) !== '') {
        $newEmails = array_values(array_unique(array_filter(array_map(
            'trim',
            explode(',', (string) $body['emails'])
        ), fn($e) => $e !== '')));
    } elseif (array_key_exists('email', $body) && trim((string) $body['email']) !== '') {
        $newEmails = [trim((string) $body['email'])];
    }
    $newDescription = array_key_exists('description', $body) ? trim((string) $body['description']) : null;
    $newDeadline = array_key_exists('deadline', $body) ? trim((string) $body['deadline']) : null;
    $newCompleted = array_key_exists('completed', $body)
        ? filter_var($body['completed'], FILTER_VALIDATE_BOOLEAN)
        : null;

    // Se trata como reasignación cualquier `emails`/`email` presente en el
    // body, sin importar si son las mismas personas que ya tenían la tarea:
    // reasignar a quien ya la tenía es una acción válida (p. ej. para
    // reenviarle la notificación de "se te asignó esta tarea" a modo de
    // recordatorio), así que no se descarta comparando contra `$task['email']`.
    $isReassign = !empty($newEmails);

    if ($isReassign) {
        // Todas las personas nuevas asignadas deben pertenecer a la misma
        // área, igual que al crear la tarea.
        $stmt = $pdo->prepare('SELECT id FROM domains WHERE team_id = ? AND name = ?');
        $stmt->execute([$team['id'], $task['domain_name']]);
        $domain = $stmt->fetch();
        if (!$domain) {
            text_response('Domain not found in this team', 404);
        }
        foreach ($newEmails as $candidateEmail) {
            $stmt = $pdo->prepare('SELECT 1 FROM domain_members WHERE domain_id = ? AND email = ? LIMIT 1');
            $stmt->execute([$domain['id'], $candidateEmail]);
            if (!$stmt->fetch()) {
                text_response('That person does not belong to this domain', 403);
            }
        }
    }

    $finalDescription = ($newDescription !== null && $newDescription !== '') ? $newDescription : $task['description'];
    $finalDeadline = ($newDeadline !== null && $newDeadline !== '') ? $newDeadline : $task['deadline'];
    $deadlineChanged = $newDeadline !== null && $newDeadline !== '' && $newDeadline !== $task['deadline'];

    $fields = [];
    $params = [];
    if ($isReassign) {
        // La primera persona seleccionada se queda con esta misma fila (y
        // conserva su id); si se eligió a más de una, el resto recibe filas
        // nuevas (misma idea que addTask(), que inserta una fila por
        // asignado). Al reasignar, la tarea siempre vuelve a quedar
        // pendiente para quien(es) la reciben, aunque ya estuviera marcada
        // como completa.
        $fields[] = 'email = ?';
        $params[] = $newEmails[0];
        $fields[] = 'completed = 0';
    }
    if ($newDescription !== null && $newDescription !== '' && $newDescription !== $task['description']) {
        $fields[] = 'description = ?';
        $params[] = $newDescription;
    }
    if ($deadlineChanged) {
        $fields[] = 'deadline = ?';
        $params[] = $newDeadline;
    }
    if (!$isReassign && $newCompleted !== null && $newCompleted !== (bool) $task['completed']) {
        $fields[] = 'completed = ?';
        $params[] = $newCompleted ? 1 : 0;
    }

    if (empty($fields)) {
        text_response('Nothing to update', 200);
    }

    $params[] = $taskId;
    $stmt = $pdo->prepare('UPDATE tasks SET ' . implode(', ', $fields) . ' WHERE id = ?');
    $stmt->execute($params);

    // Personas adicionales (más allá de la primera) reciben una fila nueva
    // de tarea propia, con la misma descripción y fecha final que acaba de
    // quedar guardada.
    if ($isReassign && count($newEmails) > 1) {
        $insert = $pdo->prepare(
            'INSERT INTO tasks (team_code, domain_name, email, description, deadline) VALUES (?, ?, ?, ?, ?)'
        );
        for ($i = 1; $i < count($newEmails); $i++) {
            $insert->execute([
                $task['team_code'],
                $task['domain_name'],
                $newEmails[$i],
                $finalDescription,
                $finalDeadline,
            ]);
        }
    }

    if ($isReassign) {
        // Todas las personas seleccionadas reciben la notificación de
        // reasignación, incluida quien ya tenía la tarea antes (sirve como
        // recordatorio de que se le volvió a asignar).
        foreach ($newEmails as $assigneeEmail) {
            notify_user($pdo, $assigneeEmail, $team['id'], 'task_assigned',
                'Se te asignó la tarea "' . $finalDescription . '" en "' . $task['domain_name'] . '"');
        }
    } elseif ($deadlineChanged) {
        notify_user($pdo, $task['email'], $team['id'], 'task_assigned',
            'Se reprogramó la tarea "' . $finalDescription . '" para el ' . $newDeadline);
    }

    text_response('Task updated', 200);
}

// teamCode y domainName viajan además de la descripción porque la lista de
// tareas (home_page/tasks.dart) los necesita para poder marcar una tarea como
// hecha sin tener que entrar al detalle del equipo.
function tasks_for_user(PDO $pdo, string $email, int $completed): array {
    // Antes esto solo filtraba por tk.email, así que si alguien renunciaba
    // o lo sacaban del equipo, sus tareas de ese equipo seguían apareciendo
    // en "Mis tareas" (las filas de la tabla tasks no se borran al salir).
    // Ahora, para tareas de equipo (team_code no vacío), se exige además
    // que el correo siga en team_members de ese equipo; las tareas de
    // departamento (team_code = '') no usan team_members y no se filtran.
    $stmt = $pdo->prepare(
        'SELECT tk.id, tk.description, tk.email AS assignedTo, tk.deadline,
                tk.team_code AS teamCode, tk.domain_name AS domainName,
                t.team_name AS teamName
         FROM tasks tk
         LEFT JOIN teams t ON t.team_code = tk.team_code
         WHERE tk.email = ? AND tk.completed = ?
           AND (
             tk.team_code = \'\'
             OR EXISTS (
               SELECT 1 FROM team_members tm
               WHERE tm.team_id = t.id AND tm.email = tk.email
             )
           )
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

// El líder agrega un miembro directamente por correo (sin pasar por el
// código de equipo). Reemplaza al flujo antiguo donde solo se podía unir
// alguien uniéndose con teamCode.
function addMember(PDO $pdo, string $teamId) {
    $user = require_auth($pdo);
    require_team_leader($pdo, $teamId, $user);
    $body = request_body();
    $memberEmail = trim($body['memberEmail'] ?? '');

    if ($memberEmail === '') {
        text_response('memberEmail is required', 400);
    }
    if (!filter_var($memberEmail, FILTER_VALIDATE_EMAIL)) {
        text_response('memberEmail is not a valid email address', 400);
    }

    $stmt = $pdo->prepare('SELECT id, team_name FROM teams WHERE id = ?');
    $stmt->execute([$teamId]);
    $team = $stmt->fetch();
    if (!$team) {
        text_response('Team not found', 404);
    }

    $stmt = $pdo->prepare('SELECT 1 FROM team_members WHERE team_id = ? AND email = ? LIMIT 1');
    $stmt->execute([$teamId, $memberEmail]);
    if ($stmt->fetch() || strcasecmp($memberEmail, $user['email']) === 0) {
        text_response('That person is already a member of this team', 409);
    }

    $stmt = $pdo->prepare('INSERT INTO team_members (team_id, email) VALUES (?, ?)');
    $stmt->execute([$teamId, $memberEmail]);

    // addTask.dart arma el selector de "Asignar a" a partir de los miembros
    // de cada área (domain_members), no de team_members — así que sin esto
    // la persona quedaba "en el equipo" pero invisible para asignarle
    // tareas en cualquier área. Se le agrega a todas las áreas que ya
    // existen en el equipo, igual que hacen createTeam/sendTeamcode al
    // invitar por área. (El chat y los mensajes al líder ya funcionaban:
    // se basan en team_members, no en domain_members.)
    $stmt = $pdo->prepare('SELECT id FROM domains WHERE team_id = ?');
    $stmt->execute([$teamId]);
    foreach ($stmt->fetchAll() as $domain) {
        $check = $pdo->prepare('SELECT 1 FROM domain_members WHERE domain_id = ? AND email = ? LIMIT 1');
        $check->execute([$domain['id'], $memberEmail]);
        if (!$check->fetch()) {
            $insert = $pdo->prepare('INSERT INTO domain_members (domain_id, email) VALUES (?, ?)');
            $insert->execute([$domain['id'], $memberEmail]);
        }
    }

    notify_user($pdo, $memberEmail, $teamId, 'member_added',
        'Fuiste agregado al equipo "' . ($team['team_name'] ?? '') . '"');

    text_response('Member added', 200);
}

// Un miembro (no el líder) renuncia por su cuenta al equipo. A diferencia
// de deleteMember (que el líder usa para sacar a alguien), aquí el propio
// usuario autenticado es quien sale, y son el resto de los integrantes del
// equipo (líder incluido) quienes reciben la notificación, no la persona
// que renuncia.
function resignFromTeam(PDO $pdo, string $teamId) {
    $user = require_auth($pdo);
    require_team_member($pdo, $teamId, $user);

    $stmt = $pdo->prepare('SELECT team_name, leader_email FROM teams WHERE id = ?');
    $stmt->execute([$teamId]);
    $team = $stmt->fetch();
    if (!$team) {
        text_response('Team not found', 404);
    }
    if (strcasecmp($user['email'], $team['leader_email']) === 0) {
        text_response('El líder no puede renunciar; transfiere el liderazgo primero', 400);
    }

    // Se leen los miembros restantes (incluido el líder) antes de borrar,
    // para poder avisarles a todos que esta persona salió del equipo.
    $stmt = $pdo->prepare('SELECT email FROM team_members WHERE team_id = ? AND email <> ?');
    $stmt->execute([$teamId, $user['email']]);
    $remainingMembers = array_column($stmt->fetchAll(), 'email');
    if (!in_array($team['leader_email'], $remainingMembers, true)) {
        $remainingMembers[] = $team['leader_email'];
    }

    $stmt = $pdo->prepare('DELETE FROM team_members WHERE team_id = ? AND email = ?');
    $stmt->execute([$teamId, $user['email']]);

    $stmt = $pdo->prepare('DELETE FROM domain_members WHERE email = ? AND domain_id IN (SELECT id FROM domains WHERE team_id = ?)');
    $stmt->execute([$user['email'], $teamId]);

    // Todo el equipo (no solo el líder) recibe la notificación de que esta
    // persona salió del grupo.
    foreach ($remainingMembers as $memberEmail) {
        notify_user($pdo, $memberEmail, $teamId, 'member_resigned',
            'La persona "' . $user['name'] . '" salió del grupo "' . $team['team_name'] . '"');
    }

    text_response('Has salido del equipo', 200);
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

    // Antes esto siempre respondía 200 aunque no se hubiera borrado nada
    // (por ejemplo, si el correo ya no pertenecía al equipo), lo que hacía
    // que la app diera por hecho que "Sacar del grupo" funcionó cuando en
    // realidad no cambió nada en la base de datos. Ahora se informa el
    // fallo con 404 para que el front-end lo refleje correctamente.
    if ($removed === 0) {
        text_response('Member not found in this team', 404);
    }

    $stmt = $pdo->prepare('SELECT team_name FROM teams WHERE id = ?');
    $stmt->execute([$teamId]);
    $team = $stmt->fetch();
    notify_user($pdo, $memberEmail, $teamId, 'member_removed',
        'Fuiste eliminado del equipo "' . ($team['team_name'] ?? '') . '"');

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
        // referencia al equipo porque este deja de existir. Su mensaje
        // original (p.ej. "Se te asignó la tarea...") ya no tiene sentido
        // sin el equipo detrás, así que se reemplaza por un aviso genérico
        // en vez de dejar un mensaje que apunta a algo que ya no existe.
        $stmt = $pdo->prepare(
            "UPDATE notifications
             SET team_id = NULL, type = 'team_content_removed',
                 message = 'La notificación no esta disponible ya que el encargado elimino el grupo'
             WHERE team_id = ?"
        );
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

// Arma la vista previa de un chat en el dashboard "Mensajes" (tipo
// WhatsApp): "Tú: mensaje" si el último mensaje lo escribió el usuario
// actual; en un chat de equipo (grupo), el nombre de quien lo escribió si
// fue otra persona; en un chat directo, el mensaje solo (ya se sabe quién
// es el remitente: la otra persona del hilo).
function chat_preview(array $row, string $me, bool $isGroup): string {
    $text = text_preview($row['message'], 60);
    if ($row['username'] === $me) {
        return 'Tú: ' . $text;
    }
    if ($isGroup) {
        $sender = $row['display_name'] ?: $row['username'];
        return $sender . ': ' . $text;
    }
    return $text;
}

// Lista combinada de chats de equipo (grupo) y chats directos a los que
// pertenece el usuario, con el mensaje más reciente de cada uno, para la
// pantalla "Mensajes" (dashboard tipo WhatsApp). No se listan equipos o
// personas con los que no se comparte hilo: equipos vienen de
// team_members (igual que showTeams); conversaciones directas, de
// chat_messages donde el usuario participa como remitente o destinatario.
function listChats(PDO $pdo) {
    $user = require_auth($pdo);
    $me = $user['email'];

    $stmt = $pdo->prepare(
        'SELECT t.id, t.team_name
         FROM teams t
         JOIN team_members tm ON tm.team_id = t.id
         WHERE tm.email = ?'
    );
    $stmt->execute([$me]);
    $teams = $stmt->fetchAll();

    $teamLastMessages = [];
    if ($teams) {
        $teamIds = array_column($teams, 'id');
        $placeholders = implode(',', array_fill(0, count($teamIds), '?'));
        $stmt = $pdo->prepare(
            "SELECT cm.team_id, cm.message, cm.username, cm.created_at, u.name AS display_name
             FROM chat_messages cm
             INNER JOIN (
                 SELECT team_id, MAX(id) AS max_id
                 FROM chat_messages
                 WHERE team_id IN ($placeholders)
                 GROUP BY team_id
             ) last ON last.team_id = cm.team_id AND last.max_id = cm.id
             LEFT JOIN users u ON u.email = cm.username"
        );
        $stmt->execute($teamIds);
        foreach ($stmt->fetchAll() as $row) {
            $teamLastMessages[$row['team_id']] = $row;
        }
    }

    // Cuántos mensajes de cada equipo todavía no leí: mensajes que no
    // escribí yo, y son más nuevos que mi chat_reads para ese equipo (si
    // nunca entré a ese chat, cuentan todos). Un LEFT JOIN para poder
    // aplicar ese corte por equipo en una sola consulta, en vez de una
    // consulta por equipo.
    $teamUnread = [];
    if ($teams) {
        $stmt = $pdo->prepare(
            "SELECT cm.team_id, COUNT(*) AS unread
             FROM chat_messages cm
             LEFT JOIN chat_reads cr
                 ON cr.user_email = ? AND cr.chat_key = CONCAT('team:', cm.team_id)
             WHERE cm.team_id IN ($placeholders)
               AND cm.username <> ?
               AND (cr.last_read_at IS NULL OR cm.created_at > cr.last_read_at)
             GROUP BY cm.team_id"
        );
        $stmt->execute(array_merge([$me], $teamIds, [$me]));
        foreach ($stmt->fetchAll() as $row) {
            $teamUnread[$row['team_id']] = (int) $row['unread'];
        }
    }

    $chats = [];
    foreach ($teams as $t) {
        $last = $teamLastMessages[$t['id']] ?? null;
        $chats[] = [
            'type'          => 'team',
            'id'            => $t['id'],
            'title'         => $t['team_name'],
            'photoUrl'      => null,
            'lastMessage'   => $last ? chat_preview($last, $me, true) : null,
            'lastMessageAt' => $last['created_at'] ?? null,
            'unreadCount'   => $teamUnread[$t['id']] ?? 0,
        ];
    }

    // Un mensaje directo pertenece al hilo con "la otra persona" — la
    // subconsulta calcula quién es esa persona (peer_email) según si el
    // usuario actual fue el remitente o el destinatario de cada fila, y
    // luego nos quedamos con el más reciente por cada peer_email.
    $stmt = $pdo->prepare(
        'SELECT t.peer_email, t.message, t.username, t.created_at,
                u.name AS display_name, u.photo_path
         FROM (
             SELECT
                 CASE WHEN cm.username = ? THEN cm.recipient_email ELSE cm.username END AS peer_email,
                 cm.message, cm.username, cm.created_at, cm.id
             FROM chat_messages cm
             WHERE cm.team_id IS NULL AND (cm.username = ? OR cm.recipient_email = ?)
         ) t
         INNER JOIN (
             SELECT
                 CASE WHEN cm.username = ? THEN cm.recipient_email ELSE cm.username END AS peer_email,
                 MAX(cm.id) AS max_id
             FROM chat_messages cm
             WHERE cm.team_id IS NULL AND (cm.username = ? OR cm.recipient_email = ?)
             GROUP BY peer_email
         ) last ON last.peer_email = t.peer_email AND last.max_id = t.id
         LEFT JOIN users u ON u.email = t.peer_email'
    );
    $stmt->execute([$me, $me, $me, $me, $me, $me]);

    // Mensajes directos que me mandó cada persona y todavía no leí: solo
    // cuentan los que me enviaron a mí (no los que yo mandé), más nuevos
    // que mi chat_reads para ese peer_email.
    $directUnread = [];
    $stmt2 = $pdo->prepare(
        "SELECT cm.username AS peer_email, COUNT(*) AS unread
         FROM chat_messages cm
         LEFT JOIN chat_reads cr
             ON cr.user_email = ? AND cr.chat_key = CONCAT('direct:', cm.username)
         WHERE cm.team_id IS NULL AND cm.recipient_email = ?
           AND (cr.last_read_at IS NULL OR cm.created_at > cr.last_read_at)
         GROUP BY cm.username"
    );
    $stmt2->execute([$me, $me]);
    foreach ($stmt2->fetchAll() as $row) {
        $directUnread[$row['peer_email']] = (int) $row['unread'];
    }

    foreach ($stmt->fetchAll() as $row) {
        $chats[] = [
            'type'          => 'direct',
            'id'            => $row['peer_email'],
            'title'         => $row['display_name'] ?: $row['peer_email'],
            'photoUrl'      => !empty($row['photo_path']) ? UPLOAD_URL_BASE . $row['photo_path'] : null,
            'lastMessage'   => chat_preview($row, $me, false),
            'lastMessageAt' => $row['created_at'],
            'unreadCount'   => $directUnread[$row['peer_email']] ?? 0,
        ];
    }

    // Más reciente primero; los equipos sin ningún mensaje todavía
    // (lastMessageAt null) se van al final, ordenados alfabéticamente.
    usort($chats, function ($a, $b) {
        if ($a['lastMessageAt'] === null && $b['lastMessageAt'] === null) {
            return strcasecmp($a['title'], $b['title']);
        }
        if ($a['lastMessageAt'] === null) return 1;
        if ($b['lastMessageAt'] === null) return -1;
        return strcmp($b['lastMessageAt'], $a['lastMessageAt']);
    });

    json_response(['chats' => $chats]);
}

// Calcula el estado ('delivered' o 'read', al estilo WhatsApp) de un
// mensaje propio a partir de a quién debía llegarle ($recipientEmails) y
// desde cuándo cada quien tiene leído el chat ($readAtByEmail, email =>
// timestamp string "Y-m-d H:i:s" o null si nunca lo abrió). Como no hay
// notificaciones push, "entregado" (✓✓ gris) es lo más fuerte que se puede
// afirmar en cuanto el mensaje queda guardado en el servidor — los demás
// clientes lo recibirán en su próximo sondeo. "Leído" (✓✓ azul) solo
// cuando TODOS los destinatarios marcaron el chat como leído después de
// que se creó el mensaje.
function chat_message_status(string $createdAt, array $recipientEmails, array $readAtByEmail): string {
    if (empty($recipientEmails)) {
        return 'delivered';
    }
    foreach ($recipientEmails as $email) {
        $readAt = $readAtByEmail[$email] ?? null;
        if ($readAt === null || $readAt < $createdAt) {
            return 'delivered';
        }
    }
    return 'read';
}

// El chat es por equipo: cada equipo tiene su propio hilo y solo sus
// integrantes (o el líder) pueden leerlo o escribir en él.
function getAllChats(PDO $pdo, string $teamId) {
    $user = require_auth($pdo);
    require_team_member($pdo, $teamId, $user);
    $me = $user['email'];
    // chat_messages.username en realidad guarda el correo de quien escribió
    // (ver sendChatMessage abajo) — se cruza con users por email para poder
    // mostrar su nombre real y su foto de perfil en vez del correo/inicial.
    // LEFT JOIN porque un remitente pudo haber sido borrado después de
    // escribir; en ese caso se cae de vuelta al correo guardado.
    $stmt = $pdo->prepare(
        'SELECT cm.username, cm.message, cm.created_at, u.name AS display_name, u.photo_path
         FROM chat_messages cm
         LEFT JOIN users u ON u.email = cm.username
         WHERE cm.team_id = ?
         ORDER BY cm.id ASC'
    );
    $stmt->execute([$teamId]);
    $rows = $stmt->fetchAll();

    // Para saber si mis propios mensajes ya fueron leídos por todo el
    // equipo: quiénes son los demás integrantes, y desde cuándo cada uno
    // tiene marcado como leído este chat de equipo.
    $stmt = $pdo->prepare('SELECT email FROM team_members WHERE team_id = ? AND email <> ?');
    $stmt->execute([$teamId, $me]);
    $otherMembers = array_column($stmt->fetchAll(), 'email');

    $readAtByEmail = [];
    if ($otherMembers) {
        $placeholders = implode(',', array_fill(0, count($otherMembers), '?'));
        $stmt = $pdo->prepare(
            "SELECT user_email, last_read_at FROM chat_reads
             WHERE chat_key = ? AND user_email IN ($placeholders)"
        );
        $stmt->execute(array_merge(['team:' . $teamId], $otherMembers));
        foreach ($stmt->fetchAll() as $r) {
            $readAtByEmail[$r['user_email']] = $r['last_read_at'];
        }
    }

    $chats = array_map(function ($row) use ($me, $otherMembers, $readAtByEmail) {
        return [
            'username'  => $row['username'],
            'message'   => $row['message'],
            'name'      => $row['display_name'] ?: $row['username'],
            'photoUrl'  => !empty($row['photo_path']) ? UPLOAD_URL_BASE . $row['photo_path'] : null,
            'createdAt' => $row['created_at'],
            // Solo tiene sentido mostrar el estado de mis propios mensajes
            // (así funciona WhatsApp: los ✓ van en lo que YO envié).
            'status'    => $row['username'] === $me
                ? chat_message_status($row['created_at'], $otherMembers, $readAtByEmail)
                : null,
        ];
    }, $rows);

    json_response(['chats' => $chats]);
}

function sendChatMessage(PDO $pdo, string $teamId) {
    // El username se toma del token, nunca del body, para que nadie pueda
    // publicar en el chat haciéndose pasar por otra persona.
    $user = require_auth($pdo);
    require_team_member($pdo, $teamId, $user);
    $body = request_body();
    $message = trim($body['message'] ?? '');

    if ($message === '') {
        text_response('message is required', 400);
    }

    $stmt = $pdo->prepare('INSERT INTO chat_messages (team_id, username, message) VALUES (?, ?, ?)');
    $stmt->execute([$teamId, $user['email'], $message]);

    // Cada integrante del equipo (menos quien lo envía) recibe una
    // notificación de que hay un mensaje nuevo en el chat de ese equipo.
    $stmt = $pdo->prepare('SELECT team_name FROM teams WHERE id = ?');
    $stmt->execute([$teamId]);
    $teamName = $stmt->fetch()['team_name'] ?? '';

    $stmt = $pdo->prepare('SELECT email FROM team_members WHERE team_id = ? AND email <> ?');
    $stmt->execute([$teamId, $user['email']]);
    $recipients = array_column($stmt->fetchAll(), 'email');

    $preview = text_preview($message);
    foreach ($recipients as $recipientEmail) {
        notify_user($pdo, $recipientEmail, $teamId, 'message_received',
            $user['name'] . ' envió un mensaje en el chat de "' . $teamName . '": "' . $preview . '"');
    }

    text_response('Message sent', 200);
}

// Chat privado 1 a 1: reutiliza la tabla chat_messages del chat de equipo,
// pero con team_id NULL y recipient_email como destinatario. No exige que
// ambas personas compartan equipo/área — se abre desde ahí en la app (al
// tocar el correo de un integrante en teamDetail.dart), pero cualquier par
// de cuentas registradas puede tener su propio hilo.
function getDirectChat(PDO $pdo) {
    $user = require_auth($pdo);
    $peerEmail = trim($_GET['with'] ?? '');
    if ($peerEmail === '') {
        text_response('with is required', 400);
    }

    $stmt = $pdo->prepare('SELECT 1 FROM users WHERE email = ?');
    $stmt->execute([$peerEmail]);
    if (!$stmt->fetch()) {
        text_response('User not found', 404);
    }

    // Un mensaje pertenece al hilo si va de mí hacia esa persona o de esa
    // persona hacia mí; se leen ambos sentidos para armar la conversación.
    $stmt = $pdo->prepare(
        'SELECT cm.username, cm.message, cm.created_at, u.name AS display_name, u.photo_path
         FROM chat_messages cm
         LEFT JOIN users u ON u.email = cm.username
         WHERE cm.team_id IS NULL
           AND ((cm.username = ? AND cm.recipient_email = ?) OR (cm.username = ? AND cm.recipient_email = ?))
         ORDER BY cm.id ASC'
    );
    $stmt->execute([$user['email'], $peerEmail, $peerEmail, $user['email']]);
    $rows = $stmt->fetchAll();

    // Para saber si mis mensajes ya fueron leídos por el otro lado: el
    // peer marca este hilo como leído con chat_key = 'direct:' + MI correo
    // (ver markChatRead — el "id" que manda es el correo de la otra
    // persona desde SU punto de vista, que soy yo).
    $stmt = $pdo->prepare(
        "SELECT last_read_at FROM chat_reads WHERE user_email = ? AND chat_key = ?"
    );
    $stmt->execute([$peerEmail, 'direct:' . $user['email']]);
    $peerReadAt = $stmt->fetch();
    $readAtByEmail = $peerReadAt ? [$peerEmail => $peerReadAt['last_read_at']] : [];

    $chats = array_map(function ($row) use ($user, $peerEmail, $readAtByEmail) {
        return [
            'username'  => $row['username'],
            'message'   => $row['message'],
            'name'      => $row['display_name'] ?: $row['username'],
            'photoUrl'  => !empty($row['photo_path']) ? UPLOAD_URL_BASE . $row['photo_path'] : null,
            'createdAt' => $row['created_at'],
            'status'    => $row['username'] === $user['email']
                ? chat_message_status($row['created_at'], [$peerEmail], $readAtByEmail)
                : null,
        ];
    }, $rows);

    json_response(['chats' => $chats]);
}

function sendDirectMessage(PDO $pdo) {
    // El remitente se toma del token, nunca del body, por la misma razón
    // que en sendChatMessage: que nadie pueda escribir haciéndose pasar
    // por otra persona.
    $user = require_auth($pdo);
    $body = request_body();
    $to = trim($body['to'] ?? '');
    $message = trim($body['message'] ?? '');

    if ($to === '') {
        text_response('to is required', 400);
    }
    if ($message === '') {
        text_response('message is required', 400);
    }
    if (strcasecmp($to, $user['email']) === 0) {
        text_response('No puedes enviarte un mensaje a ti mismo', 400);
    }

    $stmt = $pdo->prepare('SELECT email FROM users WHERE email = ?');
    $stmt->execute([$to]);
    if (!$stmt->fetch()) {
        text_response('User not found', 404);
    }

    $stmt = $pdo->prepare(
        'INSERT INTO chat_messages (team_id, username, recipient_email, message) VALUES (NULL, ?, ?, ?)'
    );
    $stmt->execute([$user['email'], $to, $message]);

    $preview = text_preview($message);
    notify_user($pdo, $to, null, 'message_received',
        $user['name'] . ' te envió un mensaje privado: "' . $preview . '"');

    text_response('Message sent', 200);
}

// Marca un chat (de equipo o directo) como leído "hasta ahora": guarda
// last_read_at = NOW() para ese chat_key, así que los mensajes existentes
// dejan de contar como no leídos en listChats(). Se llama al entrar a
// ChatScreen/DirectChatScreen (y en cada refresco mientras siguen abiertas,
// para que un mensaje que llega con el chat ya abierto no quede marcado
// como pendiente).
function markChatRead(PDO $pdo) {
    $user = require_auth($pdo);
    $body = request_body();
    $type = trim($body['type'] ?? '');
    $id = trim($body['id'] ?? '');

    if ($type !== 'team' && $type !== 'direct') {
        text_response('type must be team or direct', 400);
    }
    if ($id === '') {
        text_response('id is required', 400);
    }
    if ($type === 'team') {
        require_team_member($pdo, $id, $user);
    }

    $chatKey = $type . ':' . $id;
    $stmt = $pdo->prepare(
        'INSERT INTO chat_reads (user_email, chat_key, last_read_at)
         VALUES (?, ?, NOW())
         ON DUPLICATE KEY UPDATE last_read_at = NOW()'
    );
    $stmt->execute([$user['email'], $chatKey]);

    text_response('OK', 200);
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

// ---- handlers: documents --------------------------------------------

// Extensiones permitidas para "Documentos" (distinto de las imágenes de
// addImage): documentos de oficina, PDF y comprimidos comunes.
const ALLOWED_DOCUMENT_EXTENSIONS = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
    'txt', 'csv', 'zip', 'rar', '7z',
];
const MAX_DOCUMENT_SIZE_BYTES = 25 * 1024 * 1024; // 25 MB

function showDocuments(PDO $pdo, string $teamId) {
    $user = require_auth($pdo);
    require_team_member($pdo, $teamId, $user);
    $stmt = $pdo->prepare(
        'SELECT id, doc_name, original_name, file_size, uploaded_by, created_at
         FROM documents WHERE team_id = ? ORDER BY id DESC'
    );
    $stmt->execute([$teamId]);
    $rows = $stmt->fetchAll();

    $documents = array_map(fn($r) => [
        'id' => (string) $r['id'],
        'docName' => $r['doc_name'],
        'originalName' => $r['original_name'],
        'fileSize' => (int) $r['file_size'],
        'uploadedBy' => $r['uploaded_by'],
        'createdAt' => $r['created_at'],
        'downloadUrl' => rtrim(kBaseUrlForRequest(), '/') . '/document/download/' . $r['id'],
    ], $rows);

    json_response(['data' => $documents], 200);
}

function addDocument(PDO $pdo) {
    $user = require_auth($pdo);
    $teamId = trim($_POST['teamId'] ?? '');
    $docName = trim($_POST['docName'] ?? '');

    if ($teamId === '' || empty($_FILES['document']) || $_FILES['document']['error'] !== UPLOAD_ERR_OK) {
        text_response('teamId and document are required', 400);
    }
    require_team_member($pdo, $teamId, $user);

    $tmpPath = $_FILES['document']['tmp_name'];
    $originalName = $_FILES['document']['name'];
    $size = (int) $_FILES['document']['size'];
    $ext = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));

    if (!in_array($ext, ALLOWED_DOCUMENT_EXTENSIONS, true)) {
        text_response('File type not allowed', 400);
    }
    if ($size > MAX_DOCUMENT_SIZE_BYTES) {
        text_response('File is too large (max 25 MB)', 400);
    }

    $storedName = bin2hex(random_bytes(16)) . '.' . $ext;
    if (!move_uploaded_file($tmpPath, UPLOAD_DIR . $storedName)) {
        text_response('Failed to save the uploaded document', 500);
    }

    $stmt = $pdo->prepare(
        'INSERT INTO documents (team_id, doc_name, doc_path, original_name, file_size, uploaded_by)
         VALUES (?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $teamId,
        $docName !== '' ? $docName : $originalName,
        $storedName,
        $originalName,
        $size,
        $user['email'],
    ]);

    text_response('Document uploaded successfully', 200);
}

function downloadDocument(PDO $pdo, string $documentId) {
    $user = require_auth($pdo);
    $stmt = $pdo->prepare('SELECT * FROM documents WHERE id = ?');
    $stmt->execute([$documentId]);
    $doc = $stmt->fetch();
    if (!$doc) {
        error_response('Document not found', 404);
    }
    require_team_member($pdo, $doc['team_id'], $user);

    $filePath = UPLOAD_DIR . $doc['doc_path'];
    if (!is_file($filePath)) {
        error_response('File missing on server', 404);
    }

    // Fuerza la descarga (en vez de dejar que el navegador la abra inline,
    // como pasaría con un enlace estático a /uploads/) y devuelve el
    // nombre original del archivo en vez del nombre aleatorio con el que
    // se guardó en disco.
    header('Content-Type: application/octet-stream');
    header('Content-Disposition: attachment; filename="' . addslashes($doc['original_name']) . '"');
    header('Content-Length: ' . filesize($filePath));
    readfile($filePath);
    exit;
}

function deleteDocument(PDO $pdo, string $documentId) {
    $user = require_auth($pdo);
    $stmt = $pdo->prepare('SELECT * FROM documents WHERE id = ?');
    $stmt->execute([$documentId]);
    $doc = $stmt->fetch();
    if (!$doc) {
        error_response('Document not found', 404);
    }
    require_team_member($pdo, $doc['team_id'], $user);

    $stmt = $pdo->prepare('DELETE FROM documents WHERE id = ?');
    $stmt->execute([$documentId]);

    $filePath = UPLOAD_DIR . $doc['doc_path'];
    if (is_file($filePath)) {
        @unlink($filePath);
    }

    text_response('Document deleted successfully', 200);
}

// Base URL absoluta del propio backend (esquema + host + APP_BASE_PATH),
// reutilizando la misma lógica que UPLOAD_URL_BASE en config.php, para
// armar el enlace de descarga que se manda al cliente.
function kBaseUrlForRequest(): string {
    return 'http://' . ($_SERVER['HTTP_HOST'] ?? 'localhost') . APP_BASE_PATH;
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

// Elimina una notificación puntual del usuario autenticado. Se filtra
// siempre por email para que nadie pueda borrar notificaciones ajenas
// aunque adivine el id.
function deleteNotification(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    $stmt = $pdo->prepare('DELETE FROM notifications WHERE id = ? AND email = ?');
    $stmt->execute([$id, $user['email']]);
    if ($stmt->rowCount() === 0) {
        json_response(['error' => 'Notification not found'], 404);
    }
    json_response(['message' => 'Notification deleted']);
}

// Vacía por completo el historial de notificaciones del usuario (botón
// "Eliminar todas" en la pantalla de notificaciones).
function deleteAllNotifications(PDO $pdo) {
    $user = require_auth($pdo);
    $stmt = $pdo->prepare('DELETE FROM notifications WHERE email = ?');
    $stmt->execute([$user['email']]);
    json_response(['message' => 'Notifications deleted']);
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
        'department' => $department,
        'photoUrl'   => !empty($user['photo_path']) ? UPLOAD_URL_BASE . $user['photo_path'] : null,
    ];
}

// La app llama esto justo después de login para saber qué dashboard mostrar
// (Director / Manager / Employee) — el token en sí no lleva el rol.
function getMe(PDO $pdo) {
    $user = require_auth($pdo);
    json_response(build_user_profile_payload($pdo, $user));
}

// Reemplaza la foto de perfil del usuario autenticado (tipo WhatsApp: se ve
// en su propio perfil y en la burbuja del chat en lugar de la inicial).
// Mismo patrón de validación/guardado que addImage() para los recursos de
// equipo, pero atado al usuario del token en vez de a un teamId del body.
function updateProfilePhoto(PDO $pdo) {
    $user = require_auth($pdo);

    if (empty($_FILES['photo']) || $_FILES['photo']['error'] !== UPLOAD_ERR_OK) {
        text_response('photo is required', 400);
    }

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

    $oldPath = $user['photo_path'] ?? null;

    $stmt = $pdo->prepare('UPDATE users SET photo_path = ? WHERE id = ?');
    $stmt->execute([$storedName, $user['id']]);

    // Borra la foto anterior del disco para no acumular archivos huérfanos
    // cada vez que alguien cambia su foto.
    if ($oldPath) {
        $oldFile = UPLOAD_DIR . $oldPath;
        if (is_file($oldFile)) {
            @unlink($oldFile);
        }
    }

    json_response(['photoUrl' => UPLOAD_URL_BASE . $storedName]);
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

// ---- handlers: department task workflow ---------------------------------
// Director -> Departamento -> Manager -> Empleado -> completa -> Manager
// valida -> Director ve estadísticas (Actualizacion.md, "Tasks" y "Task
// Workflow"). Reutiliza la tabla `tasks` que ya usa el flujo de equipos,
// pero deja team_code/domain_name/email en '' porque una tarea de
// departamento no pertenece a un equipo — usa en su lugar las columnas
// nuevas (department_id, created_by, assigned_by, priority, progress,
// status). No toca addTask/taskDone/incompleteTasks/completedTasks ni el
// payload que consumen teamDetail.dart / tasks.dart.
//
// Cada fila sigue siendo "una tarea para una persona", igual que en el
// flujo de equipos: cuando el manager reparte una tarea de departamento
// entre varios empleados, se genera una fila por empleado.

function build_department_task_payload(array $t): array {
    return [
        'id'           => (int) $t['id'],
        'description'  => $t['description'],
        'deadline'     => $t['deadline'],
        'departmentId' => $t['department_id'],
        'assignedTo'   => $t['email'] !== '' ? $t['email'] : null,
        'createdBy'    => $t['created_by'],
        'assignedBy'   => $t['assigned_by'],
        'priority'     => $t['priority'],
        'progress'     => (int) $t['progress'],
        'status'       => $t['status'],
        'completed'    => (bool) $t['completed'],
    ];
}

function department_or_404(PDO $pdo, string $departmentId): array {
    $stmt = $pdo->prepare('SELECT * FROM departments WHERE id = ?');
    $stmt->execute([$departmentId]);
    $dept = $stmt->fetch();
    if (!$dept) {
        error_response('Departamento no encontrado', 404);
    }
    return $dept;
}

// Solo busca entre las tareas del workflow de departamento (department_id
// no nulo), para no mezclarlas nunca con las tareas del flujo de equipos.
function department_task_or_404(PDO $pdo, string $taskId): array {
    $stmt = $pdo->prepare('SELECT * FROM tasks WHERE id = ? AND department_id IS NOT NULL');
    $stmt->execute([$taskId]);
    $task = $stmt->fetch();
    if (!$task) {
        error_response('Tarea no encontrada', 404);
    }
    return $task;
}

// El director asigna una tarea a un departamento completo. Queda "sin
// repartir" (email = '') hasta que el manager la distribuya entre sus
// empleados con POST /department/task/{id}/assign.
function createDepartmentTask(PDO $pdo, string $departmentId) {
    $user = require_auth($pdo);
    require_role($user, ['director']);
    $dept = department_or_404($pdo, $departmentId);

    $body = request_body();
    $description = trim($body['task'] ?? $body['description'] ?? '');
    $deadline = trim($body['deadline'] ?? '');
    $priority = trim($body['priority'] ?? '') ?: 'normal';

    if ($description === '') {
        error_response('La descripción de la tarea es requerida', 400);
    }

    $stmt = $pdo->prepare(
        "INSERT INTO tasks (team_code, domain_name, email, description, deadline, created_by, department_id, priority, status)
         VALUES ('', '', '', ?, ?, ?, ?, ?, 'pending')"
    );
    $stmt->execute([$description, $deadline, $user['id'], $departmentId, $priority]);
    $taskId = (int) $pdo->lastInsertId();

    if (!empty($dept['manager_email'])) {
        notify_user($pdo, $dept['manager_email'], null, 'task_assigned',
            'El director asignó una nueva tarea al departamento "' . $dept['name'] . '": ' . $description);
    }

    $stmt = $pdo->prepare('SELECT * FROM tasks WHERE id = ?');
    $stmt->execute([$taskId]);
    json_response(['task' => build_department_task_payload($stmt->fetch())]);
}

// Lista las tareas de un departamento (repartidas y pendientes de
// repartir). El director puede ver cualquier departamento; el manager,
// solo el suyo.
function listDepartmentTasks(PDO $pdo, string $departmentId) {
    $user = require_auth($pdo);
    department_or_404($pdo, $departmentId);
    require_department_manager_or_director($pdo, $user, $departmentId);

    $stmt = $pdo->prepare('SELECT * FROM tasks WHERE department_id = ? ORDER BY id ASC');
    $stmt->execute([$departmentId]);
    json_response(['tasks' => array_map('build_department_task_payload', $stmt->fetchAll())]);
}

// El manager (o el director) reparte una tarea de departamento entre uno o
// más empleados del departamento. La fila original (sin repartir) se
// reutiliza para el primer correo; si hay más, se clonan filas nuevas —
// mismo patrón "una fila = una persona" que ya usa el flujo de equipos.
function assignDepartmentTask(PDO $pdo, string $taskId) {
    $user = require_auth($pdo);
    $task = department_task_or_404($pdo, $taskId);
    require_department_manager_or_director($pdo, $user, $task['department_id']);

    $body = request_body();
    $emails = $body['emails'] ?? ($body['email'] ?? null);
    if (is_string($emails)) {
        $emails = [$emails];
    }
    $emails = array_values(array_unique(array_filter(array_map('trim', (array) $emails))));
    if (empty($emails)) {
        error_response('emails es requerido', 400);
    }

    foreach ($emails as $email) {
        $stmt = $pdo->prepare('SELECT 1 FROM users WHERE email = ? AND department_id = ?');
        $stmt->execute([$email, $task['department_id']]);
        if (!$stmt->fetch()) {
            error_response("$email no pertenece a este departamento", 400);
        }
    }

    // assignedIds guarda [id, email] de cada tarea creada/actualizada, para
    // poder notificar sin volver a consultar la base de datos.
    $assigned = [];

    $firstEmail = array_shift($emails);
    if ($task['email'] === '') {
        // la fila original todavía no estaba repartida: se reutiliza
        $stmt = $pdo->prepare("UPDATE tasks SET email = ?, assigned_by = ?, status = 'pending' WHERE id = ?");
        $stmt->execute([$firstEmail, $user['id'], $task['id']]);
        $assigned[] = ['id' => (int) $task['id'], 'email' => $firstEmail];
    } else {
        // ya estaba repartida a otra persona: no se pisa, se clona también
        array_unshift($emails, $firstEmail);
    }

    foreach ($emails as $email) {
        $stmt = $pdo->prepare(
            "INSERT INTO tasks (team_code, domain_name, email, description, deadline, created_by, assigned_by, department_id, priority, status)
             VALUES ('', '', ?, ?, ?, ?, ?, ?, ?, 'pending')"
        );
        $stmt->execute([$email, $task['description'], $task['deadline'], $task['created_by'], $user['id'], $task['department_id'], $task['priority']]);
        $assigned[] = ['id' => (int) $pdo->lastInsertId(), 'email' => $email];
    }

    foreach ($assigned as $a) {
        notify_user($pdo, $a['email'], null, 'task_assigned',
            'Se te asignó una nueva tarea: ' . $task['description']);
    }

    $ids = array_column($assigned, 'id');
    $placeholders = implode(',', array_fill(0, count($ids), '?'));
    $stmt = $pdo->prepare("SELECT * FROM tasks WHERE id IN ($placeholders) ORDER BY id ASC");
    $stmt->execute($ids);
    json_response(['tasks' => array_map('build_department_task_payload', $stmt->fetchAll())]);
}

// El empleado marca como hecha una tarea de departamento que le fue
// asignada. Requiere ser el dueño del correo asignado (mismo criterio de
// pertenencia que ya usa team/taskDone), no un chequeo de rol.
function completeDepartmentTask(PDO $pdo, string $taskId) {
    $user = require_auth($pdo);
    $task = department_task_or_404($pdo, $taskId);

    if ($task['email'] === '' || $task['email'] !== $user['email']) {
        error_response('Solo la persona asignada puede completar esta tarea', 403);
    }
    if ($task['status'] === 'approved') {
        error_response('Esta tarea ya fue aprobada', 400);
    }

    $stmt = $pdo->prepare("UPDATE tasks SET completed = 1, status = 'done', progress = 100 WHERE id = ?");
    $stmt->execute([$task['id']]);

    $dept = department_or_404($pdo, $task['department_id']);
    if (!empty($dept['manager_email'])) {
        notify_user($pdo, $dept['manager_email'], null, 'task_completed',
            $user['name'] . ' completó la tarea "' . $task['description'] . '"');
    }

    $stmt = $pdo->prepare('SELECT * FROM tasks WHERE id = ?');
    $stmt->execute([$task['id']]);
    json_response(['task' => build_department_task_payload($stmt->fetch())]);
}

// El manager (o el director) valida una tarea que el empleado ya marcó
// como hecha, aprobándola.
function approveDepartmentTask(PDO $pdo, string $taskId) {
    $user = require_auth($pdo);
    $task = department_task_or_404($pdo, $taskId);
    require_department_manager_or_director($pdo, $user, $task['department_id']);

    if ($task['status'] !== 'done') {
        error_response('La tarea todavía no ha sido marcada como hecha por el empleado', 400);
    }

    $stmt = $pdo->prepare("UPDATE tasks SET status = 'approved' WHERE id = ?");
    $stmt->execute([$task['id']]);

    if ($task['email'] !== '') {
        notify_user($pdo, $task['email'], null, 'task_approved',
            'Tu tarea "' . $task['description'] . '" fue aprobada');
    }

    $stmt = $pdo->prepare('SELECT * FROM tasks WHERE id = ?');
    $stmt->execute([$task['id']]);
    json_response(['task' => build_department_task_payload($stmt->fetch())]);
}

// Estadísticas para el Director (todos los departamentos) o el Manager
// (solo el suyo): tareas por departamento, completadas/pendientes.
function departmentTaskStats(PDO $pdo) {
    $user = require_auth($pdo);
    require_role($user, ['director', 'manager']);

    $params = [];
    $where = "WHERE t.department_id IS NOT NULL AND t.email != ''";
    if ($user['role'] === 'manager') {
        $where .= ' AND t.department_id = ?';
        $params[] = $user['department_id'];
    }

    $stmt = $pdo->prepare(
        "SELECT d.id AS departmentId, d.name AS departmentName,
                COUNT(*) AS total,
                SUM(t.status = 'pending') AS pending,
                SUM(t.status = 'done') AS done,
                SUM(t.status = 'approved') AS approved
         FROM tasks t
         JOIN departments d ON d.id = t.department_id
         $where
         GROUP BY d.id, d.name
         ORDER BY d.name ASC"
    );
    $stmt->execute($params);

    $stats = array_map(fn($r) => [
        'departmentId'   => $r['departmentId'],
        'departmentName' => $r['departmentName'],
        'total'          => (int) $r['total'],
        'pending'        => (int) $r['pending'],
        'done'           => (int) $r['done'],
        'approved'       => (int) $r['approved'],
    ], $stmt->fetchAll());

    json_response(['stats' => $stats]);
}
