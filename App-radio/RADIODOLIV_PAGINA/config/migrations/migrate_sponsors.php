<?php
// Migración one-off: crea las tablas sponsors/sponsor_socials (si no existen)
// y vuelca ahí el array get_sponsors() que vivía hardcodeado en
// inc/data/sponsors.php. Ejecutar una sola vez:
//   php config/migrations/migrate_sponsors.php

require_once __DIR__ . '/../../inc/helpers/env.php';
load_env(__DIR__ . '/../.env');

require_once __DIR__ . '/../../inc/data/sponsors.php';

$host = getenv('DB_HOST') ?: '127.0.0.1';
$db = getenv('DB_NAME') ?: 'hive_db';
$user = getenv('DB_USER') ?: 'hive_user';
$pass = getenv('DB_PASS') ?: '';

$pdo = new PDO("mysql:host=$host;dbname=$db;charset=utf8mb4", $user, $pass);
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

$schema = file_get_contents(__DIR__ . '/2026_08_06_create_sponsors.sql');
foreach (array_filter(array_map('trim', explode(';', $schema))) as $statement) {
    $pdo->exec($statement);
}

$count = (int) $pdo->query('SELECT COUNT(*) FROM sponsors')->fetchColumn();
if ($count > 0) {
    echo "La tabla sponsors ya tiene $count registros; no se vuelve a migrar.\n";
    exit;
}

$sponsors = get_sponsors();

$insertSponsor = $pdo->prepare('
    INSERT INTO sponsors (name, category, category_label, icon, image, subtitle, summary, description, map, sort_order)
    VALUES (:name, :category, :category_label, :icon, :image, :subtitle, :summary, :description, :map, :sort_order)
');
$insertSocial = $pdo->prepare('
    INSERT INTO sponsor_socials (sponsor_id, label, icon, url, sort_order)
    VALUES (:sponsor_id, :label, :icon, :url, :sort_order)
');

$pdo->beginTransaction();
try {
    foreach ($sponsors as $index => $sponsor) {
        $insertSponsor->execute([
            'name' => $sponsor['name'],
            'category' => $sponsor['category'],
            'category_label' => $sponsor['category_label'],
            'icon' => $sponsor['icon'],
            'image' => $sponsor['image'],
            'subtitle' => $sponsor['subtitle'] ?? null,
            'summary' => $sponsor['summary'] ?? null,
            'description' => implode("\n\n", $sponsor['description'] ?? []),
            'map' => $sponsor['map'] ?? null,
            'sort_order' => $index,
        ]);
        $sponsorId = (int) $pdo->lastInsertId();

        foreach ($sponsor['socials'] ?? [] as $socialIndex => $social) {
            $insertSocial->execute([
                'sponsor_id' => $sponsorId,
                'label' => $social['label'],
                'icon' => $social['icon'],
                'url' => $social['url'],
                'sort_order' => $socialIndex,
            ]);
        }
    }
    $pdo->commit();
} catch (Throwable $e) {
    $pdo->rollBack();
    throw $e;
}

$total = (int) $pdo->query('SELECT COUNT(*) FROM sponsors')->fetchColumn();
echo "Migración completa: $total patrocinadores insertados.\n";
