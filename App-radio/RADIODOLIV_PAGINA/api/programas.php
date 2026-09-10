<?php
require_once __DIR__ . '/_bootstrap.php';
require_once __DIR__ . '/../inc/data/programs.php';

api_run(function () {
    $programs = array_map(function (array $p) {
        $p['image'] = api_absolute_url((string) ($p['image'] ?? ''));
        return $p;
    }, get_programs());
    return ['programs' => $programs];
});
