# Área: Permisos jerárquicos + Chat y Recursos por departamento (rama `wen`)

## Parte 1 — Leave requests con jerarquía

### Punto de partida — no romper esto

El módulo ya existe en `hive-backend/index.php`: `POST
/leave/applyLeave/{teamId}`, `POST /leave/leaveResult/{leaveId}`, tabla
`leaves` (ligada a `team_id`, no a `department_id`).

### Tareas

- [ ] Decidir y documentar cómo migra `leaves` de estar ligada a `team_id`
      a también (o en vez de) `department_id`, sin romper las pantallas
      actuales (`lib/leave approval/leave.dart`, `LResign.dart`,
      `MResign.dart` son de otro flujo — no confundir "leader resign" con
      "leave request").
- [ ] Endpoint para que el Manager vea las solicitudes de su departamento.
- [ ] Endpoint/vista para que el Director vea **todas** las solicitudes de
      todos los departamentos (visibilidad final mencionada en
      `Actualizacion.md`, sección "Leave Requests").
- [ ] Mensajes y estados en español ("pendiente", "aprobado", "rechazado").

## Parte 2 — Chat por departamento

### Punto de partida

`chat_messages` ya existe (chat global simple: `username`, `message`).
`GET /chat/getAllChats` y `POST /chat/sendMessage` en `index.php`.

### Tareas

- [ ] Agregar `department_id` a `chat_messages` (migración nueva, sigue el
      patrón de `hive-backend/migrations/001_org_structure.sql`).
- [ ] Scoping: un mensaje sin `department_id` es del chat de empresa; con
      `department_id` es solo para ese departamento. Reusa
      `require_department_manager_or_director()` donde aplique, o crea un
      chequeo equivalente para "pertenece a este departamento" (director,
      o `user.department_id === el del chat`).
- [ ] No rompas el chat global existente: si no mandan `departmentId`, debe
      seguir comportándose como hoy.

## Parte 3 — Recursos por departamento

### Punto de partida

`images` y `texts` ya existen, ligados a `team_id`. `POST /image/addImage`,
`GET /image/showImage/{teamId}`, `POST /text/addText/{teamId}`, `GET
/text/showText/{teamId}`.

### Tareas

- [ ] Igual que el chat: extender (o migrar) el scoping de recursos a
      `department_id`, permitiendo también enlaces externos como tipo de
      recurso (ver `Actualizacion.md`, sección "Resources": Documents,
      Images, PDFs, Videos, External links — hoy solo hay imágenes y texto).
- [ ] Validar permisos: solo miembros del departamento (o el director)
      pueden ver/subir recursos de ese departamento.

## Cómo probar

- `node tools/php-backend-test.js` sigue en 100% (chat/recursos/leave
  actuales no se pueden romper).
- Agrega tus propias verificaciones para lo nuevo, siguiendo el patrón de
  `tools/php-backend-test-org.js`.
- Todo el texto visible en español.
