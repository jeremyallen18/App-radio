<?php
// Vinculación de dispositivo + evidencia biométrica del fichaje (Radio Doliv).
//
// Cada cuenta que ficha (employee / manager) queda atada a UN dispositivo
// confiado (`attendance_trusted_devices`, employee_id es PK). El primero se
// registra por "trust-on-first-use"; los cambios los aprueba el director.
// En la base solo se guardan HASHES sha256 de los identificadores.
//
// Cargado por index.php junto a attendance.php / attendance_admin.php; comparte
// los helpers json_response() y attendance_fail().

// Eventos que además exigen verificación biométrica del SO.
const ATT_BIOMETRIC_TYPES = ['entrada', 'salida'];

// sha256 hex de un identificador crudo; null si viene vacío.
function attendance_hash_id(?string $raw): ?string {
    $raw = trim((string) $raw);
    return $raw === '' ? null : hash('sha256', $raw);
}

// Normaliza los campos de dispositivo de un cuerpo (o de $_GET). key/uuid
// salen ya hasheados.
function attendance_device_from_body(array $body): array {
    $s = static fn($v, int $max) =>
        ($t = mb_substr(trim((string) ($v ?? '')), 0, $max)) === '' ? null : $t;
    $platform = $body['platform'] ?? '';
    return [
        'key'        => attendance_hash_id($body['deviceKey'] ?? null),
        'uuid'       => attendance_hash_id($body['deviceUuid'] ?? null),
        'platform'   => in_array($platform, ['android', 'ios'], true) ? $platform : 'android',
        'model'      => $s($body['model'] ?? null, 120),
        'osVersion'  => $s($body['osVersion'] ?? null, 60),
        'appVersion' => $s($body['appVersion'] ?? null, 30),
    ];
}

function attendance_trusted_device_for(PDO $pdo, string $employeeId): ?array {
    $st = $pdo->prepare('SELECT * FROM attendance_trusted_devices WHERE employee_id = ?');
    $st->execute([$employeeId]);
    return $st->fetch() ?: null;
}

// ¿El dispositivo de la petición es el confiado? Coincide por device_key; si la
// petición no trae key (el plugin falló), se acepta la coincidencia por uuid.
function attendance_device_matches(array $trusted, array $dev): bool {
    if ($dev['key'] !== null && hash_equals((string) $trusted['device_key'], $dev['key'])) {
        return true;
    }
    if ($dev['key'] === null && $dev['uuid'] !== null && $trusted['device_uuid'] !== null
        && hash_equals((string) $trusted['device_uuid'], $dev['uuid'])) {
        return true;
    }
    return false;
}

// Inserta o reemplaza el dispositivo confiado del empleado (es 1 solo).
function attendance_device_enroll(PDO $pdo, string $employeeId, array $dev, string $via, ?string $approvedBy = null): void {
    $key = $dev['key'] ?? $dev['uuid'];
    $st = $pdo->prepare(
        'REPLACE INTO attendance_trusted_devices
           (employee_id, device_key, device_uuid, platform, model, os_version, app_version,
            enrolled_at, enrolled_via, approved_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), ?, ?)'
    );
    $st->execute([
        $employeeId, $key, $dev['uuid'], $dev['platform'],
        $dev['model'], $dev['osVersion'], $dev['appVersion'], $via, $approvedBy,
    ]);
}

// Crea (o actualiza: +1 intento, reabre si estaba 'rejected') la solicitud de
// alta del dispositivo actual del empleado.
function attendance_device_upsert_request(PDO $pdo, string $employeeId, array $dev): void {
    $key = $dev['key'] ?? $dev['uuid'];
    if ($key === null) {
        return;
    }
    $st = $pdo->prepare(
        "INSERT INTO attendance_device_requests
           (employee_id, device_key, device_uuid, platform, model, os_version, app_version,
            status, attempts, first_seen, last_seen)
         VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', 1, NOW(), NOW())
         ON DUPLICATE KEY UPDATE
           attempts    = attempts + 1,
           last_seen   = NOW(),
           status      = IF(status = 'rejected', 'pending', status),
           device_uuid = VALUES(device_uuid),
           model       = VALUES(model),
           os_version  = VALUES(os_version),
           app_version = VALUES(app_version)"
    );
    $st->execute([
        $employeeId, $key, $dev['uuid'], $dev['platform'],
        $dev['model'], $dev['osVersion'], $dev['appVersion'],
    ]);
}

// Paso del pipeline de fichaje. Devuelve
//   ['status' => 'trusted'|'first_use'|'director_approved', 'key' => <hash|null>]
// o corta la petición con code=UNKNOWN_DEVICE (409) si hay un dispositivo
// confiado distinto.
function attendance_verify_device(PDO $pdo, string $employeeId, array $body): array {
    $dev = attendance_device_from_body($body);
    $key = $dev['key'] ?? $dev['uuid'];
    $trusted = attendance_trusted_device_for($pdo, $employeeId);

    if (!$trusted) {
        attendance_device_enroll($pdo, $employeeId, $dev, 'first_use');
        return ['status' => 'first_use', 'key' => $key];
    }
    if (attendance_device_matches($trusted, $dev)) {
        return [
            'status' => $trusted['enrolled_via'] === 'director' ? 'director_approved' : 'trusted',
            'key'    => $key,
        ];
    }
    attendance_device_upsert_request($pdo, $employeeId, $dev);
    json_response([
        'success' => false,
        'code'    => 'UNKNOWN_DEVICE',
        'message' => 'Este dispositivo no está autorizado para registrar tu asistencia. '
            . 'Solicita al director que lo autorice.',
    ], 409);
}

// Exige biometría solo en entrada y salida. Corta con BIOMETRIC_REQUIRED si el
// cliente no reporta una verificación válida ('ok' o 'skipped' = credencial del
// dispositivo). Devuelve ['result' => ?string, 'type' => ?string].
function attendance_check_biometric(array $body, string $type): array {
    if (!in_array($type, ATT_BIOMETRIC_TYPES, true)) {
        return ['result' => null, 'type' => null];
    }
    $result = $body['biometricResult'] ?? '';
    if (!in_array($result, ['ok', 'skipped'], true)) {
        json_response([
            'success' => false,
            'code'    => 'BIOMETRIC_REQUIRED',
            'message' => 'Debes completar la verificación de tu dispositivo para registrar la asistencia.',
        ], 409);
    }
    $btype = mb_substr(trim((string) ($body['biometricType'] ?? '')), 0, 20);
    return ['result' => $result, 'type' => $btype === '' ? null : $btype];
}

// Estado del dispositivo actual respecto de la cuenta, para pintar la UI:
//   'none'    — la cuenta no tiene dispositivo confiado (se vinculará al fichar)
//   'trusted' — este dispositivo es el confiado
//   'pending' — hay una solicitud pendiente para este dispositivo
//   'unknown' — hay otro dispositivo confiado y este no tiene solicitud pendiente
function attendance_device_state_for(PDO $pdo, string $employeeId, array $dev): string {
    $trusted = attendance_trusted_device_for($pdo, $employeeId);
    if (!$trusted) {
        return 'none';
    }
    if (attendance_device_matches($trusted, $dev)) {
        return 'trusted';
    }
    $key = $dev['key'] ?? $dev['uuid'];
    if ($key !== null) {
        $st = $pdo->prepare(
            'SELECT status FROM attendance_device_requests WHERE employee_id = ? AND device_key = ?'
        );
        $st->execute([$employeeId, $key]);
        $row = $st->fetch();
        if ($row && $row['status'] === 'pending') {
            return 'pending';
        }
    }
    return 'unknown';
}
