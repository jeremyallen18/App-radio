-- Migración: solicitudes de corrección de asistencia (Radio Doliv).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado.
--
-- Flujo: el EMPLEADO reporta un fichaje que olvidó o quedó mal ("olvidé
-- marcar salida el 25", "entré a las 9:05 pero marqué 9:40"). El manager de
-- su departamento (o el director) aprueba o rechaza. Al aprobar, el backend
-- crea o ajusta la fila de `attendance` correspondiente (nunca se borran
-- eventos; se ajusta la hora o se inserta el que faltaba) y enlaza la
-- solicitud con esa fila (`attendance_id`).
--
-- Es una tabla nueva. `attendance_corrections` (bitácora de correcciones
-- manuales del admin) queda como está, sin uso todavía.
USE hive_db;

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
