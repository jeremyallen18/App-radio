<?php
// Equipo de Radio Doliv, leído desde la BD compartida (hive_db, tabla
// radio_team). 'accent' es el color de identidad de cada integrante (ver
// pages/equipo.php) -- las que tienen programa propio reusan el
// --show-accent de inc/data/programs.php para que la identidad sea consistente.
function get_team(): array {
    require_once __DIR__ . '/../../config/db.php';
    $rows = get_pdo()->query('
        SELECT slug, name, role, category, accent, image, short_desc AS `short`, bio, path, interests
        FROM radio_team
        ORDER BY sort_order ASC, id ASC
    ')->fetchAll();

    return array_map(function (array $member) {
        $member['bio'] = $member['bio'] !== null && $member['bio'] !== '' ? explode("\n\n", $member['bio']) : [];
        $member['path'] = $member['path'] !== null && $member['path'] !== '' ? explode("\n", $member['path']) : [];
        $member['interests'] = $member['interests'] !== null && $member['interests'] !== '' ? explode("\n", $member['interests']) : [];
        return $member;
    }, $rows);
}
