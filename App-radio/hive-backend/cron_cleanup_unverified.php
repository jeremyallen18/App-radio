<?php
// Cron: borra las cuentas que se registraron y nunca verificaron su correo
// pasadas UNVERIFIED_ACCOUNT_TTL_HOURS (72 h). Ver cleanup_unverified_accounts()
// en helpers.php. Nunca toca cuentas verificadas.
//
// El barrido también corre de forma perezosa en cada alta nueva (signup en
// index.php), así que este cron solo hace falta para que la limpieza ocurra
// aunque nadie se registre durante días.
//
// Uso (Hostinger -> Cron Jobs, una vez al día):
//   /usr/bin/php /home/USUARIO/domains/.../hive-backend/cron_cleanup_unverified.php
//
// En local:  C:\xampp\php\php.exe cron_cleanup_unverified.php

require __DIR__ . '/config.php';
require __DIR__ . '/helpers.php';

$removed = cleanup_unverified_accounts($pdo);
fwrite(STDOUT, date('c') . "  cuentas sin verificar eliminadas: $removed\n");
