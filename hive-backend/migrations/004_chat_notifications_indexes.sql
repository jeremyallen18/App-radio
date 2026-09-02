-- Migración: índices que aceleran el chat por equipo (filtra por team_id en
-- cada carga) y la limpieza de notificaciones al borrar un equipo.
-- `hive-backend/schema.sql` ya los trae desde el inicio, así que instalaciones
-- nuevas no necesitan correr esto. Solo para bases de datos existentes.
--
-- Aplicar una sola vez sobre hive_db, después de 001, 002 y 003.
USE hive_db;

-- MySQL no soporta `ADD INDEX IF NOT EXISTS` en todas las versiones que
-- puede haber en producción, así que se revisa primero con INFORMATION_SCHEMA
-- para que la migración se pueda correr sin reventar si el índice ya existe.
SET @idx_exists = (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'chat_messages'
    AND INDEX_NAME = 'idx_chat_messages_team'
);
SET @sql = IF(@idx_exists = 0,
  'ALTER TABLE chat_messages ADD KEY idx_chat_messages_team (team_id, id)',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists = (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'notifications'
    AND INDEX_NAME = 'idx_notifications_team'
);
SET @sql = IF(@idx_exists = 0,
  'ALTER TABLE notifications ADD KEY idx_notifications_team (team_id)',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
