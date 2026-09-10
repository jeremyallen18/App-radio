# Sub-equipos dentro de un departamento — diseño

Fecha: 2026-09-08
Estado: aprobado para implementación (modo autónomo; decisiones tomadas en la
sesión de brainstorming del 2026-09-08).

## Problema

Hoy la estructura organizacional es `companies (1) → departments (áreas) →
users`. El director crea las áreas y asigna un manager a cada una. El manager
no puede subdividir su área.

Se quiere que **el manager de un área pueda crear sub-equipos dentro de ella**
(ej.: el director crea "Sistemas"; el manager de Sistemas crea "Frontend",
"Backend", "QA"…).

## Decisiones (sesión de brainstorming)

| Tema | Decisión |
|------|----------|
| Profundidad | **Un solo nivel.** Departamento → sub-equipo. Un sub-equipo no contiene sub-sub-equipos. |
| Membresía | Un empleado del área puede estar en **varios** sub-equipos a la vez (muchos-a-muchos). Solo agrupa gente que **ya** pertenece al departamento. |
| Sub-líder | Cada sub-equipo puede tener **un** responsable opcional: un empleado del mismo departamento. |
| Permisos del sub-líder | Puede **crear/asignar tareas de su sub-equipo** y **gestionar los miembros de su sub-equipo** (agregar/quitar gente que ya está en el departamento). No da de alta usuarios nuevos, no toca el resto del área. |
| Tareas | **Un solo tablero** por departamento, con **filtro por sub-equipo**. Cada tarea puede llevar (opcionalmente) un `sub_team_id`. El sub-líder entra al mismo tablero, ya filtrado a su sub-equipo. |
| Asistencia | Fuera de alcance. Los sub-equipos no afectan asistencia ni reportes. |
| Quién crea/borra sub-equipos | El **director** o el **manager de ese departamento**. El sub-líder NO crea ni borra sub-equipos, solo administra los miembros del suyo. |

## Enfoque de datos: tablas nuevas (enfoque A)

Descartados: `departments.parent_id` (rompe `users.department_id` de valor único,
scope de directorio, asistencia por área, y obliga a un tablero por sub-área);
reutilizar `teams`/`domains` legacy (semántica de "unirse por código", concepto
distinto).

### Migración `030_sub_teams.sql`

```sql
CREATE TABLE sub_teams (
  id            CHAR(24)     NOT NULL PRIMARY KEY,
  department_id CHAR(24)     NOT NULL,
  name          VARCHAR(255) NOT NULL,
  description   TEXT         NULL,
  lead_user_id  CHAR(24)     NULL,
  created_at    TIMESTAMP    NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_subteam_department FOREIGN KEY (department_id)
    REFERENCES departments(id) ON DELETE CASCADE,
  CONSTRAINT fk_subteam_lead FOREIGN KEY (lead_user_id)
    REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE KEY uq_subteam_dept_name (department_id, name)
);

CREATE TABLE sub_team_members (
  sub_team_id CHAR(24) NOT NULL,
  user_id     CHAR(24) NOT NULL,
  PRIMARY KEY (sub_team_id, user_id),
  CONSTRAINT fk_stm_subteam FOREIGN KEY (sub_team_id)
    REFERENCES sub_teams(id) ON DELETE CASCADE,
  CONSTRAINT fk_stm_user FOREIGN KEY (user_id)
    REFERENCES users(id) ON DELETE CASCADE
);

ALTER TABLE dept_tasks
  ADD COLUMN sub_team_id CHAR(24) NULL AFTER department_id,
  ADD CONSTRAINT fk_depttask_subteam FOREIGN KEY (sub_team_id)
    REFERENCES sub_teams(id) ON DELETE SET NULL;
```

Borrar un sub-equipo NO borra tareas: `dept_tasks.sub_team_id` vuelve a NULL
(la tarea pasa a ser "de área").

## Backend

### `hive-backend/sub_teams.php` (nuevo)

Helpers:
- `sub_team_row($pdo,$id): ?array`
- `sub_team_payload($pdo,$row): array` → `{id, departmentId, name, description,
  lead: miniUser|null, memberCount, members: miniUser[]}`
- `sub_team_lead_ids($pdo,$userId): string[]` — ids de sub-equipos que lidera.
- `sub_team_require_admin($pdo,$user,$deptId)` — director | manager del área
  (reusa `require_department_manager_or_director`).
