-- Migración: hilo de comentarios por tarea de departamento (Radio Doliv).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado.
--
-- Cualquier persona que pueda VER la tarea (director, manager o empleado del
-- departamento) puede leer el hilo; escriben el director, el manager del
-- departamento y el empleado asignado. Al comentar se notifica a la otra
-- parte vía la tabla `notifications` (ver dept_tasks.php -> deptTaskCommentCreate).
USE hive_db;

CREATE TABLE IF NOT EXISTS dept_task_comments (
  id CHAR(24) PRIMARY KEY,
  task_id CHAR(24) NOT NULL,
  author_id CHAR(24) NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_dtc_task (task_id, created_at),
  FOREIGN KEY (task_id) REFERENCES dept_tasks(id) ON DELETE CASCADE,
  FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
