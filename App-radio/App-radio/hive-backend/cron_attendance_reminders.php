<?php
// Cron de recordatorios de asistencia. DEBE ejecutarse cada 5 minutos para que
// los avisos (entrada, hora de comida 15 min antes, salida) lleguen a tiempo.
//
// Hostinger -> Cron Jobs:
//   */5 * * * *  /usr/bin/php /home/USUARIO/domains/.../hive-backend/cron_attendance_reminders.php
//
// En local:  C:\xampp\php\php.exe cron_attendance_reminders.php
//
// Es idempotente: cada (trabajador, día, tipo de aviso) se emite una sola vez
// (attendance_reminders_sent). También se dispara de forma perezosa cuando el
// trabajador abre "Mi asistencia" (GET /attendance/today), así que sin este cron
// los avisos siguen llegando, pero solo si el trabajador abre la app.

require __DIR__ . '/config.php';
require __DIR__ . '/helpers.php';
require __DIR__ . '/leave_requests.php';
require __DIR__ . '/attendance.php';
require __DIR__ . '/attendance_reminders.php';

$n = attendance_dispatch_due_reminders($pdo, null);
fwrite(STDOUT, date('c') . "  recordatorios de asistencia emitidos: $n\n");
