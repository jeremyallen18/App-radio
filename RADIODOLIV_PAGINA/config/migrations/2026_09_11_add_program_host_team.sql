-- Migración: vínculo real programa <-> locutor (hive_db compartida).
-- Ver App-radio/hive-backend/migrations/034_radio_program_host_team.sql para
-- el mismo cambio documentado del lado de la app. Solo hace falta aplicarla
-- una vez sobre la base compartida; se documenta aquí también porque
-- RADIODOLIV_PAGINA lee `radio_programs.host_team_id` para mostrar el nombre
-- real del locutor vinculado.
ALTER TABLE radio_programs
  ADD COLUMN host_team_id INT NULL AFTER host,
  ADD KEY host_team_id (host_team_id),
  ADD CONSTRAINT radio_programs_host_team_fk
    FOREIGN KEY (host_team_id) REFERENCES radio_team (id) ON DELETE SET NULL;
