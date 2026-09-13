<?php
// Script de mantenimiento: limpia archivos huérfanos de assets/img y assets/audio.
// Uso: php site_content_orphan_cleanup.php [--dry-run]
// Seguridad: nunca borra nada fuera de RADIODOLIV_PAGINA_PATH/assets.

require __DIR__ . '/config.php';

$dryRun = in_array('--dry-run', $argv, true);

// [directorio relativo a assets/, columna(s) que referencian archivos ahí]
$sources = [
    ['img/anuncios',        'anuncios',               ['imagen_url']],
    ['img/eventos',         'radio_events',           ['image']],
    ['img/servicios',       'radio_services',         ['image']],
    ['img/locutores',       'radio_team',             ['image']],
    ['img/programas',       'radio_programs',         ['image']],
    ['img/patrocinadores',  'sponsors',               ['image']],
    ['img/portadas',        'radio_podcasts',         ['cover']],
    ['audio/podcasts',      'radio_podcast_episodes', ['audio_url']],
];

$deleted = 0;
$kept = 0;

foreach ($sources as [$relDir, $table, $columns]) {
    $dir = RADIODOLIV_PAGINA_PATH . '/assets/' . $relDir;
    if (!is_dir($dir)) continue;

    $referenced = [];
    foreach ($columns as $column) {
        $stmt = $pdo->query("SELECT `$column` FROM `$table` WHERE `$column` IS NOT NULL AND `$column` <> ''");
        foreach ($stmt->fetchAll(PDO::FETCH_COLUMN) as $path) {
            $referenced[basename($path)] = true;
        }
    }

    foreach (scandir($dir) as $file) {
        if ($file === '.' || $file === '..') continue;
        $fullPath = $dir . '/' . $file;
        if (!is_file($fullPath)) continue;

        if (isset($referenced[$file])) {
            $kept++;
            continue;
        }

        echo ($dryRun ? '[dry-run] borraría: ' : 'borrando: ') . "assets/$relDir/$file" . PHP_EOL;
        if (!$dryRun) {
            @unlink($fullPath);
        }
        $deleted++;
    }
}

echo PHP_EOL . ($dryRun ? "Total a borrar: $deleted" : "Total borrado: $deleted") . " (referenciados y conservados: $kept)" . PHP_EOL;
