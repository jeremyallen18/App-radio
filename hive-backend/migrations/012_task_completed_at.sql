-- Migración: responder a un mensaje puntual dentro del chat (de equipo o
-- directo). Agrega `chat_messages.reply_to_id`, que apunta al `id` del
-- mensaje citado (NULL si el mensaje no responde a nada).
-- `hive-backend/schema.sql` ya trae esta columna desde el inicio, así que
-- instalaciones nuevas no necesitan correr esto. Solo para bases de datos
-- existentes creadas antes de que existiera.
--
-- Aplicar una sola vez sobre hive_db, después de 001-011.
USE hive_db;

SET @col_exists = (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'chat_messages'
    AND COLUMN_NAME = 'reply_to_id'
);
SET @sql = IF(@col_exists = 0,
  'ALTER TABLE chat_messages ADD COLUMN reply_to_id INT NULL AFTER message',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists = (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'chat_messages'
    AND INDEX_NAME = 'idx_chat_messages_reply'
);
SET @sql = IF(@idx_exists = 0,
  'ALTER TABLE chat_messages ADD KEY idx_chat_messages_reply (reply_to_id)',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;