<?php
// Endpoints del trabajador para la vinculación de dispositivo:
//   POST /attendance/device/status
//   POST /attendance/device/request
//
// Mecanismo: se levanta el backend real con el servidor embebido de PHP
// (php -S) y se golpean los dos endpoints por HTTP con un token de sesión
// válido (users.token, que es como require_auth() autentica en este repo).
// Así se ejercita el enrutado de index.php + require_auth + los handlers.
//
// Uso: C:\xampp\php\php.exe scratchpad/test_attendance_device_endpoints.php

require __DIR__ . '/../config.php'; // provee $pdo (y las constantes de entorno)

const HOST = '127.0.0.1';
const PORT = 8765;
const BASE = 'http://' . HOST . ':' . PORT;

$pass = 0; $fail = 0;
function check(string $n, bool $ok): void {
    global $pass, $fail;
    echo ($ok ? "  OK   " : "  FAIL ") . $n . "\n";
    $ok ? $pass++ : $fail++;
}

// --- fixtures ---------------------------------------------------------------
$empId = 'tmpdev' . substr(bin2hex(random_bytes(9)), 0, 18); // 24 chars
$email = $empId . '@test.local';
$token = 'devtok' . bin2hex(random_bytes(24));
$pdo->prepare(
    "INSERT INTO users (id, name, email, password, role, token, email_verified_at)
     VALUES (?, 'Tmp Device', ?, 'x', 'employee', ?, NOW())"
)->execute([$empId, $email, $token]);

$serverProc = null;
function cleanup(): void {
    global $pdo, $empId, $serverProc;
    if (is_resource($serverProc)) {
        proc_terminate($serverProc);
        proc_close($serverProc);
    }
    foreach (['attendance_device_requests', 'attendance_trusted_devices', 'attendance'] as $t) {
        $pdo->prepare("DELETE FROM $t WHERE employee_id = ?")->execute([$empId]);
    }
    $pdo->prepare('DELETE FROM users WHERE id = ?')->execute([$empId]);
}
register_shutdown_function('cleanup');

// --- arrancar el servidor embebido --------------------------------------
$logFile = tempnam(sys_get_temp_dir(), 'attdev_srv_');
$serverProc = proc_open(
    escapeshellarg(PHP_BINARY) . ' -S ' . HOST . ':' . PORT . ' index.php',
    [0 => ['pipe', 'r'], 1 => ['file', $logFile, 'w'], 2 => ['file', $logFile, 'a']],
    $pipes,
    dirname(__DIR__)
);
if (!is_resource($serverProc)) {
    fwrite(STDERR, "No se pudo arrancar php -S\n");
    exit(1);
}
// esperar a que el puerto acepte conexiones
$up = false;
for ($i = 0; $i < 100; $i++) {
    $c = @fsockopen(HOST, PORT, $errno, $errstr, 0.2);
    if ($c) { fclose($c); $up = true; break; }
    usleep(100_000);
}
if (!$up) {
    fwrite(STDERR, "El servidor no respondió en el puerto " . PORT . "\n");
    fwrite(STDERR, (string) @file_get_contents($logFile) . "\n");
    exit(1);
}

// --- helpers HTTP ------------------------------------------------------------
function http_req(string $method, string $path, string $token, ?array $json = null): array {
    $headers = ['Authorization: Bearer ' . $token];
    $opts = ['http' => ['method' => $method, 'ignore_errors' => true, 'timeout' => 10]];
    if ($json !== null) {
        $headers[] = 'Content-Type: application/json';
        $opts['http']['content'] = json_encode($json);
    }
    $opts['http']['header'] = implode("\r\n", $headers);
    $raw = @file_get_contents(BASE . $path, false, stream_context_create($opts));
    $status = 0;
    foreach ($http_response_header ?? [] as $h) {
        if (preg_match('#^HTTP/\S+\s+(\d+)#', $h, $m)) { $status = (int) $m[1]; }
    }
    return ['status' => $status, 'body' => (string) $raw, 'json' => json_decode((string) $raw, true)];
}

// --- 1) status sin dispositivo confiado => state:none ------------------
// POST con los identificadores en el CUERPO: nunca en la query string (no deben
// acabar en los logs de acceso del servidor web).
$r = http_req('POST', '/attendance/device/status', $token,
    ['deviceKey' => 'K1', 'deviceUuid' => 'U1', 'platform' => 'android']);
check('status responde 200', $r['status'] === 200);
check('status: success true', ($r['json']['success'] ?? null) === true);
check('status: state === "none" sin dispositivo confiado', ($r['json']['state'] ?? null) === 'none');
check('status: device === null', array_key_exists('device', $r['json'] ?? []) && $r['json']['device'] === null);

// --- 2) request crea exactamente una solicitud pendiente --------------
$r = http_req('POST', '/attendance/device/request', $token, [
    'deviceKey'  => 'K1',
    'deviceUuid' => 'U1',
    'platform'   => 'android',
    'model'      => 'Pixel 7',
    'osVersion'  => '14',
    'appVersion' => '1.2.3',
]);
check('request responde 200', $r['status'] === 200);
check('request: success true', ($r['json']['success'] ?? null) === true);
check('request: state === "pending"', ($r['json']['state'] ?? null) === 'pending');
check('request: incluye message', !empty($r['json']['message']));

$c = $pdo->prepare("SELECT COUNT(*) FROM attendance_device_requests WHERE employee_id = ? AND status = 'pending'");
$c->execute([$empId]);
check('request creó exactamente 1 fila pendiente', (int) $c->fetchColumn() === 1);

// --- 3) idempotencia: segundo request no crea otra fila --------------
$r = http_req('POST', '/attendance/device/request', $token, [
    'deviceKey' => 'K1', 'deviceUuid' => 'U1', 'platform' => 'android', 'model' => 'Pixel 7',
]);
check('segundo request sigue en state "pending"', ($r['json']['state'] ?? null) === 'pending');
$c->execute([$empId]);
check('sigue habiendo exactamente 1 fila pendiente', (int) $c->fetchColumn() === 1);
$a = $pdo->prepare("SELECT attempts FROM attendance_device_requests WHERE employee_id = ? AND device_key = ?");
$a->execute([$empId, hash('sha256', 'K1')]);
check('attempts se incrementó a 2', (int) $a->fetchColumn() === 2);

// Sin dispositivo confiado, el estado sigue siendo "none" aunque exista una
// solicitud pendiente: "pending" solo aplica cuando hay OTRO dispositivo
// confiado (ver attendance_device_state_for). Aquí no se ha hecho enroll.
$r = http_req('POST', '/attendance/device/status', $token,
    ['deviceKey' => 'K1', 'deviceUuid' => 'U1', 'platform' => 'android']);
check('status: sigue "none" (no hay dispositivo confiado)', ($r['json']['state'] ?? null) === 'none');

// La ruta ya NO acepta GET: los identificadores no viajan por la URL.
$rGet = http_req('GET', '/attendance/device/status?deviceKey=K1&platform=android', $token);
check('status por GET ya no está enrutado', $rGet['status'] === 404);

echo "\n$pass passed, $fail failed\n";
exit($fail === 0 ? 0 : 1);
