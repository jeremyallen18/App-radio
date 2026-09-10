# Android Push Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver every notification the backend already creates (`notify_user()`) as an Android push, reaching users when the app is backgrounded or closed.

**Architecture:** The backend sends a data-only FCM HTTP v1 message from inside `notify_user()`, authenticated with a pure-PHP RS256 JWT exchanged for a cached OAuth2 token. Devices register their FCM token via two new authenticated endpoints. The Flutter client always renders received messages with `flutter_local_notifications` (foreground and background), collapses chat pushes per conversation, suppresses the toast for a chat thread that is currently open, and routes taps through the existing `NotificationRouter`.

**Tech Stack:** PHP 8 (vanilla, no Composer) + MySQL; Flutter 3.41 (Dart 3.9) with `firebase_core`, `firebase_messaging`, `flutter_local_notifications`, `http`.

**Spec:** `docs/superpowers/specs/2026-09-06-push-notifications-design.md`

## Global Constraints

- **Platform scope:** Android only. Do not add iOS/macOS/web/Windows Firebase config. Dart code must not reference iOS-only APIs.
- **No Composer in the backend.** JWT signing uses `openssl_sign` + `OPENSSL_ALGO_SHA256`. HTTP uses `curl`.
- **Push is best-effort.** Every send path is wrapped so a failure never changes the HTTP response or aborts `notify_user()`. The in-app `notifications` row is the source of truth.
- **Messages are data-only.** No `notification` block in the FCM payload; `title`/`body` travel inside `data`. The client renders every message.
- **No user-facing preferences** in this version. Opt-out is the Android OS permission.
- **Env config:** backend reads config via `env_get('KEY')` (from `hive-backend/.env`), never `getenv()`. New key: `FCM_PROJECT_ID`.
- **Secrets:** `hive-backend/private/fcm-service-account.json` and `hive-backend/private/fcm-token.cache` are git-ignored. `android/app/google-services.json` IS committed (documented as swappable on client handover).
- **App id / FCM package name:** `com.example.brl_task4` (current `applicationId` in `android/app/build.gradle.kts`; do not change it).
- **Backend router:** routes are `[$METHOD, $pcre, $handlerFn]` tuples in the `$routes` array in `hive-backend/index.php`; handlers are `function handler(PDO $pdo, ...$urlArgs)`. Response helpers: `json_response($data, $status=200)`, `text_response($msg, $status)`, `error_response($msg, $status=400)` (all `exit`). `require_auth(PDO): array` returns the user row (`['email'], ['id'], ['role'], ...`). `request_body(): array` parses JSON or form body.
- **Notification titles** (Spanish, from `push_title_for_type`): `chat`→"Nuevo mensaje"; `dept_task`/`task_assigned`→"Tarea"; `event_created`/`event_reminder`→"Evento"; `internal_announcement`/`internal_announcement_reminder`→"Anuncio"; `attendance_correction`→"Asistencia"; `absence_justification`/`absence_approved`/`absence_rejected`→"Ausencia"; `leave_approved`/`leave_rejected`/`leave_cancelled`→"Permiso"; `member_removed`/`team_deleted`/`leader_assigned`/`department_removed`/`department_assigned`/`department_manager_assigned`→"Equipo"; default→"Radio Doliv".

---

## File Structure

**Backend (create):**
- `hive-backend/migrations/026_device_tokens.sql` — `device_tokens` table.
- `hive-backend/push.php` — FCM: config check, service-account loader, JWT + OAuth2 token cache, `push_send_to_user`, `push_title_for_type`, injectable HTTP/clock seams.

**Backend (modify):**
- `hive-backend/schema.sql` — add `device_tokens` DDL.
- `hive-backend/config.php` — define `FCM_PROJECT_ID`.
- `hive-backend/.env.example` — document `FCM_PROJECT_ID`.
- `hive-backend/helpers.php` — `require_once __DIR__ . '/push.php';`; `notify_user()` fires a push after the INSERT.
- `hive-backend/index.php` — two routes + `deviceRegister` / `deviceUnregister` handlers.
- `.gitignore` — ignore FCM secrets + `/scratchpad/`.

**Flutter (create):**
- `lib/core/push/push_messages.dart` — pure helpers (`normalizePushData`, `shouldShowLocalNotification`, `localNotificationId`).
- `lib/core/push/push_service.dart` — `PushService` singleton, `ensureFirebaseInitialized`, `appNavigatorKey`, background handler.
- `lib/firebase_options.dart` — Android-only `DefaultFirebaseOptions`.
- `android/app/google-services.json` — from the Firebase console.
- `test/push_messages_test.dart` — unit tests for the pure helpers.

**Flutter (modify):**
- `pubspec.yaml` — add the three deps.
- `android/settings.gradle.kts` — declare the `com.google.gms.google-services` plugin.
- `android/app/build.gradle.kts` — apply the plugin; enable core-library desugaring.
- `android/app/src/main/AndroidManifest.xml` — `POST_NOTIFICATIONS` permission.
- `lib/main.dart` — init Firebase, register background handler, set `navigatorKey`, kick off `PushService.init()` when a session exists.
- `lib/shared/auth/login.dart` — `PushService.instance.init()` after a successful login.
- `lib/shared/home/profile.dart` — `PushService.instance.disable()` during logout, before the token is deleted.
- `lib/shared/chat/chat.dart` — set/clear the active chat peer on the `ChatScreen` thread view.

---

## Task 1: `device_tokens` table

**Files:**
- Create: `hive-backend/migrations/026_device_tokens.sql`
- Modify: `hive-backend/schema.sql` (append near the other `CREATE TABLE` blocks, after `notifications`)
- Test: `scratchpad/test_push.php` (new; created here, extended by later tasks)

**Interfaces:**
- Produces: table `device_tokens(id, email, token, platform, created_at, last_seen_at)`, `UNIQUE KEY uq_token (token(191))`, `KEY idx_email (email)`.

- [ ] **Step 1: Write the migration**

`hive-backend/migrations/026_device_tokens.sql`:

```sql
-- 026: FCM device tokens for Android push notifications.
-- Sin FK a users (igual que `notifications`): la relación es por email.
CREATE TABLE IF NOT EXISTS device_tokens (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email         VARCHAR(255) NOT NULL,
  token         VARCHAR(512) NOT NULL,
  platform      ENUM('android','ios','web') NOT NULL DEFAULT 'android',
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_token (token(191)),
  KEY idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

- [ ] **Step 2: Mirror the DDL into `schema.sql`**

Paste the same `CREATE TABLE device_tokens (...)` block into `hive-backend/schema.sql` immediately after the `notifications` table definition. Match the file's existing quoting/indent style (it uses plain `CREATE TABLE` blocks).

- [ ] **Step 3: Apply the migration to the live DB**

Run:
```bash
"/c/Program Files/MySQL/MySQL Server 9.6/bin/mysql.exe" -uhive_user -p'HivePass_2026!' hive_db < hive-backend/migrations/026_device_tokens.sql
```
Expected: no output, exit 0.

- [ ] **Step 4: Create `scratchpad/test_push.php` with the schema check**

```php
<?php
// Ejecutar: php scratchpad/test_push.php
// Pruebas de integración del push (no se commitea; scratchpad está en .gitignore).
require __DIR__ . '/../hive-backend/config.php'; // define $pdo, env_get()

$failures = 0;
function check(string $name, bool $ok): void {
    global $failures;
    echo ($ok ? "PASS " : "FAIL ") . $name . PHP_EOL;
    if (!$ok) $failures++;
}

