-- Migración: workflow jerárquico de tareas (Director -> Departamento ->
-- Manager -> Empleado -> completa -> Manager valida -> Director ve
-- estadísticas). Ver Actualizacion.md, secciones "Tasks" y "Task Workflow".
--
-- Aplicar una sola vez sobre hive_db, después de 001_org_structure.sql.
-- Ver hive-backend/schema.sql para el esquema completo ya actualizado
-- (instalaciones nuevas parten de ahí).
--
-- IMPORTANTE: no toca team_code / domain_name / email, que es la forma
-- exacta de payload que ya consumen team/task, team/taskDone,
-- team/incompleteTasks, team/completedTasks y la app Flutter
-- (lib/home_page/tasks.dart, lib/screens/addTask.dart,
-- lib/screens/MarkTaskDone.dart, lib/screens/teamDetail.dart). Solo agrega
-- columnas nuevas que ese flujo ignora por completo.
USE hive_db;

ALTER TABLE tasks
  ADD COLUMN created_by CHAR(24) NULL AFTER completed,
  ADD COLUMN assigned_by CHAR(24) NULL AFTER created_by,
  ADD COLUMN department_id CHAR(24) NULL AFTER assigned_by,
  ADD COLUMN priority VARCHAR(20) NOT NULL DEFAULT 'normal' AFTER department_id,
  ADD COLUMN progress TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER priority,
  ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'pending' AFTER progress,
  ADD CONSTRAINT fk_tasks_department FOREIGN KEY (department_id)
    REFERENCES departments(id) ON DELETE SET NULL,
  ADD KEY idx_tasks_department (department_id);
