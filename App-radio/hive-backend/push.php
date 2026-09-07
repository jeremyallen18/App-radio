<?php
// Envío de notificaciones push por Firecloud Messaging (FCM HTTP v1).
// PHP puro, sin Composer: el JWT se firma con openssl_sign. El envío es
// best-effort — quien llame NUNCA debe romperse si esto falla.
//
// Semillas inyectables para pruebas:
//   $GLOBALS['fcm_clock']     = fn(): int => ...;      // reemplaza time()
//   $GLOBALS['fcm_http_post'] = fn($url,$headers,$body): array => [int,string];

require_once __DIR__ . '/config.php'; // env_get()

function fcm_service_account(): ?array {
    static $cached = null;
    if ($cached !== null) {
        return $cached === false ? null : $cached;
    }
    $path = __DIR__ . '/private/fcm-service-account.json';
    if (!is_file($path)) {
        $cached = false;
        return null;
    }
    $decoded = json_decode((string) file_get_contents($path), true);
    $cached = (is_array($decoded) && isset($decoded['client_email'], $decoded['private_key']))
        ? $decoded
        : false;
    return $cached === false ? null : $cached;
}

function fcm_enabled(): bool {
    return FCM_PROJECT_ID !== '' && fcm_service_account() !== null;
}

function fcm_b64url(string $bin): string {
    return rtrim(strtr(base64_encode($bin), '+/', '-_'), '=');
}

function fcm_now(): int {
    return isset($GLOBALS['fcm_clock']) ? (int) ($GLOBALS['fcm_clock'])() : time();
}

/** @return array{0:int,1:string} [status, body] */
function fcm_http_post(string $url, array $headers, string $body): array {
    if (isset($GLOBALS['fcm_http_post'])) {
        return ($GLOBALS['fcm_http_post'])($url, $headers, $body);
    }
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_POST           => true,
        CURLOPT_HTTPHEADER     => $headers,
        CURLOPT_POSTFIELDS     => $body,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 3,
        CURLOPT_TIMEOUT        => 5,
    ]);
    $resp = curl_exec($ch);
    if ($resp === false) {
        $err = curl_error($ch);
        curl_close($ch);
        throw new RuntimeException('fcm curl: ' . $err);
    }
    $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    return [$status, (string) $resp];
}

