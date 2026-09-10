-- 031: tolerancia de retardo configurable por empleado + tabla de deduplicación
-- de recordatorios de asistencia. Ver
-- docs/superpowers/specs/2026-09-08-attendance-windows-reminders-design.md

ALTER TABLE employee_schedules
  ADD COLUMN late_tolerance_minutes INT NOT NULL DEFAULT 15 AFTER meal_max_minutes;

ALTER TABLE attendance_schedule_snapshots
  ADD COLUMN late_tolerance_minutes INT NOT NULL DEFAULT 15 AFTER meal_max_minutes;

-- Un aviso por (trabajador, día, tipo). El INSERT que viole la PK indica
-- "ya enviado" y el despachador lo salta. kind ∈
-- entry_pre | entry_late | meal_pre | exit_due | exit_late
CREATE TABLE IF NOT EXISTS attendance_reminders_sent (
  employee_id CHAR(24)    NOT NULL,
  work_date   DATE        NOT NULL,
  kind        VARCHAR(16) NOT NULL,
  sent_at     DATETIME    NOT NULL,
  PRIMARY KEY (employee_id, work_date, kind),
  FOREIGN KEY (employee_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
