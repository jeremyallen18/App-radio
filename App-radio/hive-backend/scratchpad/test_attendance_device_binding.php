<?php
// Harness de vinculación de dispositivo + biometría en el fichaje.
// Uso: C:\xampp\php\php.exe scratchpad/test_attendance_device_binding.php
require __DIR__ . '/../config.php';
require __DIR__ . '/../helpers.php';
require __DIR__ . '/../attendance_device.php';

$pass = 0; $fail = 0;
function check(string $name, bool $ok): void {
    global $pass, $fail;
    echo ($ok ? "  OK   " : "  FAIL ") . $name . "\n";
    $ok ? $pass++ : $fail++;
}

$empId = 'tmpdev' . substr(bin2hex(random_bytes(9)), 0, 18);
$pdo->prepare(
  "INSERT INTO users (id, name, email, password, role, email_verified_at)
   VALUES (?, 'Tmp Dev', ?, 'x', 'employee', NOW())"
)->execute([$empId, $empId . '@test.local']);

function cleanup(PDO $pdo, string $empId): void {
    $pdo->prepare('DELETE FROM attendance_device_requests WHERE employee_id = ?')->execute([$empId]);
    $pdo->prepare('DELETE FROM attendance_trusted_devices WHERE employee_id = ?')->execute([$empId]);
    $pdo->prepare('DELETE FROM attendance WHERE employee_id = ?')->execute([$empId]);
    $pdo->prepare('DELETE FROM users WHERE id = ?')->execute([$empId]);
}
register_shutdown_function('cleanup', $pdo, $empId);

// --- hash ---
check('hash de cadena vacía es null', attendance_hash_id('') === null);
check('hash es sha256 hex de 64', strlen(attendance_hash_id('abc')) === 64
    && attendance_hash_id('abc') === hash('sha256', 'abc'));

// --- from_body normaliza ---
$dev = attendance_device_from_body([
    'deviceKey' => 'RAWKEY-1', 'deviceUuid' => 'RAWUUID-1',
    'platform' => 'ios', 'model' => 'iPhone14,2', 'osVersion' => 'iOS 17.5', 'appVersion' => '1.0.0+1',
]);
check('from_body hashea la key', $dev['key'] === hash('sha256', 'RAWKEY-1'));
check('from_body hashea el uuid', $dev['uuid'] === hash('sha256', 'RAWUUID-1'));
check('from_body respeta platform válida', $dev['platform'] === 'ios');
check('from_body cae a android si platform inválida',
    attendance_device_from_body(['platform' => 'x'])['platform'] === 'android');

// --- first-use enrolla ---
$devA = attendance_device_from_body(['deviceKey' => 'KEY-A', 'deviceUuid' => 'UUID-A', 'platform' => 'android']);
$r = attendance_verify_device($pdo, $empId, ['deviceKey' => 'KEY-A', 'deviceUuid' => 'UUID-A', 'platform' => 'android']);
check('first-use devuelve status first_use', $r['status'] === 'first_use');
$t = attendance_trusted_device_for($pdo, $empId);
check('first-use creó la fila confiada', $t !== null && $t['enrolled_via'] === 'first_use');
check('device_state=trusted para el mismo dispositivo',
    attendance_device_state_for($pdo, $empId, $devA) === 'trusted');

// --- mismo dispositivo => trusted ---
$r2 = attendance_verify_device($pdo, $empId, ['deviceKey' => 'KEY-A', 'deviceUuid' => 'UUID-A', 'platform' => 'android']);
check('segundo fichaje del mismo => trusted', $r2['status'] === 'trusted');

// --- match por uuid cuando falta la key ---
check('match por uuid si key ausente',
    attendance_device_matches($t, attendance_device_from_body(['deviceUuid' => 'UUID-A', 'platform' => 'android'])) === true);
check('no-match si key distinta y sin uuid',
    attendance_device_matches($t, attendance_device_from_body(['deviceKey' => 'KEY-Z', 'platform' => 'android'])) === false);

// --- dispositivo desconocido crea solicitud + estado ---
attendance_device_upsert_request($pdo, $empId,
    attendance_device_from_body(['deviceKey' => 'KEY-B', 'deviceUuid' => 'UUID-B', 'platform' => 'android', 'model' => 'Pixel 7']));
$reqCount = $pdo->prepare('SELECT COUNT(*) FROM attendance_device_requests WHERE employee_id = ? AND status = "pending"');
$reqCount->execute([$empId]);
check('upsert_request creó 1 pendiente', (int) $reqCount->fetchColumn() === 1);
attendance_device_upsert_request($pdo, $empId,
    attendance_device_from_body(['deviceKey' => 'KEY-B', 'deviceUuid' => 'UUID-B', 'platform' => 'android', 'model' => 'Pixel 7']));
$att = $pdo->prepare('SELECT attempts FROM attendance_device_requests WHERE employee_id = ? AND device_key = ?');
$att->execute([$empId, hash('sha256', 'KEY-B')]);
check('reintento sube attempts a 2', (int) $att->fetchColumn() === 2);
check('device_state=pending para KEY-B',
    attendance_device_state_for($pdo, $empId,
        attendance_device_from_body(['deviceKey' => 'KEY-B', 'platform' => 'android'])) === 'pending');

// --- enroll director reemplaza ---
attendance_device_enroll($pdo, $empId,
    attendance_device_from_body(['deviceKey' => 'KEY-C', 'deviceUuid' => 'UUID-C', 'platform' => 'ios', 'model' => 'iPhone']),
    'director', null);
$t2 = attendance_trusted_device_for($pdo, $empId);
check('enroll director reemplazó el dispositivo', $t2['device_key'] === hash('sha256', 'KEY-C')
    && $t2['enrolled_via'] === 'director');

// --- biometría ---
$b = attendance_check_biometric(['biometricResult' => 'ok', 'biometricType' => 'face'], 'entrada');
check('biometría ok en entrada pasa', $b['result'] === 'ok' && $b['type'] === 'face');
$b2 = attendance_check_biometric([], 'inicio_comida');
check('biometría no exigida en inicio_comida', $b2['result'] === null);

echo "\n$pass passed, $fail failed\n";
exit($fail === 0 ? 0 : 1);
