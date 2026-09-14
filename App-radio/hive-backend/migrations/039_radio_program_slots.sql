-- Migración: varias franjas horarias por programa (hive_db compartida).
-- Aplicar una sola vez. Ver hive-backend/schema.sql para el esquema completo
-- ya actualizado (instalaciones nuevas parten de ahí).
--
-- Antes un programa tenía UN solo horario (radio_programs.weekdays +
-- slot_start/slot_end) aplicado a TODOS sus días -- no había forma de
-- representar, por ejemplo, "miércoles 9-13, viernes 11-13" (mismo
-- programa, horas distintas según el día). radio_program_slots permite
-- cualquier cantidad de franjas (día ISO + hora de inicio/fin) por
-- programa. Las columnas viejas se conservan como agregado (unión de
-- días / hora mínima de inicio / hora máxima de fin) para no romper nada
-- que aún no haya migrado a leer la tabla nueva.
USE hive_db;

CREATE TABLE IF NOT EXISTS radio_program_slots (
  id INT NOT NULL AUTO_INCREMENT,
  program_id INT NOT NULL,
  weekday TINYINT NOT NULL COMMENT '1=lunes..7=domingo',
  start_hour TINYINT NOT NULL COMMENT '0-23',
  end_hour TINYINT NOT NULL COMMENT '0-23; <= start_hour = cruza medianoche',
  sort_order INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY program_id (program_id),
  CONSTRAINT radio_program_slots_program_fk FOREIGN KEY (program_id) REFERENCES radio_programs (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Migra los horarios existentes: un programa con weekdays="3,5" y el mismo
-- slot_start/slot_end de hoy se vuelve UNA fila por día en la tabla nueva
-- (misma hora en ambos, que es exactamente lo que significaba antes).
-- Programas sin weekdays (todos los días) generan las 7 filas.
INSERT INTO radio_program_slots (program_id, weekday, start_hour, end_hour, sort_order)
SELECT p.id, d.weekday, p.slot_start, p.slot_end, d.weekday
FROM radio_programs p
JOIN (
  SELECT 1 AS weekday UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
  UNION SELECT 5 UNION SELECT 6 UNION SELECT 7
) d ON (
  p.weekdays IS NULL OR p.weekdays = ''
  OR FIND_IN_SET(d.weekday, p.weekdays) > 0
)
WHERE p.slot_start IS NOT NULL AND p.slot_end IS NOT NULL;
