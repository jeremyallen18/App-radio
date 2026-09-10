<?php
require_once __DIR__ . '/_bootstrap.php';
require_once __DIR__ . '/../inc/data/programs.php';

// Parrilla de la radio con el MISMO contrato que ya consume la app Flutter
// contra hive-backend (GET /radio/programs -> RadioProgram.fromJson):
//   - la lista viaja en la clave "items" (no "programs"),
//   - las llaves van en camelCase (slotStart, slotEnd, badgeTime),
//   - "weekdays" es una lista de enteros ISO (1=lunes..7=domingo), no la
//     cadena "1,2,3,4,5" que guarda la BD,
//   - se incluye "id".
// Asi la app puede apuntar a este endpoint o a hive-backend sin cambios.
api_run(function () {
    $items = array_map(function (array $p) {
        $weekdays = array_values(array_filter(array_map(
            'intval',
            $p['weekdays'] !== null && $p['weekdays'] !== ''
                ? explode(',', $p['weekdays']) : []
        ), fn($n) => $n >= 1 && $n <= 7));

        return [
            'id'        => (int) ($p['id'] ?? 0),
            'title'     => $p['title'],
            'host'      => $p['host'],
            'schedule'  => $p['schedule'],
            'badgeTime' => $p['badge_time'],
            'slotStart' => $p['slot_start'] !== null ? (int) $p['slot_start'] : null,
            'slotEnd'   => $p['slot_end'] !== null ? (int) $p['slot_end'] : null,
            'weekdays'  => $weekdays,
            'accent'    => $p['accent'],
            'image'     => api_absolute_url((string) ($p['image'] ?? '')),
        ];
    }, get_programs());

    return ['items' => $items];
});
