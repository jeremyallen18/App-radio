<?php
// Migración de datos one-off: limpia la tabla `anuncios` dejando solo los
// tres anuncios en uso (31 Minutos, Lufesca, El Reporterito) y da de alta el
// de la Carrera del Tecnológico de Santiago Tilapa.
// Ver 2026_08_31_anuncios_cleanup.sql para el detalle.
// Ejecutar una sola vez:
//   php config/migrations/migrate_anuncios_cleanup.php

require_once __DIR__ . '/../../inc/helpers/env.php';
load_env(__DIR__ . '/../.env');

$host = env_get('DB_HOST') ?: '127.0.0.1';
$db = env_get('DB_NAME') ?: 'hive_db';
$user = env_get('DB_USER') ?: 'hive_user';
$pass = env_get('DB_PASS') ?: '';

$pdo = new PDO("mysql:host=$host;dbname=$db;charset=utf8mb4", $user, $pass);
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

$before = (int) $pdo->query('SELECT COUNT(*) FROM anuncios')->fetchColumn();

$sql = file_get_contents(__DIR__ . '/2026_08_31_anuncios_cleanup.sql');
// Quita las líneas de comentario "--" antes de partir por ";" (un ";" dentro
// de un comentario partiría un statement a la mitad).
$sql = preg_replace('/^\s*--.*$/m', '', $sql);
foreach (array_filter(array_map('trim', explode(';', $sql))) as $statement) {
    $pdo->exec($statement);
}

$after = (int) $pdo->query('SELECT COUNT(*) FROM anuncios')->fetchColumn();
$rows = $pdo->query('SELECT titulo FROM anuncios ORDER BY fecha_publicacion DESC, id DESC')->fetchAll(PDO::FETCH_COLUMN);

echo "anuncios: {$before} -> {$after}\n";
echo "Quedan:\n - " . implode("\n - ", $rows) . "\n";
echo "Migración completa.\n";
