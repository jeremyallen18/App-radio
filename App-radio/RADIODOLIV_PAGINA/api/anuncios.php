<?php
require_once __DIR__ . '/_bootstrap.php';
require_once __DIR__ . '/../inc/data/announcements.php';

$result = get_announcements();
if ($result['error']) {
    api_fail($result['error']);
}

$items = array_map(function (array $a) {
    $a['imagen_url'] = api_absolute_url((string) ($a['imagen_url'] ?? ''));
    return $a;
}, $result['items']);

api_ok(['announcements' => $items]);
