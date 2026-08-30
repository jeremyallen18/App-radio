-- Migración: asistencia y hora de comida de empleados (Radio Doliv).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado (instalaciones nuevas parten de ahí).
--
-- Diseño basado en eventos inmutables: cada acción del empleado (entrada,
-- inicio_comida, fin_comida, salida) crea una fila nueva en `attendance` y
-- nunca se sobrescribe. El horario asignado vive en `employee_schedules` y
-- se CONGELA por día en `attendance_schedule_snapshots` la primera vez que
-- el empleado registra entrada, para que un cambio de horario posterior no
-- altere el histórico (llegada tarde / exceso de comida ya calculados).
--
-- El director NUNCA tiene filas aquí: el backend (attendance.php) rechaza
-- cualquier operación de asistencia cuyo rol no sea 'employee'.
USE hive_db;

CREATE TABLE IF NOT EXISTS attendance (
  id INT AUTO_INCREMENT PRIMARY KEY,
  employee_id CHAR(24) NOT NULL,
  type ENUM('entrada','inicio_comida','fin_comida','salida') NOT NULL,
  work_date DATE NOT NULL,
  -- Marca oficial generada por el servidor (nunca el reloj del dispositivo).
  event_time DATETIME NOT NULL,
  -- Marca enviada por el dispositivo: solo diagnóstico, nunca autoritativa.
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

-- Correcciones administrativas: NO se expone todavía en la UI, pero la tabla
-- existe para que una corrección nunca sobrescriba el evento original —
-- guarda quién, cuándo y el antes/después (sección 20 del alcance).
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