// --- Task 1: tabla device_tokens existe con las columnas esperadas ---
$cols = $pdo->query("SHOW COLUMNS FROM device_tokens")->fetchAll(PDO::FETCH_COLUMN);
check('device_tokens has email/token/platform columns',
    in_array('email', $cols, true) &&
    in_array('token', $cols, true) &&
    in_array('platform', $cols, true));

echo PHP_EOL . ($failures === 0 ? "ALL PASS" : "$failures FAILURE(S)") . PHP_EOL;
exit($failures === 0 ? 0 : 1);
```

Note: confirm `hive-backend/config.php` exposes `$pdo` at include time (it does — `index.php` relies on it). If it also emits headers/output, guard by defining `if (!defined('PHP_SAPI') ...)`—not needed for CLI.

- [ ] **Step 5: Run the check**

Run: `php scratchpad/test_push.php`
Expected: `PASS device_tokens has email/token/platform columns` then `ALL PASS`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add hive-backend/migrations/026_device_tokens.sql hive-backend/schema.sql
git commit -m "feat(push): device_tokens table + migration 026"
```

---

## Task 2: FCM config plumbing + `push.php` foundation

**Files:**
- Create: `hive-backend/push.php`
- Modify: `hive-backend/config.php`, `hive-backend/.env.example`, `.gitignore`
- Test: `scratchpad/test_push.php` (extend)

**Interfaces:**
- Consumes: `env_get()` from `config.php`.
- Produces:
  - `FCM_PROJECT_ID` constant (string, `''` when unset).
  - `fcm_service_account(): ?array` — decoded `private/fcm-service-account.json`, or `null`.
  - `fcm_enabled(): bool` — `FCM_PROJECT_ID !== '' && fcm_service_account() !== null`.
  - `fcm_b64url(string $bin): string` — base64url, no padding.
  - `fcm_now(): int` — `time()`, overridable via `$GLOBALS['fcm_clock']` (a `callable(): int`).
  - `fcm_http_post(string $url, array $headers, string $body): array` — returns `[int $status, string $responseBody]`; throws `RuntimeException` on transport failure; overridable via `$GLOBALS['fcm_http_post']` (a `callable(string,array,string): array`).

- [ ] **Step 1: Add the failing test**

Append to `scratchpad/test_push.php` before the summary line:

```php
// --- Task 2: config + helpers de push.php ---
require __DIR__ . '/../hive-backend/push.php';

check('fcm_b64url strips padding and is url-safe', (function () {
    $out = fcm_b64url("\xff\xef\xfe");
    return strpos($out, '=') === false
        && strpos($out, '+') === false
        && strpos($out, '/') === false;
})());

check('fcm_now honours $GLOBALS[fcm_clock]', (function () {
    $GLOBALS['fcm_clock'] = fn () => 1234567890;
    $v = fcm_now();
    unset($GLOBALS['fcm_clock']);
    return $v === 1234567890;
})());

check('fcm_enabled is false without project id + service account', fcm_enabled() === false);

check('fcm_http_post is overridable', (function () {
    $GLOBALS['fcm_http_post'] = fn ($u, $h, $b) => [201, 'stubbed'];
    [$s, $body] = fcm_http_post('https://example.test', [], '');
    unset($GLOBALS['fcm_http_post']);
    return $s === 201 && $body === 'stubbed';
})());
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `php scratchpad/test_push.php`
Expected: FAIL — fatal `require ... push.php` (file does not exist).

- [ ] **Step 3: Create `hive-backend/push.php`**

```php
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
```

- [ ] **Step 4: Define `FCM_PROJECT_ID` in `config.php`**

In `hive-backend/config.php`, next to the other `define(...)` env lines (e.g. after `define('PUBLIC_BASE_URL', ...)`):

```php
// ID del proyecto Firebase para el envío de push (FCM HTTP v1). Vacío en
// local o si aún no se configuró: deshabilita el push sin romper nada.
define('FCM_PROJECT_ID', (string) (env_get('FCM_PROJECT_ID') ?: ''));
```

- [ ] **Step 5: Document it in `.env.example`**

Append to `hive-backend/.env.example`:

```
# --- Push (Firebase Cloud Messaging) ---
# ID del proyecto Firebase (Configuración del proyecto -> General -> ID del proyecto).
# Déjalo vacío para deshabilitar el push. La clave de cuenta de servicio va en
# hive-backend/private/fcm-service-account.json (no se versiona).
FCM_PROJECT_ID=
```

- [ ] **Step 6: Ignore secrets + scratchpad in `.gitignore`**

Append to `.gitignore`:

```
# Firebase / FCM (backend)
hive-backend/private/fcm-service-account.json
hive-backend/private/fcm-token.cache

# Throwaway test/debug scripts
/scratchpad/
```

- [ ] **Step 7: Run the tests**

Run: `php scratchpad/test_push.php`
Expected: all four new lines `PASS`, `ALL PASS`, exit 0.

- [ ] **Step 8: Commit**

```bash
git add hive-backend/push.php hive-backend/config.php hive-backend/.env.example .gitignore
git commit -m "feat(push): FCM config + push.php foundation (config, jwt/http seams)"
```

---

## Task 3: OAuth2 access token (`fcm_access_token`)

**Files:**
- Modify: `hive-backend/push.php`
- Test: `scratchpad/test_push.php` (extend)

**Interfaces:**
- Consumes: `fcm_service_account()`, `fcm_now()`, `fcm_http_post()`, `fcm_b64url()`.
- Produces: `fcm_access_token(): string` — a valid bearer token. Reads/writes cache file `hive-backend/private/fcm-token.cache` (JSON `{token, exp}`); refetches when `exp <= now + 60`. Throws `RuntimeException` when the service account is missing or the exchange fails.

- [ ] **Step 1: Add the failing tests**

Append to `scratchpad/test_push.php`:

```php
// --- Task 3: fcm_access_token (JWT + canje + cache) ---
$fixtureCache = __DIR__ . '/../hive-backend/private/fcm-token.cache';
@unlink($fixtureCache);

