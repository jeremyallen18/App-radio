<?php
// Servicios para marcas y negocios, leídos desde la BD compartida
// (hive_db, tabla radio_services).
function get_services(): array {
    require_once __DIR__ . '/../../config/db.php';
    return get_pdo()->query('
        SELECT title, image, description, whatsapp_url, category, icon
        FROM radio_services
        ORDER BY sort_order ASC, id ASC
    ')->fetchAll();
}

// Agrupa get_services() por 'category', preservando el orden de aparicion
// de cada categoria y de cada servicio dentro de ella (para que
// pages/servicios.php pueda pintar una seccion por bloque tematico).
function get_services_by_category(): array {
    $grouped = [];
    foreach (get_services() as $service) {
        $grouped[$service['category']][] = $service;
    }
    return $grouped;
}
