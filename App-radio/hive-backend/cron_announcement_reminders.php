<?php
// Cron OPCIONAL: emite los recordatorios recurrentes de asistencia a reuniones
// para TODA la plantilla que haya confirmado "sí", sin depender de que cada
// persona abra la app.
//
// El recordatorio también se emite de forma perezosa cada vez que alguien
// consulta sus notificaciones (ver ia_dispatch_due_reminders en
// internal_announcements.php), así que este cron solo hace falta si quieres
// que llegue aunque el usuario no abra la app en todo el día.
//
// Uso (Hostinger → Cron Jobs, una vez al día):
//   /usr/bin/php /home/USUARIO/domains/.../hive-backend/cron_announcement_reminders.php
//
// En local:  C:\xampp\php\php.exe cron_announcement_reminders.php

require __DIR__ . '/config.php';
require __DIR__ . '/helpers.php';
require __DIR__ . '/internal_announcements.php';

$sent = ia_dispatch_due_reminders($pdo, null);
fwrite(STDOUT, date('c') . "  recordatorios emitidos: $sent\n");
