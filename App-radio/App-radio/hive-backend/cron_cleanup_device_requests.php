<?php
// Cron: purga las solicitudes de vinculación de dispositivo ya resueltas
// (aprobadas o rechazadas) con más de 180 días. Es la retención que promete el
// aviso de privacidad de "Mi asistencia": del historial de solicitudes solo se
// conservan seis meses. Las solicitudes 'pending' NUNCA se borran (siguen
// esperando decisión del director) ni se toca el dispositivo confiado.
//
// Uso (Hostinger -> Cron Jobs, una vez al día):
//   /usr/bin/php /home/USUARIO/domains/.../hive-backend/cron_cleanup_device_requests.php
//
// En local:  C:\xampp\php\php.exe cron_cleanup_device_requests.php

require __DIR__ . '/config.php';
require __DIR__ . '/helpers.php';

$purged = $pdo->exec(
    "DELETE FROM attendance_device_requests
      WHERE status IN ('approved','rejected')
        AND resolved_at IS NOT NULL
        AND resolved_at < (NOW() - INTERVAL 180 DAY)"
);
fwrite(STDOUT, date('c') . "  solicitudes de dispositivo purgadas: $purged\n");
