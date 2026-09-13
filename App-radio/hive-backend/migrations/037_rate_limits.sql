-- Contadores de ventana fija para limitar abuso (login, OTP, reset de
-- contraseña, registro, subidas) y bitácora ligera de eventos de seguridad
-- (intentos fallidos, límites alcanzados). Ver helpers.php: rate_limit_check(),
-- enforce_rate_limit(), log_security_event().
USE hive_db;

CREATE TABLE IF NOT EXISTS rate_limits (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  bucket_key VARCHAR(191) NOT NULL,
  window_start DATETIME NOT NULL,
  hits INT UNSIGNED NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  UNIQUE KEY uq_bucket_window (bucket_key, window_start),
  KEY idx_window_start (window_start)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS security_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  event_type VARCHAR(64) NOT NULL,
  identifier VARCHAR(191) DEFAULT NULL,
  request_ip VARCHAR(45) DEFAULT NULL,
  meta TEXT DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_event_type_created (event_type, created_at),
  KEY idx_identifier (identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
