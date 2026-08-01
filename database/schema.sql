-- ============================================================================
-- Team Management App — esquema MySQL
-- ============================================================================
-- Refleja el modelo de datos que consume el frontend Flutter (lib/) contra
-- el backend "hive-backend" configurado en lib/utils/api_config.dart (kBaseUrl).
-- Los nombres de columna siguen, en la medida de lo posible, los mismos campos
-- que ya viajan en los payloads JSON de la app (email, teamCode, domainName,
-- assignedTo, deadline, startDate/endDate/reason, etc.) para que mapear
-- request <-> tabla sea directo.
--
-- Motor: InnoDB (soporte de FOREIGN KEY) · Charset: utf8mb4 (emojis, tildes)
-- ============================================================================

CREATE DATABASE IF NOT EXISTS team_management
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE team_management;

SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------------------------------------------------------
-- users
-- Cuenta de usuario. Usada por: signup, login, forgot password, sendName,
-- appbar (foto/nombre), y como referencia (por email) en equipos/tareas/chat.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name           VARCHAR(120)  NOT NULL,
  email          VARCHAR(190)  NOT NULL,
  password_hash  VARCHAR(255)  NOT NULL,
  photo_url      VARCHAR(500)  NULL,
  created_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- password_reset_otps
-- OTP de un solo uso para el flujo forgot_pass -> otp_verify -> new_password.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS password_reset_otps (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id     INT UNSIGNED NOT NULL,
  otp_code    VARCHAR(10)  NOT NULL,
  expires_at  DATETIME     NOT NULL,
  used_at     DATETIME     NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_otp_user FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  KEY idx_otp_user (user_id)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- teams
-- Un equipo con nombre, código de invitación único y un líder.
-- Usada por: create-team.dart (createTeam), dashboard.dart (showTeams),
-- teamDetail.dart, join_team.dart (joinTeam por teamCode).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS teams (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  team_name   VARCHAR(150) NOT NULL,
  team_code   VARCHAR(20)  NOT NULL,
  leader_id   INT UNSIGNED NOT NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
                            ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_teams_code (team_code),
  CONSTRAINT fk_teams_leader FOREIGN KEY (leader_id) REFERENCES users(id)
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- domains
-- Área/departamento dentro de un equipo (ej. Backend, Frontend, Machine
-- Learning, App Development). Usada por: create-team.dart (multi-select al
-- crear equipo), Domain-team.dart (invitar miembros por área), addTask.dart
-- y teamDetail.dart (dropdown/tarjeta de área -> domainName).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS domains (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  team_id     INT UNSIGNED NOT NULL,
  name        VARCHAR(100) NOT NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_domains_team FOREIGN KEY (team_id) REFERENCES teams(id)
    ON DELETE CASCADE,
  UNIQUE KEY uq_domain_per_team (team_id, name)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- team_members
-- Pertenencia a nivel de EQUIPO (no de área). Se crea cuando alguien se une
-- con un código (join_team.dart -> POST /team/joinTeam) y todavía no tiene
-- área asignada. Es distinta de domain_members: un usuario puede estar en
-- team_members sin estar en ningún domain_members todavía, y viceversa un
-- domain_members implica membresía del equipo (se inserta en ambas al
-- invitar por área, ver POST /team/sendTeamcode).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS team_members (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  team_id     INT UNSIGNED NOT NULL,
  user_id     INT UNSIGNED NOT NULL,
  joined_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_teammem_team FOREIGN KEY (team_id) REFERENCES teams(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_teammem_user FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  UNIQUE KEY uq_member_per_team (team_id, user_id)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- domain_members
-- Relación N:M entre usuarios y áreas (un miembro puede pertenecer a varias
-- áreas de un mismo equipo). Alimenta la lista "Miembros" de cada tarjeta de
-- área en teamDetail.dart y el dropdown de "Miembro" en addTask.dart.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS domain_members (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  domain_id   INT UNSIGNED NOT NULL,
  user_id     INT UNSIGNED NOT NULL,
  joined_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_dommem_domain FOREIGN KEY (domain_id) REFERENCES domains(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_dommem_user FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  UNIQUE KEY uq_member_per_domain (domain_id, user_id)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- tasks
-- Tarea asignada a un miembro dentro de un área. Usada por:
--   - addTask.dart          -> POST /team/task/:teamcode        (insert)
--   - teamDetail.dart        -> POST /team/taskDone              (completed=1)
--   - home_page/tasks.dart    -> GET  /team/incompleteTasks|completedTasks
-- team_id queda denormalizado junto a domain_id para poder resolver
-- "tareas de todos mis equipos" (home_page/tasks.dart) sin tener que pasar
-- siempre por domains.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tasks (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  team_id       INT UNSIGNED NOT NULL,
  domain_id     INT UNSIGNED NOT NULL,
  assigned_to   INT UNSIGNED NOT NULL,
  description   VARCHAR(255) NOT NULL,
  deadline      DATE         NOT NULL,
  completed     TINYINT(1)   NOT NULL DEFAULT 0,
  completed_at  DATETIME     NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_tasks_team FOREIGN KEY (team_id) REFERENCES teams(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_tasks_domain FOREIGN KEY (domain_id) REFERENCES domains(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_tasks_user FOREIGN KEY (assigned_to) REFERENCES users(id)
    ON DELETE CASCADE,
  KEY idx_tasks_team_completed (team_id, completed),
  KEY idx_tasks_domain_completed (domain_id, completed),
  KEY idx_tasks_assigned (assigned_to, completed)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- leave_requests
-- Solicitud de permiso de un miembro. Usada por: leave approval/leave.dart
-- (applyLeave crea la fila y devuelve _id -> leaveResult la resuelve).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS leave_requests (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  team_id     INT UNSIGNED NOT NULL,
  user_id     INT UNSIGNED NOT NULL,
  start_date  DATE         NOT NULL,
  end_date    DATE         NOT NULL,
  reason      VARCHAR(500) NOT NULL,
  status      ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  resolved_by INT UNSIGNED NULL,
  resolved_at DATETIME     NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_leave_team FOREIGN KEY (team_id) REFERENCES teams(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_leave_user FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_leave_resolver FOREIGN KEY (resolved_by) REFERENCES users(id)
    ON DELETE SET NULL,
  KEY idx_leave_team_status (team_id, status)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- chat_messages
-- Mensajería GLOBAL (el frontend actual llama GET /chat/getAllChats y
-- POST /chat/sendMessage sin ningún identificador de equipo — chat.dart no
-- envía teamId ni token en estas dos llamadas). Se deja sin FK a teams a
-- propósito para reflejar fielmente ese contrato; si en el futuro se agrega
-- team_id al payload del frontend, esta tabla es el lugar para sumarlo.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS chat_messages (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  username    VARCHAR(150) NOT NULL,
  message     TEXT         NOT NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_chat_created (created_at)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- leader_messages
-- Mensaje directo de un miembro al líder del equipo. Un mismo endpoint
-- (POST /user/sendMessage/:teamId) se reutiliza desde dos pantallas:
--   - ResourceM/Leaderassist.dart  -> pedir ayuda al líder
--   - screens/MResign.dart          -> avisar intención de renunciar
-- "correo" se guarda tal cual lo escribe el usuario en el campo de texto
-- (no siempre coincide con from_user, por eso se guarda aparte).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS leader_messages (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  team_id     INT UNSIGNED NOT NULL,
  from_user   INT UNSIGNED NOT NULL,
  correo      VARCHAR(190) NOT NULL,
  message     TEXT         NOT NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_leadermsg_team FOREIGN KEY (team_id) REFERENCES teams(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_leadermsg_user FOREIGN KEY (from_user) REFERENCES users(id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- resource_texts / resource_images
-- Recursos compartidos del equipo (ResourceM/doc.dart, getR.dart, fetchR.dart,
-- imagecc.dart). Se modelan por separado porque el backend expone dos
-- endpoints distintos (text/addText y image/addImage) con formularios propios.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS resource_texts (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  team_id     INT UNSIGNED NOT NULL,
  posted_by   INT UNSIGNED NOT NULL,
  content     TEXT         NOT NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_restext_team FOREIGN KEY (team_id) REFERENCES teams(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_restext_user FOREIGN KEY (posted_by) REFERENCES users(id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS resource_images (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  team_id     INT UNSIGNED NOT NULL,
  posted_by   INT UNSIGNED NOT NULL,
  image_name  VARCHAR(255) NULL,
  image_url   VARCHAR(500) NOT NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_resimg_team FOREIGN KEY (team_id) REFERENCES teams(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_resimg_user FOREIGN KEY (posted_by) REFERENCES users(id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- Datos de ejemplo (opcional) — descomenta para poblar un equipo de prueba.
-- ============================================================================
-- INSERT INTO users (name, email, password_hash) VALUES
--   ('Jeremi Narvaez', 'jeremi.narvaez@gmail.com', '$2y$10$examplehash');
--
-- INSERT INTO teams (team_name, team_code, leader_id) VALUES
--   ('sistemas', '8EAFPG', 1);
--
-- INSERT INTO domains (team_id, name) VALUES
--   (1, 'Backend'), (1, 'Frontend'), (1, 'Machine Learning'), (1, 'App Development');
--
-- INSERT INTO domain_members (domain_id, user_id) VALUES (1, 1);
--
-- INSERT INTO tasks (team_id, domain_id, assigned_to, description, deadline) VALUES
--   (1, 1, 1, 'Configurar el servidor', '2026-08-15');
