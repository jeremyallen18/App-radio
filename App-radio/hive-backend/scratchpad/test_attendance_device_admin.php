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
$st2 = $pdo->query("SELECT status FROM attendance_device_requests WHERE id = $req2")->fetchColumn();
check('reject dejo la solicitud en rejected', $st2 === 'rejected');
check('reject no cambio el dispositivo confiado',
    attendance_trusted_device_for($pdo, $emp)['device_key'] === hash('sha256', 'NEWKEY'));

// reset borra el dispositivo confiado
attendance_device_admin_reset($pdo, $emp, $dir);
check('reset borro el dispositivo confiado', attendance_trusted_device_for($pdo, $emp) === null);

// anomalia frequent_device_change: 2 approved en 30 dias
$pdo->prepare("UPDATE attendance_device_requests SET status='approved', resolved_at=NOW() WHERE employee_id=?")->execute([$emp]);
$an = attendance_device_anomalies($pdo, 30);
$hasFreq = false;
foreach ($an as $a) { if ($a['type'] === 'frequent_device_change' && $a['employeeId'] === $emp) $hasFreq = true; }
check('anomalia frequent_device_change detectada', $hasFreq);

echo "\n$pass passed, $fail failed\n";
exit($fail === 0 ? 0 : 1);