- `sub_team_require_member_admin($pdo,$user,$subTeam)` — lo anterior **o** el
  `lead_user_id` del sub-equipo.
- `sub_team_assert_department_member($pdo,$userId,$deptId)` — 400 si el usuario
  no es empleado verificado de ese departamento.

Endpoints (`index.php`):

| Método | Ruta | Quién | Acción |
|--------|------|-------|--------|
| POST | `/subteam/create` | director / manager del área | body `departmentId, name, description?` |
| GET  | `/subteam/list?departmentId=X` | quien pueda ver el área (`dept_task_require_view`) | lista con miembros |
| POST | `/subteam/{id}` | director / manager del área | editar `name`, `description` |
| POST | `/subteam/{id}/delete` | director / manager del área | borra (tareas quedan sin sub-equipo) |
| POST | `/subteam/{id}/setLead` | director / manager del área | body `userId` (vacío = quitar líder); debe ser empleado del área |
| POST | `/subteam/{id}/addMember` | director / manager / **sub-líder** | body `userId`; debe ser empleado del área |
| POST | `/subteam/{id}/removeMember` | director / manager / **sub-líder** | body `userId` |

### `hive-backend/dept_tasks.php` (cambios)

1. **Choke-point de permiso** — nueva función:
   ```php
   function dept_task_can_admin(PDO $pdo, array $user, string $deptId, ?string $subTeamId): bool {
       if ($user['role'] === 'director') return true;
       if ($user['role'] === 'manager' && ($user['department_id'] ?? null) === $deptId) return true;
       if ($subTeamId !== null && in_array($subTeamId, sub_team_lead_ids($pdo, $user['id']), true)) return true;
       return false;
   }
   ```
2. `deptTaskCreate`: se quita `require_role(['director','manager'])`. Se resuelve
   `departmentId` (para un empleado sub-líder = su propio `department_id`), se lee
   `subTeamId` del body. Si el actor NO es director ni manager del área, `subTeamId`
   es **obligatorio** y debe liderarlo. Se valida con `dept_task_can_admin`. El
   caso especial "director + tarea principal → se asigna al manager" solo aplica
   cuando `subTeamId` es NULL.
3. `deptTaskUpdate` / `deptTaskDelete` / `deptTaskReview`: tras cargar `$row`,
   permiso vía `dept_task_can_admin($pdo,$user,$row['department_id'],$row['sub_team_id'])`.
   El sub-líder puede revisar (aprobar/devolver) tareas de su sub-equipo.
4. `dept_task_require_assignable($pdo,$userId,$deptId,$subTeamId=null)`: si
   `$subTeamId` no es NULL, el asignado además debe estar en `sub_team_members`
   de ese sub-equipo.
5. `deptTasksList`: acepta `?subTeamId=`; filtra `sub_team_id = ?`. Valor
   especial `?subTeamId=none` → `sub_team_id IS NULL` (tareas de área).
6. `dept_task_payload`: agrega `subTeam: {id, name} | null`.
7. INSERT/UPDATE de `dept_tasks` incluye `sub_team_id`. En update solo cambia si
   viene `subTeamId` en el body y el actor es director/manager (el sub-líder no
   puede sacar una tarea de su sub-equipo).

### `removeDepartmentEmployee` y reasignación (`assignDepartmentEmployee`)

Cuando un empleado sale de un departamento (o se mueve a otro):
```sql
DELETE stm FROM sub_team_members stm
  JOIN sub_teams st ON st.id = stm.sub_team_id
 WHERE stm.user_id = ? AND st.department_id = ?;
UPDATE sub_teams SET lead_user_id = NULL
 WHERE lead_user_id = ? AND department_id = ?;
```

## Flutter

### Modelos
- `lib/models/sub_team.dart`: `SubTeam { id, departmentId, name, description?,
  lead: TaskUserRef?, memberCount, members: List<TaskUserRef> }`.
- `lib/models/dept_task.dart`: campo `subTeam` (`({String id, String name})?`),
  parseado de `json['subTeam']`.

### Servicio
- `lib/services/sub_team_service.dart`: `SubTeamApi` con `list(departmentId)`,
  `create`, `update`, `delete`, `setLead`, `addMember`, `removeMember`. Mismo
  patrón de token/errores que `team_service.dart` (`TeamException`).
