-- Migración: chat privado 1 a 1 entre dos personas (getDirectChat /
-- sendDirectMessage en hive-backend/index.php). Reutiliza la tabla
-- `chat_messages` que ya usa el chat por equipo: para un mensaje directo,
-- team_id queda NULL y la nueva columna recipient_email identifica al
-- destinatario (username sigue siendo el remitente, igual que en el chat
-- de equipo). `hive-backend/schema.sql` ya trae esta columna desde el
-- inicio, así que instalaciones nuevas no necesitan correr esto. Solo para
-- bases de datos existentes creadas antes de que existiera.
--
-- Aplicar una sola vez sobre hive_db, después de 001-006.
USE hive_db;

SET @col_exists = (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'chat_messages'
    AND COLUMN_NAME = 'recipient_email'
);
SET @sql = IF(@col_exists = 0,
  'ALTER TABLE chat_messages ADD COLUMN recipient_email VARCHAR(255) NULL AFTER username',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists = (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'chat_messages'
    AND INDEX_NAME = 'idx_chat_messages_direct'
);
SET @sql = IF(@idx_exists = 0,
  'ALTER TABLE chat_messages ADD KEY idx_chat_messages_direct (recipient_email, username, id)',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
