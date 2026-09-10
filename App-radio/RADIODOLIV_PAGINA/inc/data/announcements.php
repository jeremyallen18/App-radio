<?php
require_once __DIR__ . '/../helpers/format.php';

// Consulta los anuncios activos desde la BD compartida (hive_db). Devuelve
// siempre ['items' => array, 'error' => string|null] para que el controlador
// pueda distinguir "sin anuncios todavía" de "la consulta falló" sin manejar
// excepciones él mismo — mismo contrato de degradación amable que tenía el
// try/catch original de pages/anuncios.php (mensaje "no pudimos cargar" en
// vez de pantalla en blanco si la BD falla).
function get_announcements(): array {
    $items = [];
    $error = null;
    try {
        require_once __DIR__ . '/../../config/db.php';
        $stmt = get_pdo()->query('
            SELECT
                id,
                titulo,
                descripcion,
                imagen_url,
                link_web,
                link_facebook,
                link_whatsapp,
                fecha_publicacion
            FROM anuncios
            ORDER BY fecha_publicacion DESC, id DESC
        ');
        $items = $stmt->fetchAll();
    } catch (Throwable $e) {
        $error = 'No pudimos cargar los anuncios por el momento.';
    }
    return ['items' => $items, 'error' => $error];
}
