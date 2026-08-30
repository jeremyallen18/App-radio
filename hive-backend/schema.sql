-- Esquema COMPLETO de hive_db (base compartida Radio Doliv).
-- Cubre las dos mitades del ecosistema:
--   1. Gestión interna (App-radio/hive-backend)  — migraciones 001..013 ya plegadas.
--   2. Contenido del sitio público (RADIODOLIV_PAGINA) — sección `radio_*` / `sponsors` al final.
-- Instalación nueva = importar SOLO este archivo y luego cargar los datos
-- iniciales del sitio con los dos scripts migrate_*.php de RADIODOLIV_PAGINA.
-- Las carpetas migrations/ de ambos proyectos se conservan como historial
-- incremental para actualizar bases de datos que YA tienen datos.
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

-- ----------------------------------------------------------------------------
-- Anuncios del sitio público (RADIODOLIV_PAGINA/pages/anuncios.php). Ambos
-- proyectos comparten hive_db a partir de la migración 002_anuncios.sql.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS anuncios (
  id INT AUTO_INCREMENT PRIMARY KEY,
  titulo VARCHAR(255) NOT NULL,
  descripcion TEXT NULL,
  imagen_url VARCHAR(500) NULL,
  link_web VARCHAR(500) NULL,
  link_facebook VARCHAR(500) NULL,
  link_whatsapp VARCHAR(500) NULL,
  fecha_publicacion DATE NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Asistencia y hora de comida de empleados (ver migrations/004_attendance.sql
-- y hive-backend/attendance.php). Eventos inmutables + horario asignado por
-- el director + snapshot diario del horario para no alterar el histórico.
-- El director NUNCA tiene filas aquí.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS attendance (
  id INT AUTO_INCREMENT PRIMARY KEY,
  employee_id CHAR(24) NOT NULL,
  type ENUM('entrada','inicio_comida','fin_comida','salida') NOT NULL,
  work_date DATE NOT NULL,
  event_time DATETIME NOT NULL,
  device_time DATETIME NULL,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  method VARCHAR(20) NOT NULL DEFAULT 'gps',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_attendance_emp_date (employee_id, work_date),
  FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS employee_schedules (
  employee_id CHAR(24) PRIMARY KEY,
  entry_time TIME NOT NULL DEFAULT '09:00:00',
  exit_time TIME NOT NULL DEFAULT '17:00:00',
  meal_time TIME NOT NULL DEFAULT '14:00:00',
  meal_max_minutes INT NOT NULL DEFAULT 60,
  updated_by CHAR(24) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS attendance_schedule_snapshots (
  employee_id CHAR(24) NOT NULL,
  work_date DATE NOT NULL,
  entry_time TIME NOT NULL,
  exit_time TIME NOT NULL,
  meal_time TIME NOT NULL,
  meal_max_minutes INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (employee_id, work_date),
  FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS attendance_corrections (
  id INT AUTO_INCREMENT PRIMARY KEY,
  attendance_id INT NOT NULL,
  corrected_by CHAR(24) NOT NULL,
  old_event_time DATETIME NOT NULL,
  new_event_time DATETIME NOT NULL,
  reason VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (attendance_id) REFERENCES attendance(id) ON DELETE CASCADE,
  FOREIGN KEY (corrected_by) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Solicitudes de corrección de asistencia hechas por el EMPLEADO (migración
-- 013). El manager de su depto (o el director) las aprueba/rechaza; al
-- aprobar se crea o ajusta la fila de `attendance` y se enlaza aquí.
CREATE TABLE IF NOT EXISTS attendance_correction_requests (
  id INT AUTO_INCREMENT PRIMARY KEY,
  employee_id CHAR(24) NOT NULL,
  work_date DATE NOT NULL,
  kind ENUM('entrada','inicio_comida','fin_comida','salida') NOT NULL,
  requested_time TIME NOT NULL,
  reason VARCHAR(1000) NOT NULL,
  status ENUM('pendiente','aprobado','rechazado') NOT NULL DEFAULT 'pendiente',
  reviewed_by CHAR(24) NULL,
  review_note VARCHAR(1000) NULL,
  attendance_id INT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  resolved_at DATETIME NULL,
  KEY idx_acr_emp (employee_id, status),
  KEY idx_acr_status (status, created_at),
  FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (attendance_id) REFERENCES attendance(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Lugar de asistencia (una sola fila, id=1). El director define el punto y el
-- radio; `entrada` y `fin_comida` se rechazan si el GPS cae fuera del radio.
CREATE TABLE IF NOT EXISTS attendance_location (
  id TINYINT NOT NULL PRIMARY KEY DEFAULT 1,
  latitude DECIMAL(10,7) NOT NULL,
  longitude DECIMAL(10,7) NOT NULL,
  radius_m INT NOT NULL DEFAULT 10,
  label VARCHAR(255) NULL,
  updated_by CHAR(24) NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Permisos, vacaciones e incapacidades (ver migrations/006_leave_requests.sql
-- y hive-backend/leave_requests.php). Un permiso `aprobado` exime del registro
-- de asistencia los días laborales que cubre su rango aprobado. Nunca se borran
-- solicitudes: el historial completo se conserva para auditoría.
CREATE TABLE IF NOT EXISTS leave_requests (
  id CHAR(24) PRIMARY KEY,
  employee_id CHAR(24) NOT NULL,
  type ENUM('vacaciones','incapacidad','permiso') NOT NULL,
  requested_start_date DATE NOT NULL,
  requested_end_date DATE NOT NULL,
  requested_days INT NOT NULL,
  approved_start_date DATE NULL,
  approved_end_date DATE NULL,
  approved_days INT NULL,
  reason VARCHAR(1000) NULL,
  status ENUM('pendiente','aprobado','rechazado','cancelado') NOT NULL DEFAULT 'pendiente',
  evidence_path VARCHAR(255) NULL,
  evidence_mime VARCHAR(100) NULL,
  rejection_reason VARCHAR(1000) NULL,
  cancellation_reason VARCHAR(1000) NULL,
  approved_by CHAR(24) NULL,
  approved_at DATETIME NULL,
  cancelled_by CHAR(24) NULL,
  cancelled_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_lr_employee (employee_id),
  KEY idx_lr_status (status),
  KEY idx_lr_req_start (requested_start_date),
  KEY idx_lr_req_end (requested_end_date),
  KEY idx_lr_appr_start (approved_start_date),
  KEY idx_lr_appr_end (approved_end_date),
  FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (cancelled_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Eventos del calendario (ver migrations/007_events.sql y hive-backend/events.php).
-- El director crea eventos 'general' (toda la empresa) o 'areas' (solo los
-- departamentos de event_areas y sus managers). Si has_location = 1, el evento
-- lleva ubicación + hora de entrada y, ese día, sustituye la ubicación y la
-- hora de ENTRADA de asistencia para los miembros de esas áreas (la salida y la
-- comida no cambian; las áreas no incluidas siguen igual y no se les notifica).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS events (
  id CHAR(24) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description VARCHAR(1000) NULL,
  event_date DATE NOT NULL,
  start_time TIME NULL,
  end_time TIME NULL,
  scope ENUM('general','areas') NOT NULL DEFAULT 'general',
  has_location TINYINT(1) NOT NULL DEFAULT 0,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  radius_m INT NULL,
  location_label VARCHAR(255) NULL,
  entry_time TIME NULL,
  created_by CHAR(24) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_events_date (event_date),
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS event_areas (
  event_id CHAR(24) NOT NULL,
  department_id CHAR(24) NOT NULL,
  PRIMARY KEY (event_id, department_id),
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Flujo jerárquico de tareas por departamento/equipo (ver
-- migrations/008_dept_tasks.sql y hive-backend/dept_tasks.php). Director:
-- cualquier departamento. Manager: tareas y subtareas de su departamento.
-- Empleado: solo cambia el estado (marcar completada). Paralela a `tasks`.
--
-- Ampliaciones posteriores:
--   009 dept_task_comments  · hilo de comentarios por tarea
--   010 requires_evidence / evidence_path / evidence_mime · evidencia al completar
--   011 review_status / review_note / reviewed_by / reviewed_at · revisión del manager
--   012 recurrence / recurrence_until · tareas recurrentes (sin cron)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dept_tasks (
  id CHAR(24) PRIMARY KEY,
  parent_id CHAR(24) NULL,
  department_id CHAR(24) NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT NULL,
  assigned_to CHAR(24) NULL,
  created_by CHAR(24) NOT NULL,
  created_by_role VARCHAR(20) NOT NULL,
  due_date DATE NULL,
  requires_evidence TINYINT(1) NOT NULL DEFAULT 0,
  evidence_path VARCHAR(255) NULL,
  evidence_mime VARCHAR(100) NULL,
  recurrence ENUM('none','daily','weekdays','weekly','monthly') NOT NULL DEFAULT 'none',
  recurrence_until DATE NULL,
  status ENUM('pendiente','en_progreso','completada') NOT NULL DEFAULT 'pendiente',
  completed_by CHAR(24) NULL,
  completed_at DATETIME NULL,
  review_status ENUM('sin_revision','pendiente_revision','aprobada','rechazada') NOT NULL DEFAULT 'sin_revision',
  review_note VARCHAR(1000) NULL,
  reviewed_by CHAR(24) NULL,
  reviewed_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_dt_department (department_id, status),
  KEY idx_dt_parent (parent_id),
  KEY idx_dt_assigned (assigned_to),
  FOREIGN KEY (parent_id) REFERENCES dept_tasks(id) ON DELETE CASCADE,
  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE,
  FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (completed_by) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Hilo de comentarios por tarea (migración 009). Leen todos los que pueden
-- ver la tarea; escriben director, manager del depto y el empleado asignado.
CREATE TABLE IF NOT EXISTS dept_task_comments (
  id CHAR(24) PRIMARY KEY,
  task_id CHAR(24) NOT NULL,
  author_id CHAR(24) NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_dtc_task (task_id, created_at),
  FOREIGN KEY (task_id) REFERENCES dept_tasks(id) ON DELETE CASCADE,
  FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================================
-- CONTENIDO DEL SITIO PÚBLICO (RADIODOLIV_PAGINA)
-- ----------------------------------------------------------------------------
-- Las mismas tablas viven, como historial incremental, en
-- RADIODOLIV_PAGINA/config/migrations/2026_08_06_create_*.sql. Se replican
-- aquí para que `schema.sql` sea el esquema COMPLETO de hive_db (RRHH + sitio)
-- y una instalación nueva se levante importando un solo archivo.
--
-- Solo DDL: los datos iniciales (los arrays que antes vivían hardcodeados en
-- RADIODOLIV_PAGINA/inc/data/*.php) se cargan aparte, una vez, con:
--   php RADIODOLIV_PAGINA/config/migrations/migrate_radio_content.php
--   php RADIODOLIV_PAGINA/config/migrations/migrate_sponsors.php
-- (ambos son idempotentes: si la tabla ya tiene filas, no reinsertan).
--
-- Prefijo `radio_` para no chocar con las tablas de RRHH de arriba
-- (teams/tasks/etc. son del backend interno, no del sitio).
-- ============================================================================

CREATE TABLE IF NOT EXISTS radio_events (
  id INT NOT NULL AUTO_INCREMENT,
  slug VARCHAR(100) NOT NULL,
  title VARCHAR(255) NOT NULL,
  artist VARCHAR(255) DEFAULT NULL,
  location VARCHAR(255) DEFAULT NULL,
  image VARCHAR(500) DEFAULT NULL,
  weekday VARCHAR(20) DEFAULT NULL,
  day VARCHAR(10) DEFAULT NULL,
  month VARCHAR(20) DEFAULT NULL,
  year VARCHAR(10) DEFAULT NULL,
  event_date DATE DEFAULT NULL,
  time_label VARCHAR(255) DEFAULT NULL,
  description TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS radio_podcasts (
  id INT NOT NULL AUTO_INCREMENT,
  slug VARCHAR(100) NOT NULL,
  title VARCHAR(255) NOT NULL,
  filter_icon VARCHAR(50) DEFAULT NULL,
  cover VARCHAR(500) DEFAULT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS radio_podcast_episodes (
  id INT NOT NULL AUTO_INCREMENT,
  podcast_id INT NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  audio_url VARCHAR(500) DEFAULT NULL,
  category_label VARCHAR(100) DEFAULT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY podcast_id (podcast_id),
  CONSTRAINT radio_podcast_episodes_ibfk_1 FOREIGN KEY (podcast_id) REFERENCES radio_podcasts (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS radio_programs (
  id INT NOT NULL AUTO_INCREMENT,
  slug VARCHAR(100) NOT NULL,
  title VARCHAR(255) NOT NULL,
  modal_title VARCHAR(255) DEFAULT NULL,
  host VARCHAR(255) DEFAULT NULL,
  schedule VARCHAR(255) DEFAULT NULL,
  slot_start INT DEFAULT NULL,
  slot_end INT DEFAULT NULL,
  weekdays VARCHAR(20) DEFAULT NULL COMMENT 'Dias ISO (1=lunes..7=domingo) separados por coma; NULL = todos los dias',
  badge_icon VARCHAR(50) DEFAULT NULL,
  badge_time VARCHAR(100) DEFAULT NULL,
  badge_label VARCHAR(255) DEFAULT NULL,
  accent VARCHAR(20) DEFAULT NULL,
  icon VARCHAR(50) DEFAULT NULL,
  image VARCHAR(500) DEFAULT NULL,
  categories VARCHAR(255) DEFAULT NULL,
  card_desc TEXT,
  index_desc TEXT,
  summary TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS radio_services (
  id INT NOT NULL AUTO_INCREMENT,
  title VARCHAR(255) NOT NULL,
  image VARCHAR(500) DEFAULT NULL,
  description TEXT,
  whatsapp_url VARCHAR(1000) DEFAULT NULL,
  category VARCHAR(100) DEFAULT NULL,
  icon VARCHAR(50) DEFAULT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS radio_team (
  id INT NOT NULL AUTO_INCREMENT,
  slug VARCHAR(100) NOT NULL,
  name VARCHAR(255) NOT NULL,
  role VARCHAR(255) DEFAULT NULL,
  category VARCHAR(100) DEFAULT NULL,
  accent VARCHAR(20) DEFAULT NULL,
  image VARCHAR(500) DEFAULT NULL,
  short_desc VARCHAR(500) DEFAULT NULL,
  bio TEXT COMMENT 'Párrafos separados por \n\n',
  path TEXT COMMENT 'Items separados por \n',
  interests TEXT COMMENT 'Items separados por \n',
  sort_order INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Patrocinadores de la Sección Azul (reemplaza inc/data/sponsors.php).
CREATE TABLE IF NOT EXISTS sponsors (
  id INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(255) NOT NULL,
  category VARCHAR(50) NOT NULL,
  category_label VARCHAR(100) NOT NULL,
  icon VARCHAR(100) NOT NULL,
  image VARCHAR(500) NOT NULL,
  subtitle VARCHAR(255) DEFAULT NULL,
  summary TEXT,
  description TEXT COMMENT 'Párrafos separados por \n\n',
  map VARCHAR(1000) DEFAULT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sponsor_socials (
  id INT NOT NULL AUTO_INCREMENT,
  sponsor_id INT NOT NULL,
  label VARCHAR(50) NOT NULL,
  icon VARCHAR(50) NOT NULL,
  url VARCHAR(1000) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY sponsor_id (sponsor_id),
  CONSTRAINT sponsor_socials_ibfk_1 FOREIGN KEY (sponsor_id) REFERENCES sponsors (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
