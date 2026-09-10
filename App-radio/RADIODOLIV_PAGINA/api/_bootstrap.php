<?php
// Bootstrap compartido de la API JSON para la app Flutter. No reemplaza
// nada del sitio web: solo expone en formato JSON las mismas fuentes de
// datos que ya usan las páginas PHP (inc/data/*.php), para que la app móvil
// consuma el mismo backend/BD sin duplicar lógica.
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

function api_send(array $data, int $status = 200): void {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function api_ok(array $payload): void {
    api_send(['success' => true] + $payload);
}

function api_fail(string $message, int $status = 500): void {
    api_send(['success' => false, 'error' => $message], $status);
}

// Envuelve una llamada a inc/data/*.php: cualquier excepción (BD caída,
// etc.) se convierte en un JSON de error en vez de un 500 en blanco, igual
// que el patron try/catch que ya usan get_announcements()/get_sponsors().
function api_run(callable $fn): void {
    try {
        api_ok($fn());
    } catch (Throwable $e) {
        api_fail('No se pudo cargar la información. Intenta de nuevo más tarde.');
    }
}

// Prefijo de carpeta donde vive el sitio, calculado a partir de la propia
// petición en vez de asumir la raíz del dominio. En produccion (Hostinger)
// el sitio vive en la raiz y esto da "" (ESQUEMA_PROYECTO.md exige raiz de
// dominio); en XAMPP local vive en /RADIODOLIV_PAGINA/, y SCRIPT_NAME trae
// ese prefijo (ej. "/RADIODOLIV_PAGINA/api/config.php"): se le quita el
// "/api/archivo.php" final para quedarse solo con la carpeta del sitio.
function api_site_prefix(): string {
    $script = $_SERVER['SCRIPT_NAME'] ?? '';
    $prefix = preg_replace('#/api/[^/]+\.php$#', '', $script);
    return $prefix === $script ? '' : $prefix;
}

// Convierte una ruta relativa del sitio (ej. "assets/img/logo/logo.png") en
// una URL absoluta, para que la app Flutter pueda cargar imágenes sin tener
// que conocer el dominio (ni la subcarpeta, en desarrollo local) de antemano.
function api_absolute_url(string $relativePath): string {
    if ($relativePath === '' || preg_match('#^https?://#i', $relativePath)) {
        return $relativePath;
    }
    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $host = $_SERVER['HTTP_HOST'] ?? 'localhost';
    return $scheme . '://' . $host . api_site_prefix() . '/' . ltrim($relativePath, '/');
}
