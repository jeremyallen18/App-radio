-- Migración: estructura organizacional (companies, departments, roles).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado (instalaciones nuevas parten de ahí).
USE hive_db;

CREATE TABLE IF NOT EXISTS companies (
  id CHAR(24) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT NULL,
  logo VARCHAR(500) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS departments (
  id CHAR(24) PRIMARY KEY,
  company_id CHAR(24) NOT NULL,
  name VARCHAR(255) NOT NULL,
  description TEXT NULL,
  manager_email VARCHAR(255) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_dept_per_company (company_id, name),
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
) ENGINE=InnoDB;

ALTER TABLE users
  ADD COLUMN role VARCHAR(20) NOT NULL DEFAULT 'employee' AFTER password,
  ADD COLUMN position VARCHAR(150) NULL AFTER role,
  ADD COLUMN department_id CHAR(24) NULL AFTER position,
  ADD CONSTRAINT fk_users_department FOREIGN KEY (department_id)
    REFERENCES departments(id) ON DELETE SET NULL;
