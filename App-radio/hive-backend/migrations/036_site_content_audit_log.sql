-- Migración: bitácora de auditoría para el API de contenido del sitio
-- público (site_content.php, rutas /site/*). Aplicar una sola vez. Ver
-- hive-backend/schema.sql para el esquema completo (instalaciones nuevas
-- parten de ahí).
--
-- Registra cada create/update/delete hecho a través de /site/* para poder
-- rastrear quién cambió o borró algo por error. `before_json`/`after_json`
-- son opcionales (NULL si no aplica, p. ej. en un delete no se guarda
-- "after"). `actor_id` es el id de usuario (sesión de director) o el nombre
-- fijo de la integración (llave de API) — nunca NULL, para que el log
-- siempre sea atribuible a algo.
USE hive_db;

CREATE TABLE IF NOT EXISTS site_content_audit_log (
  id BIGINT NOT NULL AUTO_INCREMENT,
  resource VARCHAR(50) NOT NULL,
  action ENUM('create', 'update', 'delete') NOT NULL,
  record_id INT DEFAULT NULL,
  actor_type ENUM('session', 'api_key') NOT NULL,
  actor_id VARCHAR(100) NOT NULL,
  actor_email VARCHAR(255) DEFAULT NULL,
  request_ip VARCHAR(45) DEFAULT NULL,
  before_json LONGTEXT DEFAULT NULL,
  after_json LONGTEXT DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY resource_record (resource, record_id),
  KEY created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
