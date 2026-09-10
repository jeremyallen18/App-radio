-- Migración: blindaje de concurrencia (Radio Doliv).
-- Aplicar una sola vez sobre hive_db. Ver hive-backend/schema.sql para el
-- esquema completo ya actualizado.
--
-- Contexto: varios handlers hacían "SELECT ... ; if (existe) fail(); INSERT"
-- sin transacción ni restricción única. Dos peticiones simultáneas del mismo
-- usuario (doble toque, reintento de red, dos dispositivos) podían pasar
-- ambas la comprobación y duplicar la fila. Estos índices únicos hacen la
-- inserción atómica: la segunda petición falla con SQLSTATE 23000 y el PHP
-- lo traduce al mismo mensaje de negocio (attendance.php / leave_requests.php).
--
-- Requiere que no existan duplicados previos. En una instalación con datos
-- reales, deduplicar antes:
--   -- asistencia (deja el evento más antiguo de cada tipo/día):
--   DELETE a FROM attendance a JOIN attendance b
--     ON a.employee_id=b.employee_id AND a.work_date=b.work_date
--    AND a.type=b.type AND a.id>b.id;
--   -- solicitudes pendientes duplicadas: cancelar todas menos la más antigua
--   -- a mano según el caso.

USE hive_db;

-- 1) Asistencia: cada tipo de evento es único por (trabajador, día).
--    Hoy los tipos son entrada / inicio_comida / fin_comida / salida /
--    sin_comida, y todos ocurren como máximo una vez al día.
ALTER TABLE attendance
  ADD UNIQUE KEY uq_attendance_evento (employee_id, work_date, type);

-- 2) Solicitudes de corrección de fichaje: solo UNA pendiente por
--    (trabajador, día, tipo de fichaje). Tras resolverse (aprobada/rechazada)
--    se puede volver a solicitar, así que la unicidad se limita a las
--    pendientes mediante una columna generada: pending_slot vale 1 mientras
--    está pendiente y NULL en cualquier otro estado (NULL no colisiona en un
--    índice UNIQUE).
ALTER TABLE attendance_correction_requests
  ADD COLUMN pending_slot TINYINT
    GENERATED ALWAYS AS (IF(status = 'pendiente', 1, NULL)) VIRTUAL,
  ADD UNIQUE KEY uq_acr_pendiente (employee_id, work_date, kind, pending_slot);

-- 3) Permisos / vacaciones / incapacidades: impide el doble envío accidental
--    de una solicitud idéntica (mismo tipo y mismo rango solicitado) mientras
--    siga pendiente. Mismo patrón de columna generada.
ALTER TABLE leave_requests
  ADD COLUMN pending_slot TINYINT
    GENERATED ALWAYS AS (IF(status = 'pendiente', 1, NULL)) VIRTUAL,
  ADD UNIQUE KEY uq_leave_pendiente
    (employee_id, type, requested_start_date, requested_end_date, pending_slot);
