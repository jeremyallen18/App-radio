-- Migración: agrega users.photo_path para la foto de perfil, subida vía
-- POST /user/updatePhoto y usada en el perfil y en las burbujas del chat
-- en lugar de la inicial (tipo WhatsApp).
-- `hive-backend/schema.sql` ya la trae desde el inicio, así que
-- instalaciones nuevas no necesitan correr esto. Solo para bases de datos
-- existentes.
--
-- Aplicar una sola vez sobre hive_db, después de 001-005.
USE hive_db;

-- Igual que en 004: se revisa primero con INFORMATION_SCHEMA para que la
-- migración se pueda correr sin reventar si la columna ya existe.
SET @col_exists = (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'users'
    AND COLUMN_NAME = 'photo_path'
);
SET @sql = IF(@col_exists = 0,
  'ALTER TABLE users ADD COLUMN photo_path VARCHAR(500) NULL AFTER position',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
