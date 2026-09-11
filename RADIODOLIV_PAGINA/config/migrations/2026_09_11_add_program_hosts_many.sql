-- Migración: varios locutores por programa (hive_db compartida).
-- Ver App-radio/hive-backend/migrations/035_radio_program_hosts_many.sql para
-- el mismo cambio documentado del lado de la app. Solo hace falta aplicarla
-- una vez sobre la base compartida; se documenta aquí también porque
-- RADIODOLIV_PAGINA lee `radio_program_hosts` para mostrar la foto y el link
-- de cada locutor vinculado a un programa (puede ser más de uno).
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

INSERT INTO radio_program_hosts (program_id, team_id, sort_order)
SELECT id, host_team_id, 0 FROM radio_programs WHERE host_team_id IS NOT NULL;

ALTER TABLE radio_programs
  DROP FOREIGN KEY radio_programs_host_team_fk,
  DROP KEY host_team_id,
  DROP COLUMN host_team_id;
