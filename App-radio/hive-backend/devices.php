<?php
// Registro del token FCM del dispositivo para las notificaciones push
// (ver push.php). El cliente lo llama al iniciar sesión y al cerrarla.

// POST /devices/register — body { token, platform? }. Guarda el token FCM del
// dispositivo para el usuario autenticado. Idempotente por token: si el mismo
// dispositivo lo reenvía (o cambia de cuenta), se reasigna al usuario actual.
function deviceRegister(PDO $pdo) {
    $me = require_auth($pdo);
    $body = request_body();
    $token = trim((string) ($body['token'] ?? ''));
    $platform = (string) ($body['platform'] ?? 'android');
    if (!in_array($platform, ['android', 'ios', 'web'], true)) {
        $platform = 'android';
    }
    if ($token === '') {
        error_response('token is required', 400);
    }
    if (strlen($token) > 512) {
        error_response('token too long', 400);
    }
    $stmt = $pdo->prepare(
        'INSERT INTO device_tokens (email, token, platform)
         VALUES (?, ?, ?)
         ON DUPLICATE KEY UPDATE
             email = VALUES(email),
             platform = VALUES(platform),
             last_seen_at = NOW()'
    );
    $stmt->execute([$me['email'], $token, $platform]);
    json_response(['ok' => true]);
}

// POST /devices/unregister — body { token }. Lo llama el cliente al cerrar
// sesión. Idempotente.
function deviceUnregister(PDO $pdo) {
    $me = require_auth($pdo);
    $body = request_body();
    $token = trim((string) ($body['token'] ?? ''));
    if ($token === '') {
        error_response('token is required', 400);
    }
    // Acotado al dueño: un usuario no puede desregistrar el dispositivo de otro.
    // Sigue siendo idempotente (0 filas borradas => {ok:true}).
    $pdo->prepare('DELETE FROM device_tokens WHERE token = ? AND email = ?')
        ->execute([$token, $me['email']]);
    json_response(['ok' => true]);
}
