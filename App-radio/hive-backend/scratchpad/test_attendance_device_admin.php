<?php
require __DIR__ . '/../config.php';
require __DIR__ . '/../helpers.php';
require __DIR__ . '/../attendance_device.php';
require __DIR__ . '/../attendance.php';
require __DIR__ . '/../attendance_admin.php';

$pass = 0; $fail = 0;
function check(string $n, bool $ok): void {
    global $pass, $fail; echo ($ok ? "  OK   " : "  FAIL ") . $n . "\n"; $ok ? $pass++ : $fail++;
}

$emp = 'tmpadm' . substr(bin2hex(random_bytes(9)), 0, 18);
$dir = 'tmpdir' . substr(bin2hex(random_bytes(9)), 0, 18);
$pdo->prepare("INSERT INTO users (id,name,email,password,role,email_verified_at)
               VALUES (?, 'Emp', ?, 'x', 'employee', NOW())")->execute([$emp, $emp . '@t.local']);
$pdo->prepare("INSERT INTO users (id,name,email,password,role,email_verified_at)
               VALUES (?, 'Dir', ?, 'x', 'director', NOW())")->execute([$dir, $dir . '@t.local']);

function cleanup(PDO $pdo, string $emp, string $dir): void {
    foreach (['attendance_device_requests','attendance_trusted_devices','attendance'] as $t) {
        $pdo->prepare("DELETE FROM $t WHERE employee_id = ?")->execute([$emp]);
    }
    $pdo->prepare('DELETE FROM users WHERE id IN (?, ?)')->execute([$emp, $dir]);
    @unlink(__DIR__ . '/_child_resolve_404.php');
    @unlink(__DIR__ . '/_child_resolve_409.php');
}
register_shutdown_function('cleanup', $pdo, $emp, $dir);

$dirUser = ['id' => $dir, 'role' => 'director', 'email' => $dir . '@t.local'];

// Semilla: una solicitud pendiente.
attendance_device_upsert_request($pdo, $emp, attendance_device_from_body(
    ['deviceKey' => 'NEWKEY', 'deviceUuid' => 'NEWUUID', 'platform' => 'android', 'model' => 'Pixel 8']));
$reqId = (int) $pdo->query("SELECT id FROM attendance_device_requests WHERE employee_id = '$emp'")->fetchColumn();

// resolve approve -> crea/reemplaza dispositivo confiado
attendance_device_admin_resolve($pdo, $dirUser, $reqId, 'approve', null);
$t = attendance_trusted_device_for($pdo, $emp);
check('approve creo el dispositivo confiado', $t !== null && $t['device_key'] === hash('sha256', 'NEWKEY'));
check('approve marco enrolled_via=director', $t['enrolled_via'] === 'director');
$st = $pdo->query("SELECT status FROM attendance_device_requests WHERE id = $reqId")->fetchColumn();
check('approve dejo la solicitud en approved', $st === 'approved');

// segunda solicitud + reject
attendance_device_upsert_request($pdo, $emp, attendance_device_from_body(
    ['deviceKey' => 'KEY3', 'deviceUuid' => 'U3', 'platform' => 'ios']));
$req2 = (int) $pdo->query("SELECT id FROM attendance_device_requests WHERE employee_id = '$emp' AND device_key = '" . hash('sha256','KEY3') . "'")->fetchColumn();
attendance_device_admin_resolve($pdo, $dirUser, $req2, 'reject', 'no reconozco este equipo');
$row2 = $pdo->query("SELECT status, note, resolved_by FROM attendance_device_requests WHERE id = $req2")->fetch();
check('reject dejo la solicitud en rejected', $row2['status'] === 'rejected');
check('reject guardo la nota en la fila', $row2['note'] === 'no reconozco este equipo');
check('reject registro resolved_by = director', $row2['resolved_by'] === $dir);
check('reject no cambio el dispositivo confiado',
    attendance_trusted_device_for($pdo, $emp)['device_key'] === hash('sha256', 'NEWKEY'));

// anomalia unknown_device_attempt: req2 quedo 'rejected' con last_seen = NOW (dentro de 30 dias)
$anU = attendance_device_anomalies($pdo, 30);
$hasUnknown = false;
foreach ($anU as $a) { if ($a['type'] === 'unknown_device_attempt' && $a['employeeId'] === $emp) $hasUnknown = true; }
check('anomalia unknown_device_attempt detectada', $hasUnknown);

// guard 404: id inexistente -> attendance_fail(404) que hace exit. Proceso hijo.
$php = PHP_BINARY;
$c404 = __DIR__ . '/_child_resolve_404.php';
file_put_contents($c404, <<<'PHP'
<?php
require __DIR__ . '/../config.php';
require __DIR__ . '/../helpers.php';
require __DIR__ . '/../attendance_device.php';
require __DIR__ . '/../attendance.php';
require __DIR__ . '/../attendance_admin.php';
attendance_device_admin_resolve($pdo, ['id' => 'x', 'role' => 'director', 'email' => 'x'], 999999999, 'approve', null);
echo "NO_HALT";
PHP);
$out404 = (string) shell_exec(escapeshellarg($php) . ' ' . escapeshellarg($c404) . ' 2>&1');
@unlink($c404);
check('resolve 404: responde success:false', str_contains($out404, '"success":false'));
check('resolve 404: mensaje "no existe"', str_contains($out404, 'La solicitud no existe.'));
check('resolve 404: corto antes de terminar', !str_contains($out404, 'NO_HALT'));

// guard 409: solicitud ya resuelta (reqId ya esta 'approved'). Proceso hijo.
$c409 = __DIR__ . '/_child_resolve_409.php';
file_put_contents($c409, <<<'PHP'
<?php
require __DIR__ . '/../config.php';
require __DIR__ . '/../helpers.php';
require __DIR__ . '/../attendance_device.php';
require __DIR__ . '/../attendance.php';
require __DIR__ . '/../attendance_admin.php';
attendance_device_admin_resolve($pdo, ['id' => 'x', 'role' => 'director', 'email' => 'x'], (int) $argv[1], 'approve', null);
echo "NO_HALT";
PHP);
$out409 = (string) shell_exec(escapeshellarg($php) . ' ' . escapeshellarg($c409) . ' ' . escapeshellarg((string) $reqId) . ' 2>&1');
@unlink($c409);
check('resolve 409: responde success:false', str_contains($out409, '"success":false'));
check('resolve 409: mensaje "ya fue resuelta"', str_contains($out409, 'Esta solicitud ya fue resuelta.'));
check('resolve 409: corto antes de terminar', !str_contains($out409, 'NO_HALT'));

// reset tambien cierra solicitudes 'pending': se inserta una genuina antes del reset.
$pdo->prepare(
    "INSERT INTO attendance_device_requests
       (employee_id, device_key, device_uuid, platform, model, status, attempts, first_seen, last_seen)
     VALUES (?, ?, NULL, 'android', 'PendPhone', 'pending', 1, NOW(), NOW())"
)->execute([$emp, hash('sha256', 'PENDKEY')]);
$pendId = (int) $pdo->lastInsertId();

// reset borra el dispositivo confiado
attendance_device_admin_reset($pdo, $emp, $dir);
check('reset borro el dispositivo confiado', attendance_trusted_device_for($pdo, $emp) === null);
$pendRow = $pdo->query("SELECT status, resolved_by FROM attendance_device_requests WHERE id = $pendId")->fetch();
check('reset marco rechazada la solicitud pendiente', $pendRow['status'] === 'rejected');
check('reset registro resolved_by = director en la pendiente', $pendRow['resolved_by'] === $dir);

// anomalia first_use_after_history: fila confiada 'first_use' + attendance con device_key distinto
$pdo->prepare(
    "INSERT INTO attendance_trusted_devices
       (employee_id, device_key, device_uuid, platform, model, os_version, app_version,
        enrolled_at, enrolled_via, approved_by)
     VALUES (?, ?, NULL, 'android', 'FU Phone', NULL, NULL, NOW(), 'first_use', NULL)"
)->execute([$emp, hash('sha256', 'FUKEY')]);
$pdo->prepare(
    "INSERT INTO attendance (employee_id, type, work_date, event_time, device_key)
     VALUES (?, 'entrada', CURDATE(), NOW(), ?)"
)->execute([$emp, hash('sha256', 'OLDKEY')]);

// anomalia frequent_device_change: >1 approved en 30 dias
$pdo->prepare("UPDATE attendance_device_requests SET status='approved', resolved_at=NOW() WHERE employee_id=?")->execute([$emp]);
$an = attendance_device_anomalies($pdo, 30);
$hasFreq = false; $hasFirstUse = false;
foreach ($an as $a) {
    if ($a['type'] === 'frequent_device_change' && $a['employeeId'] === $emp) $hasFreq = true;
    if ($a['type'] === 'first_use_after_history' && $a['employeeId'] === $emp) $hasFirstUse = true;
}
check('anomalia frequent_device_change detectada', $hasFreq);
check('anomalia first_use_after_history detectada', $hasFirstUse);

echo "\n$pass passed, $fail failed\n";
exit($fail === 0 ? 0 : 1);
