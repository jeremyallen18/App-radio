<?php
// Cron: poda las tablas de límite de tasa y bitácora de seguridad
// (migración 037). rate_limits solo importa mientras la ventana está activa
// (como mucho 1h en los límites actuales de este backend), así que conservar
// más de un día es puro peso muerto. security_events se conserva más tiempo
// para poder revisar intentos de abuso, pero tampoco para siempre.
//
// Uso (Hostinger -> Cron Jobs, una vez al día):
//   /usr/bin/php /home/USUARIO/domains/.../hive-backend/cron_cleanup_rate_limits.php
//
// En local:  C:\xampp\php\php.exe cron_cleanup_rate_limits.php

require __DIR__ . '/config.php';
require __DIR__ . '/helpers.php';

$prunedLimits = $pdo->exec(
    "DELETE FROM rate_limits WHERE window_start < DATE_SUB(NOW(), INTERVAL 1 DAY)"
);
fwrite(STDOUT, date('c') . "  rate_limits podados: $prunedLimits\n");

$prunedEvents = $pdo->exec(
    "DELETE FROM security_events WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY)"
);
fwrite(STDOUT, date('c') . "  security_events podados: $prunedEvents\n");
