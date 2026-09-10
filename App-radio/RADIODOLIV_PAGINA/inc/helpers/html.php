<?php
// Escapado de texto para imprimir en HTML de forma segura.
function h($value): string {
    return htmlspecialchars((string) $value, ENT_QUOTES, 'UTF-8');
}

// URL absoluta (desde la raiz del dominio, ej. "/RADIODOLIV_PAGINA/") a la
// raiz del sitio, calculada a partir de SCRIPT_NAME y de cuantos "../" trae
// SITE_BASE_PATH. Existe porque navbar.php y footer.php NO se vuelven a
// pintar en cada navegacion AJAX (ver core/page-router.js, que solo
// reemplaza <main>): si sus enlaces usaran SITE_BASE_PATH tal cual (una ruta
// relativa al DIRECTORIO del script que los imprimio, pensada para recargas
// de pagina completas), dejarian de apuntar al lugar correcto en cuanto la
// URL del navegador cambiara de "profundidad" (index.php en la raiz vs.
// pages/*.php un nivel abajo) -- por eso el enlace a veces funcionaba y a
// veces daba 404 "Not Found", segun desde donde se habia navegado.
function site_root_url(): string {
    $scriptDir = dirname($_SERVER['SCRIPT_NAME'] ?? '/');
    $upLevels = defined('SITE_BASE_PATH') ? substr_count(SITE_BASE_PATH, '../') : 0;
    for ($i = 0; $i < $upLevels; $i++) {
        $scriptDir = dirname($scriptDir);
    }
    return rtrim(str_replace('\\', '/', $scriptDir), '/') . '/';
}
