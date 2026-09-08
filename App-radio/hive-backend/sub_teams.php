<?php
// Sub-equipos dentro de un departamento (Radio Doliv). Ver
// migrations/030_sub_teams.sql y docs/superpowers/specs/2026-09-08-sub-equipos-design.md
//
//   El director o el manager del área crean/editan/borran sub-equipos y
//   fijan el sub-líder. El sub-líder (un empleado del mismo departamento)
//   administra los miembros de SU sub-equipo y crea/asigna sus tareas
//   (esto último vive en dept_tasks.php via dept_task_can_admin()).

// ---- helpers ----------------------------------------------------------------

function sub_team_row(PDO $pdo, string $id): ?array {
    $stmt = $pdo->prepare('SELECT * FROM sub_teams WHERE id = ?');
    $stmt->execute([$id]);
    return $stmt->fetch() ?: null;
}

// ids de los sub-equipos que lidera este usuario (para el choke-point de
// permisos de tareas y para pintar el menú del sub-líder).
function sub_team_lead_ids(PDO $pdo, string $userId): array {
    $stmt = $pdo->prepare('SELECT id FROM sub_teams WHERE lead_user_id = ?');
    $stmt->execute([$userId]);
    return array_map('strval', $stmt->fetchAll(PDO::FETCH_COLUMN));
}

// Sub-equipos que lidera, con datos mínimos, para /user/me.
function sub_team_led_summary(PDO $pdo, string $userId): array {
    $stmt = $pdo->prepare(
        'SELECT id, name, department_id FROM sub_teams WHERE lead_user_id = ? ORDER BY name ASC'
    );
    $stmt->execute([$userId]);
    return array_map(fn($r) => [
        'id'           => $r['id'],
        'name'         => $r['name'],
        'departmentId' => $r['department_id'],
    ], $stmt->fetchAll());
}

function sub_team_mini_user(PDO $pdo, ?string $userId): ?array {
    if (!$userId) return null;
    $stmt = $pdo->prepare('SELECT id, name, email, role FROM users WHERE id = ?');
    $stmt->execute([$userId]);
    $u = $stmt->fetch();
    return $u ? ['id' => $u['id'], 'name' => $u['name'], 'email' => $u['email'], 'role' => $u['role']] : null;
}

function sub_team_members_list(PDO $pdo, string $subTeamId): array {
    $stmt = $pdo->prepare(
        'SELECT u.id, u.name, u.email, u.role
           FROM sub_team_members m JOIN users u ON u.id = m.user_id
          WHERE m.sub_team_id = ?
          ORDER BY u.name ASC'
    );
    $stmt->execute([$subTeamId]);
    return array_map(fn($u) => [
        'id' => $u['id'], 'name' => $u['name'], 'email' => $u['email'], 'role' => $u['role'],
    ], $stmt->fetchAll());
}

function sub_team_payload(PDO $pdo, array $row): array {
    $members = sub_team_members_list($pdo, $row['id']);
    return [
        'id'           => $row['id'],
        'departmentId' => $row['department_id'],
        'name'         => $row['name'],
        'description'  => $row['description'],
        'lead'         => sub_team_mini_user($pdo, $row['lead_user_id']),
        'memberCount'  => count($members),
        'members'      => $members,
    ];
}

// director | manager de ESE departamento. Corta con 403 si no.
function sub_team_require_admin(PDO $pdo, array $user, string $departmentId): void {
    require_department_manager_or_director($pdo, $user, $departmentId);
}

// director | manager del área | sub-líder del sub-equipo. Para agregar/quitar
// miembros.
function sub_team_require_member_admin(PDO $pdo, array $user, array $subTeam): void {
    if ($user['role'] === 'director') return;
    if ($user['role'] === 'manager' && ($user['department_id'] ?? null) === $subTeam['department_id']) return;
    if (($subTeam['lead_user_id'] ?? null) === $user['id']) return;
    error_response('No puedes administrar los miembros de este sub-equipo', 403);
}

// Corta (400) si $userId no es un empleado verificado de $departmentId. Los
// sub-equipos solo agrupan gente que ya pertenece al área.
function sub_team_assert_department_member(PDO $pdo, string $userId, string $departmentId): void {
    $stmt = $pdo->prepare(
        "SELECT id FROM users
          WHERE id = ? AND department_id = ? AND role = 'employee' AND " . SQL_USER_VERIFIED
    );
    $stmt->execute([$userId, $departmentId]);
    if (!$stmt->fetch()) {
        error_response('Esa persona no es un empleado de esta área', 400);
    }
}

