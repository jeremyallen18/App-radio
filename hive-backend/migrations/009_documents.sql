-- Migración: agrega la tabla `documents`, usada por el nuevo apartado
-- "Documentos" de Resource Manager (subir/descargar PDF, Word, Excel,
-- etc. — antes solo existían "recursos" de texto e imágenes).
-- `hive-backend/schema.sql` ya la trae desde el inicio, así que
-- instalaciones nuevas no necesitan correr esto. Solo para bases de datos
-- existentes.
--
-- Aplicar una sola vez sobre hive_db, después de 001-008.
USE hive_db;

CREATE TABLE IF NOT EXISTS documents (
  id INT AUTO_INCREMENT PRIMARY KEY,
  team_id CHAR(24) NOT NULL,
  doc_name VARCHAR(255) NOT NULL,
  doc_path VARCHAR(500) NOT NULL,
  original_name VARCHAR(255) NOT NULL,
  file_size INT NOT NULL DEFAULT 0,
  uploaded_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
