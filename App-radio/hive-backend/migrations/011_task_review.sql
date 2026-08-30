-- Migración: revisión del manager sobre tareas completadas por un empleado
-- (Radio Doliv). Aplicar una sola vez sobre hive_db. Ver
-- hive-backend/schema.sql para el esquema completo ya actualizado.
--
-- Cuando un EMPLEADO marca una tarea como `completada`, no se da por cerrada:
-- pasa a `review_status = 'pendiente_revision'`. El director o el manager del
-- departamento la aprueba (queda completada, `aprobada`) o la rechaza
-- (vuelve a `en_progreso`, `rechazada`, con nota). Si un manager/director la
-- completa directamente, no requiere revisión (`sin_revision`).
USE hive_db;

ALTER TABLE dept_tasks
  ADD COLUMN review_status ENUM('sin_revision','pendiente_revision','aprobada','rechazada')
    NOT NULL DEFAULT 'sin_revision' AFTER completed_at,
  ADD COLUMN review_note VARCHAR(1000) NULL AFTER review_status,
  ADD COLUMN reviewed_by CHAR(24) NULL AFTER review_note,
  ADD COLUMN reviewed_at DATETIME NULL AFTER reviewed_by,
  ADD FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL;
