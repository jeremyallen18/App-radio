# Push notifications (Android) — design

Date: 2026-09-06
Status: approved for implementation
Scope: App-radio (Flutter `doliv_social`) + hive-backend (vanilla PHP + MySQL)

## Goal

Deliver every notification the backend already creates as an Android push,
so users are reached when the app is backgrounded or closed. The existing
in-app notification system stays the source of truth; push is an additive
delivery channel.

## Decisions (from brainstorming)

- **Event scope:** every call that today goes through `notify_user()` also
  sends a push. No per-type filtering.
- **Platforms:** Android only in v1. iOS/Windows/web are out of scope
  (iOS needs an APNs key from an Apple Developer account we do not have;
  `firebase_messaging` has no Windows support). Dart code stays
  platform-neutral so iOS can be switched on later.
- **Foreground behaviour:** show a system notification whether the app is
  foreground or background. Achieved by sending **data-only** FCM messages
  and always rendering them client-side with `flutter_local_notifications`
  (avoids the OS drawing a second copy).
- **Backend send:** inline, inside the same request, at the end of
  `notify_user()`, wrapped in try/catch. Low volume; acceptable latency.
- **No user preferences** in v1. Opt-out is via the Android OS permission.
- **Chat:** collapse per conversation (Android `collapse_key` + a stable
  local-notification id per sender) and suppress the local notification
  when the recipient currently has that chat thread open (still refresh
  the badge).
- **FCM auth:** pure-PHP JWT (RS256 via `openssl_sign`) exchanged for an
  OAuth2 access token, cached ~55 min. No Composer (backend vendors
  PHPMailer/fpdf by hand).

## 1. Data model

New migration `hive-backend/migrations/026_device_tokens.sql`:

```sql
CREATE TABLE device_tokens (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email         VARCHAR(255) NOT NULL,
  token         VARCHAR(512) NOT NULL,
  platform      ENUM('android','ios','web') NOT NULL DEFAULT 'android',
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_token (token(191)),
  KEY idx_email (email)
);
```

No FK to `users` (consistent with `notifications`). `schema.sql` updated to
match. Migration applied to the live DB (`hive_db`) as part of the work,
following the project's existing practice.

## 2. Backend — sending

### Config

- `hive-backend/private/fcm-service-account.json` — the Firebase service
  account key. Gitignored. Absence disables push cleanly.
- `FCM_PROJECT_ID` — added to `config.php` (read from env) and
  `.env.example`. Empty => push disabled.
- `hive-backend/private/fcm-token.cache` — cached OAuth2 access token +
  expiry (JSON). Gitignored.

### `hive-backend/push.php` (new)

- `fcm_enabled(): bool` — true when `FCM_PROJECT_ID` and the service
  account file are both present.
- `fcm_access_token(): string` — returns a cached token if
  `expiry - 60s` is still in the future; otherwise builds a JWT
  (`{alg: RS256, typ: JWT}` header; claims `iss`=client_email,
  `scope=https://www.googleapis.com/auth/firebase.messaging`,
  `aud=https://oauth2.googleapis.com/token`, `iat`, `exp=iat+3600`),
  signs the `base64url(header).base64url(claims)` string with
  `openssl_sign(..., OPENSSL_ALGO_SHA256)` using the service account
  `private_key`, POSTs `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=<jwt>`
  to `https://oauth2.googleapis.com/token`, writes the cache file, returns
  the token.
- `push_send_to_user(PDO $pdo, string $email, string $title, string $body, array $data, ?string $collapseKey = null): void`
  - `return` immediately if `!fcm_enabled()`.
  - `SELECT token FROM device_tokens WHERE email = ?`.
  - For each token: POST to
    `https://fcm.googleapis.com/v1/projects/{FCM_PROJECT_ID}/messages:send`
    with body:
    ```json
    {"message": {
      "token": "<token>",
      "data": {"title": "<title>", "body": "<body>",
               "type": "...", "entityType": "...", "entityId": "..."},
      "android": {"priority": "high",
                  "collapse_key": "<collapseKey or omitted>"}
    }}
    ```
    (`title`/`body` travel inside `data` because messages are data-only.)
  - On HTTP `404` or a body containing `UNREGISTERED` /
    `registration-token-not-registered`: `DELETE FROM device_tokens WHERE token = ?`.
  - Any other error: log via the project's existing logging and continue.
  - Never throws.
