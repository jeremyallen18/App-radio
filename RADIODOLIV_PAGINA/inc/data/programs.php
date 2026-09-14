<?php
// Programas al aire de Radio Doliv, leídos desde la BD compartida
// (hive_db, tabla radio_programs + radio_program_hosts para los locutores
// vinculados, que pueden ser varios por programa, + radio_program_slots
// para sus franjas horarias, que pueden tener horas distintas en días
// distintos del mismo programa).
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

    $slotsStmt = $pdo->query('SELECT program_id, weekday, start_hour, end_hour FROM radio_program_slots ORDER BY program_id ASC, weekday ASC');
    $slotsByProgram = [];
    foreach ($slotsStmt->fetchAll() as $row) {
        $slotsByProgram[$row['program_id']][] = [
            'weekday'    => (int) $row['weekday'],
            'start_hour' => (int) $row['start_hour'],
            'end_hour'   => (int) $row['end_hour'],
        ];
    }

    foreach ($rows as &$row) {
        $row['host_team_ids'] = $hostIdsByProgram[$row['id']] ?? [];
        $row['slots'] = $slotsByProgram[$row['id']] ?? [];
    }

    return $rows;
}

// Aplana cada programa en una "ocurrencia" por franja horaria (un
// weekday + slot_start/slot_end propios) para que el dial, los bloques
// del día y el rundown puedan representar horarios distintos en días
// distintos del mismo programa (p. ej. miércoles 9-13, viernes 11-13) --
// antes una sola fila por programa forzaba el mismo horario a todos sus
// días. Un programa sin franjas (música 24/7, o datos que aún no migran)
// produce UNA sola ocurrencia, igual que antes. Cada ocurrencia trae
// `_occurrence_key` (único incluso si el mismo programa aparece varias
// veces) y `_index`/`_multi_slot` para que el HTML sepa numerarlas y
// mostrar el horario correcto de cada una.
function program_occurrences(array $programs): array {
    $occurrences = [];
    foreach ($programs as $index => $program) {
        $slots = $program['slots'] ?? [];
        if (!$slots) {
            $occurrence = $program;
            $occurrence['_index'] = $index;
            $occurrence['_occurrence_key'] = $program['slug'];
            $occurrence['_multi_slot'] = false;
            $occurrences[] = $occurrence;
            continue;
        }
        foreach ($slots as $slotIndex => $slot) {
            $occurrence = $program;
            $occurrence['slot_start'] = $slot['start_hour'];
            $occurrence['slot_end'] = $slot['end_hour'];
            $occurrence['weekdays'] = (string) $slot['weekday'];
            $occurrence['_index'] = $index;
            $occurrence['_occurrence_key'] = $program['slug'] . '-' . $slotIndex;
            $occurrence['_multi_slot'] = count($slots) > 1;
            $occurrences[] = $occurrence;
        }
    }
    return $occurrences;
}
