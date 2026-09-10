<?php
// Genera el mismo global `searchItems` que antes vivía hardcodeado en
// search-items.js, pero derivado en vivo de inc/data/*.php — misma fuente
// que renderiza las páginas, así que nunca vuelve a desincronizarse.
//
// ob_start() + ob_clean() descartan cualquier warning/notice de PHP que se
// haya colado antes del JSON (p. ej. un error de conexión a BD): un solo
// "Warning: ..." al inicio de este archivo rompe el `const searchItems = `
// como JS y deja el buscador sin datos en el navegador de quien lo cargó
// -- y con max-age=3600 esa respuesta rota quedaba cacheada hasta una hora.
// Bajamos tambien el cache a 5 minutos para que un error pasajero del
// servidor no deje el buscador roto por tanto tiempo.
ob_start();
header('Content-Type: application/javascript; charset=utf-8');
header('Cache-Control: public, max-age=300');

require_once __DIR__ . '/../../../inc/data/search_index.php';

$items = build_search_index();
ob_clean();
echo '/* Generado por assets/js/data/search-items.php a partir de inc/data/*.php */' . "\n";
echo 'const searchItems = ' . json_encode($items, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) . ';';
