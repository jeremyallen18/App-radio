-- Migración: evidencia opcional/obligatoria al completar una tarea de
-- departamento (Radio Doliv). Aplicar una sola vez sobre hive_db. Ver
-- hive-backend/schema.sql para el esquema completo ya actualizado.
--
-- `requires_evidence` lo activa el director/manager al crear/editar la tarea.
-- Si está activo, el backend rechaza marcarla como `completada` sin adjuntar
-- un archivo. La evidencia se guarda en hive-backend/private/task_evidence/
-- (fuera del acceso web) y solo se sirve por el endpoint autenticado
-- GET /dept-tasks/{id}/evidence. Mismo patrón que la evidencia de permisos.
USE hive_db;

ALTER TABLE dept_tasks
  ADD COLUMN requires_evidence TINYINT(1) NOT NULL DEFAULT 0 AFTER due_date,
  ADD COLUMN evidence_path VARCHAR(255) NULL AFTER requires_evidence,
  ADD COLUMN evidence_mime VARCHAR(100) NULL AFTER evidence_path;
