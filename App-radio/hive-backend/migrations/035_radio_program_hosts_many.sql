-- Migración: varios locutores por programa (hive_db compartida).
-- Aplicar una sola vez. Ver hive-backend/schema.sql para el esquema completo
-- ya actualizado (instalaciones nuevas parten de ahí).
--
-- Reemplaza `radio_programs.host_team_id` (un solo locutor vinculado, ver
-- migración 034) por la tabla `radio_program_hosts`, que permite vincular
-- cualquier cantidad de integrantes del equipo a un mismo programa (locutor
-- principal + co-conductores). El texto libre `host` sigue existiendo y se
-- sigue autogenerando, ahora uniendo los nombres de todos los vinculados.
USE hive_db;

CREATE TABLE IF NOT EXISTS radio_program_hosts (
  id INT NOT NULL AUTO_INCREMENT,
  program_id INT NOT NULL,
  team_id INT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY program_team (program_id, team_id),
  KEY team_id (team_id),
  CONSTRAINT radio_program_hosts_program_fk FOREIGN KEY (program_id) REFERENCES radio_programs (id) ON DELETE CASCADE,
  CONSTRAINT radio_program_hosts_team_fk FOREIGN KEY (team_id) REFERENCES radio_team (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Migra los vínculos existentes (un solo locutor por programa) a la nueva tabla.
INSERT INTO radio_program_hosts (program_id, team_id, sort_order)
SELECT id, host_team_id, 0 FROM radio_programs WHERE host_team_id IS NOT NULL;

ALTER TABLE radio_programs
  DROP FOREIGN KEY radio_programs_host_team_fk,
  DROP KEY host_team_id,
  DROP COLUMN host_team_id;
