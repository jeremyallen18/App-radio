-- Migración: limpieza automática de cuentas sin verificar (Radio Doliv).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado.
--
-- Contexto: una cuenta que se registra y nunca abre el enlace de
-- verificación se conserva como máximo 72 h (UNVERIFIED_ACCOUNT_TTL_HOURS en
-- helpers.php). Pasado ese plazo la borra cleanup_unverified_accounts():
--   - de forma perezosa en cada alta nueva (signup), y
--   - por el cron cron_cleanup_unverified.php (diario en el host).
-- NUNCA toca cuentas verificadas (la condición es email_verified_at IS NULL).
--
-- Esta migración solo añade el índice que hace barato ese barrido; no cambia
-- ninguna columna ni borra datos.

USE hive_db;

ALTER TABLE users
  ADD KEY idx_users_unverified (email_verified_at, created_at);
