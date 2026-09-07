# Encryption at rest for sensitive columns — design

Date: 2026-09-06
Status: approved for implementation
Scope: hive-backend (vanilla PHP + MySQL). No Flutter changes.

## Goal

Stop a leaked MySQL dump, a stolen backup, or direct SQL access from
exposing sensitive free text. The application server still holds the key
and can read every value; the protection is against data that leaves the
running server as plaintext.

This is **encryption at rest with a server-held key**, not end-to-end
encryption. The server decrypts to build push previews, render API
responses, etc. Admin/compliance visibility is unchanged.

## Decisions (from brainstorming)

- **Threat model:** DB dump / backup theft / raw SQL access. Not the
  server operator, not Google, not compliance.
- **Approach:** application-layer AES-256-GCM. Ciphertext is what lands in
  the column, so `mysqldump` and any `SELECT` return ciphertext. The key
  never appears in SQL (rules out MySQL `AES_ENCRYPT()`), and transparent
  InnoDB tablespace encryption is rejected because it does not protect
  dumps or SQL access.
- **Key:** one 32-byte key in `hive-backend/.env` as `DB_ENCRYPTION_KEY`
  (base64). Envelope carries a `v1:` version tag so rotation later is a
  code change, not a data-format change. Rotation itself is out of scope
  now.
- **Columns:** chat message bodies, notification previews, and HR free
  text (leave reasons, absence justification text + review notes). Not
  `users.email` / `users.name` (join keys — need blind indexes, separate
  project). `users` has no phone/address column.
- **Client:** unchanged. It receives decrypted plaintext over TLS.

## 1. Crypto primitive — `hive-backend/crypto.php` (new)

```php
require_once __DIR__ . '/config.php'; // env_get()

// 32 raw bytes, or null when DB_ENCRYPTION_KEY is unset/blank.
function db_encryption_key(): ?string;

// True when a key is configured.
function db_encryption_enabled(): bool;

// NULL -> NULL. '' -> ''. No key -> $plain unchanged.
// Otherwise: "v1:" . base64( iv(12) || tag(16) || ciphertext )
function db_encrypt(?string $plain): ?string;

// NULL -> NULL. No "v1:" prefix -> returned unchanged (plaintext / legacy).
// "v1:" -> decrypted plaintext.
// Decrypt failure (bad key, tampered value, GCM tag mismatch) ->
//   returns "[contenido no disponible]" and error_log()s. Never throws,
//   never returns the raw ciphertext.
function db_decrypt(?string $stored): ?string;
```

Implementation notes:
- `openssl_encrypt($plain, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $iv, $tag)`
  with `$iv = random_bytes(12)`; `openssl_decrypt(..., $iv, $tag)` on the
  way back, `$iv`/`$tag` sliced off the decoded envelope.
- `db_encryption_key()` memoizes; `base64_decode` the env value with
  strict mode, assert `strlen === 32`, else treat as "no key" + `error_log`.
- `db_decrypt` guards: value must start with `v1:`, decode must be valid
  base64 of length >= 28, `openssl_decrypt` must not return `false`.

Sentinel: `const DB_DECRYPT_UNAVAILABLE = '[contenido no disponible]';`

## 2. Key & config

- `config.php`: `define('DB_ENCRYPTION_KEY', (string) (env_get('DB_ENCRYPTION_KEY') ?: ''));`
  next to the other `define(...)` lines. (Kept as a raw base64 string;
  `crypto.php` decodes + validates.)
- `.env.example`: new block —
  ```
  # --- Cifrado en reposo de columnas sensibles (crypto.php) ---
  # Clave de 32 bytes en base64. Vacía => las columnas se guardan en plano.
  # Generar: php -r "echo base64_encode(random_bytes(32));"
  # IMPORTANTE: respaldar esta clave POR SEPARADO de la base de datos. Un
  # backup que contenga la BD cifrada y este .env juntos anula el cifrado.
  DB_ENCRYPTION_KEY=
  ```
- `.gitignore` already ignores `hive-backend/.env`. No new ignore lines.
- Empty key ⇒ `db_encrypt`/`db_decrypt` are identity. Local dev and any
  environment without the key keep working in plaintext; the feature is a
  no-op until the key is set and the data migration is run.

## 3. Schema migration `027_encrypt_at_rest.sql`

Ciphertext of a 1000-char plaintext ≈ ≤ 5.4 KB base64; of a 4000-char chat
message ≈ ≤ 21 KB. Columns that currently cap below that must widen to
`TEXT` (64 KB).

