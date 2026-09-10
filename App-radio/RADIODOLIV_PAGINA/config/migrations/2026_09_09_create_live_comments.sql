-- Tabla de la caja "Comentarios en vivo" del hero de Inicio.
-- Comparte la BD hive_db con App-radio/hive-backend.
--
-- Los comentarios son efímeros: pertenecen a la "franja" de la hora en punto
-- y inc/data/live_comments.php borra los de franjas cerradas en cada
-- lectura/escritura (no hace falta cron). Por eso no se siembran datos aquí.

CREATE TABLE IF NOT EXISTS radio_live_comments (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(60) NOT NULL,
    body VARCHAR(240) NOT NULL,
    client_id VARCHAR(40) DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_live_comments_created_at (created_at),
    KEY idx_live_comments_client (client_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
