-- Migración: justificación de faltas pasadas (Radio Doliv).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado.
--
-- Contexto: una "falta" es un día laboral (lun-sáb) ya pasado sin registro de
-- asistencia y sin permiso aprobado (attendance.php la cuenta como
-- `faltaInjustificada`). No existía forma de justificarla. Esta tabla guarda
-- la justificación del trabajador (motivo + evidencia OBLIGATORIA) y su
-- revisión por el director. Una justificación APROBADA hace que esos días
-- dejen de contar como falta injustificada.
--
-- La evidencia se guarda con la misma tubería que la de permisos
-- (leave_store_evidence -> EVIDENCE_DIR privado) y solo se sirve por el
-- endpoint autenticado GET /absences/justifications/{id}/evidence.

USE hive_db;

CREATE TABLE IF NOT EXISTS absence_justifications (
  id CHAR(24) PRIMARY KEY,
  employee_id CHAR(24) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  reason VARCHAR(1000) NULL,
  evidence_path VARCHAR(255) NULL,
  evidence_mime VARCHAR(100) NULL,
  status ENUM('pendiente','aprobada','rechazada') NOT NULL DEFAULT 'pendiente',
  review_note VARCHAR(1000) NULL,
  reviewed_by CHAR(24) NULL,
  reviewed_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  -- Una sola justificación por (trabajador, rango exacto): backstop de
  -- concurrencia contra el doble envío.
  UNIQUE KEY uq_absence_just (employee_id, start_date, end_date),
  KEY idx_aj_employee (employee_id, start_date),
  KEY idx_aj_status (status)
) ENGINE=InnoDB;