// Cuenta de servicio de prueba (par de claves RSA generado al vuelo).
$rsa = openssl_pkey_new(['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA]);
openssl_pkey_export($rsa, $rsaPriv);
$rsaPubPem = openssl_pkey_get_details($rsa)['key'];
$saPath = __DIR__ . '/../hive-backend/private/fcm-service-account.json';
$saBackup = is_file($saPath) ? file_get_contents($saPath) : null;
file_put_contents($saPath, json_encode([
    'client_email' => 'svc@doliv.iam.gserviceaccount.com',
    'private_key'  => $rsaPriv,
]));
// Reset del cache estático de fcm_service_account(): se corre en proceso nuevo,
// así que basta con haber escrito el archivo ANTES del primer uso.

$captured = null;
$GLOBALS['fcm_clock'] = fn () => 1_700_000_000;
$GLOBALS['fcm_http_post'] = function ($url, $headers, $body) use (&$captured) {
    parse_str($body, $form);
    $captured = $form['assertion'] ?? null;
    return [200, json_encode(['access_token' => 'ya29.test', 'expires_in' => 3600])];
};

$tok = fcm_access_token();
check('fcm_access_token returns the exchanged token', $tok === 'ya29.test');

check('assertion is a well-formed RS256 JWT with the right claims', (function () use ($captured, $rsaPubPem) {
    if (!$captured || substr_count($captured, '.') !== 2) return false;
    [$h, $c, $s] = explode('.', $captured);
    $dec = fn ($p) => json_decode(base64_decode(strtr($p, '-_', '+/')), true);
    $header = $dec($h);
    $claim = $dec($c);
    $sigOk = openssl_verify("$h.$c", base64_decode(strtr($s, '-_', '+/')), $rsaPubPem, OPENSSL_ALGO_SHA256) === 1;
    return $header['alg'] === 'RS256'
        && $claim['iss'] === 'svc@doliv.iam.gserviceaccount.com'
        && $claim['aud'] === 'https://oauth2.googleapis.com/token'
        && $claim['scope'] === 'https://www.googleapis.com/auth/firebase.messaging'
        && ($claim['exp'] - $claim['iat']) === 3600
        && $claim['iat'] === 1_700_000_000
        && $sigOk;
})());

// Segunda llamada dentro del TTL: NO debe volver a canjear.
$calls = 0;
$GLOBALS['fcm_http_post'] = function ($url, $headers, $body) use (&$calls) {
    $calls++;
    return [200, json_encode(['access_token' => 'ya29.SHOULD_NOT_HAPPEN', 'expires_in' => 3600])];
};
$tok2 = fcm_access_token();
check('cached token is reused within TTL', $tok2 === 'ya29.test' && $calls === 0);

// Limpieza
@unlink($fixtureCache);
if ($saBackup !== null) file_put_contents($saPath, $saBackup); else @unlink($saPath);
unset($GLOBALS['fcm_clock'], $GLOBALS['fcm_http_post']);
```

- [ ] **Step 2: Run to confirm failure**

Run: `php scratchpad/test_push.php`
Expected: FAIL — `Call to undefined function fcm_access_token()`.

- [ ] **Step 3: Implement `fcm_access_token()` in `push.php`**

Append to `hive-backend/push.php`:

```php
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
```

- [ ] **Step 4: Run the tests**

Run: `php scratchpad/test_push.php`
Expected: the three new lines `PASS`, `ALL PASS`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add hive-backend/push.php
git commit -m "feat(push): RS256 JWT + cached FCM OAuth2 access token"
```

---

## Task 4: `push_send_to_user` + `push_title_for_type`

**Files:**
- Modify: `hive-backend/push.php`
- Test: `scratchpad/test_push.php` (extend)

**Interfaces:**
- Consumes: `fcm_enabled()`, `fcm_access_token()`, `fcm_http_post()`, a `PDO` with the `device_tokens` table.
- Produces:
  - `push_title_for_type(string $type): string` — per the Global Constraints title map.
  - `push_send_to_user(PDO $pdo, string $email, string $title, string $body, array $data, ?string $collapseKey = null): void` — sends one data-only message per registered token for `$email`. `data` payload = `['title'=>$title,'body'=>$body] + array_map('strval',$data)`; `android.priority='high'`, `android.collapse_key=$collapseKey` when non-null. Deletes a token row when the response is HTTP 404 or its body contains `UNREGISTERED` or `registration-token-not-registered`. Returns early when `!fcm_enabled()` or the user has no tokens or the token exchange throws. Never throws.

- [ ] **Step 1: Add the failing tests**

Append to `scratchpad/test_push.php`:

```php
// --- Task 4: push_title_for_type + push_send_to_user ---
check('push_title_for_type maps known + unknown types', (function () {
    return push_title_for_type('chat') === 'Nuevo mensaje'
        && push_title_for_type('task_assigned') === 'Tarea'
        && push_title_for_type('event_reminder') === 'Evento'
        && push_title_for_type('leave_rejected') === 'Permiso'
        && push_title_for_type('something_else') === 'Radio Doliv';
})());

// Semillas: habilitar FCM con la cuenta de prueba + token cacheado.
$saPath = __DIR__ . '/../hive-backend/private/fcm-service-account.json';
$saBackup = is_file($saPath) ? file_get_contents($saPath) : null;
$rsa = openssl_pkey_new(['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA]);
openssl_pkey_export($rsa, $rsaPriv);
file_put_contents($saPath, json_encode([
    'client_email' => 'svc@doliv.iam.gserviceaccount.com',
    'private_key'  => $rsaPriv,
]));
$cacheFile = __DIR__ . '/../hive-backend/private/fcm-token.cache';
file_put_contents($cacheFile, json_encode(['token' => 'ya29.test', 'exp' => time() + 3000]));

// NOTE: FCM_PROJECT_ID viene de .env; para la prueba se fuerza vía runkit-less
// truco: definirlo si aún no está (config.php ya lo definió como '' -> este
// bloque solo funciona si .env trae FCM_PROJECT_ID=demo-project). Si está
// vacío, se marca la prueba como SKIP.
if (FCM_PROJECT_ID === '') {
    echo "SKIP push_send_to_user (set FCM_PROJECT_ID=demo-project in hive-backend/.env to run)" . PHP_EOL;
} else {
    $pdo->exec("DELETE FROM device_tokens WHERE email = 'pushtest@doliv.test'");
    $pdo->prepare("INSERT INTO device_tokens (email, token, platform) VALUES (?,?,?)")
        ->execute(['pushtest@doliv.test', 'GOOD_TOKEN', 'android']);
    $pdo->prepare("INSERT INTO device_tokens (email, token, platform) VALUES (?,?,?)")
        ->execute(['pushtest@doliv.test', 'DEAD_TOKEN', 'android']);

    $seen = [];
    $GLOBALS['fcm_http_post'] = function ($url, $headers, $body) use (&$seen) {
        $msg = json_decode($body, true)['message'];
        $seen[] = $msg;
        if ($msg['token'] === 'DEAD_TOKEN') {
            return [404, json_encode(['error' => ['status' => 'UNREGISTERED']])];
        }
        return [200, json_encode(['name' => 'projects/x/messages/1'])];
    };

    push_send_to_user($pdo, 'pushtest@doliv.test', 'Hola', 'Cuerpo',
        ['type' => 'chat', 'entityType' => 'user', 'entityId' => 'ana@doliv.test'],
        'chat:ana@doliv.test');

    check('push_send_to_user posts once per token', count($seen) === 2);
    check('payload is data-only with title/body/type merged', (function () use ($seen) {
        $m = $seen[0];
        return !isset($m['notification'])
            && $m['data']['title'] === 'Hola'
            && $m['data']['body'] === 'Cuerpo'
            && $m['data']['type'] === 'chat'
            && $m['android']['priority'] === 'high'
            && $m['android']['collapse_key'] === 'chat:ana@doliv.test';
    })());
    $left = $pdo->prepare("SELECT token FROM device_tokens WHERE email = 'pushtest@doliv.test'");
    $left->execute();
    $tokens = $left->fetchAll(PDO::FETCH_COLUMN);
    check('dead token pruned, good token kept', $tokens === ['GOOD_TOKEN']);

    // No lanza ante error de transporte.
    $GLOBALS['fcm_http_post'] = function () { throw new RuntimeException('network down'); };
    $threw = false;
    try {
        push_send_to_user($pdo, 'pushtest@doliv.test', 't', 'b', ['type' => 'dept_task']);
    } catch (Throwable $e) {
        $threw = true;
    }
    check('push_send_to_user never throws on transport failure', $threw === false);

    $pdo->exec("DELETE FROM device_tokens WHERE email = 'pushtest@doliv.test'");
    unset($GLOBALS['fcm_http_post']);
}

@unlink($cacheFile);
if ($saBackup !== null) file_put_contents($saPath, $saBackup); else @unlink($saPath);
```

- [ ] **Step 2: Run to confirm failure**

Run: `php scratchpad/test_push.php`
Expected: FAIL — `Call to undefined function push_title_for_type()`.

- [ ] **Step 3: Implement both functions in `push.php`**

Append to `hive-backend/push.php`:

```php
function push_title_for_type(string $type): string {
    switch ($type) {
        case 'chat':
            return 'Nuevo mensaje';
        case 'dept_task':
        case 'task_assigned':
            return 'Tarea';
        case 'event_created':
        case 'event_reminder':
            return 'Evento';
        case 'internal_announcement':
        case 'internal_announcement_reminder':
            return 'Anuncio';
        case 'attendance_correction':
            return 'Asistencia';
        case 'absence_justification':
        case 'absence_approved':
        case 'absence_rejected':
            return 'Ausencia';
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

        try {
            [$status, $respBody] = fcm_http_post($url, $headers, json_encode($message));
        } catch (Throwable $e) {
            error_log('push: send failed: ' . $e->getMessage());
            continue;
        }

        if ($status === 404
            || strpos($respBody, 'UNREGISTERED') !== false
            || strpos($respBody, 'registration-token-not-registered') !== false) {
            $pdo->prepare('DELETE FROM device_tokens WHERE token = ?')->execute([$token]);
        }
    }
}
```

- [ ] **Step 4: Run the tests**

Run: `php scratchpad/test_push.php`
Expected: `push_title_for_type` line PASSes. The `push_send_to_user` block either PASSes (if `.env` has `FCM_PROJECT_ID=demo-project`) or prints `SKIP`. To exercise it now, temporarily set `FCM_PROJECT_ID=demo-project` in `hive-backend/.env`, re-run, expect all `PASS`, then restore `.env`.

- [ ] **Step 5: Commit**

```bash
git add hive-backend/push.php
git commit -m "feat(push): push_send_to_user + title map, data-only messages, dead-token pruning"
```

---

## Task 5: Fire a push from `notify_user()`

**Files:**
- Modify: `hive-backend/helpers.php` (`require_once` near top; `notify_user()` body around line 461-475)
- Test: `scratchpad/test_push.php` (extend)

**Interfaces:**
- Consumes: `push_send_to_user()`, `push_title_for_type()`.
- Produces: no signature change to `notify_user()`. After the INSERT it captures `$pdo->lastInsertId()` and calls `push_send_to_user()` inside `try/catch (Throwable)`. `collapseKey` = `'chat:' . $entityId` when `$type === 'chat'` and `$entityId` is non-empty, else `'notif:' . $notifId`. Push `data` = `['type'=>$type,'entityType'=>(string)$entityType,'entityId'=>(string)$entityId]`.

- [ ] **Step 1: Add the failing test**

Append to `scratchpad/test_push.php`:

```php
// --- Task 5: notify_user dispara push sin romperse si el envío falla ---
$pdo->exec("DELETE FROM notifications WHERE email = 'notifytest@doliv.test'");
$saPath = __DIR__ . '/../hive-backend/private/fcm-service-account.json';
$saBackup = is_file($saPath) ? file_get_contents($saPath) : null;
$rsa = openssl_pkey_new(['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA]);
openssl_pkey_export($rsa, $rsaPriv);
file_put_contents($saPath, json_encode(['client_email' => 'svc@x.iam.gserviceaccount.com', 'private_key' => $rsaPriv]));
file_put_contents(__DIR__ . '/../hive-backend/private/fcm-token.cache', json_encode(['token' => 't', 'exp' => time() + 3000]));

if (FCM_PROJECT_ID !== '') {
    $pdo->prepare("INSERT INTO device_tokens (email, token, platform) VALUES (?,?,?)")
        ->execute(['notifytest@doliv.test', 'T1', 'android']);
    $GLOBALS['fcm_http_post'] = function () { throw new RuntimeException('boom'); };

    $threw = false;
    try {
        notify_user($pdo, 'notifytest@doliv.test', null, 'chat', 'Ana te escribió', 'user', 'ana@doliv.test');
    } catch (Throwable $e) {
        $threw = true;
    }
    check('notify_user does not throw when push fails', $threw === false);

    $row = $pdo->prepare("SELECT message FROM notifications WHERE email = 'notifytest@doliv.test'");
    $row->execute();
    check('notify_user still wrote the in-app row', $row->fetchColumn() === 'Ana te escribió');

    $pdo->exec("DELETE FROM device_tokens WHERE email = 'notifytest@doliv.test'");
    $pdo->exec("DELETE FROM notifications WHERE email = 'notifytest@doliv.test'");
    unset($GLOBALS['fcm_http_post']);
} else {
    echo "SKIP notify_user push (needs FCM_PROJECT_ID in .env)" . PHP_EOL;
}
@unlink(__DIR__ . '/../hive-backend/private/fcm-token.cache');
if ($saBackup !== null) file_put_contents($saPath, $saBackup); else @unlink($saPath);
```

- [ ] **Step 2: Run to confirm current behaviour**

Run: `php scratchpad/test_push.php` (with `FCM_PROJECT_ID=demo-project` temporarily in `.env`)
Expected: FAIL — `notify_user` throws (push not yet wired / `push_send_to_user` undefined inside helpers.php scope) OR the in-app row assertion is the only thing checked. Confirm at least one new line FAILs.

- [ ] **Step 3: Add the `require_once` to `helpers.php`**

Near the top of `hive-backend/helpers.php`, with the other includes (or immediately before `function notify_user(`):

```php
require_once __DIR__ . '/push.php';
```

- [ ] **Step 4: Wire the push into `notify_user()`**

In `hive-backend/helpers.php`, replace the body of `notify_user()` (currently just the prepare/execute) with:

```php
    $stmt = $pdo->prepare(
        'INSERT INTO notifications (team_id, email, type, message, entity_type, entity_id)
         VALUES (?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([$teamId, $email, $type, $message, $entityType, $entityId]);
    $notifId = $pdo->lastInsertId();

    // Push best-effort: nunca debe afectar la respuesta ni el flujo que llamó.
    try {
        $collapse = ($type === 'chat' && $entityId)
            ? 'chat:' . $entityId
            : 'notif:' . $notifId;
        push_send_to_user(
            $pdo,
            $email,
            push_title_for_type($type),
            $message,
            [
                'type'       => $type,
                'entityType' => (string) $entityType,
                'entityId'   => (string) $entityId,
            ],
            $collapse
        );
    } catch (Throwable $e) {
        error_log('notify_user push failed: ' . $e->getMessage());
    }
```

- [ ] **Step 5: Run the tests**

Run: `php scratchpad/test_push.php` (with the temporary `.env` value)
Expected: both new lines `PASS`; `ALL PASS`. Then restore `hive-backend/.env` (remove/blank `FCM_PROJECT_ID`) and re-run — expect `SKIP` lines where noted and `ALL PASS`.

- [ ] **Step 6: PHP lint the touched files**

Run: `php -l hive-backend/helpers.php && php -l hive-backend/push.php && php -l hive-backend/config.php`
Expected: `No syntax errors detected` for each.

- [ ] **Step 7: Commit**

```bash
git add hive-backend/helpers.php
git commit -m "feat(push): send an FCM push from notify_user (best-effort, chat collapse key)"
```

---

## Task 6: `/devices/register` + `/devices/unregister` endpoints

**Files:**
- Modify: `hive-backend/index.php` (add two tuples to `$routes`; add two handler functions near `sendChatMessage`)
- Test: `scratchpad/test_push.php` (extend)

**Interfaces:**
- Consumes: `require_auth(PDO): array`, `request_body(): array`, `json_response()`, `error_response()`.
- Produces:
  - `POST /devices/register` → `deviceRegister(PDO $pdo)` — body `{token: string, platform?: 'android'|'ios'|'web'}`. Upsert on `token` (`ON DUPLICATE KEY UPDATE email, platform, last_seen_at`). `400` if `token` empty. `{ "ok": true }`.
  - `POST /devices/unregister` → `deviceUnregister(PDO $pdo)` — body `{token: string}`. `DELETE FROM device_tokens WHERE token = ?`. `400` if `token` empty. Idempotent. `{ "ok": true }`.

- [ ] **Step 1: Add the failing test**

Append to `scratchpad/test_push.php`:

```php
// --- Task 6: endpoints de registro de dispositivo (prueba directa del handler) ---
require_once __DIR__ . '/../hive-backend/index.php'; // define los handlers; el router no corre en CLI

// Nota: si index.php ejecuta el router al incluirse, extraer los handlers a un
// archivo aparte NO es necesario — el foreach del router está bajo
// `if (php_sapi_name() !== 'cli')`? Verificar; si corre, este test llama a las
// funciones vía un sub-proceso curl contra http://localhost/hive-backend.
```

Because `hive-backend/index.php` dispatches on include, test these over HTTP instead. Replace the block above with:

```php
// --- Task 6: endpoints de registro de dispositivo (vía HTTP local) ---
$base = 'http://localhost/hive-backend';
// Token de un usuario real de prueba. Usa uno de los 8 autorizados; aquí se
// asume que existe una fila con token conocido. Si no, crea una temporal:
$authRow = $pdo->query("SELECT email, token FROM users WHERE token IS NOT NULL AND token <> '' LIMIT 1")->fetch(PDO::FETCH_ASSOC);
if (!$authRow) {
    echo "SKIP devices endpoints (no user with a token in DB)" . PHP_EOL;
} else {
    $tok = $authRow['token'];
    $post = function (string $path, array $body, ?string $auth) use ($base) {
        $ch = curl_init($base . $path);
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => json_encode($body),
            CURLOPT_HTTPHEADER => array_filter([
                'Content-Type: application/json',
                $auth ? "Authorization: $auth" : null,
            ]),
            CURLOPT_RETURNTRANSFER => true,
        ]);
        $r = curl_exec($ch);
        $s = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        return [$s, $r];
    };

    $pdo->exec("DELETE FROM device_tokens WHERE token = 'HTTP_TEST_TOKEN'");

    [$s1] = $post('/devices/register', ['token' => 'HTTP_TEST_TOKEN', 'platform' => 'android'], $tok);
    check('POST /devices/register returns 200', $s1 === 200);

    $cnt = $pdo->query("SELECT COUNT(*) FROM device_tokens WHERE token = 'HTTP_TEST_TOKEN' AND email = " . $pdo->quote($authRow['email']))->fetchColumn();
    check('register inserted the row for the authed user', (int) $cnt === 1);

    [$s2] = $post('/devices/register', ['token' => 'HTTP_TEST_TOKEN', 'platform' => 'android'], $tok);
    $cnt2 = $pdo->query("SELECT COUNT(*) FROM device_tokens WHERE token = 'HTTP_TEST_TOKEN'")->fetchColumn();
    check('register is idempotent (still one row)', $s2 === 200 && (int) $cnt2 === 1);

    [$s3] = $post('/devices/register', ['platform' => 'android'], $tok);
    check('register without token is 400', $s3 === 400);

    [$s4] = $post('/devices/register', ['token' => 'X'], null);
    check('register without auth is 401', $s4 === 401);

    [$s5] = $post('/devices/unregister', ['token' => 'HTTP_TEST_TOKEN'], $tok);
    $cnt3 = $pdo->query("SELECT COUNT(*) FROM device_tokens WHERE token = 'HTTP_TEST_TOKEN'")->fetchColumn();
    check('unregister deletes the row', $s5 === 200 && (int) $cnt3 === 0);

    [$s6] = $post('/devices/unregister', ['token' => 'HTTP_TEST_TOKEN'], $tok);
    check('unregister is idempotent', $s6 === 200);
}
```

Prerequisite: Apache (XAMPP) is serving `http://localhost/hive-backend`. If it is not running, start it before this task.

- [ ] **Step 2: Run to confirm failure**

Run: `php scratchpad/test_push.php`
Expected: `POST /devices/register returns 200` FAILs (route not found → likely `404`/`text_response`).

- [ ] **Step 3: Add the routes**

In `hive-backend/index.php`, in the `$routes` array near the `/notifications` lines (order does not matter — no wildcard collision):

```php
    ['POST', '#^/devices/register/?$#',                       'deviceRegister'],
    ['POST', '#^/devices/unregister/?$#',                     'deviceUnregister'],
```

- [ ] **Step 4: Add the handlers**

In `hive-backend/index.php`, after `function sendChatMessage(...) { ... }`:

```php
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
    require_auth($pdo);
    $body = request_body();
    $token = trim((string) ($body['token'] ?? ''));
    if ($token === '') {
        error_response('token is required', 400);
    }
    $pdo->prepare('DELETE FROM device_tokens WHERE token = ?')->execute([$token]);
    json_response(['ok' => true]);
}
```

- [ ] **Step 5: Run the tests**

Run: `php scratchpad/test_push.php`
Expected: all Task 6 lines `PASS`, `ALL PASS`, exit 0.

- [ ] **Step 6: PHP lint**

Run: `php -l hive-backend/index.php`
Expected: `No syntax errors detected`.

- [ ] **Step 7: Commit**

```bash
git add hive-backend/index.php
git commit -m "feat(push): POST /devices/register + /devices/unregister endpoints"
```

---

## Task 7: Flutter dependencies + Android platform config

**Files:**
- Modify: `pubspec.yaml`, `android/settings.gradle.kts`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`
- Create: `android/app/google-services.json`, `lib/firebase_options.dart`

**Interfaces:**
- Produces: `DefaultFirebaseOptions.currentPlatform` (a `FirebaseOptions` for Android). App compiles with `firebase_core`, `firebase_messaging`, `flutter_local_notifications` on the classpath.

**Manual prerequisite (do this first, it produces the two generated files):**

1. In the Firebase console (personal Google account for now), create a project (or reuse one). **Project settings → General → Project ID** is the value for `FCM_PROJECT_ID`.
2. **Add app → Android**, package name **`com.example.brl_task4`**. Download `google-services.json`.
3. **Project settings → Service accounts → Generate new private key.** Save the JSON as `hive-backend/private/fcm-service-account.json` and set `FCM_PROJECT_ID=<project id>` in `hive-backend/.env` (both git-ignored).

- [ ] **Step 1: Add the dependencies**

Run:
```bash
flutter pub add firebase_core firebase_messaging flutter_local_notifications
```
Then record the resolved versions in `pubspec.yaml` (pub writes caret ranges automatically). Expected: `flutter pub get` completes without version-solve errors on Flutter 3.41 / Dart 3.9.

- [ ] **Step 2: Drop in `google-services.json`**

Place the downloaded file at `android/app/google-services.json`. Confirm its `client[].client_info.android_client_info.package_name` is `com.example.brl_task4`.

- [ ] **Step 3: Declare the Google Services Gradle plugin**

In `android/settings.gradle.kts`, inside the top-level `plugins { }` block, add alongside the existing `apply false` lines:

```kotlin
    id("com.google.gms.google-services") version "4.4.2" apply false
```

- [ ] **Step 4: Apply the plugin + enable desugaring in the app module**

In `android/app/build.gradle.kts`:

In the `plugins { }` block (after `id("dev.flutter.flutter-gradle-plugin")`):
```kotlin
    id("com.google.gms.google-services")
```

In the `android { }` block, add (or merge into an existing `compileOptions`):
```kotlin
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
```

Add a top-level `dependencies { }` block in `android/app/build.gradle.kts` (Kotlin DSL, module-level) if none exists:
```kotlin
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

If the build later reports a minSdkVersion below 21, set `minSdk = 23` explicitly in `defaultConfig`.

- [ ] **Step 5: Add the notifications permission**

In `android/app/src/main/AndroidManifest.xml`, as a direct child of `<manifest>` (before `<application>`):

```xml
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

- [ ] **Step 6: Create `lib/firebase_options.dart` (Android only)**

Fill the values from `google-services.json` using this mapping:
- `apiKey` = `client[0].api_key[0].current_key`
- `appId` = `client[0].client_info.mobilesdk_app_id`
- `messagingSenderId` = `project_info.project_number`
- `projectId` = `project_info.project_id`
- `storageBucket` = `project_info.storage_bucket`

```dart
// Generado a mano a partir de android/app/google-services.json.
// SOLO Android: iOS/web/Windows quedan fuera de alcance (ver spec 2026-09-06).
// Al pasar a la cuenta Firebase del cliente, regenerar SOLO estos valores.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Push no está configurado para web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Push solo está configurado para Android (plataforma actual: '
          '$defaultTargetPlatform).',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PASTE_current_key',
    appId: 'PASTE_mobilesdk_app_id',
    messagingSenderId: 'PASTE_project_number',
    projectId: 'PASTE_project_id',
    storageBucket: 'PASTE_storage_bucket',
  );
}
```

Replace every `PASTE_*` with the real value from `google-services.json`. (Alternative: run `flutterfire configure --platforms=android` if the FlutterFire CLI is installed — it writes this file for you.)

- [ ] **Step 7: Verify the build**

Run:
```bash
flutter pub get
flutter analyze
flutter build apk --debug
```
Expected: `flutter analyze` shows no new errors (pre-existing baseline infos/warnings only); the APK builds. If Gradle complains about the Google Services plugin not finding `google-services.json`, re-check Step 2's path.

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock android/ lib/firebase_options.dart
git commit -m "chore(push): add Firebase/FCM deps + Android platform config"
```

