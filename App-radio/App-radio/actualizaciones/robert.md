# Área: Extensión de tareas (workflow jerárquico) + Notificaciones nuevas (rama `robert`)

## Parte 1 — Extensión de tareas

### Objetivo

Extender el módulo de tareas ya existente para soportar el flujo
`Director → Departamento → Manager → Employee → completa → Manager valida →
Director ve estadísticas` (ver `Actualizacion.md`, secciones "Tasks" y
"Task Workflow").

### Punto de partida — no romper esto

`hive-backend/index.php` ya tiene `addTask`, `taskDone`,
`incompleteTasks`, `completedTasks`, y `tasks` está indexada por
`team_code` + `domain_name` + `email` (no por id numérico). La app Flutter
(`lib/home_page/tasks.dart`, `lib/screens/addTask.dart`,
`lib/screens/MarkTaskDone.dart`) depende de esa forma exacta de payload —
revísala antes de tocar nada.

### Tareas

- [ ] Migración: agregar a la tabla `tasks` las columnas `created_by`,
      `assigned_by`, `department_id`, `priority`, `progress`, `status`
      (mantén `email`/`assignedTo` como está, es lo que ya consume
      `teamDetail.dart` y `tasks.dart` — agrega, no reemplaces).
- [ ] Endpoint nuevo o extensión de `addTask` para que un Director pueda
      asignar una tarea a un departamento completo (no solo a un email), y
      el Manager la reparta entre sus empleados.
- [ ] Endpoint de validación: el Manager marca una tarea del empleado como
      aprobada (`status = 'approved'`) después de que el empleado la marcó
      como hecha.
- [ ] Endpoint de estadísticas para el Director (tareas por departamento,
      completadas/pendientes) — puede vivir aquí o coordinarlo con Diana si
      ya está construyendo el módulo de reportes.
- [ ] Proteger cada endpoint nuevo con `require_role()` /
      `require_department_manager_or_director()` de `helpers.php`.

## Parte 2 — Notificaciones nuevas

### Punto de partida

El sistema de notificaciones ya existe: tabla `notifications`,
`notify_user()` en `helpers.php`, endpoints `GET /notifications` y
`POST /notifications/{id}/read`. Ya se usa para `member_removed`,
`team_deleted`, `leader_assigned`, `department_manager_assigned`,
`department_assigned`.

### Tareas

- [ ] Emitir notificaciones nuevas con los tipos: `task_assigned`,
      `task_completed`, `task_approved` (desde los endpoints de la Parte 1),
      y coordinar con Jona/Wen para `new_announcement` y
      `resource_uploaded` si esos módulos no las emiten ya.
- [ ] No hace falta tocar el modelo Flutter de notificaciones
      (`lib/screens/notifications.dart`) salvo que los tipos nuevos
      necesiten un ícono/texto distinto — en ese caso, mapea el `type` a un
      texto en español.

## Cómo probar

- `node tools/php-backend-test.js` sigue en 100% (las tareas actuales no se
  pueden romper).
- Agrega tus propias verificaciones para el workflow nuevo, siguiendo el
  patrón de `tools/php-backend-test-org.js`.
