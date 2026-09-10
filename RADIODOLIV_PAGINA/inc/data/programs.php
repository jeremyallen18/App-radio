<?php
// Programas al aire de Radio Doliv, leídos desde la BD compartida
// (hive_db, tabla radio_programs).
function get_programs(): array {
    require_once __DIR__ . '/../../config/db.php';
    return get_pdo()->query('
        SELECT id, slug, title, modal_title, host, schedule, slot_start, slot_end, weekdays,
               badge_icon, badge_time, badge_label, accent, icon, image,
               categories, card_desc, index_desc, summary
        FROM radio_programs
        ORDER BY sort_order ASC, id ASC
    ')->fetchAll();
}