---

## Task 8: Pure push-message helpers

**Files:**
- Create: `lib/core/push/push_messages.dart`
- Test: `test/push_messages_test.dart`

**Interfaces:**
- Produces:
  - `Map<String, String> normalizePushData(Map<Object?, Object?> raw)` — string-coerces keys and values; `null` value → `''`.
  - `bool shouldShowLocalNotification(Map<String, String> data, String? activeChatPeerEmail)` — `false` only when `data['type'] == 'chat'` and `data['entityId']` is non-empty and equals `activeChatPeerEmail`.
  - `int localNotificationId(Map<String, String> data)` — deterministic non-negative 31-bit hash of `'${data['type'] ?? ''}:${data['entityId'] ?? ''}'`.

- [ ] **Step 1: Write the failing test**

`test/push_messages_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:doliv_social/core/push/push_messages.dart';

void main() {
  group('normalizePushData', () {
    test('coerces keys and values to strings, null -> empty', () {
      final out = normalizePushData(<Object?, Object?>{
        'type': 'chat',
        'entityId': 'a@b.com',
        'count': 3,
        'missing': null,
      });
      expect(out, {
        'type': 'chat',
        'entityId': 'a@b.com',
        'count': '3',
        'missing': '',
      });
    });
  });

  group('shouldShowLocalNotification', () {
    test('suppresses a chat push for the open thread', () {
      expect(
        shouldShowLocalNotification(
          {'type': 'chat', 'entityId': 'ana@doliv.test'},
          'ana@doliv.test',
        ),
        isFalse,
      );
    });

    test('shows a chat push for a different thread', () {
      expect(
        shouldShowLocalNotification(
          {'type': 'chat', 'entityId': 'ana@doliv.test'},
          'beto@doliv.test',
        ),
        isTrue,
      );
    });

    test('shows a chat push when no thread is open', () {
      expect(
        shouldShowLocalNotification(
          {'type': 'chat', 'entityId': 'ana@doliv.test'},
          null,
        ),
        isTrue,
      );
    });

    test('always shows a non-chat push', () {
      expect(
        shouldShowLocalNotification(
          {'type': 'dept_task', 'entityId': 'ana@doliv.test'},
          'ana@doliv.test',
        ),
        isTrue,
      );
    });
  });

  group('localNotificationId', () {
    test('is stable for the same type + entity', () {
      final a = localNotificationId({'type': 'chat', 'entityId': 'ana@doliv.test'});
      final b = localNotificationId({'type': 'chat', 'entityId': 'ana@doliv.test'});
      expect(a, b);
    });

    test('differs by entity', () {
      final a = localNotificationId({'type': 'chat', 'entityId': 'ana@doliv.test'});
      final b = localNotificationId({'type': 'chat', 'entityId': 'beto@doliv.test'});
      expect(a, isNot(b));
    });

    test('is a non-negative 31-bit int', () {
      final id = localNotificationId({'type': 'x', 'entityId': 'y'});
      expect(id, greaterThanOrEqualTo(0));
      expect(id, lessThanOrEqualTo(0x7fffffff));
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/push_messages_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:doliv_social/core/push/push_messages.dart'`.

