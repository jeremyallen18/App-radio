<?php
// DB connection for the Hive backend

// Almacen de variables de .env. No se usa putenv()/getenv() porque algunos
// hostings compartidos (p. ej. InfinityFree) tienen putenv() deshabilitada
// por seguridad: se ejecuta sin error pero no guarda nada. En su lugar las
// variables se acumulan en un static y env_get() las lee desde ahi.
function &env_store(): array {
    static $vars = [];
    return $vars;
}

function load_env(string $path): void {
    if (!is_file($path)) return;
    $store = &env_store();
    foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        $line = trim($line);
        if ($line === '' || $line[0] === '#') continue;
        [$key, $value] = array_pad(explode('=', $line, 2), 2, '');
        $key = trim($key);
        $value = trim($value);
        if ($key !== '' && !array_key_exists($key, $store)) {
            $store[$key] = $value;
        }
    }
}

// Reemplazo de getenv(): devuelve la variable cargada por load_env() o
// $default si no existe.
function env_get(string $key, $default = null) {
    $store = &env_store();
    return array_key_exists($key, $store) ? $store[$key] : $default;
}

load_env(__DIR__ . '/.env');

// Zona horaria del servidor para TODAS las fechas generadas por PHP
// (date(), incluidas las marcas oficiales de asistencia en attendance.php).
// Radio Doliv opera en México, así que por defecto es horario de México; se
// puede sobreescribir con APP_TIMEZONE en .env. Las comparaciones de caducidad
// del OTP se hacen en SQL con NOW(), no dependen de esto.
date_default_timezone_set(env_get('APP_TIMEZONE') ?: 'America/Mexico_City');

$DB_HOST = env_get('DB_HOST') ?: '127.0.0.1';
$DB_NAME = env_get('DB_NAME') ?: 'hive_db';
$DB_USER = env_get('DB_USER') ?: 'root';
$DB_PASS = env_get('DB_PASS') ?: '';

define('APP_BASE_PATH', env_get('APP_BASE_PATH') !== null ? env_get('APP_BASE_PATH') : '/hive-backend');

define('SMTP_HOST', env_get('SMTP_HOST') ?: '');
define('SMTP_PORT', (int) (env_get('SMTP_PORT') ?: 587));
define('SMTP_USER', env_get('SMTP_USER') ?: '');
define('SMTP_PASS', env_get('SMTP_PASS') ?: '');
define('SMTP_FROM', env_get('SMTP_FROM') ?: env_get('SMTP_USER') ?: '');
define('SMTP_FROM_NAME', env_get('SMTP_FROM_NAME') ?: 'Radio Doliv');

require __DIR__ . '/lib/PHPMailer/Exception.php';
require __DIR__ . '/lib/PHPMailer/PHPMailer.php';
require __DIR__ . '/lib/PHPMailer/SMTP.php';

try {
    $pdo = new PDO(
        "mysql:host=$DB_HOST;dbname=$DB_NAME;charset=utf8mb4",
        $DB_USER,
        $DB_PASS,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]
    );

    // Zona horaria de la SESIÓN de MySQL: varias comparaciones (expiración de
    // OTP, marcas de asistencia) se hacen en SQL con NOW(), no con PHP -- ver
    // comentario de date_default_timezone_set() arriba. En XAMPP local MySQL
    // ya corre en hora de México (config del SO), pero en Hostinger arranca
    // en UTC, así que sin esto esas comparaciones quedan 6h adelantadas.
    // Offset fijo (no nombre de zona) porque hosting compartido normalmente
    // no trae cargadas las tablas de zonas horarias de MySQL; México ya no
    // cambia de horario (DST abolido desde 2022 salvo franja fronteriza).
    $pdo->exec("SET time_zone = '-06:00'");
} catch (PDOException $e) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Database connection failed']);
    exit;
}

define('UPLOAD_DIR', __DIR__ . '/uploads/');

// Almacenamiento privado: evidencia de incapacidades. NO se sirve por HTTP
// (hay un .htaccess que lo bloquea); solo se entrega por el endpoint
// autenticado GET /leave-requests/{id}/evidence.
define('EVIDENCE_DIR', __DIR__ . '/private/evidence/');
if (!is_dir(EVIDENCE_DIR)) {
    @mkdir(EVIDENCE_DIR, 0700, true);
}

// Evidencia adjunta al completar una tarea de departamento. Mismo trato que
// EVIDENCE_DIR: privado, solo por GET /dept-tasks/{id}/evidence autenticado.
define('TASK_EVIDENCE_DIR', __DIR__ . '/private/task_evidence/');
if (!is_dir(TASK_EVIDENCE_DIR)) {
    @mkdir(TASK_EVIDENCE_DIR, 0700, true);
}

// Documentos de equipo (PDF, Word, Excel, ...). Privados como la evidencia:
// nunca se sirven estáticos por Apache, solo por GET /document/download/{id}
// tras comprobar que quien pide pertenece al equipo dueño del documento.
define('DOCUMENT_DIR', __DIR__ . '/private/documents/');
if (!is_dir(DOCUMENT_DIR)) {
    @mkdir(DOCUMENT_DIR, 0700, true);
}

// Detecta http vs https del request actual en vez de asumir uno fijo: en
// local (XAMPP) es http, en Hostinger detrás de su proxy/SSL es https. Si
// se sirve como http y se anuncia https (o viceversa), el navegador/WebView
// bloquea la imagen como contenido mixto.
$isHttps = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
    || ($_SERVER['SERVER_PORT'] ?? null) == 443
    || strcasecmp($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '', 'https') === 0;
$uploadScheme = $isHttps ? 'https://' : 'http://';
define('UPLOAD_URL_BASE', $uploadScheme . ($_SERVER['HTTP_HOST'] ?? 'localhost') . APP_BASE_PATH . '/uploads/');
if (!is_dir(UPLOAD_DIR)) {
    mkdir(UPLOAD_DIR, 0777, true);
}

// Ruta al sitio público RADIODOLIV_PAGINA, para que site_content.php pueda
// guardar ahí las imágenes que sube el director desde la app (misma
// hive_db, pero es un proyecto PHP aparte). En local ambos proyectos son
// hermanos bajo htdocs; en producción puede no serlo, así que se puede
// sobreescribir con RADIODOLIV_PAGINA_PATH en .env.
define(
    'RADIODOLIV_PAGINA_PATH',
    env_get('RADIODOLIV_PAGINA_PATH') ?: dirname(__DIR__, 2) . '/RADIODOLIV_PAGINA'
);
