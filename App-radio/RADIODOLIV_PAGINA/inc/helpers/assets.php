<?php
// Construye una URL de asset con cache-busting basado en la fecha de modificación
// del archivo, en vez de depender de un "?v=" manual que hay que recordar subir.
// Falla suave (usa time()) si el archivo no existe, para no tumbar la página por
// una ruta mal escrita.
function asset_url(string $relativePath): string {
    static $siteRoot = null;
    if ($siteRoot === null) {
        $siteRoot = dirname(__DIR__, 2); // .../RADIODOLIV_PAGINA
    }
    $base = defined('SITE_BASE_PATH') ? SITE_BASE_PATH : '';
    $full = $siteRoot . '/' . ltrim($relativePath, '/');
    $version = is_file($full) ? filemtime($full) : time();
    return $base . $relativePath . '?v=' . $version;
}