```sql
-- 027: widen sensitive columns to hold AES-256-GCM ciphertext (crypto.php).
ALTER TABLE notifications        MODIFY message             TEXT NOT NULL;
ALTER TABLE leave_requests       MODIFY reason              TEXT NULL;
ALTER TABLE leave_requests       MODIFY rejection_reason    TEXT NULL;
ALTER TABLE leave_requests       MODIFY cancellation_reason TEXT NULL;
ALTER TABLE absence_justifications MODIFY reason             TEXT NULL;
ALTER TABLE absence_justifications MODIFY review_note        TEXT NULL;
```

- `chat_messages.body` is already `TEXT` — no change.
- `schema.sql` updated to match.
- Plaintext truncation stays where it is (`mb_substr($reason, 0, 1000)`,
  chat `mb_strlen > 4000`) — it runs on plaintext, before `db_encrypt`.
- Applied to the live DB (`hive_db`) as part of the work.

## 4. Integration points

`helpers.php` gets `require_once __DIR__ . '/crypto.php';` next to its
existing `require_once __DIR__ . '/push.php';`. Every PHP entry point
already pulls in `helpers.php`, so `db_encrypt`/`db_decrypt` are in scope
everywhere without per-file includes.

### 4.1 Writes — wrap the value in `db_encrypt()`

| File | Site | Column |
|---|---|---|
| `index.php` `sendChatMessage` | `INSERT INTO chat_messages (..., body) VALUES (..., ?)` (~L1021) | `body` |
| `helpers.php` `notify_user` | `INSERT INTO notifications (..., message, ...)` (L479) | `message` |
| `leave_requests.php` | create `INSERT ... reason` (L368/L373) | `reason` |
| `leave_requests.php` | employee cancel `UPDATE ... SET cancellation_reason = ?` (L432/L435) | `cancellation_reason` |
| `leave_requests.php` | admin reject `UPDATE ... SET rejection_reason = ?` (L615/L618) | `rejection_reason` |
| `leave_requests.php` | admin revoke `UPDATE ... SET cancellation_reason = ?` (L650/L653) | `cancellation_reason` |
| `absences.php` | create `INSERT ... reason` (L304/L308) | `reason` |
| `absences.php` | admin review `UPDATE ... SET review_note = ?` (L419) | `review_note` |
| `index.php` `applyLeave` (legacy `leaves` table) | `INSERT INTO leaves (..., reason, ...)` (L1340) | `reason` — wrap for consistency; see §8 |

Rule: the exact `db_encrypt(...)` call wraps the bound parameter, e.g.
`$stmt->execute([..., db_encrypt($reason !== '' ? $reason : null), ...])`.
`db_encrypt(null)` returns `null`, so the optional-reason `?: null` logic
is unchanged.

### 4.2 Reads — wrap the result in `db_decrypt()` at the row mapper

| File | Mapper / site | Columns |
|---|---|---|
| `leave_requests.php` | `leave_request_payload()` (L123) — the single mapper every leave API response goes through | `reason` → `db_decrypt($row['reason'])`, same for `rejection_reason`, `cancellation_reason` |
| `absences.php` | `absence_justification_payload()` (L100) — single mapper | `reason`, `review_note` |
| `index.php` `chatConversations` | `'lastMessage' => db_decrypt($r['body'])` (~L955); the correlated subquery that picks the latest message id needs no change (it selects `id`, not `body`) — but if it selects `body`, decrypt there too | `body` |
| `index.php` `chatThread` | `'message' => db_decrypt($r['body'])` (~L985) | `body` |
| `index.php` `listNotifications` | `message` field of each returned row (~L1398) — decrypt in the row loop before `json_response` | `message` |

`leave_absence_payload()` (L214) exposes only type/dates — **no change**.
The join/aggregation queries at `leave_requests.php` L714/L748 select
counts/dates, not `reason` — **no change** (implementer confirms).

### 4.3 Verified: nothing searches or indexes these columns

`grep` for `LIKE` / `MATCH` / `FULLTEXT` over `body` / `message` /
`reason` / `review_note` returns nothing. None of the columns are in an
index. Encryption breaks no query.

## 5. Data migration script — `hive-backend/scripts/migrate_encrypt_027.php`

- Requires `DB_ENCRYPTION_KEY`; aborts with a clear message if absent.
- For each `(table, column, pk)` in:
  - `chat_messages.body` (pk `id`)
  - `notifications.message` (pk `id`)
  - `leave_requests.reason` / `rejection_reason` / `cancellation_reason` (pk `id`)
  - `absence_justifications.reason` / `review_note` (pk `id`)
  do: `SELECT pk, col FROM table WHERE col IS NOT NULL AND col NOT LIKE 'v1:%'`,
  then `db_encrypt` each and `UPDATE table SET col = ? WHERE pk = ?`.
- Batched (e.g. 200 rows), one transaction per batch, prints a per-column
  count and a grand total.
