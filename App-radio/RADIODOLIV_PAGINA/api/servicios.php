<?php
require_once __DIR__ . '/_bootstrap.php';
require_once __DIR__ . '/../inc/data/services.php';

api_run(function () {
    $services = array_map(function (array $s) {
        $s['image'] = api_absolute_url((string) ($s['image'] ?? ''));
        return $s;
    }, get_services());
    return ['services' => $services];
});
