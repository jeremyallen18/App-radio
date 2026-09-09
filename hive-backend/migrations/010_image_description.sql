-- Migración: agrega la columna `img_description` a `images`, usada por el
-- nuevo campo de descripción del apartado "Imágenes" de Resource Manager
-- (antes solo se podía poner un nombre). `hive-backend/schema.sql` ya la
-- trae desde el inicio, así que instalaciones nuevas no necesitan correr
-- esto. Solo para bases de datos existentes.
--
-- Aplicar una sola vez sobre hive_db, después de 001-009.
USE hive_db;

ALTER TABLE images
  ADD COLUMN img_description TEXT NULL AFTER img_name;
