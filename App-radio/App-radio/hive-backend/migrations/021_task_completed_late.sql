-- Migración: marca de entrega con retardo en tareas de departamento (Radio Doliv).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado.
--
-- Contexto: una tarea entregada después de su fecha límite debe quedar
-- marcada como "retardo". Se modela como una BANDERA derivada (no un nuevo
-- valor del enum `status`, que rompería todas las transiciones y filtros):
-- la tarea sigue con status 'completada' y `completed_late = 1` cuando se
-- cerró pasado el `due_date`. La app muestra una insignia "Retardo".
--
-- El valor lo calcula SIEMPRE el servidor al pasar a 'completada'
-- (dept_tasks.php); nunca se confía en un valor enviado por el cliente.

USE hive_db;

ALTER TABLE dept_tasks
  ADD COLUMN completed_late TINYINT(1) NOT NULL DEFAULT 0 AFTER completed_at;

-- Reponer la marca en las tareas ya completadas fuera de plazo (histórico):
-- `due_date` es una fecha (DATE), así que el plazo vence al final de ese día.
UPDATE dept_tasks
   SET completed_late = 1
 WHERE status = 'completada'
   AND due_date IS NOT NULL
   AND completed_at IS NOT NULL
   AND completed_at > CONCAT(due_date, ' 23:59:59');
