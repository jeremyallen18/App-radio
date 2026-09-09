-- Migración: múltiples admins por equipo. Antes un equipo tenía un único
-- "líder" (columna teams.leader_email). Ahora un equipo puede tener varios
-- admins con los mismos permisos (agregar/sacar miembros, gestionar tareas,
-- borrar el equipo, y poner o quitar a otros admins).
--
-- `hive-backend/schema.sql` ya trae la tabla team_admins desde el inicio,
-- así que instalaciones nuevas no necesitan correr esto. Solo para bases de
-- datos existentes creadas antes de este cambio.
--
-- Aplicar una sola vez sobre hive_db, después de 001-010.
--
-- teams.leader_email se conserva (no se borra la columna): sigue
-- funcionando como respaldo de compatibilidad si por algún motivo
-- team_admins queda vacía para un equipo, y el endpoint legado
-- POST /team/leaderResign/{teamId} la sigue actualizando.
USE hive_db;

CREATE TABLE IF NOT EXISTS team_admins (
  id INT AUTO_INCREMENT PRIMARY KEY,
  team_id CHAR(24) NOT NULL,
  email VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_team_admin (team_id, email),
  FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Backfill: cada equipo existente pasa a tener a su antiguo líder como
-- único admin inicial. A partir de aquí, cualquier admin puede agregar más
-- admins desde la app (POST /team/addAdmin/{teamId}).
INSERT IGNORE INTO team_admins (team_id, email)
SELECT id, leader_email FROM teams;
