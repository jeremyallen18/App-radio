<?php
// DB connection for the Hive backend

function load_env(string $path): void {
    if (!is_file($path)) return;
    foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        $line = trim($line);
        if ($line === '' || $line[0] === '#') continue;
        [$key, $value] = array_pad(explode('=', $line, 2), 2, '');
        $key = trim($key);
        $value = trim($value);
        if ($key !== '' && getenv($key) === false) {
            putenv("$key=$value");
        }
    }
}
load_env(__DIR__ . '/.env');

// Zona horaria del servidor para TODAS las fechas generadas por PHP
// (date(), incluidas las marcas oficiales de asistencia en attendance.php).
// Radio Doliv opera en México, así que por defecto es horario de México; se
// puede sobreescribir con APP_TIMEZONE en .env. Las comparaciones de caducidad
// del OTP se hacen en SQL con NOW(), no dependen de esto.
date_default_timezone_set(getenv('APP_TIMEZONE') ?: 'America/Mexico_City');

$DB_HOST = getenv('DB_HOST') ?: '127.0.0.1';
$DB_NAME = getenv('DB_NAME') ?: 'hive_db';
$DB_USER = getenv('DB_USER') ?: 'root';
$DB_PASS = getenv('DB_PASS') ?: '';

define('APP_BASE_PATH', getenv('APP_BASE_PATH') !== false ? getenv('APP_BASE_PATH') : '/hive-backend');

define('SMTP_HOST', getenv('SMTP_HOST') ?: '');
define('SMTP_PORT', (int) (getenv('SMTP_PORT') ?: 587));
define('SMTP_USER', getenv('SMTP_USER') ?: '');
define('SMTP_PASS', getenv('SMTP_PASS') ?: '');
define('SMTP_FROM', getenv('SMTP_FROM') ?: getenv('SMTP_USER') ?: '');
define('SMTP_FROM_NAME', getenv('SMTP_FROM_NAME') ?: 'Radio Doliv');

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
    getenv('RADIODOLIV_PAGINA_PATH') ?: dirname(__DIR__, 2) . '/RADIODOLIV_PAGINA'
);
