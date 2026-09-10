# Split `hive-backend/index.php` into per-domain modules — design

Date: 2026-09-07
Status: approved for implementation
Scope: `hive-backend/` only. No Flutter changes. No behaviour changes.

## Goal

`hive-backend/index.php` is 1873 lines: the route table, the dispatch
loop, and 62 functions covering ~8 unrelated domains. Every other backend
module (`attendance.php`, `events.php`, `dept_tasks.php`, …) is already its
own file; `index.php` was never split. Move each handler group into its
own file so `index.php` is just routing (~250 lines).

**This is a pure move.** No function is renamed, resignatured, deleted,
merged, reformatted beyond the cut/paste, or changed in behaviour. No
route changes. No dead-code removal even where tempting.

## Why it's safe

PHP resolves functions by global name at call time. Every new module is
`require`d in `index.php`'s top `require` block (before the dispatch
loop), exactly like the existing modules. A moved function is callable
from anywhere once its file is required. The only failure modes are:

1. a function left un-moved or moved twice → caught by the per-file grep
   check (§4) and by a runtime "undefined function" on the smoke curl;
2. a missing `require` → caught by `php -l` is *not* enough (lint doesn't
   resolve cross-file calls), so caught by the smoke curl (§4);
3. the two `const`s (`DOCUMENT_*`) losing their pre-dispatch definition →
   avoided by moving them into `documents.php`, which is required up front.

## Existing structure to match

The current modules start with `<?php` + a comment block, no self-require
of `config.php`/`helpers.php` — they rely on `index.php` requiring those
first. New files follow the same convention: `<?php`, a one-paragraph
header comment, then the functions. No `require` lines inside them.

## 1. `index.php` after the split

Keeps, in this order:
- The `require` block — extended with the 8 new modules (see §3).
- `home()` (L244) and `sendName()` (L510) — 2-line stubs, no domain.
- The routing setup (`$uri` / `$base` / `$method` derivation).
- The `$routes` array — **unchanged, byte for byte** (handler names are
  strings resolved at dispatch).
- The `try { foreach ($routes …) … } catch (PDOException …)` dispatch loop
  — unchanged.

Removed: the `DOCUMENT_ALLOWED_EXT` / `DOCUMENT_MAX_BYTES` `const`s (move
to `documents.php`) and their explanatory comment (the "hoisting" caveat
no longer applies — `documents.php` is required before dispatch).

Target size: ~250 lines.

## 2. Function → module map

Line numbers are current `index.php` positions.

### `auth.php` — signup, login, email verification, password reset
`googleOAuthStub` (248), `dispatch_verification_email` (256), `signup`
(265), `verifyEmail` (312), `resendVerification` (357), `login` (377),
`resetPassword` (424), `verifyOTP` (450), `newPassword` (478).
Self-contained: `dispatch_verification_email` is only called by
`signup` / `login` / `resendVerification`.

### `chat.php` — 1:1 direct messaging
`chat_convo_key` (896), `chat_resolve_peer` (902), `chatConversations`
(921), `chatThread` (969), `sendChatMessage` (1005).
Self-contained: the two helpers are only called within this group.

### `devices.php` — FCM push-token registration
`deviceRegister` (1044), `deviceUnregister` (1072).

### `documents.php` — team document store
`document_payload` (1178), `teamDocumentsList` (1190),
`teamDocumentUpload` (1203), `teamDocumentDownload` (1261),
`teamDocumentDelete` (1286). **Plus** the `const DOCUMENT_ALLOWED_EXT`
and `const DOCUMENT_MAX_BYTES` definitions (moved verbatim from
`index.php` L15-19; drop the "ponerlas arriba" comment).
Self-contained: `document_payload` is only called by
`teamDocumentsList` / `teamDocumentDownload`.

### `notifications.php` — the bell
`listNotifications` (1388), `markNotificationRead` (1421),
`markAllNotificationsRead` (1434), `clearNotifications` (1448).

### `users.php` — me, profile, colleague directory, photo
`build_public_user_payload` (1484), `build_user_profile_payload` (1498),
`getMe` (1514), `updateProfilePhoto` (1522), `departments_by_id` (1567),
`listColleagues` (1595), `getColleagueProfile` (1653).

### `org.php` — company + departments
`build_department_payload` (1465), `get_the_company` (1684),
`createCompany` (1693), `getCompany` (1717), `updateCompany` (1726),
`createDepartment` (1753), `listDepartments` (1782),
`assignDepartmentManager` (1792), `assignDepartmentEmployee` (1836).

### `legacy_teams.php` — pre-organisation system (teams, team tasks, `leaves` table, team image/text blobs)
`sendMessageToLeader` (515), `build_team_payload` (538), `createTeam`
(576), `sendTeamcode` (625), `joinTeam` (666), `showTeams` (684),
`deleteMember` (761), `deleteTeam` (793), `leaderResign` (859),
`taskDone` (706), `tasks_for_user` (737), `incompleteTasks` (751),
`completedTasks` (756), `applyLeave` (1313), `leaveResult` (1364),
`showImage` (1088), `addImage` (1104), `addText` (1134), `showText`
(1150).
Self-contained: `build_team_payload` / `tasks_for_user` are only called
within this group. (Header comment should note this file is the legacy
pre-departments system, kept for compatibility — not where new work goes.)

