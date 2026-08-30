-- Migración: tareas recurrentes de departamento (Radio Doliv), útil para la
-- parrilla diaria de la radio. Aplicar una sola vez sobre hive_db. Ver
-- hive-backend/schema.sql para el esquema completo ya actualizado.
--
-- No hay cron: cuando una tarea recurrente queda cerrada (completada por un
-- manager/director, o aprobada en revisión), el backend crea de una vez la
-- siguiente ocurrencia con su nueva fecha límite, mientras esté dentro de
-- `recurrence_until` (ver dept_tasks.php -> dept_task_spawn_next()).
-- Solo aplica a tareas de nivel superior (no subtareas).
USE hive_db;

ALTER TABLE dept_tasks
  ADD COLUMN recurrence ENUM('none','daily','weekdays','weekly','monthly')
    NOT NULL DEFAULT 'none' AFTER evidence_mime,
  ADD COLUMN recurrence_until DATE NULL AFTER recurrence;