- **Idempotent**: the `NOT LIKE 'v1:%'` filter means a second run touches
  0 rows.
- Legacy `leaves` table: **skipped** (0 rows, write-only, no read path —
  see §8).
- Optional `--decrypt` inverse mode: `WHERE col LIKE 'v1:%'`, writes
  `db_decrypt` back. Only safe while the deployed code still tolerates
  plaintext (which it always does, per `db_decrypt`'s passthrough). For
  rollback.
- Run order: apply `027` → deploy code → set `DB_ENCRYPTION_KEY` → run the
  script once.

## 6. Failure modes & edge cases

- **Key absent in production by mistake:** new rows stored as plaintext;
  setting the key + re-running the migration encrypts them. No data loss.
- **Wrong key (botched rotation):** reads return
  `"[contenido no disponible]"`, `error_log` per value, no crash, no
  ciphertext leak to the client.
- **Partial migration / mixed rows:** a plaintext value read through
  `db_decrypt` has no `v1:` prefix → returned unchanged. Safe coexistence.
- **`NULL` (optional reason not provided):** stays `NULL`; `db_encrypt`
  and `db_decrypt` pass `NULL` through — `''` is never encrypted into a
  non-empty blob.
- **Length:** ciphertext+base64+`v1:` of the largest inputs (1000-char HR
  text ≈ 5.4 KB, 4000-char chat ≈ 21 KB) fits `TEXT` (64 KB).
- **`notify_user` interpolating a fresh reason into its message text**
  (`leave_requests.php` L621/L658): that plaintext string is passed to
  `notify_user`, which encrypts it once when writing `notifications.message`.
  No double-encryption — it is the in-memory plaintext, not a re-read
  ciphertext.

## 7. Testing

### `hive-backend/scripts/test_crypto.php` (style of the existing throwaway tests)

- `db_decrypt(db_encrypt($x)) === $x` for: ASCII, UTF-8 with accents,
  emoji, a 1000-char string, `''`.
- `db_encrypt(null) === null`, `db_decrypt(null) === null`.
- A plaintext value without `v1:` passes through `db_decrypt` unchanged.
- Two `db_encrypt` calls on the same input produce different envelopes
  (random IV).
- A tampered ciphertext (flip one base64 byte) → `db_decrypt` returns
  `DB_DECRYPT_UNAVAILABLE`, does not throw.
- With `DB_ENCRYPTION_KEY` unset (temporarily blank the env): `db_encrypt`
  / `db_decrypt` are identity.
- A wrong-length / non-base64 key value → treated as "no key" + `error_log`,
  not a fatal.

### Integration (`hive-backend/scripts/test_encrypt_at_rest.php`, needs the key set)

- Create a chat message / notification / leave request / absence
  justification through the real code paths, then:
  - assert the raw column value in the DB starts with `v1:` and does NOT
    contain the plaintext substring;
  - assert the corresponding read endpoint / mapper returns the original
    plaintext.
- `notify_user` still stores an (encrypted) row and the push still carries
  the readable preview (server decrypts at send time — confirm
  `push_send_to_user` receives plaintext).
- Migration: seed plaintext rows, run `migrate_encrypt_027.php`, assert
  every target value is now `v1:`-prefixed and reads back correct; second
  run reports 0 changes.

### Regression

- `php -l` on every touched file.
- The existing backend push suite (`scratchpad/test_push.php`) still
  passes with the key set (it exercises `notify_user` → `notifications`).
- Flutter suite unaffected (no client change) — run once to confirm.

## 8. Operational notes & out of scope

- **Back up `DB_ENCRYPTION_KEY` separately from the database.** A backup
  bundle containing both the encrypted DB and this `.env` provides no
  protection. Documented in `.env.example` and here.
- **Rotation** is out of scope now. The `v1:` envelope enables it later: a
  future `crypto.php` holds `{v1, v2, ...}`, decrypts by tag, encrypts
  with the current tag, and `migrate_encrypt_027.php` (or a `028` variant)
  re-encrypts.
- **Evidence files** (`hive-backend/private/**` for leave/absence
  attachments) are on disk, not in the DB — out of scope. They already sit
  behind an Apache `Require all denied`.
- **Legacy `leaves` table**: 0 rows, written by the still-routed
  `applyLeave` but never read for `reason` anywhere. The write gets a
  `db_encrypt` wrap for consistency; no migration, no read-side change.
  A follow-up could retire the endpoint.
- **`users.email` / `users.name`**: join/lookup keys across the whole
  codebase; encrypting them needs deterministic encryption or blind
  indexes — a separate project.
- **Client Flutter**: no change. Values arrive decrypted over TLS.
