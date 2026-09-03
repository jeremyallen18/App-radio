-- Migración: mensajería directa 1 a 1 entre compañeros (Radio Doliv).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado.
--
-- Antes, `chat_messages` era una única sala global: una fila por mensaje con
-- solo `username` (texto libre) y `message`, y GET /chat/getAllChats devolvía
-- TODAS las filas a cualquier usuario autenticado. La app, en cambio, abría el
-- chat "por compañero" (desde el directorio, el equipo y el tablero), dando a
-- entender que eran conversaciones privadas. Resultado: todo lo que escribía
-- cualquiera lo podían leer los ~N usuarios de la empresa.
--
-- Esta migración reconstruye `chat_messages` como conversaciones privadas
-- entre dos personas:
--   - sender_id / recipient_id: FK reales a users(id).
--   - conversation_key: los dos ids ordenados y unidos por ':' (49 chars).
--     Permite resolver "la conversación entre A y B" con un índice, sin
--     importar quién escribió cada mensaje.
--   - read_at: marca de lectura, para el contador de no leídos del inbox.
--
-- Las 2 filas de la sala global vieja (datos de prueba: "Hey", "hola amigos")
-- se conservan en `chat_messages_legacy_global` por si hiciera falta
-- revisarlas; ningún código las vuelve a leer.

USE hive_db;

DROP TABLE IF EXISTS chat_messages_legacy_global;
RENAME TABLE chat_messages TO chat_messages_legacy_global;

CREATE TABLE IF NOT EXISTS chat_messages (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  conversation_key CHAR(49) NOT NULL,
  sender_id CHAR(24) NOT NULL,
  recipient_id CHAR(24) NOT NULL,
  body TEXT NOT NULL,
  read_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_cm_convo (conversation_key, id),
  KEY idx_cm_inbox (recipient_id, read_at),
  KEY idx_cm_sender (sender_id, id),
  FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (recipient_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
