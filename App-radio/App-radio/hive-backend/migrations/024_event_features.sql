-- Migración: funciones de eventos del director (Radio Doliv).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado.
--
-- 1) events.location_text  — lugar del evento en texto libre, para CUALQUIER
--    evento (independiente de la geocerca has_location).
-- 2) events.reminder_offsets — CSV de días de antelación para los
--    recordatorios automáticos (por defecto "7,5,3,2").
-- 3) internal_announcements.event_id — enlaza el anuncio interno que se
--    publica automáticamente cuando existe un evento. UNIQUE: un evento
--    genera como mucho un anuncio; al editar el evento se actualiza ese
--    mismo anuncio, al borrarlo se borra.
-- 4) event_reminders_sent — control de idempotencia de los recordatorios:
--    una fila por (evento, antelación, usuario) ya avisado.

USE hive_db;

ALTER TABLE events
  ADD COLUMN location_text VARCHAR(255) NULL AFTER location_label,
  ADD COLUMN reminder_offsets VARCHAR(50) NOT NULL DEFAULT '7,5,3,2' AFTER location_text;

ALTER TABLE internal_announcements
  ADD COLUMN event_id CHAR(24) NULL AFTER created_by,
  ADD UNIQUE KEY uq_ia_event (event_id),
  ADD CONSTRAINT fk_ia_event FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;

CREATE TABLE IF NOT EXISTS event_reminders_sent (
  event_id CHAR(24) NOT NULL,
  offset_days INT NOT NULL,
  user_id CHAR(24) NOT NULL,
  sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (event_id, offset_days, user_id),
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