// ---- POST /subteam/create -------------------------------------------------

function subTeamCreate(PDO $pdo) {
    $user = require_auth($pdo);
    $body = request_body();

    $departmentId = trim($body['departmentId'] ?? '');
    if ($departmentId === '') {
        error_response('departmentId es requerido', 400);
    }
    $stmt = $pdo->prepare('SELECT id FROM departments WHERE id = ?');
    $stmt->execute([$departmentId]);
    if (!$stmt->fetch()) {
        error_response('Departamento no encontrado', 404);
    }
    sub_team_require_admin($pdo, $user, $departmentId);

    $name = trim($body['name'] ?? '');
    if ($name === '') {
        error_response('El nombre del sub-equipo es obligatorio', 400);
    }

    $stmt = $pdo->prepare('SELECT id FROM sub_teams WHERE department_id = ? AND name = ?');
    $stmt->execute([$departmentId, $name]);
    if ($stmt->fetch()) {
        error_response('Ya existe un sub-equipo con ese nombre en esta área', 409);
    }

    $id = generate_id();
    $stmt = $pdo->prepare(
        'INSERT INTO sub_teams (id, department_id, name, description) VALUES (?, ?, ?, ?)'
    );
    $stmt->execute([$id, $departmentId, $name, trim($body['description'] ?? '') ?: null]);

    json_response(['success' => true, 'subTeam' => sub_team_payload($pdo, sub_team_row($pdo, $id))]);
}

// ---- GET /subteam/list?departmentId=X -----------------------------------

function subTeamList(PDO $pdo) {
    $user = require_auth($pdo);

    $departmentId = trim($_GET['departmentId'] ?? '');
    if ($departmentId === '') {
        // Sin departamento explícito: el suyo (manager/empleado). El director
        // debe indicar cuál.
        $departmentId = $user['department_id'] ?? '';
    }
    if ($departmentId === '') {
        error_response('departmentId es requerido', 400);
    }
    // Ver los sub-equipos = poder ver las tareas de ese departamento.
    dept_task_require_view($user, $departmentId);

    $stmt = $pdo->prepare('SELECT * FROM sub_teams WHERE department_id = ? ORDER BY name ASC');
    $stmt->execute([$departmentId]);
    $subTeams = array_map(fn($r) => sub_team_payload($pdo, $r), $stmt->fetchAll());

    json_response(['success' => true, 'subTeams' => $subTeams]);
}

// ---- POST /subteam/{id} (editar nombre/descripción) --------------------

function subTeamUpdate(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    $row = sub_team_row($pdo, $id);
    if (!$row) error_response('Sub-equipo no encontrado', 404);
    sub_team_require_admin($pdo, $user, $row['department_id']);

    $body = request_body();
    $name = array_key_exists('name', $body) ? trim($body['name']) : $row['name'];
    if ($name === '') {
        error_response('El nombre del sub-equipo es obligatorio', 400);
    }
    if ($name !== $row['name']) {
        $stmt = $pdo->prepare('SELECT id FROM sub_teams WHERE department_id = ? AND name = ? AND id <> ?');
        $stmt->execute([$row['department_id'], $name, $id]);
        if ($stmt->fetch()) {
            error_response('Ya existe un sub-equipo con ese nombre en esta área', 409);
        }
    }
    $description = array_key_exists('description', $body)
        ? (trim($body['description']) ?: null)
        : $row['description'];

    $stmt = $pdo->prepare('UPDATE sub_teams SET name = ?, description = ? WHERE id = ?');
    $stmt->execute([$name, $description, $id]);

    json_response(['success' => true, 'subTeam' => sub_team_payload($pdo, sub_team_row($pdo, $id))]);
}

// ---- POST /subteam/{id}/delete ---------------------------------------

function subTeamDelete(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    $row = sub_team_row($pdo, $id);
    if (!$row) error_response('Sub-equipo no encontrado', 404);
    sub_team_require_admin($pdo, $user, $row['department_id']);

    // dept_tasks.sub_team_id -> NULL por la FK ON DELETE SET NULL; los
    // sub_team_members se van por CASCADE.
    $stmt = $pdo->prepare('DELETE FROM sub_teams WHERE id = ?');
    $stmt->execute([$id]);

    json_response(['success' => true, 'message' => 'Sub-equipo eliminado.']);
}

