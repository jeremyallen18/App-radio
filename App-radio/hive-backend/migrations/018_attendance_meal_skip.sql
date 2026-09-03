-- Migración: "No tomaré hora de comida" como evento propio (Radio Doliv).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado.
--
-- Contexto: antes, el trabajador que no tomaba hora de comida solo tenía en la
-- app un botón que registraba DIRECTAMENTE la salida ("No tomaré hora de comida
-- · Registrar salida"). Eso mezclaba dos operaciones independientes: renunciar
-- a la comida y cerrar la jornada.
--
-- Con este evento `sin_comida`, declarar que no se tomará la comida solo deja
-- constancia de esa decisión; NO registra salida ni cierra la jornada. El
-- trabajador sigue "en jornada" hasta que pulse explícitamente "Registrar
-- salida". El evento es inmutable como el resto y no exige ubicación.
--
-- Efecto en el ciclo de vida: en `en_jornada`, si existe `sin_comida` (igual
-- que si existe `fin_comida`) la siguiente acción disponible es `salida`, no
-- `inicio_comida`.
USE hive_db;

ALTER TABLE attendance
  MODIFY type ENUM('entrada','inicio_comida','fin_comida','salida','sin_comida') NOT NULL;
