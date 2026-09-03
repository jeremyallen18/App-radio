-- Migración: destino estructurado de las notificaciones (Radio Doliv).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado.
--
-- Contexto: al tocar una notificación la app solo la marcaba como leída, sin
-- llevar a ningún sitio. El texto libre de `message` no basta para saber a
-- qué pantalla ir. Estas dos columnas (ambas opcionales) guardan el tipo de
-- entidad referida y su id, para que el cliente pueda abrir la pantalla
-- correcta. Son NULLables: las notificaciones antiguas y las que no
-- referencian una entidad concreta siguen funcionando (el cliente cae al
-- destino por categoría según `type`).

USE hive_db;

ALTER TABLE notifications
  ADD COLUMN entity_type VARCHAR(32) NULL AFTER type,
  ADD COLUMN entity_id   VARCHAR(64) NULL AFTER entity_type;
