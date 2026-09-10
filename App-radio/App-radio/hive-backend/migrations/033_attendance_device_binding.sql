-- Migración: vinculación de dispositivo + evidencia biométrica en el fichaje.
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado (instalaciones nuevas parten de ahí).
--
-- Cada cuenta que ficha (employee / manager) queda atada a UN dispositivo
-- confiado. El primero se registra por "trust-on-first-use"; cualquier cambio
-- lo aprueba el director. En la base solo se guardan HASHES (sha256) de los
-- identificadores del dispositivo, nunca el valor crudo.
USE hive_db;

CREATE TABLE IF NOT EXISTS attendance_trusted_devices (
  employee_id  CHAR(24) NOT NULL PRIMARY KEY,
  device_key   VARCHAR(64) NOT NULL,        -- sha256(ANDROID_ID | IDFV) o, si faltó, sha256(uuid)
  device_uuid  VARCHAR(64) NULL,            -- sha256(uuid de secure storage)
  platform     ENUM('android','ios') NOT NULL,
  model        VARCHAR(120) NULL,
  os_version   VARCHAR(60) NULL,
  app_version  VARCHAR(30) NULL,
  enrolled_at  DATETIME NOT NULL,
  enrolled_via ENUM('first_use','director') NOT NULL DEFAULT 'first_use',
  approved_by  CHAR(24) NULL,
  FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS attendance_device_requests (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  employee_id  CHAR(24) NOT NULL,
  device_key   VARCHAR(64) NOT NULL,
  device_uuid  VARCHAR(64) NULL,
  platform     ENUM('android','ios') NOT NULL,
  model        VARCHAR(120) NULL,
  os_version   VARCHAR(60) NULL,
  app_version  VARCHAR(30) NULL,
  status       ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  attempts     INT NOT NULL DEFAULT 1,
  first_seen   DATETIME NOT NULL,
  last_seen    DATETIME NOT NULL,
  resolved_by  CHAR(24) NULL,
  resolved_at  DATETIME NULL,
  note         VARCHAR(255) NULL,
  UNIQUE KEY uq_att_dev_req (employee_id, device_key),
  KEY idx_att_dev_req_status (status),
  FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (resolved_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

ALTER TABLE attendance
  ADD COLUMN location_accuracy_m DECIMAL(6,1) NULL AFTER longitude,
  ADD COLUMN device_key    VARCHAR(64) NULL AFTER method,
  ADD COLUMN device_status ENUM('trusted','first_use','director_approved') NULL AFTER device_key,
  ADD COLUMN biometric_result ENUM('ok','skipped','failed') NULL AFTER device_status,
  ADD COLUMN biometric_type   VARCHAR(20) NULL AFTER biometric_result;