- `DeptTaskApi.list` gana parámetro opcional `subTeamId` (`'none'` para las de
  área).

### Pantallas
- `lib/features/dashboard/manager/sub_team_admin_screen.dart` —
  `SubTeamAdminScreen({ required departmentId, required departmentName,
  bool leadScope = false })`:
  - Manager/director (`leadScope=false`): lista de sub-equipos, FAB "Crear
    sub-equipo", cada tarjeta abre detalle → editar/borrar, fijar líder,
    agregar/quitar miembros (selector = empleados del área vía
    `TeamApi.members`).
  - Sub-líder (`leadScope=true`): solo ve los sub-equipos que lidera; sin crear
    ni borrar; puede agregar/quitar miembros del suyo. Sin "fijar líder".
- Entradas de menú (`app_menu_sections.dart`):
  - `_managerSections` → sección "Mi departamento" → "Sub-equipos"
    (`SubTeamAdminScreen(leadScope:false)`), habilitado si hay `department`.
  - `_employeeSections` → si `profile` lidera ≥1 sub-equipo (nuevo campo del
    perfil, ver abajo) → "Mis sub-equipos" (`SubTeamAdminScreen(leadScope:true)`).

### Tablero de tareas (`task_board_screen.dart` / `task_form_screen.dart`)
- `TaskBoardBody`: carga los sub-equipos del área (`SubTeamApi.list`). Si hay
  ≥1, muestra una fila de chips de filtro ("Todos", "De área", <cada
  sub-equipo>). El filtro se aplica pidiendo `DeptTaskApi.list(subTeamId:)` y
  recargando (no es filtro cliente porque el sub-líder no debe recibir tareas
  de otros sub-equipos).
- `TaskBoardScreen` acepta `subTeamId`/`subTeamName` opcionales + `leadScope`
  para la entrada del sub-líder: filtro fijo a su sub-equipo, `canManage=true`
  acotado.
- `TaskFormScreen`: selector opcional "Sub-equipo" (dropdown con los
  sub-equipos del área) para manager/director; para el sub-líder va fijo a su
  sub-equipo y no editable. Al elegir sub-equipo, el selector de responsable se
  restringe a los miembros de ese sub-equipo.

### Perfil (`/user/me`, `UserProfile`)
- El backend agrega `ledSubTeams: [{id,name,departmentId}]` al payload de
  `/user/me` (para pintar la entrada de menú del sub-líder sin una llamada
  extra). `UserProfile.ledSubTeams`.

## Errores y validación
- Nombre de sub-equipo único por departamento (`uq_subteam_dept_name`) → 409
  "Ya existe un sub-equipo con ese nombre en esta área".
- `setLead`/`addMember` con un userId que no es empleado verificado del área →
  400.
- Sub-líder intentando crear tarea sin `subTeamId`, o con uno que no lidera →
  403.
- Borrar un empleado del área lo saca de sus sub-equipos y libera el liderazgo.

## Pruebas
- Modelo: `SubTeam.fromJson`, `DeptTask.subTeam`.
- Backend (curl en vivo, matriz de permisos):
  - manager crea sub-equipo en su área ✓; en otra área → 403.
  - sub-líder agrega/quita miembro del suyo ✓; de otro sub-equipo → 403.
  - sub-líder crea tarea con su `subTeamId` ✓; sin subTeamId → 403; con otro
    subTeamId → 403.
  - sub-líder asigna a un miembro del sub-equipo ✓; a alguien del área que no
    está en el sub-equipo → 400.
  - empleado normal (no líder) crea tarea → 403 (sin cambios).
  - borrar sub-equipo → sus tareas quedan `sub_team_id` NULL, no se borran.
  - quitar empleado del área → desaparece de `sub_team_members`, `lead_user_id`
    a NULL.
- `flutter analyze` limpio, `flutter test` verde.

## Fuera de alcance (posible iteración futura)
- Sub-equipos en asistencia / reportes.
- Mostrar el sub-equipo de cada persona en el directorio.
- Anidamiento de más de un nivel.
- Notificación específica "te agregaron a un sub-equipo" (por ahora se reutiliza
  la notificación de asignación de tarea existente).
