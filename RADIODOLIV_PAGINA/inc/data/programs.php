<?php
// Programas al aire de Radio Doliv, leídos desde la BD compartida
// (hive_db, tabla radio_programs + radio_program_hosts para los locutores
// vinculados, que pueden ser varios por programa).
function get_programs(): array {
    require_once __DIR__ . '/../../config/db.php';
    $pdo = get_pdo();

    $rows = $pdo->query('
        SELECT id, slug, title, modal_title, host, schedule, slot_start, slot_end, weekdays,
               badge_icon, badge_time, badge_label, accent, icon, image,
               categories, card_desc, index_desc, summary
        FROM radio_programs
        ORDER BY sort_order ASC, id ASC
    ')->fetchAll();

    $hostIdsStmt = $pdo->query('SELECT program_id, team_id FROM radio_program_hosts ORDER BY program_id ASC, sort_order ASC, id ASC');
    $hostIdsByProgram = [];
    foreach ($hostIdsStmt->fetchAll() as $row) {
        $hostIdsByProgram[$row['program_id']][] = (int) $row['team_id'];
    }

    foreach ($rows as &$row) {
        $row['host_team_ids'] = $hostIdsByProgram[$row['id']] ?? [];
    }

    return $rows;
}
