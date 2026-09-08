<?php
// Perfil propio (GET /user/me), foto de perfil, y el directorio interno de
// compañeros (buscar + abrir ficha). build_*_payload arman la forma pública
// del usuario que consumen login, /user/me y el directorio.

// Forma pública de un usuario: lo único que se le puede mostrar a otra
// persona de la empresa. Deliberadamente NO incluye password, token ni otp —
// todo lo que sale de `users` hacia el cliente pasa por aquí (perfil propio,
// directorio y ficha de un compañero).
function build_public_user_payload(array $user, ?array $department): array {
    return [
        'id'            => $user['id'],
        'name'          => $user['name'],
        'email'         => $user['email'],
        'role'          => $user['role'],
        'position'      => $user['position'],
        'controlNumber' => $user['control_number'] ?? null,
        // Cambio de correo pendiente de confirmar (migración 029). Solo tiene
        // sentido en el perfil propio; en el directorio siempre será null a
        // menos que esa persona tenga un cambio en curso.
        'pendingEmail'  => $user['pending_email'] ?? null,
        'photoUrl'      => $user['photo_path'] ? UPLOAD_URL_BASE . $user['photo_path'] : null,
        'department'    => $department,
        // Verificación de correo (023): la app la usa para el aviso.
        'emailVerified' => !empty($user['email_verified_at']),
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

    return build_public_user_payload($user, $department);
}

// La app llama esto justo después de login para saber qué dashboard mostrar
// (Director / Manager / Employee) — el token en sí no lleva el rol.
function getMe(PDO $pdo) {
    $user = require_auth($pdo);
    $payload = build_user_profile_payload($pdo, $user);
    // Sub-equipos que lidera (migración 030), para pintar la entrada de menú
    // del sub-líder sin una llamada extra.
    $payload['ledSubTeams'] = sub_team_led_summary($pdo, $user['id']);
    json_response($payload);
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

// ---- handlers: directorio de compañeros ---------------------------------
// Directorio interno de Radio Doliv. Cualquier usuario autenticado puede
// buscar a sus compañeros y abrir su ficha; solo se exponen los datos de
// contacto de trabajo que ya se comparten dentro de la empresa (nombre,
// correo, puesto, departamento, foto) — nunca credenciales.

// Todos los departamentos con su número de empleados, indexados por id. El
// directorio los necesita para adjuntar el departamento de cada persona: se
// resuelven de una sola vez en vez de una consulta por usuario listado.
function departments_by_id(PDO $pdo): array {
    $stmt = $pdo->query(
        'SELECT d.*, (SELECT COUNT(*) FROM users u WHERE u.department_id = d.id) AS employee_count
         FROM departments d'
    );
    $byId = [];
    foreach ($stmt->fetchAll() as $dept) {
        $byId[$dept['id']] = [
            'id'            => $dept['id'],
            'companyId'     => $dept['company_id'],
            'name'          => $dept['name'],
            'description'   => $dept['description'],
            'managerEmail'  => $dept['manager_email'],
            'employeeCount' => (int) $dept['employee_count'],
        ];
    }
    return $byId;
}

// GET /user/directory?scope=&q=
//
// `scope`: 'department' (por defecto, "mi área"), 'company' para toda la
// empresa, o el id de un departamento concreto. Quien todavía no tiene
// departamento asignado (el director, o una cuenta recién creada) no tiene
// "mi área" que filtrar, así que en ese caso el default cae a toda la
// empresa en vez de devolver una lista vacía.
//
// `q`: texto libre; busca en nombre, correo, puesto y número de control
// (`SPPRD-0000000`; se puede teclear con o sin el prefijo/los ceros).
function listColleagues(PDO $pdo) {
    $user = require_auth($pdo);

    $scope = trim($_GET['scope'] ?? 'department');
    $query = trim($_GET['q'] ?? '');

    // Las cuentas sin verificar el correo no existen para el directorio.
    $where = [SQL_USER_VERIFIED];
    $params = [];

    if ($scope === 'department') {
        if ($user['department_id']) {
            $where[] = 'department_id = ?';
            $params[] = $user['department_id'];
        }
    } elseif ($scope !== 'company' && $scope !== '') {
        $where[] = 'department_id = ?';
        $params[] = $scope;
    }

    if ($query !== '') {
        // Los comodines van escapados para que un "%" tecleado por el usuario
        // se busque literalmente en vez de traer a toda la empresa.
        $like = '%' . addcslashes($query, '%_\\') . '%';
        $conds = ['name LIKE ?', 'email LIKE ?', 'position LIKE ?', 'control_number LIKE ?'];
        array_push($params, $like, $like, $like, $like);

        // Además, si lo tecleado tiene dígitos, se acepta el número de control
        // sin el prefijo ni los ceros a la izquierda ("2", "0000002" y
        // "SPPRD-0000002" llegan todos a la misma persona).
        $digits = preg_replace('/\D/', '', $query);
        if ($digits !== '' && strlen($digits) <= 15) {
            $conds[] = 'control_number LIKE ?';
            $params[] = '%' . format_control_number((int) $digits);
        }

        $where[] = '(' . implode(' OR ', $conds) . ')';
    }

    $sql = 'SELECT * FROM users';
    if ($where) {
        $sql .= ' WHERE ' . implode(' AND ', $where);
    }
    // Jerarquía primero (director, manager) y luego alfabético: así el
    // responsable del área queda arriba, que es a quien más se busca.
    $sql .= " ORDER BY FIELD(role, 'director', 'manager', 'employee'), name ASC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll();

    $departments = departments_by_id($pdo);
    $colleagues = [];
    foreach ($rows as $row) {
        $dept = $row['department_id'] ? ($departments[$row['department_id']] ?? null) : null;
        $colleagues[] = build_public_user_payload($row, $dept);
    }

    json_response([
        'colleagues'     => $colleagues,
        'departments'    => array_values($departments),
        'scope'          => $scope,
        'myDepartmentId' => $user['department_id'],
    ]);
}

// GET /user/profile/{id} — ficha de un compañero. Sobre el perfil público
// agrega los equipos a los que pertenece y desde cuándo está en la empresa,
// que es lo que hace que valga la pena abrir la ficha en vez de quedarse con
// la fila del listado.
function getColleagueProfile(PDO $pdo, string $userId) {
    require_auth($pdo);

    $stmt = $pdo->prepare('SELECT * FROM users WHERE id = ?');
    $stmt->execute([$userId]);
    $target = $stmt->fetch();
    // Una cuenta sin verificar no aparece en el directorio, así que su ficha
    // tampoco se abre: se responde igual que si no existiera.
    if (!$target || !user_email_verified($target)) {
        error_response('No encontramos a esa persona', 404);
    }

    $stmt = $pdo->prepare(
        'SELECT t.id, t.team_name, t.leader_email
         FROM teams t
         LEFT JOIN team_members tm ON tm.team_id = t.id AND tm.email = ?
         WHERE t.leader_email = ? OR tm.email IS NOT NULL
         ORDER BY t.team_name ASC'
    );
    $stmt->execute([$target['email'], $target['email']]);
    $teams = array_map(fn($t) => [
        'id'       => $t['id'],
        'teamName' => $t['team_name'],
        'isLeader' => $t['leader_email'] === $target['email'],
    ], $stmt->fetchAll());

    $payload = build_user_profile_payload($pdo, $target);
    $payload['teams'] = $teams;
    $payload['joinedAt'] = $target['created_at'];

    json_response($payload);
}

// POST /user/{id}/control-number — el director corrige el número de control
// de una persona (es único e intransferible; el alta lo autoasigna). Acepta
// body { "number": 42 } o { "controlNumber": "SPPRD-0000042" }; ambos se
// normalizan a la forma canónica SPPRD-0000000.
function setControlNumber(PDO $pdo, string $userId) {
    $user = require_auth($pdo);
    require_role($user, ['director']);

    $stmt = $pdo->prepare('SELECT * FROM users WHERE id = ?');
    $stmt->execute([$userId]);
    $target = $stmt->fetch();
    if (!$target) {
        error_response('No encontramos a esa persona', 404);
    }
    // El número de control se asigna al verificar el correo (ver verifyEmail).
    // A una cuenta sin verificar no se le puede poner ni corregir.
    if (!user_email_verified($target)) {
        error_response('Esa cuenta todavía no verifica su correo', 409);
    }

    $body = request_body();
    $n = null;
    if (isset($body['number']) && is_numeric($body['number'])) {
        $n = (int) $body['number'];
    } elseif (isset($body['controlNumber'])) {
        $n = parse_control_number($body['controlNumber']);
    }
    if ($n === null || $n < 1) {
        error_response('Número de control inválido. Formato: SPPRD-0000000', 400);
    }
    $canonical = format_control_number($n);

    $stmt = $pdo->prepare('SELECT id FROM users WHERE control_number = ? AND id <> ?');
    $stmt->execute([$canonical, $userId]);
    if ($stmt->fetch()) {
        error_response('Ese número de control ya está en uso', 409);
    }

    $stmt = $pdo->prepare('UPDATE users SET control_number = ? WHERE id = ?');
    $stmt->execute([$canonical, $userId]);

    $stmt = $pdo->prepare('SELECT * FROM users WHERE id = ?');
    $stmt->execute([$userId]);
    json_response(build_user_profile_payload($pdo, $stmt->fetch()));
}
