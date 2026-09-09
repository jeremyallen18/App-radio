# Auditoría — "Devolver tarea" (flujo dept_tasks)

Fecha: 2026-09-09
Contexto: el spec pidió extraer "Return Task" del fork `App-radio-robert`. El fork
**no** tiene esa función. El proyecto actual **sí** la tiene completa en el flujo
`dept_tasks`. Esta nota verifica ese flujo de punta a punta.

## Qué se revisó

- `hive-backend/dept_tasks.php` — `deptTaskReview()`, `deptTaskSetStatus()`
- `hive-backend/index.php` — ruta `POST /dept-tasks/{id}/review`
- `lib/services/team_service.dart` — `DeptTaskApi.review()`
- `lib/shared/teams/task_board_screen.dart` — `_review()`
- `lib/shared/teams/task_board_card.dart` — `_ReviewActions`, `_RejectNote`, `showReview`
- `lib/shared/teams/task_detail_sheet.dart` — `_ReturnedNote`, hilo de comentarios
- `lib/models/dept_task.dart` — `awaitingReview`, `wasRejected`, `reviewNote`, `reviewedBy`

## Veredicto por punto

### 1. Backend — estados y permisos · OK

`deptTaskReview(PDO, id)`:
- `require_auth` + `dept_task_can_admin($pdo, $user, department_id, sub_team_id)` →
  solo director o manager/sub-líder del departamento. Un tercero recibe **403**.
- Exige `review_status === 'pendiente_revision'`; si no, **409**
  "Esta tarea no está pendiente de revisión."
- `decision` ∈ `approve|reject`; cualquier otro → **400**.
- `reject`: `note` obligatorio (**400** "Indica el motivo del rechazo." si vacío);
  `UPDATE ... status='en_progreso', review_status='rechazada', review_note=?,
  reviewed_by=?, reviewed_at=NOW(), completed_by=NULL, completed_at=NULL`.
  Notifica al asignado: *"Tu tarea "…" fue devuelta: {note}"*. Mensaje
  "Tarea devuelta al empleado."
- `approve`: `review_status='aprobada'`, `reviewed_by/at`, `dept_task_spawn_next()`
  (genera la siguiente ocurrencia si es recurrente), notifica "fue aprobada".

`deptTaskSetStatus(PDO, id)` — reenvío tras devolución · OK:
- El empleado asignado vuelve a mandar `status='completada'`. Como su rol es
  `employee` y no es task-admin, `reviewStatus` se fija en `'pendiente_revision'`
  y el `UPDATE` limpia `review_note/reviewed_by/reviewed_at`. La transición es
  atómica (`WHERE id=? AND status<>'completada'`), evita doble notificación.
- Resultado: devolver → corregir → reenviar → volver a revisar funciona en ciclo
  indefinido. Aprobar cierra (y dispara recurrencia).
- Nota: al mover a `en_progreso` / reabrir, `deptTaskSetStatus` también limpia la
  revisión — coherente.

### 2. Flutter — visibilidad y validación · OK

- `task_board_card.dart`: `final showReview = canManage && task.awaitingReview;`
  Los botones `_ReviewActions` ("Devolver" / "Aprobar") **solo** se muestran a
  quien administra y cuando la tarea está `pendiente_revision`. Un empleado nunca
  los ve.
- `_RejectNote` se muestra si `task.wasRejected && reviewNote` no vacío — visible
  para el empleado en su propia tarjeta.
- `task_board_screen.dart::_review(t, approve:false)`: diálogo "Devolver tarea"
  con `TextField` (hint "Motivo (qué falta o corregir)"). Tras confirmar,
  `note = controller.text.trim()`; si queda vacío → snack
  "Indica el motivo del rechazo." y **no** llama al backend. Coincide con la
  validación del servidor (defensa en dos capas).
- `DeptTaskApi.review(id, approve:, note:)` → `POST /dept-tasks/{id}/review` con
  `decision: reject`, `note` solo si no vacío (tras `trim`). Devuelve la tarea
  actualizada; `_review` hace `await _load()` → el board se refresca al instante.
- `task_detail_sheet.dart`: banner `_ReturnedNote` ("Devuelta por {revisor}" +
  nota) cuando `wasRejected`, y `MessageComposer` + `ChatBubble` para el hilo de
  comentarios bidireccional (`DeptTaskApi.comments` / `addComment`), disponible
  para el revisor y para el empleado asignado (`canComment`).
- `task_detail_sheet.dart::_FactsGrid`: fila "Revisión" con
  `reviewStatusLabel` y color (rojo para "Rechazada", ámbar "Por revisar",
  verde "Aprobada").

### 3. Rutas de fallo · OK

- Sin conexión: `_post`/`_get` lanzan `TeamException` con mensaje en español;
  `_review` lo captura y hace `_snack(e.message)`, resetea `_busy`.
- 403 (no eres revisor) / 409 (ya no está pendiente): `_ensureOk` → `TeamException`
  con el `message` del backend → snack. El board no queda en estado colgado
  (`_busy=false` en el `catch`).
- Doble toque en los botones: `busy` deshabilita `_ReviewActions` mientras
  `_busy == true`.

## Tests

- Suite Flutter (línea base, antes de cualquier cambio): **122 passed**
  (`flutter test`). Incluye `test/task_board_test.dart` →
  "TaskTone prioriza revisión, devolución y vencimiento sobre el estado".
- Backend PHP: no hay suite específica de dept-tasks en `hive-backend/`
  (`tools/php-backend-test*.js` cubren auth/directory/org, no dept-tasks).
  No se ejecutó nada de PHP; la revisión fue por lectura de código.

## Fallos menores encontrados

Ninguno. El flujo está completo y es coherente en backend y frontend. **Task 2
del plan queda N/A.**

## Observaciones (no bloqueantes, fuera de alcance)

- El diálogo "Devolver tarea" crea un `TextEditingController` que no se hace
  `dispose()` (patrón local de un `showDialog`; fuga mínima de un controlador por
  devolución). No se corrige aquí por no estar en alcance y ser de impacto
  despreciable.
- No existe "devolver" para el sistema legacy de tareas de equipo (`/team/*`),
  por decisión explícita del usuario.