- [ ] **Step 3: Implement `lib/core/push/push_messages.dart`**

```dart
/// Utilidades puras para decidir qué hacer con un mensaje push recibido.
/// Sin dependencias de Firebase: se prueban con `flutter test`.
library;

/// Normaliza el `data` de un mensaje (claves/valores arbitrarios) a
/// `String -> String`. Un valor `null` se vuelve `''`.
Map<String, String> normalizePushData(Map<Object?, Object?> raw) {
  final out = <String, String>{};
  raw.forEach((key, value) {
    if (key != null) {
      out[key.toString()] = value?.toString() ?? '';
    }
  });
  return out;
}

/// `false` solo cuando el mensaje es de un chat cuyo hilo el usuario tiene
/// abierto ahora mismo (se refresca el badge, sin toast). `true` en el resto.
bool shouldShowLocalNotification(
  Map<String, String> data,
  String? activeChatPeerEmail,
) {
  if (data['type'] == 'chat') {
    final peer = data['entityId'];
    if (peer != null && peer.isNotEmpty && peer == activeChatPeerEmail) {
      return false;
    }
  }
  return true;
}

/// Id estable y no negativo (31 bits) para la notificación local, derivado de
/// `tipo:entidad`, de modo que mensajes repetidos del mismo remitente/entidad
/// se reemplacen en la bandeja en vez de apilarse. FNV-1a de 32 bits.
int localNotificationId(Map<String, String> data) {
  final seed = '${data['type'] ?? ''}:${data['entityId'] ?? ''}';
  var hash = 0x811c9dc5;
  for (final unit in seed.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/push_messages_test.dart`
Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/push/push_messages.dart test/push_messages_test.dart
git commit -m "feat(push): pure helpers for message normalization, toast gating, collapse id"
```

---

## Task 9: `PushService` + `main.dart` wiring

**Files:**
- Create: `lib/core/push/push_service.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `normalizePushData`, `shouldShowLocalNotification`, `localNotificationId` (Task 8); `NotificationsController.instance` (`lib/core/notifications_controller.dart`); `NotificationRouter.open(BuildContext, Map)` (`lib/shared/notifications/notification_router.dart`); `secureStorage` + `key` (`lib/core/session_keys.dart`); `kBaseUrl` (`lib/core/api_config.dart`); `DefaultFirebaseOptions` (Task 7).
- Produces:
  - `final GlobalKey<NavigatorState> appNavigatorKey` — set as `MaterialApp.navigatorKey`.
  - `Future<void> ensureFirebaseInitialized()` — idempotent `Firebase.initializeApp`.
  - top-level `@pragma('vm:entry-point') Future<void> firebaseMessagingBackgroundHandler(RemoteMessage)`.
  - `PushService.instance` with `Future<void> init()`, `void setActiveChatPeer(String?)`, `Future<void> disable()`.

