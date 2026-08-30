<?php
// Migración one-off: crea radio_events/radio_podcasts/radio_podcast_episodes/
// radio_programs/radio_services/radio_team y vuelca ahí los arrays hardcodeados
// que vivían en inc/data/{events,podcasts,programs,services,team}.php.
// Ejecutar una sola vez ANTES de reemplazar esos archivos por versiones que
// consultan la BD:
//   php config/migrations/migrate_radio_content.php

require_once __DIR__ . '/../../inc/helpers/env.php';
load_env(__DIR__ . '/../.env');

require_once __DIR__ . '/../../inc/data/events.php';
require_once __DIR__ . '/../../inc/data/podcasts.php';
require_once __DIR__ . '/../../inc/data/programs.php';
require_once __DIR__ . '/../../inc/data/services.php';
require_once __DIR__ . '/../../inc/data/team.php';

$host = getenv('DB_HOST') ?: '127.0.0.1';
$db = getenv('DB_NAME') ?: 'hive_db';
$user = getenv('DB_USER') ?: 'hive_user';
$pass = getenv('DB_PASS') ?: '';

$pdo = new PDO("mysql:host=$host;dbname=$db;charset=utf8mb4", $user, $pass);
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

$schema = file_get_contents(__DIR__ . '/2026_08_06_create_radio_content.sql');
foreach (array_filter(array_map('trim', explode(';', $schema))) as $statement) {
    $pdo->exec($statement);
}

function already_migrated(PDO $pdo, string $table): bool {
    $count = (int) $pdo->query("SELECT COUNT(*) FROM $table")->fetchColumn();
    if ($count > 0) {
        echo "$table ya tiene $count registros; se omite.\n";
    }
    return $count > 0;
}

