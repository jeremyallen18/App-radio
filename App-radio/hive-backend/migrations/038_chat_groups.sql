-- Chat grupal: uno para toda la empresa y uno por departamento (ver spec
-- docs/superpowers/specs/2026-09-13-chat-grupal-design.md). La membresía NO
-- se guarda en una tabla: se calcula en vivo desde companies/departments +
-- users.department_id (chat_groups.php), igual que ya hacen los permisos de
-- tareas de departamento. `ref_id` apunta a companies.id o departments.id
-- según `kind`; se resuelve en PHP, sin FK física hacia dos tablas distintas.

USE hive_db;

CREATE TABLE IF NOT EXISTS chat_groups (
  id CHAR(24) PRIMARY KEY,
  kind ENUM('company','department') NOT NULL,
  ref_id CHAR(24) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_chat_group_ref (kind, ref_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS chat_group_messages (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  group_id CHAR(24) NOT NULL,
  sender_id CHAR(24) NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_cgm_group (group_id, id),
  FOREIGN KEY (group_id) REFERENCES chat_groups(id) ON DELETE CASCADE,
  FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS chat_group_reads (
  group_id CHAR(24) NOT NULL,
  user_id CHAR(24) NOT NULL,
  last_read_message_id BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (group_id, user_id),
  FOREIGN KEY (group_id) REFERENCES chat_groups(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
