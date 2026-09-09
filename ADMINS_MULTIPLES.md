# Múltiples admins por equipo

Un equipo puede tener más de un admin. Cualquier admin puede hacer todo lo
que antes solo podía el líder único: agregar/sacar miembros, gestionar
tareas, eliminar el equipo, y **agregar o quitar a otros admins** (incluso
quitarse el rol a sí mismo). La única regla que se conserva es que un
equipo nunca puede quedarse sin ningún admin.

Estado: **implementado de punta a punta** (Flutter + backend PHP).

## Frontend (Flutter)

El concepto de "líder único" (`teams.leader_email`, una sola columna) se
reemplazó en el frontend por una lista de **admins**. Archivos tocados:
`teamDetail.dart`, `manageMembers.dart`, `MResign.dart`, `notifications.dart`,
`notification_tile.dart`.

Compatibilidad: si el backend no manda el campo `admins` (versión vieja),
la app lo simula como una lista de un solo elemento a partir de
`leaderEmail`.

## Backend (PHP, `hive-backend/`)

### 1. Modelo de datos

Nueva tabla `team_admins` (`team_id`, `email`), varios admins por equipo.
`teams.leader_email` se conserva solo como respaldo de compatibilidad
(`team_admin_emails()` cae de vuelta a esa columna si por algún motivo un
equipo no tiene todavía ninguna fila en `team_admins`) y como campo que
sigue actualizando el endpoint legado `leaderResign`.

- `schema.sql`: instalaciones nuevas ya traen `team_admins` desde el
  inicio.
- `migrations/011_team_multiple_admins.sql`: para bases de datos
  existentes. Crea la tabla y hace backfill (`admins = [leader_email]`)
  para los equipos ya creados.

### 2. `GET /team/showTeams`

Cada equipo en la respuesta incluye:

```json
{
  "_id": "...",
  "teamName": "...",
  "teamMembers": ["a@x.com", "b@x.com", "c@x.com"],
  "admins": ["a@x.com", "b@x.com"],
  "leaderEmail": "a@x.com"   // = admins[0], se conserva por compatibilidad
}
```

### 3. Endpoints nuevos

#### `POST /team/addAdmin/{teamId}`
Body: `{"memberEmail": "correo@x.com"}`

- Requiere que quien llama sea admin del equipo (403 si no).
- El correo debe ya ser miembro del equipo (400 si no pertenece).
- Agrega el correo a `team_admins` (si ya era admin, responde 200 igual,
  sin duplicar).
- Notifica al nuevo admin (`admin_added`).

#### `POST /team/removeAdmin/{teamId}`
Body: `{"memberEmail": "correo@x.com"}`

- Requiere que quien llama sea admin del equipo (403 si no).
- 400 si esa persona no es admin.
- **400 si esa persona es el único admin** del equipo (regla que evita
  equipos sin ningún admin). La app muestra este 400 con el mensaje "El
  equipo debe tener al menos un admin...".
- Si no es el único, lo saca de `team_admins` (sigue siendo miembro
  normal). Notifica (`admin_removed`).

### 4. Endpoints existentes: chequeo de permisos actualizado

Todo lo que antes validaba "¿es el líder?" (`email == leader_email`) ahora
valida "¿está en `team_admins`?" vía `require_team_admin()`:

- `POST /team/addMember/{teamId}`
- `POST /team/deleteMember/{teamId}` — además, rechaza (400) si el
  `memberEmail` es actualmente admin; primero hay que quitarle el rol con
  `removeAdmin`.
- `POST /team/deleteTeam/{teamId}`
- `POST /team/task/{teamcode}` (crear tarea) y `POST /team/taskUpdate/{taskId}`

### 5. `POST /team/resign/{teamId}`

- Si quien renuncia es admin y **es el único admin**, sigue devolviendo
  400.
- Si es admin pero no el único, se permite la renuncia y se le quita
  también de `team_admins` de paso (para no dejar un admin "fantasma" que
  ya no es miembro).

### 6. Notificaciones

Tipos `admin_added` y `admin_removed`, ya soportados en la app (ícono y
navegación al equipo). El tipo viejo `leader_assigned` se sigue emitiendo
solo desde el endpoint legado `leaderResign`.

### 7. Endpoint legado: `POST /team/leaderResign/{teamId}`

La app ya no lo usa (reemplazado por `addAdmin`/`removeAdmin`), pero se
conserva por compatibilidad. A diferencia de `addAdmin` (que suma un admin
sin quitarle el rol a nadie), este endpoint sigue haciendo una
**transferencia total**: reemplaza por completo la lista de `team_admins`
por la nueva persona.

## Pruebas

`tools/php-backend-test.js` tiene una sección `-- ADMINS MULTIPLES --` que
cubre: ascender/quitar admins, idempotencia, permisos (403 para
extraños/no-admins), la regla de "nunca sin ningún admin" (400), y que no
se puede sacar del grupo a alguien que sigue siendo admin (400).
