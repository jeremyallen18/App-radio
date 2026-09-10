-- Migración: anuncios internos de la empresa (Radio Doliv).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado.
--
-- El DIRECTOR GENERAL publica un anuncio interno TEMPORAL: vive en una
-- ventana [starts_on, ends_on] de mínimo 1 semana y máximo 1 mes (31 días).
-- Alcance:
--   - scope='general' -> lo ve toda la empresa.
--   - scope='areas'   -> solo los miembros de los departamentos en
--                        internal_announcement_areas (y sus managers).
-- Si requires_confirmation=1 (p. ej. una reunión), el resto puede confirmar
-- asistencia (sí/no). El director ve el historial de visualizaciones y de
-- confirmaciones, y puede editar o eliminar el anuncio.
USE hive_db;

CREATE TABLE IF NOT EXISTS internal_announcements (
  id CHAR(24) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  scope ENUM('general','areas') NOT NULL DEFAULT 'general',
  starts_on DATE NOT NULL,
  ends_on DATE NOT NULL,
  requires_confirmation TINYINT(1) NOT NULL DEFAULT 0,
  event_at DATETIME NULL,
  location_label VARCHAR(255) NULL,
  created_by CHAR(24) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_ia_window (starts_on, ends_on),
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS internal_announcement_areas (
  announcement_id CHAR(24) NOT NULL,
  department_id CHAR(24) NOT NULL,
  PRIMARY KEY (announcement_id, department_id),
  FOREIGN KEY (announcement_id) REFERENCES internal_announcements(id) ON DELETE CASCADE,
  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Una fila por persona que abrió el tablero de anuncios y vio este anuncio.
CREATE TABLE IF NOT EXISTS internal_announcement_views (
  announcement_id CHAR(24) NOT NULL,
  user_id CHAR(24) NOT NULL,
  viewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (announcement_id, user_id),
  FOREIGN KEY (announcement_id) REFERENCES internal_announcements(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Confirmación de asistencia (solo si requires_confirmation=1).
CREATE TABLE IF NOT EXISTS internal_announcement_confirmations (
  announcement_id CHAR(24) NOT NULL,
  user_id CHAR(24) NOT NULL,
  status ENUM('si','no') NOT NULL DEFAULT 'si',
  responded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (announcement_id, user_id),
  FOREIGN KEY (announcement_id) REFERENCES internal_announcements(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
