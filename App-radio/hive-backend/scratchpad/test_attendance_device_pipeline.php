<?php
// Pipeline de fichaje con verificación de dispositivo + biometría.
// Ejercita los handlers sin HTTP: llena $_SERVER/php://input vía un shim.
// Uso: C:\xampp\php\php.exe scratchpad/test_attendance_device_pipeline.php
require __DIR__ . '/../config.php';
require __DIR__ . '/../helpers.php';
require __DIR__ . '/../attendance_device.php';
require __DIR__ . '/../attendance.php';

$pass = 0; $fail = 0;
function check(string $n, bool $ok): void {
    global $pass, $fail; echo ($ok ? "  OK   " : "  FAIL ") . $n . "\n"; $ok ? $pass++ : $fail++;
}

$empId = 'tmppipe' . substr(bin2hex(random_bytes(9)), 0, 17);
$pdo->prepare(
  "INSERT INTO users (id, name, email, password, role, email_verified_at)
   VALUES (?, 'Tmp Pipe', ?, 'x', 'employee', NOW())"
)->execute([$empId, $empId . '@test.local']);
$pdo->prepare(
  "INSERT INTO employee_schedules
     (employee_id, entry_time, exit_time, meal_time, meal_max_minutes, late_tolerance_minutes)
   VALUES (?, '00:00:00', '23:59:00', '12:00:00', 60, 15)"
)->execute([$empId]);

function cleanup(PDO $pdo, string $empId): void {
    foreach (['attendance_device_requests','attendance_trusted_devices','attendance',
              'attendance_schedule_snapshots','employee_schedules'] as $t) {
        $pdo->prepare("DELETE FROM $t WHERE employee_id = ?")->execute([$empId]);
    }
    $pdo->prepare('DELETE FROM users WHERE id = ?')->execute([$empId]);
}
register_shutdown_function('cleanup', $pdo, $empId);

// Inserta una entrada directamente vía el helper (sin ventana horaria) para
// probar SOLO la persistencia de evidencia.
$ev = attendance_insert_event($pdo, $empId, date('Y-m-d'), 'entrada',
    ['latitude' => '1', 'longitude' => '2', 'locationAccuracy' => '7.5'],
    ['device_key' => 'HASHK', 'device_status' => 'first_use',
     'biometric_result' => 'ok', 'biometric_type' => 'face']);
$row = $pdo->query("SELECT * FROM attendance WHERE employee_id = '$empId' AND type = 'entrada'")->fetch();
check('evidencia: device_key persistido', $row['device_key'] === 'HASHK');
check('evidencia: device_status persistido', $row['device_status'] === 'first_use');
check('evidencia: biometric_result persistido', $row['biometric_result'] === 'ok');
check('evidencia: biometric_type persistido', $row['biometric_type'] === 'face');
check('evidencia: location_accuracy_m persistido', (float) $row['location_accuracy_m'] === 7.5);

// first-use: verify_device sobre una cuenta sin dispositivo confiado enrola.
$pdo->prepare('DELETE FROM attendance WHERE employee_id = ?')->execute([$empId]);
$r = attendance_verify_device($pdo, $empId,
    ['deviceKey' => 'K1', 'deviceUuid' => 'U1', 'platform' => 'android']);
check('verify_device first-use', $r['status'] === 'first_use'
    && attendance_trusted_device_for($pdo, $empId) !== null);

// dispositivo distinto: se corre en proceso hijo para capturar el exit + JSON.
$php = PHP_BINARY;
$script = __DIR__ . '/_child_unknown_device.php';
file_put_contents($script, <<<'PHP'
<?php
require __DIR__ . '/../config.php';
require __DIR__ . '/../helpers.php';
require __DIR__ . '/../attendance_device.php';
$empId = $argv[1];
attendance_verify_device($pdo, $empId, ['deviceKey' => 'OTHER', 'deviceUuid' => 'OTHER-U', 'platform' => 'android']);
PHP);
$out = shell_exec(escapeshellarg($php) . ' ' . escapeshellarg($script) . ' ' . escapeshellarg($empId) . ' 2>&1');
@unlink($script);
check('dispositivo distinto responde UNKNOWN_DEVICE', str_contains((string) $out, 'UNKNOWN_DEVICE'));
$pend = $pdo->prepare("SELECT COUNT(*) FROM attendance_device_requests WHERE employee_id = ? AND status='pending'");
$pend->execute([$empId]);
check('dispositivo distinto dejó solicitud pendiente', (int) $pend->fetchColumn() === 1);

echo "\n$pass passed, $fail failed\n";
exit($fail === 0 ? 0 : 1);
