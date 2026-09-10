<?php
require_once __DIR__ . '/_bootstrap.php';
require_once __DIR__ . '/../inc/data/sponsors.php';

api_run(function () {
    $sponsors = array_map(function (array $s) {
        $s['image'] = api_absolute_url((string) ($s['image'] ?? ''));
        return $s;
    }, get_sponsors());
    return ['sponsors' => $sponsors];
});
