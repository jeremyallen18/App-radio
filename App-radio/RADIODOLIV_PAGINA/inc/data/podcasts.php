<?php
// Podcasts y episodios de Radio Doliv, leídos desde la BD compartida
// (hive_db, tablas radio_podcasts/radio_podcast_episodes).
function get_podcasts(): array {
    require_once __DIR__ . '/../../config/db.php';
    $pdo = get_pdo();

    $podcasts = $pdo->query('
        SELECT id, slug, title, filter_icon, cover
        FROM radio_podcasts
        ORDER BY sort_order ASC, id ASC
    ')->fetchAll();

    $episodesStmt = $pdo->query('
        SELECT podcast_id, title, description, audio_url, category_label
        FROM radio_podcast_episodes
        ORDER BY podcast_id ASC, sort_order ASC
    ');
    $episodesByPodcast = [];
    foreach ($episodesStmt->fetchAll() as $episode) {
        $episodesByPodcast[$episode['podcast_id']][] = [
            'title' => $episode['title'],
            'description' => $episode['description'],
            'audio_url' => $episode['audio_url'],
            'category_label' => $episode['category_label'],
        ];
    }

    return array_map(function (array $podcast) use ($episodesByPodcast) {
        return [
            'slug' => $podcast['slug'],
            'title' => $podcast['title'],
            'filter_icon' => $podcast['filter_icon'],
            'cover' => $podcast['cover'],
            'episodes' => $episodesByPodcast[$podcast['id']] ?? [],
        ];
    }, $podcasts);
}
