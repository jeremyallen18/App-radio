-- Migración: arregla retroactivamente a los miembros de equipo que se
-- agregaron desde "Gestionar miembros" (POST /team/addMember) antes de este
-- fix. Ese endpoint solo insertaba en team_members y nunca en
-- domain_members, así que esas personas quedaban visibles en "Miembros del
-- equipo" pero invisibles para asignarles tareas en cualquier área (el
-- selector de addTask.dart arma la lista de "Asignar a" desde
-- domain_members, no desde team_members).
--
-- Esto los agrega a todas las áreas de su equipo, igual que ahora hace
-- addMember() para los miembros nuevos. Es seguro correrla más de una vez:
-- solo inserta las combinaciones (domain_id, email) que todavía no existan.
--
-- Aplicar una sola vez sobre hive_db, después de 001, 002, 003 y 004.
USE hive_db;

INSERT INTO domain_members (domain_id, email)
SELECT d.id, tm.email
FROM team_members tm
JOIN domains d ON d.team_id = tm.team_id
LEFT JOIN domain_members dm ON dm.domain_id = d.id AND dm.email = tm.email
WHERE dm.id IS NULL;
