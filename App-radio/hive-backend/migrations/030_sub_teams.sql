-- Migración: sub-equipos dentro de un departamento (Radio Doliv).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado.
--
-- Contexto: el manager de un área (departamento) puede subdividirla en
-- sub-equipos (p. ej. Sistemas -> Frontend, Backend). Un solo nivel. Un
-- empleado del área puede estar en varios sub-equipos. Cada sub-equipo puede
-- tener un sub-líder (un empleado del mismo departamento) que administra sus
-- miembros y crea/asigna las tareas de ese sub-equipo.
--
--   sub_teams          -> un sub-equipo, colgado de un departamento.
--   sub_team_members   -> muchos-a-muchos empleado <-> sub-equipo.
--   dept_tasks.sub_team_id -> tarea opcionalmente atada a un sub-equipo;
--                             al borrar el sub-equipo la tarea queda "de área".

USE hive_db;

CREATE TABLE IF NOT EXISTS sub_teams (
  id            CHAR(24)     NOT NULL PRIMARY KEY,
  department_id CHAR(24)     NOT NULL,
  name          VARCHAR(255) NOT NULL,
  description   TEXT         NULL,
  lead_user_id  CHAR(24)     NULL,
  created_at    TIMESTAMP    NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_subteam_department FOREIGN KEY (department_id)
    REFERENCES departments(id) ON DELETE CASCADE,
  CONSTRAINT fk_subteam_lead FOREIGN KEY (lead_user_id)
    REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE KEY uq_subteam_dept_name (department_id, name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sub_team_members (
  sub_team_id CHAR(24) NOT NULL,
  user_id     CHAR(24) NOT NULL,
  PRIMARY KEY (sub_team_id, user_id),
  CONSTRAINT fk_stm_subteam FOREIGN KEY (sub_team_id)
    REFERENCES sub_teams(id) ON DELETE CASCADE,
  CONSTRAINT fk_stm_user FOREIGN KEY (user_id)
    REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE dept_tasks
  ADD COLUMN sub_team_id CHAR(24) NULL AFTER department_id,
  ADD CONSTRAINT fk_depttask_subteam FOREIGN KEY (sub_team_id)
    REFERENCES sub_teams(id) ON DELETE SET NULL;
