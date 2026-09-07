# Split `hive-backend/index.php` — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the 62 handler functions in `hive-backend/index.php` (1873 lines) into 8 per-domain modules, leaving `index.php` as routing only (~250 lines). Pure move — zero behaviour change.

**Architecture:** Each new module is a plain `<?php` + header-comment + functions file (no `require` of its own — same convention as the existing `attendance.php` / `events.php` / …). `index.php` `require`s all 8 in its top block before the dispatch loop. PHP resolves handlers by global name at dispatch, so the string `$routes` table is untouched.

**Tech Stack:** PHP 8 (vanilla, no Composer) + MySQL.

**Spec:** `docs/superpowers/specs/2026-09-07-index-php-split-design.md`

## Global Constraints

- **Pure move.** No function renamed, resignatured, reformatted, merged, deleted, or changed in behaviour. Each function's immediately-preceding comment block (the `// GET /chat/... ` style doc line and any block above it that belongs to that function) moves **verbatim** with it.
- **`$routes` array in `index.php` is untouched** — byte for byte. Handler names stay as strings.
- **No dead-code removal** (`googleOAuthStub`, legacy `leaves`, etc.) — out of scope.
- **New files:** first line `<?php`, then a one-paragraph `//` header comment describing the module, then the functions. **No `require`/`use`/`include` lines inside them** — they rely on `index.php` having required `config.php` + `helpers.php` (and, transitively, `crypto.php` / `push.php`) first, exactly like every existing module.
- **`index.php` changes are limited to:** (a) adding 8 `require __DIR__ . '/<file>.php';` lines after `require __DIR__ . '/internal_announcements.php';`, kept alphabetical (`auth, chat, devices, documents, legacy_teams, notifications, org, users`); (b) removing the moved functions (and their comment blocks); (c) for the documents task only: moving the `DOCUMENT_ALLOWED_EXT` / `DOCUMENT_MAX_BYTES` `const` block into `documents.php` and deleting its 3-line "…no se hoistea" comment in `index.php`.
- **`home()` and `sendName()` stay in `index.php`.**
- **Backend only.** Do not touch `helpers.php`, `attendance.php`, or any other module. No Flutter.
- **Branch:** work on `main` (the project's standing choice this engagement). `index.php` is currently committed clean — it is the baseline; do not let unrelated working-tree changes into these commits (`git add hive-backend/index.php hive-backend/<newfile>.php` only, never `git add -A`).
- **Live env for smoke tests:** Apache serves `http://localhost/hive-backend`; MySQL `hive_db` / `hive_user` / `HivePass_2026!` at `"/c/Program Files/MySQL/MySQL Server 9.6/bin/mysql.exe"`. PHP CLI `C:/xampp/php/php.exe`; prepend `OPENSSL_CONF=C:/xampp/php/extras/ssl/openssl.cnf` for the crypto-touching test scripts.
- **Invariant checked after every task:** total `^function ` definitions across `index.php` + all new files == **62**; `index.php` holds exactly the functions not yet moved (ending at **2** — `home`, `sendName` — after the last module task).

---

## File Structure

**Create** (each: `<?php` + header comment + moved functions):
- `hive-backend/devices.php` — 2 functions
- `hive-backend/chat.php` — 5 functions
- `hive-backend/auth.php` — 9 functions
- `hive-backend/documents.php` — 5 functions + the 2 `DOCUMENT_*` consts
- `hive-backend/notifications.php` — 4 functions
- `hive-backend/users.php` — 7 functions
- `hive-backend/org.php` — 9 functions
- `hive-backend/legacy_teams.php` — 19 functions

**Modify:**
- `hive-backend/index.php` — remove the 60 moved functions + the `DOCUMENT_*` const block; add 8 `require` lines.

**Task order** (spec §7 rationale — most-isolated / smallest first to shake out the mechanics; largest last): devices → chat → auth → documents → notifications → users → org → legacy_teams. (The spec's §7 prose lists a different order in its arrow list; this plan follows the stated *rationale*, which is the intent.)

---

## Shared procedure (every module task)

Each task N below is the same shape. `NEWFILE` = the module file, `FUNCS` = its ordered function list.

- [ ] **Step 1: Create `hive-backend/NEWFILE` with the header**

```php
<?php
// <one-paragraph description — see each task>
```

- [ ] **Step 2: Move each function in `FUNCS`, in source order**

For each `F` in `FUNCS`: in `hive-backend/index.php`, locate `function F(` (search, don't trust line numbers — they shift as earlier tasks run). Select from the start of `F`'s leading comment block (the contiguous `//` lines immediately above `function F(`, if any) through `F`'s closing `}` at column 0. **Cut** that block from `index.php` and **append** it to `NEWFILE`, preserving order and the blank line between functions. Do not edit the moved text.

- [ ] **Step 3: `php -l` both files**

```bash
C:/xampp/php/php.exe -l hive-backend/index.php
C:/xampp/php/php.exe -l hive-backend/NEWFILE
```
Both: `No syntax errors detected`.

- [ ] **Step 4: Grep integrity (per moved function + totals)**

```bash
# each moved function: 0 in index.php, 1 in NEWFILE, 1 across the whole backend
for f in FUNCS; do
  echo "$f: index=$(grep -c "^function $f(" hive-backend/index.php) new=$(grep -c "^function $f(" hive-backend/NEWFILE) all=$(grep -rc "^function $f(" hive-backend/*.php | grep -v ':0' | wc -l)"
done
# conservation: index + all new files still total 62
# split-set only: index + the 8 new modules must total 62 (a bare hive-backend/*.php
   # glob would also count the ~13 pre-existing modules -> ~323, which is fine)
   echo $(( $(grep -cE "^function " hive-backend/index.php) + $(for m in auth chat devices documents legacy_teams notifications org users; do grep -cE "^function " hive-backend/$m.php; done | paste -sd+) ))
```
Expected: every function `index=0 new=1 all=1`; `total functions: 62`.

- [ ] **Step 5: Add the `require` line to `index.php`**

In the top `require` block, after `require __DIR__ . '/internal_announcements.php';`, insert `require __DIR__ . '/NEWFILE';` so the 8 new requires stay in alphabetical order (they may not all exist yet — add this task's in its alphabetical slot among those already added).

- [ ] **Step 6: Smoke curl (Apache must be up)**

Check `curl -s -o /dev/null -w '%{http_code}' http://localhost/hive-backend/` first; if it's not reachable, note it and run Step 7 instead as the substitute evidence, then proceed. Otherwise hit this task's endpoint (see each task) and confirm a normal `200`/`401`/`400` — **never** a `500` with `Fatal error: ... undefined function`.

- [ ] **Step 7: Integration suites still pass**

```bash
OPENSSL_CONF=C:/xampp/php/extras/ssl/openssl.cnf C:/xampp/php/php.exe scratchpad/test_push.php
OPENSSL_CONF=C:/xampp/php/extras/ssl/openssl.cnf C:/xampp/php/php.exe scratchpad/test_encrypt_at_rest.php
```
Both `ALL PASS`. (They exercise `notify_user`, chat inserts, notification reads — the paths most likely to break on a bad move.)

- [ ] **Step 8: Commit**

```bash
git add hive-backend/index.php hive-backend/NEWFILE
git status --porcelain   # confirm ONLY those two
git commit -m "refactor(backend): extract <domain> handlers from index.php into NEWFILE"
```

---

## Task 1: `devices.php`

**FUNCS** (order): `deviceRegister`, `deviceUnregister`

**Header comment:**
```php
<?php
// Registro del token FCM del dispositivo para las notificaciones push
// (ver push.php). El cliente lo llama al iniciar sesión y al cerrarla.
```

**Interfaces:** Consumes `require_auth`, `request_body`, `json_response`, `error_response` (helpers.php). Produces the `deviceRegister` / `deviceUnregister` handlers referenced by the `POST /devices/register` and `POST /devices/unregister` routes.

Run the shared procedure Steps 1-8. `NEWFILE = devices.php`.

**Step 6 endpoint:** `curl -s -X POST http://localhost/hive-backend/devices/register` → expect `401` (no auth) — proves the route resolves to the moved handler.

**Step 8 commit message:** `refactor(backend): extract device-token handlers from index.php into devices.php`

---

## Task 2: `chat.php`

**FUNCS** (order): `chat_convo_key`, `chat_resolve_peer`, `chatConversations`, `chatThread`, `sendChatMessage`

**Header comment:**
```php
<?php
// Mensajería directa 1 a 1 entre usuarios (ver migración 016). No hay sala
// global: cada quien solo ve las conversaciones en las que participa. El
// cuerpo del mensaje se guarda cifrado en reposo (db_encrypt, ver crypto.php).
```

**Interfaces:** Consumes `require_auth`, `json_response`, `text_response`, `db_encrypt`, `db_decrypt`, `notify_user`, `push_title_for_type`. `chat_convo_key` / `chat_resolve_peer` are used only by `chatThread` / `sendChatMessage` (same file). Produces the 5 handlers behind `/chat/*`.

Run the shared procedure. `NEWFILE = chat.php`.

**Step 6 endpoint:** `curl -s -o /dev/null -w '%{http_code}' -X GET http://localhost/hive-backend/chat/conversations` → `401`.

**Step 8 commit message:** `refactor(backend): extract chat handlers from index.php into chat.php`

---

## Task 3: `auth.php`

**FUNCS** (order): `googleOAuthStub`, `dispatch_verification_email`, `signup`, `verifyEmail`, `resendVerification`, `login`, `resetPassword`, `verifyOTP`, `newPassword`

**Header comment:**
```php
<?php
// Alta de cuenta, inicio de sesión, verificación de correo y recuperación de
// contraseña (OTP). El token que devuelve login viaja como string plano por
// compatibilidad; email_verifications guarda solo el hash del token (ver
// helpers.php / migración 023).
```

**Interfaces:** Consumes `require_auth`, `json_response`, `raw_json_response`, `text_response`, `error_response`, `generate_id`, `generate_token`, `generate_otp`, `hash_verification_token`, `issue_email_verification`, `send_verification_email`, `render_verification_page`, `send_otp_email`, `cleanup_unverified_accounts`, `email_verification_send_allowed`, `backend_public_base_url` (all helpers.php). `dispatch_verification_email` is called only by `signup` / `login` / `resendVerification` (same file). Produces the 9 handlers behind `/user/signup`, `/user/login`, `/verify-email`, `/user/resendVerification`, `/user/resetPassword`, `/user/verifyOTP/*`, `/user/newPassword/*`, `/googleOAuth`.

Run the shared procedure. `NEWFILE = auth.php`.

**Step 6 endpoint:** `curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost/hive-backend/user/login -H 'Content-Type: application/json' -d '{}'` → `400`/`401` (never 500). Optionally a real login with a known test user (`abraham@example.com` etc.) to confirm a `200` + token.

**Step 8 commit message:** `refactor(backend): extract auth/verification handlers from index.php into auth.php`

---

## Task 4: `documents.php`

**FUNCS** (order): `document_payload`, `teamDocumentsList`, `teamDocumentUpload`, `teamDocumentDownload`, `teamDocumentDelete`

**Extra — move the consts:** also cut from `index.php` (near the top, before `// ---- routing`) the block:
```php
// Documentos de equipo: tipos permitidos y tamaño máximo. Van aquí (y no
// junto a sus handlers) porque el dispatcher de rutas corre antes de llegar
// a esa sección del archivo, y `const` a nivel de script no se "hoistea".
const DOCUMENT_ALLOWED_EXT = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
    'txt', 'csv', 'zip', 'rar', '7z',
];
const DOCUMENT_MAX_BYTES = 25 * 1024 * 1024; // 25 MB
```
Paste it into `documents.php` **after the header comment, before the functions**, but drop the first 3 comment lines (the "no se hoistea" caveat no longer applies — `documents.php` is required before dispatch). Keep a short 1-line comment like `// Tipos permitidos y tamaño máximo para los documentos de equipo.`

**Header comment:**
```php
<?php
// Documentos de equipo (PDF, Word, Excel, ...). Cualquier miembro lista, sube
// y descarga; borra quien lo subió o el líder. Los archivos viven en un
// directorio privado servido solo a través de estos handlers.
```

**Interfaces:** Consumes `require_auth`, `json_response`, `error_response`, `is_team_member`, `generate_id` (helpers.php), plus `DOCUMENT_ALLOWED_EXT` / `DOCUMENT_MAX_BYTES` (now defined in this file). `document_payload` is used only by `teamDocumentsList` / `teamDocumentDownload` (same file). Produces the 5 handlers behind `/document/*`.

Run the shared procedure. `NEWFILE = documents.php`. In Step 4, also verify `grep -c "DOCUMENT_ALLOWED_EXT" hive-backend/index.php` is `0` and `grep -c "const DOCUMENT_ALLOWED_EXT" hive-backend/documents.php` is `1`.

**Step 6 endpoint:** `curl -s -o /dev/null -w '%{http_code}' http://localhost/hive-backend/document/list/nonexistent` → `401` (no auth) — proves the route + the `DOCUMENT_*` consts resolve.

**Step 8 commit message:** `refactor(backend): extract team-document handlers + consts from index.php into documents.php`

---

## Task 5: `notifications.php`

**FUNCS** (order): `listNotifications`, `markNotificationRead`, `markAllNotificationsRead`, `clearNotifications`

**Header comment:**
```php
<?php
// La campana: lista las notificaciones de esta persona (mensaje descifrado al
// vuelo, ver crypto.php), marca una / todas como leídas, y "Limpiar" borra
// todas. De paso emite los recordatorios de anuncios y eventos que le tocan
// hoy (ia_dispatch_due_reminders / event_dispatch_due_reminders).
```

**Interfaces:** Consumes `require_auth`, `json_response`, `db_decrypt`, `ia_dispatch_due_reminders` (internal_announcements.php), `event_dispatch_due_reminders` (events.php). Produces the 4 handlers behind `/notifications*`.

Run the shared procedure. `NEWFILE = notifications.php`.

**Step 6 endpoint:** `curl -s -o /dev/null -w '%{http_code}' http://localhost/hive-backend/notifications` → `401`.

**Step 8 commit message:** `refactor(backend): extract notification handlers from index.php into notifications.php`

---

## Task 6: `users.php`

**FUNCS** (order): `build_public_user_payload`, `build_user_profile_payload`, `getMe`, `updateProfilePhoto`, `departments_by_id`, `listColleagues`, `getColleagueProfile`

**Header comment:**
```php
<?php
// Perfil propio (GET /user/me), foto de perfil, y el directorio interno de
// compañeros (buscar + abrir ficha). build_*_payload arman la forma pública
// del usuario que consumen login, /user/me y el directorio.
```

**Interfaces:** Consumes `require_auth`, `json_response`, `error_response` (helpers.php), and **`build_department_payload` (defined in `org.php`)** — this is the one deliberate cross-module call; it resolves globally because `org.php` is also required before dispatch. If `org.php` has not been extracted yet when this task runs, `build_department_payload` is still in `index.php` and resolution still works; after Task 7 it lives in `org.php`. Either way, no code change here. Produces `getMe`, `updateProfilePhoto`, `listColleagues`, `getColleagueProfile` handlers + the 3 helper builders.

Run the shared procedure. `NEWFILE = users.php`.

**Step 6 endpoint:** `curl -s -o /dev/null -w '%{http_code}' http://localhost/hive-backend/user/me` → `401`; and `curl -s -o /dev/null -w '%{http_code}' http://localhost/hive-backend/user/directory` → `401`.

**Step 8 commit message:** `refactor(backend): extract profile/directory handlers from index.php into users.php`

---

## Task 7: `org.php`

**FUNCS** (order): `build_department_payload`, `get_the_company`, `createCompany`, `getCompany`, `updateCompany`, `createDepartment`, `listDepartments`, `assignDepartmentManager`, `assignDepartmentEmployee`

**Header comment:**
```php
<?php
// Estructura organizacional de Radio Doliv: un único registro en `companies`,
// N `departments` colgando, y usuarios con role/position/department_id. Solo
// el director crea la empresa y los departamentos y asigna manager/empleados.
```

**Interfaces:** Consumes `require_auth`, `require_role`, `json_response`, `error_response`, `generate_id` (helpers.php). `get_the_company` / `build_department_payload` are defined here; `build_department_payload` is the one function consumed cross-module — by `users.php` (`build_user_profile_payload`), which resolves globally since both files are required before dispatch. `org.php` itself makes no call into another new module (an earlier draft wrongly listed `build_public_user_payload` here — that is `users.php`-internal only). Produces the company + department handlers behind `/company/*` and `/department/*`.

Run the shared procedure. `NEWFILE = org.php`.

**Step 6 endpoint:** `curl -s -o /dev/null -w '%{http_code}' http://localhost/hive-backend/department/list` → `401`; `curl -s -o /dev/null -w '%{http_code}' http://localhost/hive-backend/company/info` → `401`.

**Step 8 commit message:** `refactor(backend): extract company/department handlers from index.php into org.php`

---

## Task 8: `legacy_teams.php`

**FUNCS** (source order): `sendMessageToLeader`, `build_team_payload`, `createTeam`, `sendTeamcode`, `joinTeam`, `showTeams`, `taskDone`, `tasks_for_user`, `incompleteTasks`, `completedTasks`, `deleteMember`, `deleteTeam`, `leaderResign`, `showImage`, `addImage`, `addText`, `showText`, `applyLeave`, `leaveResult`

(19 functions. Follow `index.php` source order when cutting — the list above is roughly it; verify each `function F(` as you go.)

**Header comment:**
```php
<?php
// SISTEMA LEGACY anterior a la estructura por departamentos: equipos con
// líder y código de invitación, tareas de equipo, la tabla `leaves`
// (permisos viejos), y los blobs de imagen/texto por equipo. Se mantiene por
// compatibilidad; el trabajo nuevo va en dept_tasks.php / leave_requests.php /
// la estructura org de org.php. No construir aquí.
```

**Interfaces:** Consumes `require_auth`, `json_response`, `text_response`, `error_response`, `generate_id`, `generate_team_code`, `is_team_member`, `notify_user`, `is_working_day`, `db_encrypt` (helpers/crypto). `build_team_payload` / `tasks_for_user` are used only within this file. Produces the handlers behind `/team/*`, `/user/sendMessage/*`, `/image/*`, `/text/*`, `/leave/applyLeave/*`, `/leave/leaveResult/*`.

Run the shared procedure. `NEWFILE = legacy_teams.php`. This is the largest move — in Step 4 print the per-function line explicitly for all 19 and eyeball that every one reads `index=0 new=1 all=1`.

After this task, `grep -cE "^function " hive-backend/index.php` must be exactly **2** (`home`, `sendName`).

**Step 6 endpoints:** `curl -s -o /dev/null -w '%{http_code}' http://localhost/hive-backend/team/showTeams` → `401`; `curl -s -o /dev/null -w '%{http_code}' http://localhost/hive-backend/user/sendName` → a `200`/`401` (it's a GET stub).

**Step 8 commit message:** `refactor(backend): extract legacy team/task/leave handlers from index.php into legacy_teams.php`

---

## Task 9: Whole-backend verification + require-block tidy

**Files:** possibly a 1-line reorder in `hive-backend/index.php` (require block alphabetical); otherwise none.

- [ ] **Step 1: `index.php` is routing-only**

```bash
grep -cE "^function " hive-backend/index.php      # -> 2
grep -nE "^function " hive-backend/index.php      # -> only home, sendName
wc -l hive-backend/index.php                      # -> ~250-320
grep -c "DOCUMENT_ALLOWED_EXT\|DOCUMENT_MAX_BYTES" hive-backend/index.php   # -> 0
```

- [ ] **Step 2: require block is complete + alphabetical**

`hive-backend/index.php`'s top `require` block must list, after `internal_announcements.php`:
`auth.php`, `chat.php`, `devices.php`, `documents.php`, `legacy_teams.php`, `notifications.php`, `org.php`, `users.php` — in that (alphabetical) order. If any got appended out of order across tasks, reorder those 8 lines now (pure reorder, no other change).

- [ ] **Step 3: function conservation across the whole backend**

```bash
echo $(( $(grep -cE "^function " hive-backend/index.php) + $(for m in auth chat devices documents legacy_teams notifications org users; do grep -cE "^function " hive-backend/$m.php; done | paste -sd+) ))   # -> 62 (split set only, not the whole *.php glob)
```
And no duplicate definitions:
```bash
grep -hoE "^function [a-zA-Z_]+" hive-backend/*.php | sort | uniq -d      # -> (empty)
```

- [ ] **Step 4: `php -l` every backend file**

```bash
for f in hive-backend/*.php; do C:/xampp/php/php.exe -l "$f" || echo "LINT FAIL: $f"; done
```
All `No syntax errors detected`.

- [ ] **Step 5: integration suites**

```bash
OPENSSL_CONF=C:/xampp/php/extras/ssl/openssl.cnf C:/xampp/php/php.exe scratchpad/test_push.php
OPENSSL_CONF=C:/xampp/php/extras/ssl/openssl.cnf C:/xampp/php/php.exe scratchpad/test_encrypt_at_rest.php
```
Both `ALL PASS`.

- [ ] **Step 6: broad smoke — one real request per module against live Apache + DB**

Get a token: `TOK=$(mysql ... -N -e "SELECT token FROM users WHERE token<>'' LIMIT 1")`. Then, for each, expect a `200` (not `500`):
`GET /user/me`, `GET /notifications`, `GET /chat/conversations`, `GET /department/list`, `GET /team/showTeams`, `GET /user/directory` — all with `-H "Authorization: $TOK"`.
And unauthenticated: `POST /user/login -d '{"email":"<known>","password":"<known>"}'` → `200` + a token string.

- [ ] **Step 7: move-only audit**

`git diff <base-before-Task-1>..HEAD -- hive-backend/index.php` should be almost entirely deletions plus the +8 `require` lines and the `const`-block removal. `git log --stat <base>..HEAD` — every commit is `index.php` (−) paired with one new file (+), sizes roughly mirroring. Spot-check 2-3 moved functions with `git show` that the body is identical to the pre-split version (`git show <base>:hive-backend/index.php` piped through `grep -A40 "^function <name>"`).

- [ ] **Step 8: update project memory**

Append to `C:\Users\jerem\.claude\projects\C--xampp-htdocs-radio-doliv\memory\radio-doliv-fix-plan.md`: `index.php` split into `auth.php` / `chat.php` / `devices.php` / `documents.php` / `notifications.php` / `users.php` / `org.php` / `legacy_teams.php` (pure move, `$routes` + dispatch stay in `index.php`, now ~250 lines); `DOCUMENT_*` consts moved to `documents.php`; the one cross-module call is `users.php`→`org.php` `build_department_payload`; `helpers.php` and the other large modules deliberately untouched.

- [ ] **Step 9: commit (only if Step 2 reordered anything)**

```bash
git add hive-backend/index.php
git commit -m "refactor(backend): tidy index.php require block after the split"
```

---

## Self-Review

**1. Spec coverage:**
- Spec §1 (`index.php` after) → Task 9 Steps 1-2 assert it.
- Spec §2 (function→module map, all 8 modules, 60 functions) → Tasks 1-8, one module each; §2's exact function lists are reproduced per task.
- Spec §3 (require block, alphabetical, after `internal_announcements.php`) → shared Step 5 + Task 9 Step 2.
- Spec §4 (the `build_department_payload` cross-call) → called out in Tasks 6 & 7 interfaces.
- Spec §5 (non-goals: no rename/reformat/route change/dead-code) → Global Constraints + Task 9 Step 7 move-only audit.
- Spec §6 (verification bar: php -l, grep integrity, smoke curl, integration suites) → shared Steps 3-4-6-7 per task + Task 9 Steps 3-6.
- Spec §7 (task decomposition, order) → the 9 tasks; order follows the spec's stated rationale (noted where it diverges from the spec's prose arrow-list).
- No gaps.

**2. Placeholder scan:** The shared procedure uses `NEWFILE` / `FUNCS` as substitution variables, each Task instantiates them concretely with the full ordered function list and the verbatim header comment + (Task 4) the verbatim const block. Task 8's function list is "roughly source order — verify each as you go" because a 19-function cut is done by name-search, not line number; the list is complete, the ordering caveat is a method note, not a gap. No `TBD` / "handle errors" / bare "similar to Task N".

**3. Type consistency:** Every module's header comment, function list, `require` filename, commit message, and smoke endpoint are spelled the same in its task and in Task 9's require-block list and memory note (`auth/chat/devices/documents/legacy_teams/notifications/org/users`). `build_department_payload` is consistently placed in `org.php` (Task 7) and consumed from `users.php` (Task 6). Function total is `62` everywhere it's asserted. No mismatch.
