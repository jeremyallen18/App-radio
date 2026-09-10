# DB Encryption at Rest — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Encrypt seven sensitive free-text columns at rest with a server-held AES-256-GCM key, so a leaked MySQL dump / stolen backup / raw SQL access yields ciphertext instead of chat messages and HR text.

**Architecture:** One `hive-backend/crypto.php` with `db_encrypt`/`db_decrypt` (AES-256-GCM, `v1:` versioned envelope, key from `.env`). Every write of a covered column wraps its bound parameter in `db_encrypt()`; every read decrypts at the row-mapper. A one-shot idempotent migration encrypts existing rows. No Flutter changes — the client gets plaintext over TLS because the server decrypts.

**Tech Stack:** PHP 8 (vanilla, no Composer) + MySQL. `openssl_encrypt`/`openssl_decrypt`.

**Spec:** `docs/superpowers/specs/2026-09-06-encryption-at-rest-design.md`

## Global Constraints

- **No Composer.** Crypto is `openssl_encrypt($p,'aes-256-gcm',$key,OPENSSL_RAW_DATA,$iv,$tag)` with `$iv = random_bytes(12)` and a 16-byte GCM `$tag`.
- **Envelope format, exact:** `"v1:" . base64_encode($iv . $tag . $ciphertext)`. `$iv` is 12 bytes, `$tag` 16 bytes; on decrypt, slice `substr($raw,0,12)` = iv, `substr($raw,12,16)` = tag, `substr($raw,28)` = ciphertext.
- **`db_encrypt`:** `null` → `null`; `''` → `''`; no key configured → returns `$plain` unchanged; otherwise returns the `v1:` envelope.
- **`db_decrypt`:** `null` → `null`; value without the `v1:` prefix → returned unchanged (plaintext / pre-migration coexistence); decrypt failure (bad key, tampered bytes, GCM tag mismatch, malformed base64) → returns the sentinel `DB_DECRYPT_UNAVAILABLE` (`'[contenido no disponible]'`) and `error_log`s. **Never throws. Never returns raw ciphertext.**
- **Key:** `DB_ENCRYPTION_KEY` read via `env_get()`; must `base64_decode` (strict) to exactly 32 bytes. Anything else (absent, blank, wrong length, not base64) is treated as "no key" and `error_log`ged once — not fatal.
- **Covered columns (7):** `chat_messages.body`, `notifications.message`, `leave_requests.reason`, `leave_requests.rejection_reason`, `leave_requests.cancellation_reason`, `absence_justifications.reason`, `absence_justifications.review_note`. Plus a write-only wrap on the legacy `leaves.reason` (0 rows, no read path).
- **Plaintext truncation stays and runs before encryption:** `mb_substr($reason, 0, 1000)` and the chat `mb_strlen($message) > 4000` cap are unchanged.
- **`crypto.php` is loaded via `helpers.php`** (`require_once __DIR__ . '/crypto.php';` next to the existing `require_once __DIR__ . '/push.php';`). Every entry point already pulls in `helpers.php`.
- **Client Flutter: no changes.**
- **Branch:** work on `main` (the project's standing choice this engagement). `helpers.php` / `index.php` / `leave_requests.php` / `absences.php` carry pre-existing uncommitted prior-phase changes; `git add <file>` will commit them alongside — accepted; never `git add -A`; each commit message marks its own lines.
- **File placement (repo convention — adjusts the spec's `scripts/` path):** the committed operational migration tool is `hive-backend/migrate_encrypt_027.php` (root, beside `cron_cleanup_unverified.php` / `seed_attendance_users.php`). Throwaway test scripts go in `scratchpad/` (git-ignored, like the existing `scratchpad/test_push.php`) and are **not** committed.
- **Live DB:** `mysql.exe` at `/c/Program Files/MySQL/MySQL Server 9.6/bin/mysql.exe`, db `hive_db`, user `hive_user`, pw `HivePass_2026!`. PHP CLI: `C:/xampp/php/php.exe`. Some CLI crypto needs `OPENSSL_CONF=C:/xampp/php/extras/ssl/openssl.cnf` — set it if `openssl_*` misbehaves from the CLI.

---

## File Structure

**Create:**
- `hive-backend/crypto.php` — `db_encryption_key()`, `db_encryption_enabled()`, `db_encrypt()`, `db_decrypt()`, `const DB_DECRYPT_UNAVAILABLE`.
- `hive-backend/migrations/027_encrypt_at_rest.sql` — widen 6 columns to `TEXT`.
- `hive-backend/migrate_encrypt_027.php` — one-shot idempotent data migration, `--decrypt` inverse mode. Committed.
- `scratchpad/test_crypto.php` — unit tests for `crypto.php`. Not committed.
- `scratchpad/test_encrypt_at_rest.php` — end-to-end write+read integration. Not committed.

**Modify:**
- `hive-backend/config.php` — `define('DB_ENCRYPTION_KEY', ...)`.
- `hive-backend/.env.example` — key block + "back up separately" note.
- `hive-backend/schema.sql` — the 6 columns become `TEXT`.
- `hive-backend/helpers.php` — `require_once crypto.php`; wrap `notify_user`'s `notifications.message` INSERT param.
- `hive-backend/index.php` — wrap `sendChatMessage` `body` INSERT; wrap `applyLeave` legacy `leaves.reason` INSERT; decrypt in `chatConversations` (`lastMessage`), `chatThread` (`message`), `listNotifications` (rows loop).
- `hive-backend/leave_requests.php` — wrap 4 write params; decrypt 3 fields in `leave_request_payload()`.
- `hive-backend/absences.php` — wrap 2 write params; decrypt 2 fields in `absence_justification_payload()`.

---

## Task 1: `crypto.php` + config + unit tests

**Files:**
- Create: `hive-backend/crypto.php`, `scratchpad/test_crypto.php`
- Modify: `hive-backend/config.php`, `hive-backend/.env.example`

**Interfaces:**
- Produces:
  - `const DB_DECRYPT_UNAVAILABLE = '[contenido no disponible]';`
  - `db_encryption_key(): ?string` — 32 raw bytes or `null`. Memoized. Invalid key value → `null` + one `error_log`.
  - `db_encryption_enabled(): bool` — `db_encryption_key() !== null`.
  - `db_encrypt(?string $plain): ?string`
  - `db_decrypt(?string $stored): ?string`
  - `DB_ENCRYPTION_KEY` constant in `config.php` (raw base64 string, `''` when unset).

- [ ] **Step 1: Write the failing unit tests**

`scratchpad/test_crypto.php`:

```php
<?php
// Ejecutar: php scratchpad/test_crypto.php
// (si openssl falla desde CLI: OPENSSL_CONF=C:/xampp/php/extras/ssl/openssl.cnf php ...)
require __DIR__ . '/../hive-backend/config.php';
require __DIR__ . '/../hive-backend/crypto.php';

$failures = 0;
function check(string $name, bool $ok): void {
    global $failures;
    echo ($ok ? "PASS " : "FAIL ") . $name . PHP_EOL;
    if (!$ok) $failures++;
}

// Fija una clave conocida para las pruebas, sin depender de .env.
$GLOBALS['__test_db_key'] = base64_encode(str_repeat("\x2b", 32));
// crypto.php lee la clave con db_encryption_key(); para forzar una en pruebas
// exponemos un hook: si $GLOBALS['__test_db_key'] existe, se usa esa.

$plain = 'Hola, ¿cómo estás? 🚀 acentúación';
$enc = db_encrypt($plain);
check('envelope has v1: prefix', is_string($enc) && str_starts_with($enc, 'v1:'));
check('round-trips utf-8 + emoji', db_decrypt($enc) === $plain);
check('round-trips empty string', db_encrypt('') === '' && db_decrypt('') === '');
check('null passes through both ways', db_encrypt(null) === null && db_decrypt(null) === null);
check('1000-char round-trip', db_decrypt(db_encrypt(str_repeat('á', 1000))) === str_repeat('á', 1000));
check('non-prefixed value is returned as-is by db_decrypt', db_decrypt('texto plano viejo') === 'texto plano viejo');
check('two encryptions of same input differ (random IV)', db_encrypt($plain) !== db_encrypt($plain));

// Manipular un byte del ciphertext -> sentinel, sin excepción.
$tampered = 'v1:' . base64_encode(base64_decode(substr($enc, 3)) ^ str_pad("\x01", strlen(base64_decode(substr($enc, 3))), "\x00"));
$threw = false;
try { $r = db_decrypt($tampered); } catch (Throwable $e) { $threw = true; $r = null; }
check('tampered ciphertext -> sentinel, no throw', !$threw && $r === DB_DECRYPT_UNAVAILABLE);

// Sin clave -> identidad.
unset($GLOBALS['__test_db_key']);
$GLOBALS['__test_db_key'] = '';
check('no key -> db_encrypt is identity', db_encrypt('secreto') === 'secreto');
check('no key -> db_decrypt is identity', db_decrypt('secreto') === 'secreto');
$GLOBALS['__test_db_key'] = 'not-valid-base64-!!!';
check('bad key value -> treated as no key', db_encrypt('secreto') === 'secreto');

echo PHP_EOL . ($failures === 0 ? "ALL PASS" : "$failures FAILURE(S)") . PHP_EOL;
exit($failures === 0 ? 0 : 1);
```

- [ ] **Step 2: Run tests, confirm they fail**

Run: `php scratchpad/test_crypto.php`
Expected: FAIL — fatal, `crypto.php` does not exist.

- [ ] **Step 3: Create `hive-backend/crypto.php`**

```php
<?php
// Cifrado en reposo de columnas sensibles (AES-256-GCM). La clave vive en el
// servidor (DB_ENCRYPTION_KEY en .env): esto NO es cifrado extremo a extremo,
// solo evita que un dump / backup / acceso SQL exponga texto plano.
// Formato: "v1:" . base64( iv(12) . tag(16) . ciphertext ).

require_once __DIR__ . '/config.php';

const DB_DECRYPT_UNAVAILABLE = '[contenido no disponible]';

// 32 bytes crudos o null. Memoiza. Un valor inválido se trata como "sin clave".
// Hook de pruebas: $GLOBALS['__test_db_key'] (base64) tiene prioridad si existe.
function db_encryption_key(): ?string {
    // Hook de pruebas: si $GLOBALS['__test_db_key'] existe, se resuelve SIEMPRE
    // desde él (sin memoizar), para que un test pueda cambiar la clave a media
    // ejecución. En producción (sin el hook) se memoiza tras la 1ª llamada.
    static $cached = false; // false = sin resolver
    $hooked = array_key_exists('__test_db_key', $GLOBALS);
    if (!$hooked && $cached !== false) {
        return $cached;
    }
    $raw = $hooked ? (string) $GLOBALS['__test_db_key'] : (string) DB_ENCRYPTION_KEY;

    $resolve = static function (string $raw): ?string {
        if ($raw === '') {
            return null;
        }
        $decoded = base64_decode($raw, true);
        if ($decoded === false || strlen($decoded) !== 32) {
            static $warned = false;
            if (!$warned) {
                error_log('crypto: DB_ENCRYPTION_KEY inválida (se esperaban 32 bytes base64); cifrado deshabilitado');
                $warned = true;
            }
            return null;
        }
        return $decoded;
    };

    $key = $resolve($raw);
    if (!$hooked) {
        $cached = $key;
    }
    return $key;
}

function db_encryption_enabled(): bool {
    return db_encryption_key() !== null;
}

function db_encrypt(?string $plain): ?string {
    if ($plain === null || $plain === '') {
        return $plain;
    }
    $key = db_encryption_key();
    if ($key === null) {
        return $plain;
    }
    $iv = random_bytes(12);
    $tag = '';
    $ct = openssl_encrypt($plain, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $iv, $tag, '', 16);
    if ($ct === false) {
        error_log('crypto: openssl_encrypt falló; se guarda en plano');
        return $plain;
    }
    return 'v1:' . base64_encode($iv . $tag . $ct);
}

function db_decrypt(?string $stored): ?string {
    if ($stored === null || strncmp($stored, 'v1:', 3) !== 0) {
        return $stored; // NULL o texto plano / formato desconocido
    }
    $key = db_encryption_key();
    if ($key === null) {
        error_log('crypto: valor cifrado pero no hay DB_ENCRYPTION_KEY');
        return DB_DECRYPT_UNAVAILABLE;
    }
    $raw = base64_decode(substr($stored, 3), true);
    if ($raw === false || strlen($raw) < 28) {
        error_log('crypto: envelope v1 malformado');
        return DB_DECRYPT_UNAVAILABLE;
    }
    $iv = substr($raw, 0, 12);
    $tag = substr($raw, 12, 16);
    $ct = substr($raw, 28);
    $plain = openssl_decrypt($ct, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $iv, $tag);
    if ($plain === false) {
        error_log('crypto: openssl_decrypt falló (clave equivocada o valor alterado)');
        return DB_DECRYPT_UNAVAILABLE;
    }
    return $plain;
}
```

- [ ] **Step 4: Add `DB_ENCRYPTION_KEY` to `config.php`**

In `hive-backend/config.php`, right after the `FCM_PROJECT_ID` define:

```php
// Clave de cifrado en reposo de columnas sensibles (ver crypto.php). 32 bytes
// en base64. Vacía => las columnas se guardan/leen en plano. Genera una con:
//   php -r "echo base64_encode(random_bytes(32));"
define('DB_ENCRYPTION_KEY', (string) (env_get('DB_ENCRYPTION_KEY') ?: ''));
```

- [ ] **Step 5: Document it in `.env.example`**

Append to `hive-backend/.env.example`:

```
# --- Cifrado en reposo de columnas sensibles (crypto.php) ---
# Clave de 32 bytes en base64. Vacía => las columnas se guardan en plano.
# Generar: php -r "echo base64_encode(random_bytes(32));"
# IMPORTANTE: respaldar esta clave POR SEPARADO de la base de datos. Un backup
# que contenga la BD cifrada y este .env juntos anula el cifrado.
DB_ENCRYPTION_KEY=
```

- [ ] **Step 6: Run tests, confirm pass**

Run: `php scratchpad/test_crypto.php` (prepend `OPENSSL_CONF=...` if needed)
Expected: every line `PASS`, `ALL PASS`, exit 0.

- [ ] **Step 7: Lint + commit**

```bash
php -l hive-backend/crypto.php && php -l hive-backend/config.php
git add hive-backend/crypto.php hive-backend/config.php hive-backend/.env.example
git commit -m "feat(crypto): AES-256-GCM db_encrypt/db_decrypt + DB_ENCRYPTION_KEY config"
```
(Do not `git add scratchpad/test_crypto.php` — it is git-ignored.)

---

## Task 2: Schema migration `027` + widen columns

**Files:**
- Create: `hive-backend/migrations/027_encrypt_at_rest.sql`
- Modify: `hive-backend/schema.sql`

**Interfaces:**
- Consumes: nothing.
- Produces: `notifications.message`, `leave_requests.{reason,rejection_reason,cancellation_reason}`, `absence_justifications.{reason,review_note}` are all `TEXT`. `chat_messages.body` already `TEXT` (untouched).

- [ ] **Step 1: Write the migration**

`hive-backend/migrations/027_encrypt_at_rest.sql`:

```sql
-- 027: ensanchar columnas sensibles para alojar ciphertext AES-256-GCM
-- (crypto.php). El envelope "v1:" + base64(iv+tag+ct) de 1000 caracteres de
-- texto ocupa ~5.4 KB; de un mensaje de chat de 4000, ~21 KB. VARCHAR se queda
-- corto; TEXT (64 KB) sobra. chat_messages.body ya es TEXT.
ALTER TABLE notifications         MODIFY message             TEXT NOT NULL;
ALTER TABLE leave_requests        MODIFY reason              TEXT NULL;
ALTER TABLE leave_requests        MODIFY rejection_reason    TEXT NULL;
ALTER TABLE leave_requests        MODIFY cancellation_reason TEXT NULL;
ALTER TABLE absence_justifications MODIFY reason              TEXT NULL;
ALTER TABLE absence_justifications MODIFY review_note         TEXT NULL;
```

- [ ] **Step 2: Mirror into `schema.sql`**

In `hive-backend/schema.sql`, change these column definitions:
- `notifications`: `message VARCHAR(255) NOT NULL` → `message TEXT NOT NULL`
- `leave_requests`: `reason VARCHAR(1000) NULL` → `reason TEXT NULL`; `rejection_reason VARCHAR(1000) NULL` → `rejection_reason TEXT NULL`; `cancellation_reason VARCHAR(1000) NULL` → `cancellation_reason TEXT NULL`
- `absence_justifications`: `reason VARCHAR(1000) NULL` → `reason TEXT NULL`; `review_note VARCHAR(1000) NULL` → `review_note TEXT NULL`

Keep every surrounding line (comments, keys, FKs) exactly as-is.

- [ ] **Step 3: Apply to the live DB**

Run:
```bash
"/c/Program Files/MySQL/MySQL Server 9.6/bin/mysql.exe" -uhive_user -p'HivePass_2026!' hive_db < hive-backend/migrations/027_encrypt_at_rest.sql
```
Expected: no output, exit 0.

- [ ] **Step 4: Verify**

Run:
```bash
"/c/Program Files/MySQL/MySQL Server 9.6/bin/mysql.exe" -uhive_user -p'HivePass_2026!' hive_db -e "SELECT COLUMN_NAME, DATA_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='hive_db' AND ((TABLE_NAME='notifications' AND COLUMN_NAME='message') OR (TABLE_NAME='leave_requests' AND COLUMN_NAME IN ('reason','rejection_reason','cancellation_reason')) OR (TABLE_NAME='absence_justifications' AND COLUMN_NAME IN ('reason','review_note')));"
```
Expected: all six rows show `text`.

- [ ] **Step 5: Commit**

```bash
git add hive-backend/migrations/027_encrypt_at_rest.sql hive-backend/schema.sql
git commit -m "feat(crypto): migration 027 widens sensitive columns to TEXT"
```

---

## Task 3: Encrypt on write, decrypt on read (all sites)

**Files:**
- Modify: `hive-backend/helpers.php`, `hive-backend/index.php`, `hive-backend/leave_requests.php`, `hive-backend/absences.php`
- Create: `scratchpad/test_encrypt_at_rest.php`

**Interfaces:**
- Consumes: `db_encrypt()`, `db_decrypt()`, `DB_DECRYPT_UNAVAILABLE` (Task 1); the `TEXT` columns (Task 2).
- Produces: every covered write stores a `v1:` envelope (when a key is configured); every covered read returns plaintext.

- [ ] **Step 1: Write the failing integration test**

`scratchpad/test_encrypt_at_rest.php`:

```php
<?php
// Ejecutar con clave puesta:
//   OPENSSL_CONF=C:/xampp/php/extras/ssl/openssl.cnf php scratchpad/test_encrypt_at_rest.php
// Requiere DB_ENCRYPTION_KEY en hive-backend/.env (o el hook __test_db_key).
require __DIR__ . '/../hive-backend/config.php';
require __DIR__ . '/../hive-backend/helpers.php'; // arrastra crypto.php + push.php

$failures = 0;
function check(string $n, bool $ok): void {
    global $failures; echo ($ok ? "PASS " : "FAIL ") . $n . PHP_EOL; if (!$ok) $failures++;
}

if (!db_encryption_enabled()) {
    $GLOBALS['__test_db_key'] = base64_encode(str_repeat("\x2b", 32));
}
$raw = fn(string $sql, array $p = []) => (function() use ($pdo, $sql, $p) {
    $s = $pdo->prepare($sql); $s->execute($p); return $s->fetchColumn();
})();

// --- notifications: notify_user escribe cifrado, listNotifications lee plano ---
$pdo->exec("DELETE FROM notifications WHERE email='enc@doliv.test'");
notify_user($pdo, 'enc@doliv.test', null, 'chat', 'Secreto en la campana', 'user', 'a@b.com');
$stored = $pdo->query("SELECT message FROM notifications WHERE email='enc@doliv.test'")->fetchColumn();
check('notifications.message stored as v1: envelope', is_string($stored) && str_starts_with($stored, 'v1:'));
check('notifications.message has no plaintext', strpos((string)$stored, 'Secreto en la campana') === false);
check('db_decrypt recovers the notification text', db_decrypt($stored) === 'Secreto en la campana');
$pdo->exec("DELETE FROM notifications WHERE email='enc@doliv.test'");

// --- chat_messages: INSERT directo por el mismo patrón que sendChatMessage ---
$cid = 'enc-convo-test';
$pdo->exec("DELETE FROM chat_messages WHERE conversation_key='$cid'");
$u = $pdo->query("SELECT id FROM users LIMIT 1")->fetchColumn();
$pdo->prepare('INSERT INTO chat_messages (conversation_key, sender_id, recipient_id, body) VALUES (?,?,?,?)')
    ->execute([$cid, $u, $u, db_encrypt('mensaje privado de prueba')]);
$body = $pdo->query("SELECT body FROM chat_messages WHERE conversation_key='$cid'")->fetchColumn();
check('chat_messages.body stored as v1: envelope', str_starts_with((string)$body, 'v1:'));
check('chat_messages.body has no plaintext', strpos((string)$body, 'mensaje privado de prueba') === false);
check('db_decrypt recovers the chat body', db_decrypt($body) === 'mensaje privado de prueba');
$pdo->exec("DELETE FROM chat_messages WHERE conversation_key='$cid'");

// --- leave_requests.reason via db_encrypt on the create param shape ---
$lid = 'enc-leave-test';
$pdo->exec("DELETE FROM leave_requests WHERE id='$lid'");
$pdo->prepare('INSERT INTO leave_requests (id, employee_id, type, requested_start_date, requested_end_date, requested_days, reason, status)
               VALUES (?,?,?,?,?,?,?,"pendiente")')
    ->execute([$lid, $u, 'permiso', '2026-10-01', '2026-10-02', 2, db_encrypt('motivo médico reservado')]);
$rsn = $pdo->query("SELECT reason FROM leave_requests WHERE id='$lid'")->fetchColumn();
check('leave_requests.reason stored encrypted', str_starts_with((string)$rsn, 'v1:'));
check('leave_requests.reason no plaintext', strpos((string)$rsn, 'motivo médico reservado') === false);
check('leave_request_payload decrypts reason', leave_request_payload($pdo, leave_row($pdo, $lid))['reason'] === 'motivo médico reservado');
$pdo->exec("DELETE FROM leave_requests WHERE id='$lid'");

// --- absence_justifications.reason ---
$aid = 'enc-abs-test';
$pdo->exec("DELETE FROM absence_justifications WHERE id='$aid'");
$pdo->prepare('INSERT INTO absence_justifications (id, employee_id, start_date, end_date, reason, evidence_path, evidence_mime, status)
               VALUES (?,?,?,?,?,?,?,"pendiente")')
    ->execute([$aid, $u, '2026-09-01', '2026-09-01', db_encrypt('cita con especialista'), 'x', 'image/png']);
$arsn = $pdo->query("SELECT reason FROM absence_justifications WHERE id='$aid'")->fetchColumn();
check('absence_justifications.reason stored encrypted', str_starts_with((string)$arsn, 'v1:'));
check('absence_justification_payload decrypts reason',
      absence_justification_payload($pdo, absence_row($pdo, $aid))['reason'] === 'cita con especialista');
$pdo->exec("DELETE FROM absence_justifications WHERE id='$aid'");

echo PHP_EOL . ($failures === 0 ? "ALL PASS" : "$failures FAILURE(S)") . PHP_EOL;
exit($failures === 0 ? 0 : 1);
```

- [ ] **Step 2: Run it, confirm failures**

Run: `OPENSSL_CONF=C:/xampp/php/extras/ssl/openssl.cnf php scratchpad/test_encrypt_at_rest.php`
Expected: the `notify_user` checks FAIL (message stored as plaintext — `notify_user` not yet wrapping) and the `*_payload decrypts` checks pass only trivially. Confirm at least the two `notify_user` "stored as v1:" / "no plaintext" lines FAIL.

- [ ] **Step 3: `helpers.php` — load crypto + wrap `notify_user`**

In `hive-backend/helpers.php`, next to `require_once __DIR__ . '/push.php';` add:
```php
require_once __DIR__ . '/crypto.php';
```
In `notify_user()`, the INSERT execute currently is:
```php
$stmt->execute([$teamId, $email, $type, $message, $entityType, $entityId]);
```
Change the `$message` slot:
```php
$stmt->execute([$teamId, $email, $type, db_encrypt($message), $entityType, $entityId]);
```
Everything else in `notify_user` (the `$notifId = lastInsertId()`, the push block that passes `$pushBody ?? $message` — plaintext — to `push_send_to_user`) is unchanged. The push still carries readable text.

- [ ] **Step 4: `index.php` — chat write + reads + legacy `leaves` write**

`sendChatMessage` INSERT — change:
```php
)->execute([$key, $me['id'], $peer['id'], $message]);
```
to:
```php
)->execute([$key, $me['id'], $peer['id'], db_encrypt($message)]);
```
(The `$preview` built afterward from `$message` stays plaintext — it feeds `notify_user`, which encrypts `notifications.message` itself.)

`chatConversations` — the `'lastMessage' => $r['body'],` line becomes:
```php
'lastMessage'  => db_decrypt($r['body']),
```

`chatThread` — the `'message'   => $r['body'],` line inside the `array_map` becomes:
```php
'message'   => db_decrypt($r['body']),
```

`listNotifications` — after `$rows = $stmt->fetchAll();`, add:
```php
foreach ($rows as &$row) {
    $row['message'] = db_decrypt($row['message']);
}
unset($row);
```

`applyLeave` (legacy `leaves` table) — in the `INSERT INTO leaves (...)` execute, wrap the `reason` value with `db_encrypt(...)`. Find the `$stmt->execute([...])` for that insert and wrap whichever element is the reason (the 6th column). If the value is passed as a variable, wrap that variable; if inline, wrap inline.

- [ ] **Step 5: `leave_requests.php` — 4 write wraps + payload decrypt**

Create INSERT (`~L371-373`): `$reason !== '' ? $reason : null,` →
```php
db_encrypt($reason !== '' ? $reason : null),
```

Employee cancel (`~L435`): `$stmt->execute([mb_substr($reason, 0, 1000), $user['id'], $id]);` →
```php
$stmt->execute([db_encrypt(mb_substr($reason, 0, 1000)), $user['id'], $id]);
```

Admin reject (`~L618`): `$stmt->execute([mb_substr($reason, 0, 1000), $director['id'], $id]);` →
```php
$stmt->execute([db_encrypt(mb_substr($reason, 0, 1000)), $director['id'], $id]);
```

Admin revoke (`~L653`): same shape as reject →
```php
$stmt->execute([db_encrypt(mb_substr($reason, 0, 1000)), $director['id'], $id]);
```

`leave_request_payload()` (`~L136-138`):
```php
'reason'              => db_decrypt($row['reason']),
'rejectionReason'     => db_decrypt($row['rejection_reason']),
'cancellationReason'  => db_decrypt($row['cancellation_reason']),
```

**Do NOT** change `leave_absence_payload()` (it exposes only type/dates). The `notify_user(...)` calls at `~L621` / `~L658` that interpolate `$reason` are unchanged — `$reason` there is the fresh plaintext, and `notify_user` encrypts `notifications.message` itself.

- [ ] **Step 6: `absences.php` — 2 write wraps + payload decrypt**

Create INSERT (`~L308`): `$reason !== '' ? $reason : null,` →
```php
db_encrypt($reason !== '' ? $reason : null),
```

Admin review UPDATE (`~L423`): `$upd->execute([$decision, $note !== '' ? mb_substr($note, 0, 1000) : null, $user['id'], $id]);` →
```php
$upd->execute([$decision, db_encrypt($note !== '' ? mb_substr($note, 0, 1000) : null), $user['id'], $id]);
```

`absence_justification_payload()` (`~L105-109`):
```php
'reason'      => db_decrypt($row['reason']),
'reviewNote'  => db_decrypt($row['review_note']),
```

- [ ] **Step 7: Run the integration test green**

Run: `OPENSSL_CONF=C:/xampp/php/extras/ssl/openssl.cnf php scratchpad/test_encrypt_at_rest.php`
Expected: every line `PASS`, `ALL PASS`, exit 0.

- [ ] **Step 8: Regression — the push suite still passes**

Run (with `DB_ENCRYPTION_KEY` set in `hive-backend/.env`, and `FCM_PROJECT_ID` as it already is): `OPENSSL_CONF=C:/xampp/php/extras/ssl/openssl.cnf php scratchpad/test_push.php`
Expected: `ALL PASS`. (`notify_user` now encrypts `notifications.message`; the push-body assertions read `data.body` which comes from the plaintext `$pushBody`/`$message` in memory, so they still hold. If any push-suite assertion inspects the stored `notifications.message` for a plaintext substring, update it to `db_decrypt()` the value first.)

- [ ] **Step 9: Lint + commit**

```bash
php -l hive-backend/helpers.php && php -l hive-backend/index.php && php -l hive-backend/leave_requests.php && php -l hive-backend/absences.php
git add hive-backend/helpers.php hive-backend/index.php hive-backend/leave_requests.php hive-backend/absences.php
git commit -m "feat(crypto): encrypt chat/notification/leave/absence text on write, decrypt on read"
```
(`git status --porcelain` first; stage only those 4 files. `scratchpad/test_encrypt_at_rest.php` stays untracked.)

---

## Task 4: Data migration tool

**Files:**
- Create: `hive-backend/migrate_encrypt_027.php`

**Interfaces:**
- Consumes: `db_encrypt()`, `db_decrypt()` (Task 1); the `TEXT` columns (Task 2).
- Produces: a committed CLI tool. Default = encrypt legacy plaintext rows. `--decrypt` = inverse. Idempotent both ways.

- [ ] **Step 1: Write the tool**

`hive-backend/migrate_encrypt_027.php`:

```php
<?php
// Cifra (o con --decrypt, descifra) las columnas sensibles existentes.
// Idempotente: solo toca filas cuyo valor NO empieza por "v1:" (o, con
// --decrypt, las que sí). Requiere DB_ENCRYPTION_KEY.
//
//   php hive-backend/migrate_encrypt_027.php
//   php hive-backend/migrate_encrypt_027.php --decrypt   (para rollback)

require __DIR__ . '/config.php';
require __DIR__ . '/crypto.php';

if (!db_encryption_enabled()) {
    fwrite(STDERR, "ABORT: DB_ENCRYPTION_KEY no configurada.\n");
    exit(1);
}
$decrypt = in_array('--decrypt', $argv, true);

/** @var array<array{table:string,col:string}> */
$targets = [
    ['table' => 'chat_messages',         'col' => 'body'],
    ['table' => 'notifications',         'col' => 'message'],
    ['table' => 'leave_requests',        'col' => 'reason'],
    ['table' => 'leave_requests',        'col' => 'rejection_reason'],
    ['table' => 'leave_requests',        'col' => 'cancellation_reason'],
    ['table' => 'absence_justifications','col' => 'reason'],
    ['table' => 'absence_justifications','col' => 'review_note'],
];

$grand = 0;
foreach ($targets as $t) {
    [$table, $col] = [$t['table'], $t['col']];
    $like = $decrypt ? "$col LIKE 'v1:%'" : "$col IS NOT NULL AND $col NOT LIKE 'v1:%'";
    $rows = $pdo->query("SELECT id, $col AS v FROM $table WHERE $like")->fetchAll(PDO::FETCH_ASSOC);
    if (!$rows) { echo str_pad("$table.$col", 40) . "0\n"; continue; }
    $upd = $pdo->prepare("UPDATE $table SET $col = ? WHERE id = ?");
    $n = 0;
    $pdo->beginTransaction();
    foreach ($rows as $i => $r) {
        $new = $decrypt ? db_decrypt($r['v']) : db_encrypt($r['v']);
        $upd->execute([$new, $r['id']]);
        $n++;
        if ($n % 200 === 0) { $pdo->commit(); $pdo->beginTransaction(); }
    }
    $pdo->commit();
    $grand += $n;
    echo str_pad("$table.$col", 40) . "$n\n";
}
echo str_repeat('-', 45) . "\n" . str_pad(($decrypt ? 'descifradas' : 'cifradas') . ':', 40) . "$grand\n";
```

- [ ] **Step 2: Test on seeded rows (not the live data yet)**

Write and run an ad-hoc check (`scratchpad/test_migrate_027.php`):
```php
<?php
require __DIR__ . '/../hive-backend/config.php';
require __DIR__ . '/../hive-backend/crypto.php';
if (!db_encryption_enabled()) { $GLOBALS['__test_db_key'] = base64_encode(str_repeat("\x2b",32)); }
$failures = 0;
function check($n,$ok){ global $failures; echo ($ok?"PASS ":"FAIL ").$n.PHP_EOL; if(!$ok)$failures++; }

$u = $pdo->query("SELECT id FROM users LIMIT 1")->fetchColumn();
$pdo->exec("DELETE FROM leave_requests WHERE id='mig-a' OR id='mig-b'");
$pdo->prepare('INSERT INTO leave_requests (id,employee_id,type,requested_start_date,requested_end_date,requested_days,reason,status) VALUES (?,?,?,?,?,?,?,"pendiente")')
    ->execute(['mig-a',$u,'permiso','2026-10-01','2026-10-02',2,'texto plano viejo A']);
$pdo->prepare('INSERT INTO leave_requests (id,employee_id,type,requested_start_date,requested_end_date,requested_days,reason,status) VALUES (?,?,?,?,?,?,?,"pendiente")')
    ->execute(['mig-b',$u,'permiso','2026-10-03','2026-10-04',2,null]);

exec('OPENSSL_CONF=C:/xampp/php/extras/ssl/openssl.cnf ' . escapeshellarg(PHP_BINARY) . ' ' . escapeshellarg(__DIR__ . '/../hive-backend/migrate_encrypt_027.php'), $out1);
$a = $pdo->query("SELECT reason FROM leave_requests WHERE id='mig-a'")->fetchColumn();
$b = $pdo->query("SELECT reason FROM leave_requests WHERE id='mig-b'")->fetchColumn();
check('plaintext row got encrypted', str_starts_with((string)$a,'v1:') && db_decrypt($a)==='texto plano viejo A');
check('NULL row left NULL', $b === null);

exec('OPENSSL_CONF=C:/xampp/php/extras/ssl/openssl.cnf ' . escapeshellarg(PHP_BINARY) . ' ' . escapeshellarg(__DIR__ . '/../hive-backend/migrate_encrypt_027.php'), $out2);
$a2 = $pdo->query("SELECT reason FROM leave_requests WHERE id='mig-a'")->fetchColumn();
check('second run is a no-op (value unchanged)', $a2 === $a);

$pdo->exec("DELETE FROM leave_requests WHERE id='mig-a' OR id='mig-b'");
echo PHP_EOL . ($failures===0 ? "ALL PASS" : "$failures FAILURE(S)") . PHP_EOL;
exit($failures===0?0:1);
```
Run: `OPENSSL_CONF=C:/xampp/php/extras/ssl/openssl.cnf php scratchpad/test_migrate_027.php`
Expected: `ALL PASS`.

- [ ] **Step 3: `php -l` + commit the tool**

```bash
php -l hive-backend/migrate_encrypt_027.php
git add hive-backend/migrate_encrypt_027.php
git commit -m "feat(crypto): migrate_encrypt_027 tool (idempotent encrypt / --decrypt)"
```
(`scratchpad/test_migrate_027.php` stays untracked.)

---

## Task 5: Live-DB cutover + full verification + memory

**Files:** none committed (operational run + memory note).

- [ ] **Step 1: Confirm the key is set for the live backend**

`hive-backend/.env` must contain a real `DB_ENCRYPTION_KEY` (32 bytes base64). If it does not, generate one and add it:
```bash
php -r "echo base64_encode(random_bytes(32)), PHP_EOL;"
```
Record (out of band) that this key must be backed up separately from the DB.

- [ ] **Step 2: Run the data migration against the live DB**

Run:
```bash
OPENSSL_CONF=C:/xampp/php/extras/ssl/openssl.cnf C:/xampp/php/php.exe hive-backend/migrate_encrypt_027.php
```
Expected: per-column counts (roughly `chat_messages.body ~32`, `notifications.message ~176`, `leave_requests.reason` up to 10, others small), then a grand total. Run it a **second time** — every count must be `0`.

- [ ] **Step 3: Spot-check the live DB directly**

Run:
```bash
"/c/Program Files/MySQL/MySQL Server 9.6/bin/mysql.exe" -uhive_user -p'HivePass_2026!' hive_db -e "SELECT LEFT(body,6) FROM chat_messages LIMIT 5; SELECT LEFT(message,6) FROM notifications LIMIT 5; SELECT LEFT(reason,6) FROM leave_requests WHERE reason IS NOT NULL LIMIT 5;"
```
Expected: every non-NULL value begins with `v1:`.

- [ ] **Step 4: End-to-end through the API**

With Apache up: as one user `curl POST /chat/sendMessage` to another; then:
- `mysql` check: the new `chat_messages.body` row starts with `v1:` and does not contain the sent text.
- `curl GET /chat/thread/<key>` as the recipient: the response `message` field is the original plaintext.
- `curl GET /notifications` as the recipient: the chat notification's `message` reads `"<sender>: <text>"` in plaintext.

- [ ] **Step 5: Full regression**

```bash
OPENSSL_CONF=C:/xampp/php/extras/ssl/openssl.cnf C:/xampp/php/php.exe scratchpad/test_crypto.php
OPENSSL_CONF=C:/xampp/php/extras/ssl/openssl.cnf C:/xampp/php/php.exe scratchpad/test_encrypt_at_rest.php
OPENSSL_CONF=C:/xampp/php/extras/ssl/openssl.cnf C:/xampp/php/php.exe scratchpad/test_push.php
C:/flutter/flutter/bin/flutter test
```
Expected: all `ALL PASS` / suite green (Flutter unchanged — sanity only).

- [ ] **Step 6: Update project memory**

Append a dated section to `C:\Users\jerem\.claude\projects\C--xampp-htdocs-radio-doliv\memory\radio-doliv-fix-plan.md`: `crypto.php` (AES-256-GCM, `v1:` envelope, key `DB_ENCRYPTION_KEY` in `.env`, identity when unset); migration `027` (6 cols → TEXT, applied live); the 9 write wraps + 5 read decrypts; `migrate_encrypt_027.php` (idempotent, `--decrypt` rollback) run against live DB; covered columns list; **key must be backed up separately from the DB**; rotation + `email`/`name` + evidence files explicitly out of scope (spec §8).

- [ ] **Step 7: Commit any tracked doc/memory changes**

```bash
git status --porcelain
# commit only if something tracked changed (spec/plan already committed; memory is outside the repo)
```

---

## Self-Review

**1. Spec coverage:**
- Spec §1 `crypto.php` contract → Task 1 (all 5 symbols + sentinel, exact envelope, never-throws, identity-without-key).
- Spec §2 key & config → Task 1 Steps 4-5 (`config.php` define, `.env.example` block with the back-up-separately note).
- Spec §3 schema migration `027` → Task 2 (6 `TEXT` alters, `schema.sql` mirror, live apply, verify).
- Spec §4.1 writes (9 sites incl. legacy `leaves`) → Task 3 Steps 3-6.
- Spec §4.2 reads (5 mappers, `leave_absence_payload` untouched) → Task 3 Steps 4-6.
- Spec §4.3 "nothing searches these" → no query changes anywhere in the plan; consistent.
- Spec §5 migration script (idempotent, batched, `--decrypt`, skips `leaves`) → Task 4.
- Spec §6 failure modes → Task 1 tests (tamper→sentinel, no-key identity, bad key, null, empty, passthrough).
- Spec §7 testing (unit + integration + migration + regression) → Task 1 Step 1, Task 3 Step 1, Task 4 Step 2, Task 5 Step 5.
- Spec §8 operational (back up key separately, rotation/`email`/evidence out of scope) → `.env.example` note + Task 5 Step 6 memory note.
- No gaps.

**2. Placeholder scan:** Every code step carries full code. `applyLeave`'s `leaves` INSERT wrap (Task 3 Step 4 last bullet) says "wrap whichever element is the reason (the 6th column)" rather than a verbatim diff — this is because the exact `execute([...])` array spans lines not fully quoted here; the instruction is concrete (6th column, `db_encrypt(...)`). Acceptable. No `TBD` / "handle errors" / "similar to" elsewhere.

**3. Type consistency:** `db_encrypt(?string): ?string` and `db_decrypt(?string): ?string` used identically in Tasks 1, 3, 4. `DB_DECRYPT_UNAVAILABLE` referenced in Task 1 test and defined in Task 1 impl. `leave_request_payload($pdo, $row)` / `absence_justification_payload($pdo, $row)` / `leave_row($pdo, $id)` / `absence_row($pdo, $id)` match the signatures surveyed from the code. Column list is identical across Task 2, Task 3, Task 4 (`chat_messages.body`, `notifications.message`, `leave_requests.{reason,rejection_reason,cancellation_reason}`, `absence_justifications.{reason,review_note}`). `$GLOBALS['__test_db_key']` hook defined in Task 1 impl and used by every test script. No mismatches.
