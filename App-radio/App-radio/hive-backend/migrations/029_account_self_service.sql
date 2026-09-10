-- Migración: autoservicio de cuenta (Radio Doliv).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado.
--
-- Contexto: la pantalla "Editar cuenta" deja al usuario cambiar su nombre y
-- su contraseña (con la contraseña actual), y pedir el cambio de su correo.
-- El correo NO cambia al instante: se guarda como pendiente y solo se aplica
-- cuando el usuario abre el enlace de verificación enviado a la dirección
-- nueva (lo procesa verifyEmail() en auth.php, reusando email_verifications).
--
--   users.pending_email            -> correo nuevo a la espera de confirmarse.
--   email_verifications.new_email  -> si no es NULL, esa fila confirma un
--                                     cambio de correo, no el alta.

USE hive_db;

ALTER TABLE users
  ADD COLUMN pending_email VARCHAR(255) NULL AFTER email;

ALTER TABLE email_verifications
  ADD COLUMN new_email VARCHAR(255) NULL AFTER user_id;
