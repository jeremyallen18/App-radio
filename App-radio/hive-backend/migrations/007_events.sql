-- Migración: eventos del calendario (Radio Doliv).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado (instalaciones nuevas parten de ahí).
--
-- El DIRECTOR crea eventos. Un evento es 'general' (visible para toda la
-- empresa) o 'areas' (visible solo para los miembros de los departamentos
-- listados en event_areas — y, por tener department_id, también sus managers).
--
-- Si has_location = 1, el evento lleva ubicación (lat/lng + radio) y una
-- hora de entrada. Ese día, para los miembros de las áreas asignadas, la
-- ENTRADA de asistencia se registra contra la ubicación y la hora del evento
-- en vez de la geocerca global (ver attendance.php ->
-- event_entry_override_for_day). La salida y la hora de comida no cambian.
-- Las áreas NO incluidas no se enteran y su asistencia sigue igual.
USE hive_db;

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
  -- Override de la hora de entrada de asistencia ese día (solo áreas asignadas).
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
