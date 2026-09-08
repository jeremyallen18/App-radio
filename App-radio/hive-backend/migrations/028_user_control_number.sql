-- Migración: número de control de cada usuario (Radio Doliv).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado.
--
-- Contexto: cada persona tiene un identificador único e intransferible con el
-- formato SPPRD-0000000 (prefijo fijo + entero con relleno a 7 dígitos, que
-- crece si la empresa supera 9 999 999 personas). El alta lo autoasigna
-- (assign_next_control_number() en helpers.php, llamado desde signup()); solo
-- el director lo edita, para corregir inconsistencias (setControlNumber() en
-- users.php, POST /user/{id}/control-number).
--
-- Esta migración añade la columna y hace el backfill de las cuentas que ya
-- existen, en orden de antigüedad: la más antigua es SPPRD-0000001.

USE hive_db;

ALTER TABLE users
  ADD COLUMN control_number VARCHAR(20) NULL UNIQUE AFTER position;

SET @n := 0;
UPDATE users
SET control_number = CONCAT('SPPRD-', LPAD((@n := @n + 1), 7, '0'))
ORDER BY created_at ASC, id ASC;