// ---- POST /subteam/{id}/setLead ------------------------------------
// body userId (vacío = quitar líder). El líder debe ser un empleado del área.

function subTeamSetLead(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    $row = sub_team_row($pdo, $id);
    if (!$row) error_response('Sub-equipo no encontrado', 404);
    sub_team_require_admin($pdo, $user, $row['department_id']);

    $body = request_body();
    $userId = trim($body['userId'] ?? '');

    if ($userId === '') {
        $stmt = $pdo->prepare('UPDATE sub_teams SET lead_user_id = NULL WHERE id = ?');
        $stmt->execute([$id]);
        json_response(['success' => true, 'subTeam' => sub_team_payload($pdo, sub_team_row($pdo, $id))]);
    }

    sub_team_assert_department_member($pdo, $userId, $row['department_id']);

    // El líder queda también como miembro del sub-equipo.
    $stmt = $pdo->prepare('INSERT IGNORE INTO sub_team_members (sub_team_id, user_id) VALUES (?, ?)');
    $stmt->execute([$id, $userId]);
    $stmt = $pdo->prepare('UPDATE sub_teams SET lead_user_id = ? WHERE id = ?');
    $stmt->execute([$userId, $id]);

    $stmt = $pdo->prepare('SELECT email FROM users WHERE id = ?');
    $stmt->execute([$userId]);
    $email = $stmt->fetchColumn();
    if ($email) {
        notify_user($pdo, $email, null, 'sub_team',
            'Ahora lideras el sub-equipo "' . $row['name'] . '".');
    }

    json_response(['success' => true, 'subTeam' => sub_team_payload($pdo, sub_team_row($pdo, $id))]);
}

// ---- POST /subteam/{id}/addMember & /removeMember ------------------

function subTeamAddMember(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    $row = sub_team_row($pdo, $id);
    if (!$row) error_response('Sub-equipo no encontrado', 404);
    sub_team_require_member_admin($pdo, $user, $row);

    $body = request_body();
    $userId = trim($body['userId'] ?? '');
    if ($userId === '') {
        error_response('userId es requerido', 400);
    }
    sub_team_assert_department_member($pdo, $userId, $row['department_id']);

    $stmt = $pdo->prepare('INSERT IGNORE INTO sub_team_members (sub_team_id, user_id) VALUES (?, ?)');
    $stmt->execute([$id, $userId]);

    json_response(['success' => true, 'subTeam' => sub_team_payload($pdo, sub_team_row($pdo, $id))]);
}

function subTeamRemoveMember(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    $row = sub_team_row($pdo, $id);
    if (!$row) error_response('Sub-equipo no encontrado', 404);
    sub_team_require_member_admin($pdo, $user, $row);

    $body = request_body();
    $userId = trim($body['userId'] ?? '');
    if ($userId === '') {
        error_response('userId es requerido', 400);
    }

    $stmt = $pdo->prepare('DELETE FROM sub_team_members WHERE sub_team_id = ? AND user_id = ?');
    $stmt->execute([$id, $userId]);
    // Si era el líder, deja de serlo.
    if (($row['lead_user_id'] ?? null) === $userId) {
        $stmt = $pdo->prepare('UPDATE sub_teams SET lead_user_id = NULL WHERE id = ?');
        $stmt->execute([$id]);
    }

    json_response(['success' => true, 'subTeam' => sub_team_payload($pdo, sub_team_row($pdo, $id))]);
}

// Limpia a un empleado de todos los sub-equipos de un departamento (al salir
// del área o al ser reasignado). La llama org.php / dept_tasks.php.
function sub_team_detach_user_from_department(PDO $pdo, string $userId, string $departmentId): void {
    $stmt = $pdo->prepare(
        'DELETE stm FROM sub_team_members stm
           JOIN sub_teams st ON st.id = stm.sub_team_id
          WHERE stm.user_id = ? AND st.department_id = ?'
    );
    $stmt->execute([$userId, $departmentId]);
    $stmt = $pdo->prepare(
        'UPDATE sub_teams SET lead_user_id = NULL WHERE lead_user_id = ? AND department_id = ?'
    );
    $stmt->execute([$userId, $departmentId]);
}