- [ ] **Step 1: Implement `lib/core/push/push_service.dart`**

```dart
import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'package:doliv_social/core/api_config.dart';
import 'package:doliv_social/core/notifications_controller.dart';
import 'package:doliv_social/core/push/push_messages.dart';
import 'package:doliv_social/core/session_keys.dart' show secureStorage, key;
import 'package:doliv_social/firebase_options.dart';
import 'package:doliv_social/shared/notifications/notification_router.dart';

/// Navigator global: enruta un push tocado cuando no hay BuildContext a mano
/// (app abierta desde frío).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'doliv_default',
  'Notificaciones',
  description: 'Mensajes, tareas y avisos de Radio Doliv',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

/// `Firebase.initializeApp` es un error si se llama dos veces con la app por
/// defecto; este guard lo hace idempotente (main + background handler + init).
Future<void> ensureFirebaseInitialized() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

/// Handler de segundo plano / app cerrada. DEBE ser top-level y estar anotado.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await ensureFirebaseInitialized();
  await PushService.instance.handleRemoteMessage(message);
}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _wired = false;
  String? _activeChatPeerEmail;
  String? _lastToken;

  /// Lo fija/limpia la pantalla de un hilo de chat (Task 10).
  void setActiveChatPeer(String? email) => _activeChatPeerEmail = email;

  /// Se llama UNA vez tras iniciar sesión (ya hay token de sesión guardado).
  Future<void> init() async {
    try {
      await ensureFirebaseInitialized();
      await _wireOnce();

      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return; // la app funciona sin push; no se vuelve a preguntar
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);

      FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);
    } catch (e) {
      debugPrint('PushService.init failed: $e');
    }
  }

  Future<void> _wireOnce() async {
    if (_wired) return;
    _wired = true;

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        _routeTo(normalizePushData(
          json.decode(payload) as Map<Object?, Object?>,
        ));
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    FirebaseMessaging.onMessage.listen(handleRemoteMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => _routeTo(normalizePushData(_asObjectMap(m.data))),
    );

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _routeTo(normalizePushData(_asObjectMap(initial.data)));
    }
  }

  /// Refresca el badge y, salvo que el hilo esté abierto, dibuja la
  /// notificación local. Público porque también lo llama el background handler.
  Future<void> handleRemoteMessage(RemoteMessage message) async {
    final data = normalizePushData(_asObjectMap(message.data));

    unawaited(NotificationsController.instance.refresh(force: true));

    if (!shouldShowLocalNotification(data, _activeChatPeerEmail)) return;

    final title = (data['title'] ?? '').isNotEmpty ? data['title']! : 'Radio Doliv';
    final tag = data['type'] == 'chat' ? 'chat:${data['entityId'] ?? ''}' : null;

    await _localNotifications.show(
      localNotificationId(data),
      title,
      data['body'] ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          tag: tag,
        ),
      ),
      payload: json.encode(data),
    );
  }

  void _routeTo(Map<String, String> data) {
    final context = appNavigatorKey.currentContext;
    if (context == null) return;
    // NotificationRouter lee 'type' / 'entityType' / 'entityId'.
    NotificationRouter.open(context, data);
  }

  Future<void> _registerToken(String token) async {
    _lastToken = token;
    final auth = await _sessionToken();
    if (auth == null) return;
    try {
      await http.post(
        Uri.parse('$kBaseUrl/devices/register'),
        headers: {'Authorization': auth},
        body: {'token': token, 'platform': 'android'},
      );
    } catch (_) {
      // se reintenta en el próximo arranque de la app
    }
  }

  /// Se llama al cerrar sesión, ANTES de borrar el token de sesión.
  Future<void> disable() async {
    final auth = await _sessionToken();
    final token = _lastToken ?? await _safeCurrentToken();
    if (token != null && auth != null) {
      try {
        await http.post(
          Uri.parse('$kBaseUrl/devices/unregister'),
          headers: {'Authorization': auth},
          body: {'token': token},
        );
      } catch (_) {}
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _lastToken = null;
  }

  Future<String?> _sessionToken() async {
    final stored = await secureStorage.readSecureData(key);
    if (stored == null) return null;
    final s = stored as String;
    return s.isEmpty ? null : s;
  }

  Future<String?> _safeCurrentToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  Map<Object?, Object?> _asObjectMap(Map<String, dynamic> m) =>
      m.map((k, v) => MapEntry<Object?, Object?>(k, v));
}
```

