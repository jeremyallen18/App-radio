-- Hive Team Management App backend schema.
--
-- Este es el ÚNICO script de esquema del proyecto: crea, en una sola base
-- de datos (hive_db), todas las tablas que usa la app (usuarios, equipos,
-- áreas, chat, notificaciones, tareas, permisos y estructura
-- organizacional). Es seguro volver a correrlo: usa CREATE ... IF NOT
-- EXISTS en todo, así que no borra datos existentes.
--
--   mysql -u root -p < hive-backend/schema.sql
--
-- (Antes existía además "setup_database.sql", una copia casi idéntica de
-- este archivo que solo agregaba la creación de un usuario de MySQL
-- dedicado. Se eliminó por duplicar el esquema en dos lugares; si querés
-- un usuario dedicado en vez de root, creálo vos con tu cliente de MySQL
-- (CREATE USER / GRANT) antes de correr este script, y después poné esas
-- credenciales en hive-backend/.env.)
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
  -- Foto de perfil (subida vía POST /user/updatePhoto): solo se guarda el
  -- nombre del archivo dentro de UPLOAD_DIR, igual que images.img_path;
  -- la URL completa se arma con UPLOAD_URL_BASE al responder. NULL = sin
  -- foto todavía, y la app muestra un avatar con la inicial en su lugar.
  photo_path VARCHAR(500) NULL,
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
  -- Workflow jerárquico Director -> Departamento -> Manager -> Empleado
  -- (ver migrations/002_task_workflow.sql). team_code/domain_name/email
  -- se dejan tal cual para no romper el flujo de equipos existente; las
  -- tareas de departamento usan '' en esas tres columnas y viven en las
  -- columnas nuevas de abajo.
  created_by CHAR(24) NULL,
  assigned_by CHAR(24) NULL,
  department_id CHAR(24) NULL,
  priority VARCHAR(20) NOT NULL DEFAULT 'normal',
  progress TINYINT UNSIGNED NOT NULL DEFAULT 0,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_tasks_department (department_id),
  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Chat por equipo: cada mensaje pertenece a un team_id, y solo los
-- integrantes de ese equipo pueden leerlo/escribirlo (hive-backend/index.php,
-- getAllChats / sendChatMessage). El índice es clave porque cada carga del
-- chat filtra por team_id.
--
-- La misma tabla también guarda los chats privados 1 a 1 (getDirectChat /
-- sendDirectMessage): en ese caso team_id queda NULL y recipient_email
-- identifica al destinatario; username sigue siendo el remitente. Un
-- mensaje nunca tiene team_id y recipient_email a la vez.
CREATE TABLE IF NOT EXISTS chat_messages (
  id INT AUTO_INCREMENT PRIMARY KEY,
  team_id CHAR(24) NULL,
  username VARCHAR(255) NOT NULL,
  recipient_email VARCHAR(255) NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_chat_messages_team (team_id, id),
  KEY idx_chat_messages_direct (recipient_email, username, id)
) ENGINE=InnoDB;

-- Marca de "hasta dónde leyó cada usuario" en cada chat (de equipo o
-- directo), para poder calcular mensajes sin leer al estilo WhatsApp en
-- /chat/list. `chat_key` identifica el hilo: 'team:<teamId>' para chats de
-- equipo, 'direct:<peerEmail>' para chats directos (siempre la otra
-- persona, sin importar quién mandó el último mensaje). Se actualiza al
-- entrar a ese chat (ver POST /chat/read).
CREATE TABLE IF NOT EXISTS chat_reads (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_email VARCHAR(255) NOT NULL,
  chat_key VARCHAR(300) NOT NULL,
  last_read_at TIMESTAMP NOT NULL,
  UNIQUE KEY uniq_chat_read (user_email, chat_key)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS images (
  id INT AUTO_INCREMENT PRIMARY KEY,
  team_id CHAR(24) NOT NULL,
  img_name VARCHAR(255) NOT NULL,
  img_path VARCHAR(500) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Documentos "de verdad" (PDF, Word, Excel, etc.) que el equipo sube y
-- descarga desde Resource Manager > Documentos. A diferencia de `images`,
-- el archivo se sirve a través de /document/download/{id} (index.php) en
-- vez de un enlace estático, para poder forzar la descarga con el nombre
-- original y revisar que quien pide el archivo pertenezca al equipo.
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
  KEY idx_notifications_email (email, read_at),
  KEY idx_notifications_team (team_id)
) ENGINE=InnoDB;
