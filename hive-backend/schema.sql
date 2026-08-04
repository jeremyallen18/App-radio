-- Hive Team Management App backend schema
CREATE DATABASE IF NOT EXISTS hive_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE hive_db;

-- ----------------------------------------------------------------------------
-- Estructura organizacional (Radio Doliv): companies -> departments -> users.
-- Un Director General administra la empresa; cada departamento tiene un único
-- manager (users.role='manager', referenciado aquí por email igual que en el
-- resto del esquema) y varios empleados (users.department_id). Van antes de
-- `users` porque esta última tiene una FK hacia `departments`.
-- ----------------------------------------------------------------------------
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

CREATE TABLE IF NOT EXISTS users (
  id CHAR(24) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL,
  -- Estructura organizacional Radio Doliv: role/position/department_id.
  -- role: 'director' | 'manager' | 'employee' (ver ROLES en helpers.php).
  role VARCHAR(20) NOT NULL DEFAULT 'employee',
  position VARCHAR(150) NULL,
  department_id CHAR(24) NULL,
  token VARCHAR(64) NULL,
  otp VARCHAR(10) NULL,
  otp_expires DATETIME NULL,
  otp_verified TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS teams (
  id CHAR(24) PRIMARY KEY,
  team_name VARCHAR(255) NOT NULL,
  team_code VARCHAR(20) NOT NULL UNIQUE,
  leader_email VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS domains (
  id INT AUTO_INCREMENT PRIMARY KEY,
  team_id CHAR(24) NOT NULL,
  name VARCHAR(255) NOT NULL,
  FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS domain_members (
  id INT AUTO_INCREMENT PRIMARY KEY,
  domain_id INT NOT NULL,
  email VARCHAR(255) NOT NULL,
  FOREIGN KEY (domain_id) REFERENCES domains(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS team_members (
  id INT AUTO_INCREMENT PRIMARY KEY,
  team_id CHAR(24) NOT NULL,
  email VARCHAR(255) NOT NULL,
  UNIQUE KEY uniq_team_email (team_id, email),
  FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tasks (
  id INT AUTO_INCREMENT PRIMARY KEY,
  team_code VARCHAR(20) NOT NULL,
  domain_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL,
  description TEXT NOT NULL,
  deadline VARCHAR(50) NOT NULL,
  completed TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS chat_messages (
  id INT AUTO_INCREMENT PRIMARY KEY,
  team_id CHAR(24) NULL,
  username VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS images (
  id INT AUTO_INCREMENT PRIMARY KEY,
  team_id CHAR(24) NOT NULL,
  img_name VARCHAR(255) NOT NULL,
  img_path VARCHAR(500) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS texts (
  id INT AUTO_INCREMENT PRIMARY KEY,
  team_id CHAR(24) NOT NULL,
  email VARCHAR(255) NOT NULL,
  text TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS leader_messages (
  id INT AUTO_INCREMENT PRIMARY KEY,
  team_id CHAR(24) NOT NULL,
  email VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS leaves (
  id CHAR(24) PRIMARY KEY,
  team_id CHAR(24) NOT NULL,
  email VARCHAR(255) NOT NULL,
  start_date VARCHAR(50) NOT NULL,
  end_date VARCHAR(50) NOT NULL,
  reason TEXT NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Notificaciones in-app (la campana del appbar y screens/notifications.dart).
-- Se emiten al eliminar a un miembro y al asignar un nuevo líder.
CREATE TABLE IF NOT EXISTS notifications (
  id INT AUTO_INCREMENT PRIMARY KEY,
  team_id CHAR(24) NULL,
  email VARCHAR(255) NOT NULL,
  type VARCHAR(50) NOT NULL,
  message VARCHAR(255) NOT NULL,
  read_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_notifications_email (email, read_at)
) ENGINE=InnoDB;
