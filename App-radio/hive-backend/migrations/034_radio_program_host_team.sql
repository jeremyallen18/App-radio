-- Migración: vínculo real programa <-> locutor (hive_db compartida).
-- Aplicar una sola vez. Ver hive-backend/schema.sql para el esquema completo
-- ya actualizado (instalaciones nuevas parten de ahí).
--
-- Antes, `radio_programs.host` era solo texto libre: no había forma de saber
-- si "Jeremy" en un programa era el mismo "Jeremy" del equipo. Con
-- `host_team_id` el director vincula el programa a un integrante real de
-- `radio_team` (o viceversa, desde la ficha del integrante) y el nombre
-- mostrado (`host`) se mantiene sincronizado con `radio_team.name`.
USE hive_db;

ALTER TABLE radio_programs
  ADD COLUMN host_team_id INT NULL AFTER host,
  ADD KEY host_team_id (host_team_id),
  ADD CONSTRAINT radio_programs_host_team_fk
    FOREIGN KEY (host_team_id) REFERENCES radio_team (id) ON DELETE SET NULL;
