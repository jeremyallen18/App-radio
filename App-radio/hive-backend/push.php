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
        CURLOPT_TIMEOUT        => 10,
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

    @file_put_contents($cacheFile, json_encode([
        'token' => $data['access_token'],
        'exp'   => $now + (int) ($data['expires_in'] ?? 3600),
    ]));

    return (string) $data['access_token'];
}
