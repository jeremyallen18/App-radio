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
  -- Cambio de correo pendiente de confirmar (migración 029): lo fija
  -- requestEmailChange(); verifyEmail() lo aplica cuando el usuario abre el
  -- enlace enviado a esa dirección, y entonces vuelve a NULL.
  pending_email VARCHAR(255) NULL,
  password VARCHAR(255) NOT NULL,
  -- Estructura organizacional Radio Doliv: role/position/department_id.
  -- role: 'director' | 'manager' | 'employee' (ver ROLES en helpers.php).
  role VARCHAR(20) NOT NULL DEFAULT 'employee',
  position VARCHAR(150) NULL,
  -- Identificador único e intransferible SPPRD-0000000 (migración 028). El
  -- alta lo autoasigna; solo el director lo corrige. NULL solo mientras no se
  -- ha asignado (p. ej. si falló el autoasignado en el alta).
  control_number VARCHAR(20) NULL UNIQUE,
  photo_path VARCHAR(500) NULL,
  department_id CHAR(24) NULL,
  token VARCHAR(64) NULL,
  otp VARCHAR(10) NULL,
  otp_expires DATETIME NULL,
  otp_verified TINYINT(1) NOT NULL DEFAULT 0,
  -- Verificación de correo al registrarse (migración 023). NULL = sin
  -- verificar. Las cuentas creadas antes de la migración se dan por
  -- verificadas (email_verified_at = created_at).
  email_verified_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  -- Índice para el barrido de cuentas sin verificar (migración 025): una
  -- cuenta con email_verified_at IS NULL y más de 72 h de antigüedad se
  -- borra automáticamente (cleanup_unverified_accounts() en helpers.php,
  -- perezoso en signup + cron_cleanup_unverified.php). Nunca afecta a
  -- cuentas verificadas.
  KEY idx_users_unverified (email_verified_at, created_at),
  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Tokens de verificación de correo (migración 023). Solo se guarda el hash