- [ ] **Step 2: Wire `main.dart`**

In `lib/main.dart`:

Add imports:
```dart
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:doliv_social/core/push/push_service.dart';
```

In `main()` (which is already `async` and calls `WidgetsFlutterBinding.ensureInitialized()`), after the binding line and before `runApp(...)`:
```dart
  await ensureFirebaseInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
```

Where `hasSession` is computed (the token check that decides the initial route), after it is known and before/after `runApp`:
```dart
  if (hasSession) {
    unawaited(PushService.instance.init());
  }
```

In the `MaterialApp(...)` constructor, add:
```dart
      navigatorKey: appNavigatorKey,
```

- [ ] **Step 3: Verify build + analyze + full test suite**

Run:
```bash
flutter analyze
flutter test
flutter build apk --debug
```
Expected: no new analyzer errors; `test/push_messages_test.dart` and the pre-existing suite pass; APK builds.

- [ ] **Step 4: Commit**

```bash
git add lib/core/push/push_service.dart lib/main.dart
git commit -m "feat(push): PushService (FCM wiring, local notifications, tap routing) + main.dart init"
```

---

## Task 10: Login / logout / chat hook points

**Files:**
- Modify: `lib/shared/auth/login.dart`, `lib/shared/home/profile.dart`, `lib/shared/chat/chat.dart`

**Interfaces:**
- Consumes: `PushService.instance.init()`, `PushService.instance.disable()`, `PushService.instance.setActiveChatPeer(String?)` (Task 9).
- Produces: no new symbols. Behaviour: push registers right after login; unregisters during logout before the session token is cleared; the active chat peer is tracked while a `ChatScreen` thread is on screen.

- [ ] **Step 1: Register on login**

In `lib/shared/auth/login.dart`, near line 88 where `unawaited(Session.fetchCurrentUser(accessToken));` runs (token already stored at this point):

