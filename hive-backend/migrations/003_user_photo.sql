-- Migración: foto de perfil del usuario.
-- Aplicar una sola vez sobre hive_db.
USE hive_db;

ALTER TABLE users ADD COLUMN photo_path VARCHAR(500) NULL AFTER position;
