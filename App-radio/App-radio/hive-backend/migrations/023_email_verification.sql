-- Migración: verificación de correo al registrarse (Radio Doliv).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado.
--
-- Contexto: al crear una cuenta no se comprobaba que el correo fuera real.
-- Ahora el registro genera un token de verificación (aleatorio, de un solo
-- uso, con caducidad de 24 h) que se envía por correo; hasta que el usuario
-- abre el enlace, la cuenta NO se considera verificada. El login NO se
-- bloquea (se puede entrar), pero la app muestra un aviso con opción de
-- reenviar el correo, y algunas acciones (crear permisos / justificar
-- faltas) exigen la verificación.
--
-- Seguridad: en `email_verifications` solo se guarda el hash SHA-256 del
-- token, nunca el token en claro. El token va únicamente en el enlace del
-- correo.

USE hive_db;

-- 1) Marca de verificación en la cuenta.
ALTER TABLE users
  ADD COLUMN email_verified_at DATETIME NULL AFTER otp_verified;

-- 2) Las cuentas que YA existían se dan por verificadas: nadie que ya usaba
--    la app debe quedar atrapado tras el aviso de "verifica tu correo".
UPDATE users SET email_verified_at = created_at WHERE email_verified_at IS NULL;

-- 3) Tokens de verificación emitidos. Un solo uso (consumed_at) y con
--    caducidad (expires_at). Al reenviar se borran los pendientes previos.
CREATE TABLE IF NOT EXISTS email_verifications (
  id CHAR(24) PRIMARY KEY,
  user_id CHAR(24) NOT NULL,
  token_hash CHAR(64) NOT NULL,
  expires_at DATETIME NOT NULL,
  consumed_at DATETIME NULL,
  requested_ip VARCHAR(45) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_ev_token (token_hash),
  KEY idx_ev_user (user_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
