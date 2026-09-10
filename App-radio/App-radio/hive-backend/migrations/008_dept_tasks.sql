-- Migración: flujo jerárquico de tareas por departamento/equipo (Radio Doliv).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado.
--
-- Jerarquía de permisos:
--   Director  -> crea/edita/borra tareas de cualquier departamento.
--   Manager   -> crea/edita/borra tareas y SUBTAREAS de su departamento.
--   Empleado  -> solo cambia el estado de las tareas de su departamento
--                (marcarlas como completada / reabrirlas).
--
-- Es una tabla nueva y paralela a `tasks` (el sistema viejo por team_code):
-- no se toca nada de aquello.
USE hive_db;

CREATE TABLE IF NOT EXISTS dept_tasks (
  id CHAR(24) PRIMARY KEY,
  parent_id CHAR(24) NULL,               -- subtarea de otra dept_task
  department_id CHAR(24) NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT NULL,
  assigned_to CHAR(24) NULL,             -- empleado concreto (opcional)
  created_by CHAR(24) NOT NULL,
  created_by_role VARCHAR(20) NOT NULL,  -- 'director' | 'manager'
  due_date DATE NULL,
  status ENUM('pendiente','en_progreso','completada') NOT NULL DEFAULT 'pendiente',
  completed_by CHAR(24) NULL,
  completed_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_dt_department (department_id, status),
  KEY idx_dt_parent (parent_id),
  KEY idx_dt_assigned (assigned_to),
  FOREIGN KEY (parent_id) REFERENCES dept_tasks(id) ON DELETE CASCADE,
  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE,
  FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (completed_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;
