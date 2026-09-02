# Múltiples admins por equipo — cambios de Flutter + lo que falta en el backend

## Qué se cambió en la app (Flutter)

El concepto de "líder único" (`teams.leader_email`, una sola columna) se
reemplazó en el frontend por una lista de **admins**. Cualquier admin puede
hacer todo lo que antes solo podía el líder: agregar/sacar miembros,
gestionar tareas, eliminar el equipo, y ahora además **agregar o quitar
otros admins**. La única regla que se conserva es que un equipo nunca puede
quedarse sin ningún admin.

Archivos tocados: `teamDetail.dart`, `manageMembers.dart`, `MResign.dart`,
`notifications.dart`, `notification_tile.dart`.

La app sigue funcionando con el backend actual (de un solo líder) porque,
si no recibe el campo `admins`, lo simula como una lista de un solo
elemento a partir de `leaderEmail`. Pero **para que "varios admins" sea real
(y no solo visual), el backend tiene que implementar lo siguiente**:

## 1. Modelo de datos

Agregar a cada equipo una lista de admins (por ejemplo `admins: string[]`
en vez de, o además de, `leader_email`). Puede migrarse fácil: al arrancar,
`admins = [leader_email]` para los equipos existentes.

## 2. `GET /team/showTeams`

Cada equipo en la respuesta debe incluir:

```json
{
  "_id": "...",
  "teamName": "...",
  "teamMembers": ["a@x.com", "b@x.com", "c@x.com"],
  "admins": ["a@x.com", "b@x.com"],
  "leaderEmail": "a@x.com"   // opcional, se puede dejar como admins[0] por compatibilidad
}
```

## 3. Nuevos endpoints

### `POST /team/addAdmin/{teamId}`
Body: `{"memberEmail": "correo@x.com"}`

- Requiere que quien llama sea admin del equipo (403 si no).
- El correo debe ya ser miembro del equipo (400 si no pertenece).
- Agrega el correo a `admins` (si ya era admin, responder 200 igual, sin duplicar).
- Notificar al nuevo admin (tipo `admin_added`, ya soportado en la app).

### `POST /team/removeAdmin/{teamId}`
Body: `{"memberEmail": "correo@x.com"}`

- Requiere que quien llama sea admin del equipo (403 si no).
- **Rechazar con 400 si esa persona es el único admin** del equipo (regla
  que evita equipos sin ningún admin). La app muestra este 400 con el
  mensaje "El equipo debe tener al menos un admin...".
- Si no es el único, lo saca de `admins` (sigue siendo miembro normal).
- Notificar (tipo `admin_removed`).

## 4. Endpoints existentes: cambiar el chequeo de permisos

Todo lo que hoy valida "¿es el líder?" (`email == leader_email`) debe pasar
a validar "¿está en `admins`?":

- `POST /team/addMember/{teamId}`
- `POST /team/deleteMember/{teamId}` — además, debe rechazar (400/409) si
  el `memberEmail` es actualmente admin; primero hay que quitarle el rol
  con `removeAdmin`.
- `POST /team/deleteTeam/{teamId}`
- `POST /team/taskUpdate/{taskId}` y cualquier otra acción que hoy sea
  "solo el líder"

## 5. `POST /team/resign/{teamId}`

- Si quien renuncia es admin y **es el único admin**, seguir devolviendo
  400 (la app ya muestra el mensaje adecuado).
- Si es admin pero no el único, permitir la renuncia y quitarlo también de
  `admins` de paso (para no dejar un admin "fantasma" que ya no es miembro).

## 6. Notificaciones

Se agregaron dos tipos nuevos, ya soportados en la app (ícono y navegación
al equipo): `admin_added` y `admin_removed`. El tipo viejo `leader_assigned`
se sigue soportando por compatibilidad, pero ya no lo dispara ningún flujo
nuevo del frontend.

## Ya se puede desactivar

El viejo `POST /team/leaderResign/{teamId}` (transferencia de un único
líder) ya no lo usa la app; se puede dejar o retirar del backend según
convenga.
