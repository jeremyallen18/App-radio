-- Migración: tabla de anuncios del sitio público (RADIODOLIV_PAGINA).
-- Aplicar una sola vez sobre hive_db. Ambos proyectos (App-radio y
-- RADIODOLIV_PAGINA) comparten esta base de datos a partir de aquí.
USE hive_db;

CREATE TABLE IF NOT EXISTS anuncios (
  id INT AUTO_INCREMENT PRIMARY KEY,
  titulo VARCHAR(255) NOT NULL,
  descripcion TEXT NULL,
  imagen_url VARCHAR(500) NULL,
  link_web VARCHAR(500) NULL,
  link_facebook VARCHAR(500) NULL,
  link_whatsapp VARCHAR(500) NULL,
  fecha_publicacion DATE NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
