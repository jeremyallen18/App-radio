<?php
require_once __DIR__ . '/_bootstrap.php';
require_once __DIR__ . '/../inc/data/events.php';

api_run(function () {
    $events = array_map(function (array $event) {
        $event['image'] = api_absolute_url((string) ($event['image'] ?? ''));
        $event['countdown'] = event_countdown($event);
        return $event;
    }, get_active_events());
    return [
        'events' => $events,
        'ticket_link' => get_event_ticket_link(),
    ];
});
