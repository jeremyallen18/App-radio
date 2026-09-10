-- Migración: los anuncios internos dejan de tener ventana de vigencia.
-- Aplicar una sola vez sobre hive_db (después de 014). Ver
-- hive-backend/schema.sql para el esquema completo ya actualizado.
--
-- Cambio de diseño: el anuncio se recibe INMEDIATAMENTE al publicarlo (no hay
-- fecha de inicio ni de fin ni límite de duración). Lo relevante es la fecha
-- de la reunión (event_at). Cuando alguien confirma asistencia, recibe un
-- recordatorio recurrente (una notificación al día) hasta que llegue la
-- reunión; internal_announcement_reminders evita duplicar el recordatorio del
-- mismo día.
USE hive_db;

ALTER TABLE internal_announcements
  DROP COLUMN starts_on,
  DROP COLUMN ends_on,
  ADD KEY idx_ia_event (event_at);

CREATE TABLE IF NOT EXISTS internal_announcement_reminders (
  announcement_id CHAR(24) NOT NULL,
  user_id CHAR(24) NOT NULL,
  reminder_date DATE NOT NULL,
  sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (announcement_id, user_id, reminder_date),
  FOREIGN KEY (announcement_id) REFERENCES internal_announcements(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