function fcm_access_token(): string {
    $cacheFile = __DIR__ . '/private/fcm-token.cache';
    $now = fcm_now();

    if (is_file($cacheFile)) {
        $c = json_decode((string) file_get_contents($cacheFile), true);
        if (is_array($c) && isset($c['token'], $c['exp']) && $c['exp'] > $now + 60) {
            return (string) $c['token'];
        }
    }

    $sa = fcm_service_account();
    if ($sa === null) {
        throw new RuntimeException('FCM service account not configured');
    }

    $header = fcm_b64url(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
    $claim = fcm_b64url(json_encode([
        'iss'   => $sa['client_email'],
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud'   => 'https://oauth2.googleapis.com/token',
        'iat'   => $now,
        'exp'   => $now + 3600,
    ]));

    $signature = '';
    if (!openssl_sign("$header.$claim", $signature, $sa['private_key'], OPENSSL_ALGO_SHA256)) {
        throw new RuntimeException('FCM JWT signing failed');
    }
    $jwt = "$header.$claim." . fcm_b64url($signature);

    [$status, $body] = fcm_http_post(
        'https://oauth2.googleapis.com/token',
        ['Content-Type: application/x-www-form-urlencoded'],
        http_build_query([
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion'  => $jwt,
        ])
    );

    $data = json_decode($body, true);
    if ($status !== 200 || !is_array($data) || !isset($data['access_token'])) {
        throw new RuntimeException('FCM token exchange failed (HTTP ' . $status . '): ' . $body);
    }

    // Escritura atómica: se escribe a un temporal y se renombra encima, para
    // que un lector concurrente nunca vea un JSON a medias.
    $tmp = $cacheFile . '.' . getmypid() . '.tmp';
    if (@file_put_contents($tmp, json_encode([
        'token' => $data['access_token'],
        'exp'   => $now + (int) ($data['expires_in'] ?? 3600),
    ])) !== false) {
        if (!@rename($tmp, $cacheFile)) {
            @unlink($tmp);
        }
    }

    return (string) $data['access_token'];
}

function push_title_for_type(string $type): string {
    switch ($type) {
        case 'chat':
            return 'Nuevo mensaje';
        case 'dept_task':
            return 'Tarea';
        case 'task_assigned':
            return 'Tarea asignada';
        case 'event_created':
            return 'Evento';
        case 'event_reminder':
            return 'Recordatorio de evento';
        case 'internal_announcement':
            return 'Anuncio';
        case 'internal_announcement_reminder':
            return 'Recordatorio de anuncio';
        case 'attendance_correction':
            return 'Asistencia';
        case 'absence_justification':
            return 'Ausencia';
        case 'absence_approved':
        case 'absence_rejected':
            return 'Justificación revisada';
        case 'leave_approved':
        case 'leave_rejected':
        case 'leave_cancelled':
            return 'Permiso';
        case 'member_removed':
        case 'team_deleted':
        case 'leader_assigned':
        case 'department_removed':
        case 'department_assigned':
        case 'department_manager_assigned':
            return 'Equipo';
        default:
            return 'Radio Doliv';
    }
}

function push_send_to_user(
    PDO $pdo,
    string $email,
    string $title,
    string $body,
    array $data,
    ?string $collapseKey = null
): void {
    if (!fcm_enabled()) {
        return;
    }

    // Cortacircuitos por petición: en PHP-FPM/mod_php una función `static` se
    // reinicia en cada petición (proceso/script nuevo), así que este contador
    // sólo agrupa los envíos de ESTA petición. Si FCM falla 5 veces seguidas
    // (timeouts, excepciones de transporte o respuestas no-2xx) se abandona el
    // resto de envíos para no arriesgar un fatal por max_execution_time.
    static $consecutiveFailures = 0;

    // Backstop: PDO corre en ERRMODE_EXCEPTION (config.php), así que el SELECT
    // y el DELETE de purga pueden lanzar PDOException. push_send_to_user NUNCA
    // debe propagar — cualquier fallo se registra y la función retorna normal.
    try {
        $stmt = $pdo->prepare('SELECT token FROM device_tokens WHERE email = ?');
        $stmt->execute([$email]);
        $tokens = $stmt->fetchAll(PDO::FETCH_COLUMN) ?: [];
        if (!$tokens) {
            return;
        }

        try {
            $access = fcm_access_token();
        } catch (Throwable $e) {
            error_log('push: token exchange failed: ' . $e->getMessage());
            return;
        }

        $payloadData = ['title' => $title, 'body' => $body];
        foreach ($data as $k => $v) {
            $payloadData[(string) $k] = (string) $v;
        }

        $url = 'https://fcm.googleapis.com/v1/projects/' . FCM_PROJECT_ID . '/messages:send';
        $headers = ['Authorization: Bearer ' . $access, 'Content-Type: application/json'];

        // Se reintenta el canje del token de acceso como mucho una vez por
        // llamada (token revocado que sigue cacheado ~55 min).
        $retriedAuth = false;

        foreach ($tokens as $token) {
            $android = ['priority' => 'high'];
            if ($collapseKey !== null && $collapseKey !== '') {
                $android['collapse_key'] = $collapseKey;
            }
            $message = ['message' => [
                'token'   => $token,
                'data'    => $payloadData,
                'android' => $android,
            ]];
            $payload = json_encode($message);

            try {
                [$status, $respBody] = fcm_http_post($url, $headers, $payload);
            } catch (Throwable $e) {
                error_log('push: send failed: ' . $e->getMessage());
                if (++$consecutiveFailures >= 5) {
                    error_log('push: circuit breaker tripped, skipping remaining sends this request');
                    return;
                }
                continue;
            }

            // Token de acceso revocado: invalidar el cache y reintentar ESTE
            // token una sola vez con un token recién canjeado.
            if (($status === 401 || $status === 403) && !$retriedAuth) {
                $retriedAuth = true;
                @unlink(__DIR__ . '/private/fcm-token.cache');
                try {
                    $access = fcm_access_token();
                } catch (Throwable $e) {
                    error_log('push: token re-fetch failed: ' . $e->getMessage());
                    break;
                }
                $headers = ['Authorization: Bearer ' . $access, 'Content-Type: application/json'];
                try {
                    [$status, $respBody] = fcm_http_post($url, $headers, $payload);
                } catch (Throwable $e) {
                    error_log('push: send failed: ' . $e->getMessage());
                    if (++$consecutiveFailures >= 5) {
                        error_log('push: circuit breaker tripped, skipping remaining sends this request');
                        return;
                    }
                    continue;
                }
            }

            if ($status < 200 || $status >= 300) {
                error_log('push: FCM HTTP ' . $status . ': ' . substr($respBody, 0, 500));
                if (++$consecutiveFailures >= 5) {
                    error_log('push: circuit breaker tripped, skipping remaining sends this request');
                    return;
                }
            } else {
                $consecutiveFailures = 0;
            }

            if ($status === 404
                || strpos($respBody, 'UNREGISTERED') !== false
                || strpos($respBody, 'registration-token-not-registered') !== false) {
                $pdo->prepare('DELETE FROM device_tokens WHERE token = ?')->execute([$token]);
            }
        }
    } catch (Throwable $e) {
        error_log('push_send_to_user failed: ' . $e->getMessage());
    }
}
