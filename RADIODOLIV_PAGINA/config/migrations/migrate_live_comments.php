<?php
// Migración one-off: crea la tabla radio_live_comments (si no existe) que
// respalda la caja "Comentarios en vivo" del hero de Inicio. Idempotente
// (CREATE TABLE IF NOT EXISTS), no siembra datos. Ejecutar una vez:
//   php config/migrations/migrate_live_comments.php
//
// En Hostinger, si no tienes acceso a CLI, corre el .sql hermano
// (2026_09_09_create_live_comments.sql) desde phpMyAdmin sobre la BD hive_db.

require_once __DIR__ . '/../../inc/helpers/env.php';
load_env(__DIR__ . '/../.env');

$host = getenv('DB_HOST') ?: '127.0.0.1';
$db = getenv('DB_NAME') ?: 'hive_db';
$user = getenv('DB_USER') ?: 'hive_user';
$pass = getenv('DB_PASS') ?: '';

$pdo = new PDO("mysql:host=$host;dbname=$db;charset=utf8mb4", $user, $pass);
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

$schema = file_get_contents(__DIR__ . '/2026_09_09_create_live_comments.sql');
foreach (array_filter(array_map('trim', explode(';', $schema))) as $statement) {
    if ($statement === '' || str_starts_with($statement, '--')) {
        continue;
    }
    $pdo->exec($statement);
}

$exists = $pdo->query("SHOW TABLES LIKE 'radio_live_comments'")->fetchColumn();
if ($exists) {
    $count = (int) $pdo->query('SELECT COUNT(*) FROM radio_live_comments')->fetchColumn();
    echo "OK: la tabla radio_live_comments existe ($count comentarios en este momento).\n";
} else {
    fwrite(STDERR, "ERROR: la tabla radio_live_comments no se creó.\n");
    exit(1);
}
