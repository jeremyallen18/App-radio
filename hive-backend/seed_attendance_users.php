<?php
// Datos de prueba para el módulo de asistencia (Radio Doliv).
//
//   php seed_attendance_users.php
//
// Idempotente: se puede correr varias veces sin duplicar nada. Crea, dentro
// de la empresa ya existente, un departamento "Locución" con su manager y
// cuatro empleados con horario asignado, para probar:
//   - registro de asistencia de empleados,
//   - panel administrativo del director (ve a los 4),
//   - panel del manager (ve solo a los de su departamento),
//   - que el director NO puede registrar asistencia (rol != employee).
//
// Todas las contraseñas: Doliv2026!

require __DIR__ . '/config.php';
require __DIR__ . '/helpers.php';

$PASSWORD = 'Doliv2026!';
$hash = password_hash($PASSWORD, PASSWORD_BCRYPT);

function upsert_user(PDO $pdo, string $hash, string $name, string $email, string $role, ?string $deptId, ?string $position): string {
    $stmt = $pdo->prepare('SELECT id FROM users WHERE email = ?');
    $stmt->execute([$email]);
    $existing = $stmt->fetch();
    if ($existing) {
        $stmt = $pdo->prepare('UPDATE users SET name = ?, role = ?, department_id = ?, position = ? WHERE id = ?');
        $stmt->execute([$name, $role, $deptId, $position, $existing['id']]);
        return $existing['id'];
    }
    $id = generate_id();
    $stmt = $pdo->prepare(
        'INSERT INTO users (id, name, email, password, role, position, department_id) VALUES (?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([$id, $name, $email, $hash, $role, $position, $deptId]);
    return $id;
}

function upsert_schedule(PDO $pdo, string $employeeId, string $entry, string $exit, string $meal, int $max): void {
    $stmt = $pdo->prepare(
        'INSERT INTO employee_schedules (employee_id, entry_time, exit_time, meal_time, meal_max_minutes)
         VALUES (?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE entry_time = VALUES(entry_time), exit_time = VALUES(exit_time),
           meal_time = VALUES(meal_time), meal_max_minutes = VALUES(meal_max_minutes)'
    );
    $stmt->execute([$employeeId, $entry, $exit, $meal, $max]);
}

// ---- empresa --------------------------------------------------------
$company = $pdo->query('SELECT * FROM companies ORDER BY created_at ASC LIMIT 1')->fetch();
if (!$company) {
    $companyId = generate_id();
    $pdo->prepare('INSERT INTO companies (id, name, description) VALUES (?, ?, ?)')
        ->execute([$companyId, 'Radio Doliv', 'Estación de radio']);
    echo "empresa creada: Radio Doliv\n";
} else {
    $companyId = $company['id'];
    echo "empresa existente: {$company['name']}\n";
}

// ---- departamento "Locución" --------------------------------------
$stmt = $pdo->prepare('SELECT * FROM departments WHERE company_id = ? AND name = ?');
$stmt->execute([$companyId, 'Locución']);
$dept = $stmt->fetch();
if (!$dept) {
    $deptId = generate_id();
    $pdo->prepare('INSERT INTO departments (id, company_id, name, description) VALUES (?, ?, ?, ?)')
        ->execute([$deptId, $companyId, 'Locución', 'Cabina y locución al aire']);
    echo "departamento creado: Locución\n";
} else {
    $deptId = $dept['id'];
    echo "departamento existente: Locución\n";
}

// ---- manager del departamento -----------------------------------
$managerEmail = 'manager.locucion@doliv.test';
$managerId = upsert_user($pdo, $hash, 'Rosa Manager', $managerEmail, 'manager', $deptId, 'Jefa de Locución');
$pdo->prepare('UPDATE departments SET manager_email = ? WHERE id = ?')->execute([$managerEmail, $deptId]);
echo "manager: {$managerEmail}\n";

// ---- empleados con horario -------------------------------------
$employees = [
    ['Juan Pérez',   'juan.perez@doliv.test',   'Locutor',          '09:00:00', '17:00:00', '14:00:00', 60],
    ['María López',  'maria.lopez@doliv.test',  'Locutora',         '08:30:00', '16:30:00', '13:30:00', 45],
    ['Carlos Ruiz',  'carlos.ruiz@doliv.test',  'Operador de audio','09:00:00', '17:00:00', '14:00:00', 60],
    ['Ana Gómez',    'ana.gomez@doliv.test',    'Productora',       '10:00:00', '18:00:00', '15:00:00', 30],
];
foreach ($employees as [$name, $email, $position, $entry, $exit, $meal, $max]) {
    $empId = upsert_user($pdo, $hash, $name, $email, 'employee', $deptId, $position);
    upsert_schedule($pdo, $empId, $entry, $exit, $meal, $max);
    echo "empleado: {$email}  horario {$entry}-{$exit} comida {$meal} limite {$max}min\n";
}

// ---- departamento "Sistemas" y su manager ---------------------
// El departamento Sistemas puede existir ya con manager_email
// gerente.demo@example.com (cuenta demo sin contraseña conocida); aquí se le
// crea un perfil de manager real y probable.
$stmt = $pdo->prepare('SELECT * FROM departments WHERE company_id = ? AND name = ?');
$stmt->execute([$companyId, 'Sistemas']);
$sis = $stmt->fetch();
if (!$sis) {
    $sisId = generate_id();
    $pdo->prepare('INSERT INTO departments (id, company_id, name, description) VALUES (?, ?, ?, ?)')
        ->execute([$sisId, $companyId, 'Sistemas', 'Infraestructura y soporte técnico']);
    echo "departamento creado: Sistemas\n";
} else {
    $sisId = $sis['id'];
    echo "departamento existente: Sistemas\n";
}

$sisManagerEmail = 'manager.sistemas@doliv.test';
$sisManagerId = upsert_user($pdo, $hash, 'Diego Sistemas', $sisManagerEmail, 'manager', $sisId, 'Jefe de Sistemas');
upsert_schedule($pdo, $sisManagerId, '09:00:00', '18:00:00', '14:00:00', 60);
$pdo->prepare('UPDATE departments SET manager_email = ? WHERE id = ?')->execute([$sisManagerEmail, $sisId]);
echo "manager de Sistemas: {$sisManagerEmail}  (horario 09:00-18:00 comida 14:00 limite 60min)\n";

// Un empleado de Sistemas para poder probar el flujo de tareas ahí.
$sisEmpId = upsert_user($pdo, $hash, 'Laura Torres', 'laura.torres@doliv.test', 'employee', $sisId, 'Soporte técnico');
upsert_schedule($pdo, $sisEmpId, '09:00:00', '17:00:00', '14:00:00', 60);
echo "empleado de Sistemas: laura.torres@doliv.test\n";

echo "\nListo. Contraseña de todas las cuentas: {$PASSWORD}\n";
echo "Director (ya existente) puede revisar el panel pero NO registrar asistencia.\n";