### Stays in `index.php`
`home` (244), `sendName` (510).

## 3. `index.php` require block

Current (L2-10):
```php
require __DIR__ . '/config.php';
require __DIR__ . '/helpers.php';
require __DIR__ . '/site_content.php';
require __DIR__ . '/events.php';
require __DIR__ . '/attendance.php';
require __DIR__ . '/leave_requests.php';
require __DIR__ . '/absences.php';
require __DIR__ . '/dept_tasks.php';
require __DIR__ . '/internal_announcements.php';
```
Add the 8 new modules after `internal_announcements.php`, alphabetical for
readability:
```php
require __DIR__ . '/auth.php';
require __DIR__ . '/chat.php';
require __DIR__ . '/devices.php';
require __DIR__ . '/documents.php';
require __DIR__ . '/legacy_teams.php';
require __DIR__ . '/notifications.php';
require __DIR__ . '/org.php';
require __DIR__ . '/users.php';
```
`config.php` + `helpers.php` stay first (the modules depend on their
functions being defined). `crypto.php` / `push.php` are already pulled in
by `helpers.php`, so `chat.php` / `notifications.php` / `devices.php` get
`db_encrypt` / `notify_user` for free — no extra require.

## 4. Cross-module calls (expected, not a problem)

The only call that crosses a proposed module boundary:
`build_user_profile_payload()` (→ `users.php`) calls
`build_department_payload()` (→ `org.php`). Both files are required before
dispatch, so global resolution works. Grouping is deliberate:
`build_department_payload` is an org concern; `users.php` just consumes it.
No shim, no move to `helpers.php`.

Everything else (`dispatch_verification_email`, `build_team_payload`,
`tasks_for_user`, `chat_convo_key`, `chat_resolve_peer`,
`document_payload`, `build_public_user_payload`,
`build_user_profile_payload`, `departments_by_id`, `get_the_company`) is
called only from within its own new module.

Handlers also call `helpers.php` / `crypto.php` / `push.php` functions
(`require_auth`, `json_response`, `db_encrypt`, `notify_user`, …) — those
are required before every new module, unchanged.

## 5. Non-goals (explicit)

- No behaviour change, no bug fixes, no "while I'm here" cleanups.
- No function renamed or resignatured. No parameter changes.
- No route added/removed/reordered. `$routes` is untouched.
- No reformatting of moved code beyond the cut. Comments move with their
  function verbatim.
- No dead-code removal (e.g. `googleOAuthStub`, legacy `leaves`) — that is
  a separate decision, out of scope here.
- No new `require` inside the moved-to files; they rely on `index.php`'s
  order like every existing module.
- `helpers.php` (554 lines) and the other large modules
  (`attendance.php` 1510, `dept_tasks.php` 898, …) are **not** touched in
  this pass — reassess after `index.php` lands.

## 6. Verification bar ("sin romper la app")

Run after **each** file is extracted (not just at the end):

1. `php -l hive-backend/index.php` + `php -l hive-backend/<newfile>.php` →
   "No syntax errors detected".
2. Grep integrity, per moved function `F`:
   - `grep -c "^function F(" hive-backend/index.php` → `0`
   - `grep -c "^function F(" hive-backend/<newfile>.php` → `1`
   And `grep -rn "function <F>" hive-backend/*.php` shows exactly one
   definition across the whole backend.
3. Function count conservation: total `^function ` definitions across
   `index.php` + all 8 new files == **62** (the original count), with
   `index.php` holding exactly **2** (`home`, `sendName`).
4. Smoke curl against live Apache + `hive_db`, one endpoint per extracted
   module (auth: `POST /user/login`; chat: `GET /chat/conversations`;
   devices: `POST /devices/register`; documents: `GET /document/list/{id}`
   or a 401; notifications: `GET /notifications`; users: `GET /user/me`;
   org: `GET /department/list`; legacy_teams: `GET /team/showTeams`) →
   each returns its normal 200/401, never a 500 "undefined function".

Run once at the end:

5. `php -l` on every `hive-backend/*.php`.
6. `OPENSSL_CONF=… php scratchpad/test_push.php` and
   `… scratchpad/test_encrypt_at_rest.php` → `ALL PASS` (they exercise
   `notify_user`, chat inserts, notifications reads).
7. `git diff` review: the only non-move change is the `index.php` require
   block (+8 lines), the `const` relocation, and the deleted "hoisting"
   comment. Every other hunk is a pure deletion in `index.php` mirrored by
   an addition in a new file.

## 7. Task decomposition (for the plan)

One module per task, each with its own §6 steps 1-4 verify + commit:
`auth.php` → `chat.php` → `devices.php` → `documents.php` (incl. the
`const` move + `index.php` comment/require edits for it) →
`notifications.php` → `users.php` → `org.php` → `legacy_teams.php`.
Final task: whole-backend `php -l` + the two integration suites + the
require-block tidy + a full `git diff` move-only audit.

Order rationale: the smallest/most-isolated groups first (`devices`,
`chat`) to shake out the mechanics; `legacy_teams` last (largest, 19
functions).
