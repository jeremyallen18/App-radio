<?php
require_once __DIR__ . '/_bootstrap.php';
require_once __DIR__ . '/../inc/data/podcasts.php';

api_run(function () {
    $podcasts = array_map(function (array $p) {
        $p['cover'] = api_absolute_url((string) ($p['cover'] ?? ''));
        $p['episodes'] = array_map(function (array $ep) {
            $ep['audio_url'] = api_absolute_url((string) ($ep['audio_url'] ?? ''));
            return $ep;
        }, $p['episodes']);
        return $p;
    }, get_podcasts());
    return ['podcasts' => $podcasts];
});