-- SHA-256 del token; un solo uso (consumed_at) y con caducidad (expires_at).
CREATE TABLE IF NOT EXISTS email_verifications (
  id CHAR(24) PRIMARY KEY,
  user_id CHAR(24) NOT NULL,
  -- Si no es NULL (migración 029), esta fila confirma un CAMBIO de correo a
  -- esta dirección, no el alta: al consumirla, verifyEmail() hace
  -- users.email = new_email.
  new_email VARCHAR(255) NULL,
  token_hash CHAR(64) NOT NULL,
  expires_at DATETIME NOT NULL,
  consumed_at DATETIME NULL,
  requested_ip VARCHAR(45) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_ev_token (token_hash),
  KEY idx_ev_user (user_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
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

-- Mensajería directa 1 a 1 entre compañeros (ver migración 016). No es una
-- sala global: cada fila es un mensaje privado de sender_id para recipient_id.
-- conversation_key = los dos ids ordenados y unidos por ':' -> permite leer
-- "la conversación entre A y B" con un índice, sin importar la dirección.
CREATE TABLE IF NOT EXISTS chat_messages (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  conversation_key CHAR(49) NOT NULL,
  sender_id CHAR(24) NOT NULL,
  recipient_id CHAR(24) NOT NULL,
  body TEXT NOT NULL,
  read_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_cm_convo (conversation_key, id),
  KEY idx_cm_inbox (recipient_id, read_at),
  KEY idx_cm_sender (sender_id, id),
  FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (recipient_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Archivo histórico de la sala de chat global anterior (ver migración 016:
-- `RENAME TABLE chat_messages TO chat_messages_legacy_global`). Ningún código
-- la lee; se incluye aquí solo para que una base creada desde este archivo
-- coincida con una actualizada por migraciones. En una instalación nueva
-- queda vacía.
CREATE TABLE IF NOT EXISTS chat_messages_legacy_global (
  id INT AUTO_INCREMENT PRIMARY KEY,
  team_id CHAR(24) NULL,
  username VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP
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

-- Documentos de equipo (apartado "Documentos" de Recursos; ver migración
-- 017). Archivos de oficina que suben y descargan los miembros; se guardan
-- en private/documents/ y solo se entregan por GET /document/download/{id}
-- autenticado (nunca estáticos).
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
  -- Destino estructurado opcional (migración 020): a qué entidad apunta la
  -- notificación, para que el cliente abra la pantalla correcta al tocarla.
  entity_type VARCHAR(32) NULL,
  entity_id VARCHAR(64) NULL,
  message TEXT NOT NULL,
  read_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_notifications_email (email, read_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS device_tokens (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email         VARCHAR(255) NOT NULL,
  token         VARCHAR(512) NOT NULL,
  platform      ENUM('android','ios','web') NOT NULL DEFAULT 'android',
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_token (token(191)),
  KEY idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
  -- `sin_comida`: el trabajador declara que hoy NO tomará hora de comida. Es
  -- solo constancia de esa decisión; NO registra salida ni cierra la jornada
  -- (ver hive-backend/attendance.php y migrations/018_attendance_meal_skip.sql).
  type ENUM('entrada','inicio_comida','fin_comida','salida','sin_comida') NOT NULL,
  work_date DATE NOT NULL,
  event_time DATETIME NOT NULL,
  device_time DATETIME NULL,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  method VARCHAR(20) NOT NULL DEFAULT 'gps',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_attendance_emp_date (employee_id, work_date),
  -- Cada tipo de evento es único por (trabajador, día): hace atómico el
  -- registro y evita duplicados por peticiones simultáneas (migración 019).
  UNIQUE KEY uq_attendance_evento (employee_id, work_date, type),
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
  -- Solo puede haber UNA solicitud pendiente por (trabajador, día, tipo de
  -- fichaje). pending_slot = 1 mientras está pendiente, NULL en cualquier otro
  -- estado (NULL no colisiona en UNIQUE), así se puede volver a solicitar tras
  -- una resolución. Backstop de concurrencia (migración 019).
  pending_slot TINYINT GENERATED ALWAYS AS (IF(status = 'pendiente', 1, NULL)) VIRTUAL,
  KEY idx_acr_emp (employee_id, status),
  KEY idx_acr_status (status, created_at),
  UNIQUE KEY uq_acr_pendiente (employee_id, work_date, kind, pending_slot),
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
  reason TEXT NULL,
  status ENUM('pendiente','aprobado','rechazado','cancelado') NOT NULL DEFAULT 'pendiente',
  evidence_path VARCHAR(255) NULL,
  evidence_mime VARCHAR(100) NULL,
  rejection_reason TEXT NULL,
  cancellation_reason TEXT NULL,
  approved_by CHAR(24) NULL,
  approved_at DATETIME NULL,
  cancelled_by CHAR(24) NULL,
  cancelled_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  -- Impide dos solicitudes PENDIENTES idénticas (mismo tipo y mismo rango
  -- solicitado) del mismo trabajador — doble envío accidental / reintento.
  -- Mismo patrón pending_slot que attendance_correction_requests (migración 019).
  pending_slot TINYINT GENERATED ALWAYS AS (IF(status = 'pendiente', 1, NULL)) VIRTUAL,
  KEY idx_lr_employee (employee_id),
  KEY idx_lr_status (status),
  KEY idx_lr_req_start (requested_start_date),
  KEY idx_lr_req_end (requested_end_date),
  KEY idx_lr_appr_start (approved_start_date),
  KEY idx_lr_appr_end (approved_end_date),
  UNIQUE KEY uq_leave_pendiente (employee_id, type, requested_start_date, requested_end_date, pending_slot),
  FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (cancelled_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Justificación de faltas pasadas (migración 022 / hive-backend/absences.php).
-- Una falta = día laboral (lun-sáb) ya pasado sin asistencia y sin permiso
-- aprobado. El trabajador la justifica con motivo + evidencia OBLIGATORIA; el
-- director aprueba o rechaza. Una justificación aprobada quita el día del
-- conteo de faltas injustificadas.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS absence_justifications (
  id CHAR(24) PRIMARY KEY,
  employee_id CHAR(24) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  reason TEXT NULL,
  evidence_path VARCHAR(255) NULL,
  evidence_mime VARCHAR(100) NULL,
  status ENUM('pendiente','aprobada','rechazada') NOT NULL DEFAULT 'pendiente',
  review_note TEXT NULL,
  reviewed_by CHAR(24) NULL,
  reviewed_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_absence_just (employee_id, start_date, end_date),
  KEY idx_aj_employee (employee_id, start_date),
  KEY idx_aj_status (status),
  FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL
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
  -- Lugar del evento en texto libre, para cualquier evento (migración 024).
  location_text VARCHAR(255) NULL,
  -- Días de antelación de los recordatorios automáticos, CSV (migración 024).
  reminder_offsets VARCHAR(50) NOT NULL DEFAULT '7,5,3,2',
  entry_time TIME NULL,
  created_by CHAR(24) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_events_date (event_date),
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Recordatorios de evento ya enviados (migración 024): idempotencia por
-- (evento, antelación en días, usuario avisado).
CREATE TABLE IF NOT EXISTS event_reminders_sent (
  event_id CHAR(24) NOT NULL,
  offset_days INT NOT NULL,
  user_id CHAR(24) NOT NULL,
  sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (event_id, offset_days, user_id),
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS event_areas (
  event_id CHAR(24) NOT NULL,
  department_id CHAR(24) NOT NULL,
  PRIMARY KEY (event_id, department_id),
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Sub-equipos dentro de un departamento (migración 030). Un solo nivel: el
-- manager del área los crea (p. ej. Sistemas -> Frontend, Backend). Un
-- empleado del área puede estar en varios. `lead_user_id` es un sub-líder
-- opcional (empleado del mismo depto) que administra los miembros y las
-- tareas de su sub-equipo.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sub_teams (
  id CHAR(24) NOT NULL PRIMARY KEY,
  department_id CHAR(24) NOT NULL,
  name VARCHAR(255) NOT NULL,
  description TEXT NULL,
  lead_user_id CHAR(24) NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_subteam_dept_name (department_id, name),
  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE,
  FOREIGN KEY (lead_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sub_team_members (
  sub_team_id CHAR(24) NOT NULL,
  user_id CHAR(24) NOT NULL,
  PRIMARY KEY (sub_team_id, user_id),
  FOREIGN KEY (sub_team_id) REFERENCES sub_teams(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
  -- Sub-equipo opcional dentro del departamento (migración 030). Al borrar el
  -- sub-equipo la tarea vuelve a ser "de área" (sub_team_id -> NULL).
  sub_team_id CHAR(24) NULL,
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
  -- Entregada fuera de plazo (migración 021): la calcula el servidor al
  -- pasar a 'completada' (completed_at > fin del día de due_date).
  completed_late TINYINT(1) NOT NULL DEFAULT 0,
  review_status ENUM('sin_revision','pendiente_revision','aprobada','rechazada') NOT NULL DEFAULT 'sin_revision',
  review_note VARCHAR(1000) NULL,
  reviewed_by CHAR(24) NULL,
  reviewed_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_dt_department (department_id, status),
  KEY idx_dt_parent (parent_id),
  KEY idx_dt_assigned (assigned_to),
  KEY idx_dt_subteam (sub_team_id),
  FOREIGN KEY (parent_id) REFERENCES dept_tasks(id) ON DELETE CASCADE,
  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE,
  FOREIGN KEY (sub_team_id) REFERENCES sub_teams(id) ON DELETE SET NULL,
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

-- ----------------------------------------------------------------------------
-- Anuncios internos de la empresa (migraciones 014 y 015, ver
-- hive-backend/internal_announcements.php). El DIRECTOR publica un anuncio y
-- TODA la audiencia lo recibe INMEDIATAMENTE (no hay ventana de vigencia). Lo
-- relevante es la fecha de la reunión, event_at. scope='general' (toda la
-- empresa) o 'areas' (departamentos en internal_announcement_areas y sus
-- managers). Si requires_confirmation=1 (una reunión), el resto confirma
-- asistencia (sí/no); quien confirma "sí" recibe un recordatorio recurrente
-- (uno al día) hasta que llegue event_at — ver internal_announcement_reminders.
-- El director ve el historial de visualizaciones y confirmaciones, y puede
-- editar o eliminar el anuncio.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS internal_announcements (
  id CHAR(24) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  scope ENUM('general','areas') NOT NULL DEFAULT 'general',
  requires_confirmation TINYINT(1) NOT NULL DEFAULT 0,
  event_at DATETIME NULL,
  location_label VARCHAR(255) NULL,
  created_by CHAR(24) NOT NULL,
  -- Evento del calendario que generó este anuncio (migración 024); NULL si el
  -- director lo publicó directamente. UNIQUE: un evento => un anuncio.
  event_id CHAR(24) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_ia_event (event_at),
  UNIQUE KEY uq_ia_event (event_id),
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS internal_announcement_areas (
  announcement_id CHAR(24) NOT NULL,
  department_id CHAR(24) NOT NULL,
  PRIMARY KEY (announcement_id, department_id),
  FOREIGN KEY (announcement_id) REFERENCES internal_announcements(id) ON DELETE CASCADE,
  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS internal_announcement_views (
  announcement_id CHAR(24) NOT NULL,
  user_id CHAR(24) NOT NULL,
  viewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (announcement_id, user_id),
  FOREIGN KEY (announcement_id) REFERENCES internal_announcements(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS internal_announcement_confirmations (
  announcement_id CHAR(24) NOT NULL,
  user_id CHAR(24) NOT NULL,
  status ENUM('si','no') NOT NULL DEFAULT 'si',
  responded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (announcement_id, user_id),
  FOREIGN KEY (announcement_id) REFERENCES internal_announcements(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Marca de recordatorio ya enviado (una fila por día) a quien confirmó
-- asistencia, para no duplicar el aviso recurrente del mismo día. Lo llena
-- ia_dispatch_due_reminders() de forma perezosa (al consultar notificaciones)
-- o el cron opcional cron_announcement_reminders.php.
CREATE TABLE IF NOT EXISTS internal_announcement_reminders (
  announcement_id CHAR(24) NOT NULL,
  user_id CHAR(24) NOT NULL,
  reminder_date DATE NOT NULL,
  sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (announcement_id, user_id, reminder_date),
  FOREIGN KEY (announcement_id) REFERENCES internal_announcements(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
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

CREATE TABLE IF NOT EXISTS team_socials (
  id INT NOT NULL AUTO_INCREMENT,
  team_id INT NOT NULL,
  label VARCHAR(50) NOT NULL,
  icon VARCHAR(50) NOT NULL,
  url VARCHAR(1000) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY team_id (team_id),
  CONSTRAINT team_socials_ibfk_1 FOREIGN KEY (team_id) REFERENCES radio_team (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Caja "Comentarios en vivo" del hero de Inicio, en tiempo real. Los
-- comentarios se agrupan por franja horaria (la hora en punto del servidor)
-- y RADIODOLIV_PAGINA/inc/data/live_comments.php borra los de franjas ya
-- cerradas, así que la caja se reinicia sola cada hora.
CREATE TABLE IF NOT EXISTS radio_live_comments (
  id BIGINT NOT NULL AUTO_INCREMENT,
  name VARCHAR(60) NOT NULL,
  body VARCHAR(240) NOT NULL,
  client_id VARCHAR(40) DEFAULT NULL COMMENT 'Id aleatorio del navegador desde localStorage, solo para anti-flood',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY created_at (created_at)
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
