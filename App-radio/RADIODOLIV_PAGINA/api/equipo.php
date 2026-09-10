<?php
require_once __DIR__ . '/_bootstrap.php';
require_once __DIR__ . '/../inc/data/team.php';

api_run(function () {
    $team = array_map(function (array $m) {
        $m['image'] = api_absolute_url((string) ($m['image'] ?? ''));
        return $m;
    }, get_team());
    return ['team' => $team];
});
