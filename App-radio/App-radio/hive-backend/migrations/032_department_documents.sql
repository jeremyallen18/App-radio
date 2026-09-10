-- Migración: documentos por departamento (Radio Doliv).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado.
--
-- Paralelo a `documents` (que es por equipo legacy): estos pertenecen a un
-- DEPARTAMENTO y siguen el RBAC de la organización.
--   - Director: sube / renombra / elimina en CUALQUIER departamento.
--   - Manager: sube / renombra / elimina SOLO en su departamento.
--   - Empleado: solo ve, busca y descarga los de SU departamento.
-- El archivo se guarda en private/department_documents/ — nunca estático,
-- solo por GET /department-documents/{id}/download tras validar pertenencia.

USE hive_db;

CREATE TABLE IF NOT EXISTS department_documents (
  id CHAR(24) PRIMARY KEY,
  department_id CHAR(24) NOT NULL,
  doc_name VARCHAR(255) NOT NULL,
  stored_path VARCHAR(255) NOT NULL,
  original_name VARCHAR(255) NOT NULL,
  mime VARCHAR(150) NULL,
  file_size INT NOT NULL DEFAULT 0,
  uploaded_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_deptdocs_dept (department_id, created_at),
  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE
) ENGINE=InnoDB;
