-- Bitácora de auditoría para /site/* (create/update/delete). before_json/
-- after_json opcionales; actor_id nunca NULL, siempre atribuible.
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