- `push_title_for_type(string $type): string` — maps notification type to a
  short Spanish title:
  - `chat` => "Nuevo mensaje"
  - `dept_task`, `task_assigned` => "Tarea"
  - `event_created`, `event_reminder` => "Evento"
  - `internal_announcement`, `internal_announcement_reminder` => "Anuncio"
  - `attendance_correction`, attendance alert types => "Asistencia"
  - `absence_justification`, `absence_*` => "Ausencia"
  - `leave_approved`, `leave_rejected`, `leave_cancelled` => "Permiso"
  - `member_removed`, `team_deleted`, `leader_assigned`,
    `department_*`, `department_manager_assigned` => "Equipo"
  - default => "Radio Doliv"

### `helpers.php` — `notify_user()`

`require_once __DIR__ . '/push.php';` near the top of the file.

After the existing `INSERT` (capture `lastInsertId()` as `$notifId`):

```php
try {
    $collapse = $type === 'chat' && $entityId ? 'chat:' . $entityId : 'notif:' . $notifId;
    push_send_to_user(
        $pdo, $email, push_title_for_type($type), $message,
        ['type' => $type,
         'entityType' => (string) $entityType,
         'entityId' => (string) $entityId],
        $collapse
    );
} catch (Throwable $e) {
    // in-app notification already persisted; push is best-effort
    error_log('push_send_to_user failed: ' . $e->getMessage());
}
```

No other call site changes — all ~25 `notify_user()` callers inherit push.

## 3. Backend — device registration

Two routes in `index.php` (existing hand-rolled router), both
`require_auth($pdo)`:

- `POST /devices/register` — body `{ token: string, platform?: 'android' }`.
  Upsert keyed by `token`:
  `INSERT ... ON DUPLICATE KEY UPDATE email = VALUES(email), platform = VALUES(platform), last_seen_at = NOW()`.
  400 if `token` missing/empty. Returns `{ ok: true }`.
- `POST /devices/unregister` — body `{ token: string }`.
  `DELETE FROM device_tokens WHERE token = ?`. Idempotent, returns
  `{ ok: true }`. Called on logout.

Routes registered before any `{id}` wildcard, matching the codebase note
about wildcard ordering.

## 4. Flutter client

### Dependencies & Android config

`pubspec.yaml`: `firebase_core`, `firebase_messaging`,
`flutter_local_notifications` (pinned versions).

Android only:
- `android/app/google-services.json` (personal Firebase project for now;
  documented as swap-on-handover).
- `com.google.gms:google-services` Gradle plugin + classpath.
- `firebase_options.dart` with the Android entry only (generated via
  `flutterfire configure`, other platforms left unconfigured).
- `AndroidManifest.xml`: `POST_NOTIFICATIONS` permission; default
  notification channel metadata (`doliv_default`, importance high).

### `lib/core/push/push_service.dart` (new)

Pure, testable helpers (no Firebase types):

- `bool shouldShowLocalNotification(Map<String,String?> data, String? activePeerEmail)`
  — false when `data['type'] == 'chat' && data['entityId'] == activePeerEmail`;
  true otherwise.
- `int localIdFor(Map<String,String?> data)` — stable non-negative hash of
  `'${data['type']}:${data['entityId']}'` so repeat messages from the same
  sender/entity replace rather than stack.
- `Object? routeTargetFor(Map<String,String?> data)` — delegates to the
  existing `NotificationRouter` using `entityType`/`entityId`/`type`.

`PushService` (singleton) wiring:

- `Future<void> init()` — called once after a session exists
  (post-login bootstrap). `Firebase.initializeApp(options: ...)`,
  request permission (`FirebaseMessaging.instance.requestPermission`;
  Android 13+ prompts `POST_NOTIFICATIONS`). If not authorized, stop
  (no retry, app still works). Get the FCM token, `POST /devices/register`.
  Subscribe to `onTokenRefresh` => re-register.
