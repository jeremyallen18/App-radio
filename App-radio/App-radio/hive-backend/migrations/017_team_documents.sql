-- Migración: documentos de equipo (Radio Doliv).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado.
--
-- Apartado "Documentos" de Recursos del equipo: cualquier miembro sube y
-- descarga archivos de oficina (PDF, Word, Excel, PowerPoint, txt, csv,
-- zip). A diferencia de "Publicar recursos" (solo texto o una imagen
-- suelta), aquí se conserva el nombre original y el archivo se guarda en
-- private/documents/ — nunca se sirve estático, solo por
-- GET /document/download/{id} tras validar la pertenencia al equipo.
-- Lo borra quien lo subió o el líder del equipo.

USE hive_db;

CREATE TABLE IF NOT EXISTS documents (
  id CHAR(24) PRIMARY KEY,
  team_id CHAR(24) NOT NULL,
  doc_name VARCHAR(255) NOT NULL,
  stored_path VARCHAR(255) NOT NULL,
  original_name VARCHAR(255) NOT NULL,
  mime VARCHAR(150) NULL,
  file_size INT NOT NULL DEFAULT 0,
  uploaded_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_documents_team (team_id, id),
  FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE
) ENGINE=InnoDB;
