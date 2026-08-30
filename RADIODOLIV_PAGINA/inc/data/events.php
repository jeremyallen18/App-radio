<?php
// Eventos de Radio Doliv, leídos desde la BD compartida (hive_db, tabla
// radio_events — ver config/migrations/2026_08_06_create_radio_content.sql).
function get_events(): array {
    require_once __DIR__ . '/../../config/db.php';
    $rows = get_pdo()->query('
        SELECT slug, title, artist, location, image, weekday, day, month, year, event_date, time_label AS time, description
        FROM radio_events
        ORDER BY sort_order ASC, id ASC
    ')->fetchAll();
    foreach ($rows as &$row) {
        $row['event_date'] = $row['event_date'] ?: null;
    }
    return $rows;
}

// Enlace oficial de compra de boletos (Guru Shows), igual para todos los eventos.
function get_event_ticket_link(): string {
    return 'https://gurushows.com/?fbclid=IwdGRzaASw4GNleHRuA2FlbQEwAGFkaWQBqzQlWCRUFHNydGMGYXBwX2lkDDM1MDY4NTUzMTcyOAABHimIvJWCr3tPGCx8zuUviCUM6PLrMYt0gjHfan1bV8_D9qs4WOKjs0weTGIT_aem_9HAJ-Ft9TnhnrpC_vEi6Uw&utm_medium=paid&utm_source=fb&utm_id=120247149955000244&utm_content=120247149954940244&utm_term=120247149954960244&utm_campaign=120247149955000244&sfnsn=scwspwa';
}

// Filtra eventos vencidos (los que ya pasaron su event_date).
function get_active_events(): array {
    $today = date('Y-m-d');
    return array_values(array_filter(get_events(), function ($event) use ($today) {
        return empty($event['event_date']) || $event['event_date'] >= $today;
    }));
}

// ---------------------------------------------------------------------------
// Cuenta regresiva en dias para un evento. Devuelve days=null cuando el
// evento todavia no tiene fecha confirmada.
//
// Vive aqui y no en pages/eventos.php porque inc/components/card-event.php la
// necesita: antes la tarjeta llamaba a una funcion global declarada dentro de
// la pagina, asi que el componente solo funcionaba si quien lo incluia era
// eventos.php. Ahora el componente depende de su propia capa de datos.
// ---------------------------------------------------------------------------
function event_countdown(array $event): array {
    if (empty($event['event_date'])) {
        return ['days' => null, 'label' => 'Fecha por confirmar', 'urgent' => false, 'bucket' => 'tbd'];
    }
    $days = (int) floor((strtotime($event['event_date']) - strtotime(date('Y-m-d'))) / 86400);
    $bucket = $days <= 7 ? 'week' : ($days <= 31 ? 'month' : 'later');
    if ($days <= 0) return ['days' => $days, 'label' => '¡Es hoy!', 'urgent' => true, 'bucket' => $bucket];
    if ($days === 1) return ['days' => $days, 'label' => 'Es mañana', 'urgent' => true, 'bucket' => $bucket];
    return ['days' => $days, 'label' => "Faltan {$days} días", 'urgent' => $days <= 7, 'bucket' => $bucket];
}

// ---------------------------------------------------------------------------
// Eventos activos listos para pintar: ordenados (fecha confirmada primero, la
// mas proxima al frente; las fechas por confirmar al final) y con dos campos
// derivados ya calculados una sola vez por evento:
//
//   'index'     posicion en el arreglo que se serializa a #events-data, o sea
//               el numero que viaja en data-event-index y con el que el JS
//               abre el modal. Antes cada seccion lo recalculaba con
//               array_search($event, $events, true) -- O(n^2) y, peor, una
//               comparacion por VALOR: dos eventos con exactamente los mismos
//               campos habrian devuelto siempre el indice del primero,
//               abriendo el modal equivocado.
//   'countdown' resultado de event_countdown(), para no llamarla 3-4 veces
//               por evento (hero + tarjeta + filtros).
//
// El orden del arreglo devuelto ES el orden de 'index', asi que el JSON que
// consume el modal y lo que se ve en pantalla no pueden desincronizarse.
// ---------------------------------------------------------------------------
function get_events_for_display(): array {
    $events = get_active_events();

    // Fecha confirmada primero (mas proxima al frente), luego las pendientes.
    usort($events, function ($a, $b) {
        $aDate = $a['event_date'] ?? null;
        $bDate = $b['event_date'] ?? null;
        if ($aDate === $bDate) return 0;
        if ($aDate === null) return 1;
        if ($bDate === null) return -1;
        return strcmp($aDate, $bDate);
    });

    foreach ($events as $i => &$event) {
        $event['index']     = $i;
        $event['countdown'] = event_countdown($event);
    }
    unset($event);

    return $events;
}
