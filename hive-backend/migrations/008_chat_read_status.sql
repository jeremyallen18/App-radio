-- Migración: estado de "leído" por chat (tabla chat_reads), para poder
-- mostrar mensajes sin leer al estilo WhatsApp en /chat/list (badge en la
-- lista de "Mensajes" y en el botón "Mensajes" del inicio). Ver
-- hive-backend/index.php: listChats() y markChatRead().
-- `hive-backend/schema.sql` ya trae esta tabla desde el inicio, así que
-- instalaciones nuevas no necesitan correr esto. Solo para bases de datos
-- existentes creadas antes de que existiera.
--
-- Aplicar una sola vez sobre hive_db, después de 001-007.
USE hive_db;

CREATE TABLE IF NOT EXISTS chat_reads (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_email VARCHAR(255) NOT NULL,
  chat_key VARCHAR(300) NOT NULL,
  last_read_at TIMESTAMP NOT NULL,
  UNIQUE KEY uniq_chat_read (user_email, chat_key)
) ENGINE=InnoDB;
