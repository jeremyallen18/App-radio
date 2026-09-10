-- Migración: lugar de asistencia con geocerca (Radio Doliv).
-- Aplicar una sola vez sobre hive_db.
--
-- El director define UN punto (lat/lng) y un radio. Empleados y managers solo
-- pueden registrar `entrada` y `fin_comida` si su GPS cae dentro de ese radio.
-- El director sigue sin registrar asistencia.
USE hive_db;

CREATE TABLE IF NOT EXISTS attendance_location (
  id TINYINT NOT NULL PRIMARY KEY DEFAULT 1,
  latitude DECIMAL(10,7) NOT NULL,
  longitude DECIMAL(10,7) NOT NULL,
  radius_m INT NOT NULL DEFAULT 10,
  label VARCHAR(255) NULL,
  updated_by CHAR(24) NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;
