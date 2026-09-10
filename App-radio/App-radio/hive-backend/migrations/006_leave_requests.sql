-- Migración: permisos, vacaciones e incapacidades de empleados (Radio Doliv).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado.
--
-- Se integra con la asistencia existente: un permiso `aprobado` cuyo rango de
-- fechas aprobado cubre un día laboral hace que ese día NO requiera registro
-- de asistencia (ver attendance.php -> attendance_approved_absence()). Nunca
-- se borran eventos de asistencia para representar una ausencia.
--
-- El director revisa/aprueba; NUNCA es tratado como empleado (no tiene filas
-- aquí como solicitante). La evidencia de incapacidad se guarda en
-- hive-backend/private/evidence/ (fuera del acceso web) y solo se sirve por
-- el endpoint autenticado GET /leave-requests/{id}/evidence.
USE hive_db;

CREATE TABLE IF NOT EXISTS leave_requests (
  id CHAR(24) PRIMARY KEY,
  employee_id CHAR(24) NOT NULL,
  type ENUM('vacaciones','incapacidad','permiso') NOT NULL,

  -- Lo que pidió el empleado (inmutable tras enviar).
  requested_start_date DATE NOT NULL,
  requested_end_date DATE NOT NULL,
  requested_days INT NOT NULL,

  -- Lo que autorizó el director (puede diferir del rango solicitado).
  approved_start_date DATE NULL,
  approved_end_date DATE NULL,
  approved_days INT NULL,

  reason VARCHAR(1000) NULL,
  status ENUM('pendiente','aprobado','rechazado','cancelado') NOT NULL DEFAULT 'pendiente',

  -- Solo el nombre de archivo privado, nunca una URL pública.
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
