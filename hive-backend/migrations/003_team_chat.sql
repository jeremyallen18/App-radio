-- Migración: chat por equipo. `hive-backend/schema.sql` ya trae
-- `chat_messages.team_id` desde el inicio, así que instalaciones nuevas no
-- necesitan esto. Esta migración es solo para bases de datos existentes
-- creadas antes de que esa columna existiera (chat global sin team_id).
--
-- Aplicar una sola vez sobre hive_db, después de 001 y 002.
USE hive_db;

-- MySQL no soporta `ADD COLUMN IF NOT EXISTS` en todas las versiones que
-- puede haber en producción, así que se revisa primero con INFORMATION_SCHEMA
-- para que la migración se pueda correr sin reventar si la columna ya existe.
SET @col_exists = (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'chat_messages'
    AND COLUMN_NAME = 'team_id'
);

SET @sql = IF(@col_exists = 0,
  'ALTER TABLE chat_messages ADD COLUMN team_id CHAR(24) NULL AFTER id',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Los mensajes viejos sin team_id no van a aparecer en ningún chat de
-- equipo (el chat global anterior ya no existe); se dejan como están para
-- no perder el histórico, simplemente quedan huérfanos.