// --- eventos ---
if (!already_migrated($pdo, 'radio_events')) {
    $insert = $pdo->prepare('
        INSERT INTO radio_events (slug, title, artist, location, image, weekday, day, month, year, event_date, time_label, description, sort_order)
        VALUES (:slug, :title, :artist, :location, :image, :weekday, :day, :month, :year, :event_date, :time_label, :description, :sort_order)
    ');
    foreach (get_events() as $i => $e) {
        $insert->execute([
            'slug' => $e['slug'], 'title' => $e['title'], 'artist' => $e['artist'] ?? null,
            'location' => $e['location'] ?? null, 'image' => $e['image'] ?? null,
            'weekday' => $e['weekday'] ?? null, 'day' => $e['day'] ?? null,
            'month' => $e['month'] ?? null, 'year' => $e['year'] ?? null,
            'event_date' => $e['event_date'] ?? null, 'time_label' => $e['time'] ?? null,
            'description' => $e['description'] ?? null, 'sort_order' => $i,
        ]);
    }
    echo 'radio_events: ' . count(get_events()) . " insertados.\n";
}

// --- podcasts + episodios ---
if (!already_migrated($pdo, 'radio_podcasts')) {
    $insertPodcast = $pdo->prepare('
        INSERT INTO radio_podcasts (slug, title, filter_icon, cover, sort_order)
        VALUES (:slug, :title, :filter_icon, :cover, :sort_order)
    ');
    $insertEpisode = $pdo->prepare('
        INSERT INTO radio_podcast_episodes (podcast_id, title, description, audio_url, category_label, sort_order)
        VALUES (:podcast_id, :title, :description, :audio_url, :category_label, :sort_order)
    ');
    foreach (get_podcasts() as $i => $p) {
        $insertPodcast->execute([
            'slug' => $p['slug'], 'title' => $p['title'],
            'filter_icon' => $p['filter_icon'] ?? null, 'cover' => $p['cover'] ?? null, 'sort_order' => $i,
        ]);
        $podcastId = (int) $pdo->lastInsertId();
        foreach ($p['episodes'] ?? [] as $j => $ep) {
            $insertEpisode->execute([
                'podcast_id' => $podcastId, 'title' => $ep['title'],
                'description' => $ep['description'] ?? null, 'audio_url' => $ep['audio_url'] ?? null,
                'category_label' => $ep['category_label'] ?? null, 'sort_order' => $j,
            ]);
        }
    }
    echo 'radio_podcasts: ' . count(get_podcasts()) . " insertados.\n";
}

// --- programas ---
if (!already_migrated($pdo, 'radio_programs')) {
    $insert = $pdo->prepare('
        INSERT INTO radio_programs (slug, title, modal_title, host, schedule, slot_start, slot_end, weekdays, badge_icon, badge_time, badge_label, accent, icon, image, categories, card_desc, index_desc, summary, sort_order)
        VALUES (:slug, :title, :modal_title, :host, :schedule, :slot_start, :slot_end, :weekdays, :badge_icon, :badge_time, :badge_label, :accent, :icon, :image, :categories, :card_desc, :index_desc, :summary, :sort_order)
    ');
    foreach (get_programs() as $i => $p) {
        $insert->execute([
            'slug' => $p['slug'], 'title' => $p['title'], 'modal_title' => $p['modal_title'] ?? null,
            'host' => $p['host'] ?? null, 'schedule' => $p['schedule'] ?? null,
            'slot_start' => $p['slot_start'] ?? null, 'slot_end' => $p['slot_end'] ?? null,
            'weekdays' => $p['weekdays'] ?? null,
            'badge_icon' => $p['badge_icon'] ?? null, 'badge_time' => $p['badge_time'] ?? null,
            'badge_label' => $p['badge_label'] ?? null, 'accent' => $p['accent'] ?? null,
            'icon' => $p['icon'] ?? null, 'image' => $p['image'] ?? null,
            'categories' => $p['categories'] ?? null, 'card_desc' => $p['card_desc'] ?? null,
            'index_desc' => $p['index_desc'] ?? null, 'summary' => $p['summary'] ?? null, 'sort_order' => $i,
        ]);
    }
    echo 'radio_programs: ' . count(get_programs()) . " insertados.\n";
}

// --- servicios ---
if (!already_migrated($pdo, 'radio_services')) {
    $insert = $pdo->prepare('
        INSERT INTO radio_services (title, image, description, whatsapp_url, category, icon, sort_order)
        VALUES (:title, :image, :description, :whatsapp_url, :category, :icon, :sort_order)
    ');
    foreach (get_services() as $i => $s) {
        $insert->execute([
            'title' => $s['title'], 'image' => $s['image'] ?? null, 'description' => $s['description'] ?? null,
            'whatsapp_url' => $s['whatsapp_url'] ?? null, 'category' => $s['category'] ?? null,
            'icon' => $s['icon'] ?? null, 'sort_order' => $i,
        ]);
    }
    echo 'radio_services: ' . count(get_services()) . " insertados.\n";
}

// --- equipo ---
if (!already_migrated($pdo, 'radio_team')) {
    $insert = $pdo->prepare('
        INSERT INTO radio_team (slug, name, role, category, accent, image, short_desc, bio, path, interests, sort_order)
        VALUES (:slug, :name, :role, :category, :accent, :image, :short_desc, :bio, :path, :interests, :sort_order)
    ');
    foreach (get_team() as $i => $m) {
        $insert->execute([
            'slug' => $m['slug'], 'name' => $m['name'], 'role' => $m['role'] ?? null,
            'category' => $m['category'] ?? null, 'accent' => $m['accent'] ?? null, 'image' => $m['image'] ?? null,
            'short_desc' => $m['short'] ?? null,
            'bio' => implode("\n\n", $m['bio'] ?? []),
            'path' => implode("\n", $m['path'] ?? []),
            'interests' => implode("\n", $m['interests'] ?? []),
            'sort_order' => $i,
        ]);
    }
    echo 'radio_team: ' . count(get_team()) . " insertados.\n";
}

echo "Migración completa.\n";
