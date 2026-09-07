<?php
// Estructura organizacional de Radio Doliv: un único registro en `companies`,
// N `departments` colgando, y usuarios con role/position/department_id. Solo
// el director crea la empresa y los departamentos y asigna manager/empleados.

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
