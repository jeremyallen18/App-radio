<?php
// Equipo de Radio Doliv, leído desde la BD compartida (hive_db, tabla
// radio_team + team_socials). 'accent' es el color de identidad de cada
// integrante (ver pages/equipo.php) -- las que tienen programa propio
// reusan el --show-accent de inc/data/programs.php para que la identidad
// sea consistente.
function get_team(): array {
    require_once __DIR__ . '/../../config/db.php';
    $pdo = get_pdo();

    $rows = $pdo->query('
        SELECT id, slug, name, role, category, accent, image, short_desc AS `short`, bio, path, interests
        FROM radio_team
        ORDER BY sort_order ASC, id ASC
    ')->fetchAll();

    $socialsStmt = $pdo->query('
        SELECT team_id, label, icon, url
        FROM team_socials
        ORDER BY team_id ASC, sort_order ASC
    ');
    $socialsByMember = [];
    foreach ($socialsStmt->fetchAll() as $social) {
        $socialsByMember[$social['team_id']][] = [
            'label' => $social['label'],
            'icon' => $social['icon'],
            'url' => $social['url'],
        ];
    }

    return array_map(function (array $member) use ($socialsByMember) {
        $member['bio'] = $member['bio'] !== null && $member['bio'] !== '' ? explode("\n\n", $member['bio']) : [];
        $member['path'] = $member['path'] !== null && $member['path'] !== '' ? explode("\n", $member['path']) : [];
        $member['interests'] = $member['interests'] !== null && $member['interests'] !== '' ? explode("\n", $member['interests']) : [];
        $member['socials'] = $socialsByMember[$member['id']] ?? [];
        unset($member['id']);
        return $member;
    }, $rows);
}
