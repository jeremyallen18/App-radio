-- Migración: redes sociales por integrante del equipo (hive_db compartida).
-- Mismo patrón que sponsors/sponsor_socials (ver 2026_08_06_create_sponsors.sql):
-- una fila por red social, borrado en cascada al eliminar al integrante.

CREATE TABLE IF NOT EXISTS `team_socials` (
  `id` int NOT NULL AUTO_INCREMENT,
  `team_id` int NOT NULL,
  `label` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `icon` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `url` varchar(1000) COLLATE utf8mb4_unicode_ci NOT NULL,
  `sort_order` int NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `team_id` (`team_id`),
  CONSTRAINT `team_socials_ibfk_1` FOREIGN KEY (`team_id`) REFERENCES `radio_team` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