Add import:
```dart
import 'package:doliv_social/core/push/push_service.dart';
```
Add after the `fetchCurrentUser` line:
```dart
      unawaited(PushService.instance.init());
```
(`unawaited` is already imported here — it is used on the line above; if not, add `import 'dart:async';`.)

- [ ] **Step 2: Unregister on logout**

In `lib/shared/home/profile.dart`, in `_confirmLogout()`, the current sequence is:
```dart
    await RadioPlayer.instance.stop();
    NotificationsController.instance.clear();
    await secureStorage.deleteSecureData(key);
```
Insert the push unregister **before** the token is deleted:
```dart
    await RadioPlayer.instance.stop();
    NotificationsController.instance.clear();
    await PushService.instance.disable();
    await secureStorage.deleteSecureData(key);
```
Add import:
```dart
import 'package:doliv_social/core/push/push_service.dart';
```

- [ ] **Step 3: Track the open chat thread**

In `lib/shared/chat/chat.dart`, in the `State` of `ChatScreen` (the thread view, `ChatScreen({required this.peerEmail, this.peerName})`):

Add import:
```dart
import 'package:doliv_social/core/push/push_service.dart';
```
In `initState()`:
```dart
    PushService.instance.setActiveChatPeer(widget.peerEmail);
```
In `dispose()` (before `super.dispose()`):
```dart
    PushService.instance.setActiveChatPeer(null);
```

- [ ] **Step 4: Verify**

Run:
```bash
flutter analyze
flutter test
```
Expected: no new errors; suite passes.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/auth/login.dart lib/shared/home/profile.dart lib/shared/chat/chat.dart
git commit -m "feat(push): register on login, unregister on logout, track open chat thread"
```

---

## Task 11: End-to-end verification on a device

**Files:** none (verification + memory note only).

- [ ] **Step 1: Configure the backend for real sending**

Ensure `hive-backend/.env` has `FCM_PROJECT_ID=<real project id>` and `hive-backend/private/fcm-service-account.json` is the real key. Restart Apache if needed.

- [ ] **Step 2: Build + install the debug APK on a physical Android device**

```bash
flutter build apk --debug
```
Install `build/app/outputs/flutter-apk/app-debug.apk`. Launch, log in, and grant the notification permission when prompted.

- [ ] **Step 3: Confirm token registration**

Run:
```bash
"/c/Program Files/MySQL/MySQL Server 9.6/bin/mysql.exe" -uhive_user -p'HivePass_2026!' hive_db -e "SELECT email, LEFT(token,12), platform, last_seen_at FROM device_tokens ORDER BY last_seen_at DESC;"
```
Expected: a row for the logged-in account.

- [ ] **Step 4: Trigger a real notification**

From another account (or via `curl`), send a chat message to the logged-in user:
```bash
curl -s -X POST http://localhost/hive-backend/chat/sendMessage \
  -H "Authorization: <sender token>" -H "Content-Type: application/json" \
  -d '{"to":"<recipient email>","message":"Prueba push"}'
```
Expected on the device:
- App backgrounded/closed → system notification "Nuevo mensaje" / "… te envió un mensaje.", tapping it opens the chat thread with that sender.
- App foregrounded on a different screen → system notification still shows.
- App foregrounded **on that chat thread** → no notification, but the unread badge/refresh still happens.
- Send 2-3 messages quickly → they collapse into one notification (same `chat:<email>` tag/collapse_key).

- [ ] **Step 5: Verify dead-token pruning**

Uninstall the app (or call `POST /devices/unregister` via the logout flow), then trigger another notification for that user and confirm the stale row is gone:
```bash
"/c/Program Files/MySQL/MySQL Server 9.6/bin/mysql.exe" -uhive_user -p'HivePass_2026!' hive_db -e "SELECT COUNT(*) FROM device_tokens WHERE email='<recipient email>';"
```

- [ ] **Step 6: Run the whole test suite once more**

```bash
php scratchpad/test_push.php
flutter test
flutter analyze
```
Expected: `ALL PASS` / suite green / analyze clean (pre-existing baseline only).

- [ ] **Step 7: Update project memory**

Append a dated section to `C:\Users\jerem\.claude\projects\C--xampp-htdocs-radio-doliv\memory\radio-doliv-fix-plan.md` summarising: migration `026 device_tokens` applied; `hive-backend/push.php` (pure-PHP FCM v1, inline in `notify_user`, data-only, dead-token prune); `/devices/register|unregister`; Flutter `lib/core/push/*` + Android-only Firebase config; personal Firebase project in use, swap path documented in the spec §8. Note that `FCM_PROJECT_ID` + `private/fcm-service-account.json` are environment-local and git-ignored.

- [ ] **Step 8: Commit any doc/memory changes tracked in the repo**

```bash
git add -A
git commit -m "docs(push): end-to-end verification notes"
```

---

## Self-Review

**1. Spec coverage:**
- Spec §1 data model → Task 1.
- Spec §2 config (`FCM_PROJECT_ID`, service account, token cache) → Tasks 2, 3, 7.
- Spec §2 `push.php` (`fcm_enabled`, `fcm_access_token`, `push_send_to_user`, `push_title_for_type`) → Tasks 2-4.
- Spec §2 `notify_user()` change + chat collapse key → Task 5.
- Spec §3 `/devices/register` + `/devices/unregister` → Task 6.
- Spec §4 deps + Android config + `firebase_options.dart` → Task 7.
- Spec §4 pure helpers (`shouldShowLocalNotification`, `localIdFor`) → Task 8.
- Spec §4 `PushService` (init, permission, token register/refresh, foreground + background handlers, tap routing, `_activePeerEmail`, `disable`) → Task 9.
- Spec §4 hook points (post-login, logout, `chat.dart`) → Task 10.
- Spec §5 error/edge cases → covered across Tasks 3-5 (try/catch, early return when disabled, lazy prune) and Task 9 (`init` try/catch, permission-denied early return).
- Spec §6 testing (PHP JWT/prune/no-throw; Flutter pure helpers; manual E2E) → Tasks 3-6, 8, 11.
- Spec §8 handover note → Task 7 prerequisite + `firebase_options.dart` comment + Task 11 memory note.
- No gaps.

**2. Placeholder scan:** The only literal `PASTE_*` tokens are in Task 7 Step 6, which explicitly instructs replacing them with values from `google-services.json` — that is a per-environment secret, not a plan placeholder. No `TODO`/`TBD`/"handle edge cases"/"similar to Task N" elsewhere; every code step carries full code.

**3. Type consistency:**
- `push_send_to_user(PDO, string, string, string, array, ?string)` — identical signature in Tasks 4, 5, and the spec.
- `fcm_http_post` returns `[int, string]` everywhere (Tasks 2, 3, 4).
- `normalizePushData(Map<Object?,Object?>)`, `shouldShowLocalNotification(Map<String,String>, String?)`, `localNotificationId(Map<String,String>)` — defined in Task 8, consumed with matching types in Task 9 (`_asObjectMap` bridges `Map<String,dynamic>` → `Map<Object?,Object?>`).
- `appNavigatorKey`, `ensureFirebaseInitialized`, `firebaseMessagingBackgroundHandler`, `PushService.instance.{init,disable,setActiveChatPeer,handleRemoteMessage}` — defined in Task 9, consumed in Tasks 9-10 with matching names.
- `NotificationRouter.open(BuildContext, Map)` — matches the existing signature in `lib/shared/notifications/notification_router.dart`.
- Channel id `doliv_default` consistent between `_channel` and `AndroidNotificationDetails` in Task 9.
- No mismatches found.