- Foreground `FirebaseMessaging.onMessage` listener and a top-level
  `@pragma('vm:entry-point')` background handler
  (`FirebaseMessaging.onBackgroundMessage`): both
  1. refresh `NotificationsController` (badge),
  2. if `shouldShowLocalNotification(data, _activePeerEmail)`, render via
     `flutter_local_notifications` on channel `doliv_default` with
     `id = localIdFor(data)`, title `data['title']`, body `data['body']`,
     payload = encoded `data`.
- Tap handling: `onMessageOpenedApp` and `getInitialMessage` (cold start)
  => `routeTargetFor(data)` => navigate with the app's existing navigator
  key, same as an in-app notification tap. Local-notification taps
  (`onDidReceiveNotificationResponse`) decode the payload and route the
  same way.
- `String? _activePeerEmail` — set by `chat.dart` in `initState`, cleared
  in `dispose`, via `PushService.instance.setActiveChatPeer(email)`.
- `Future<void> disable()` — `POST /devices/unregister` with the current
  token, delete the token locally, called from logout.

### Hook points

- Post-login bootstrap (where the session is established, e.g.
  `session.dart` / the shell that loads after auth) calls
  `PushService.instance.init()`.
- Logout path calls `PushService.instance.disable()` before clearing the
  session token (needs the bearer to hit `/devices/unregister`).
- `chat.dart` sets/clears the active peer.

## 5. Errors & edge cases

- Push failure never breaks a request: all send logic is try/catch, in-app
  notification is authoritative.
- Android permission denied: app works without push; no re-prompt.
- Invalid/expired FCM token: lazily pruned on the next send (`404` /
  `UNREGISTERED`).
- No service account / empty `FCM_PROJECT_ID`: `push_send_to_user` returns
  early; local dev runs unchanged with no Firebase.
- OAuth token cache unreadable/corrupt: treated as a cache miss, refetched.
- Same device, multiple accounts: `register` reassigns the row's `email`
  to the current user (unique on `token`), so the previous account stops
  receiving that device's pushes.

## 6. Testing

### PHP (`scratchpad/test_push.php`, style of existing integration tests)

- JWT builder: decode the produced assertion, assert header `alg=RS256`
  and the required claims (`iss`, `scope`, `aud`, `exp-iat == 3600`);
  verify the signature with the public key.
- `push_send_to_user` with an injected fake HTTP sender:
  - `404` / `UNREGISTERED` response => token row deleted.
  - network exception => no throw, other tokens still attempted.
  - `!fcm_enabled()` => no HTTP calls.
- `notify_user`: row is inserted even when the push sender throws.
- Access-token cache: second call within TTL performs no token request.

To make this testable, `push.php` takes its HTTP sender and "now" via
optional injectable hooks (function-pointer globals or a small class),
defaulting to real `curl` / `time()`.

### Flutter (`test/push_service_test.dart`)

- `shouldShowLocalNotification`: chat message for the active peer => false;
  chat for another peer => true; non-chat => true.
- `localIdFor`: stable across calls, non-negative, differs by entity.
- `routeTargetFor`: maps representative payloads to the same targets the
  in-app `NotificationRouter` produces.

Firebase classes are not instantiated in tests — only the pure helpers.

### Manual

- FCM console "test message" to a real device token.
- End-to-end: `curl` `POST /chat/sendMessage` against the live DB with a
  registered Android device; confirm a single collapsed notification and
  correct deep-link on tap.

## 7. Out of scope (YAGNI)

iOS, Windows, web push; per-user or per-category preferences; notification
action buttons; images/rich media; delivery receipts/analytics; any
notification history beyond the existing in-app list; queue + cron
delivery (revisit only if inline latency or delivery loss becomes real).

## 8. Handover to client Firebase account

Only these change when moving off the personal project: replace
`android/app/google-services.json`, regenerate the Android entry in
`firebase_options.dart` (`flutterfire configure` against the client
project, same `applicationId`), and drop in the client's
`fcm-service-account.json` + `FCM_PROJECT_ID`. No code changes; existing
device tokens re-register on next app start.
