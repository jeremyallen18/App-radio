<?php
// Shared helpers for the Hive backend

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception as PHPMailerException;

function json_response($data, int $status = 200) {
    http_response_code($status);
    header('Content-Type: application/json');
    echo json_encode($data);
    exit;
}

// Some endpoints in the original API respond with a bare JSON string/array
// rather than an object (e.g. login returns the token as a plain string).
function raw_json_response($value, int $status = 200) {
    http_response_code($status);
    header('Content-Type: application/json');
    echo json_encode($value);
    exit;
}

function text_response(string $message, int $status = 200) {
    http_response_code($status);
    header('Content-Type: text/plain; charset=utf-8');
    echo $message;
    exit;
}

function error_response(string $message, int $status = 400) {
    json_response(['error' => $message], $status);
}

// Generates a 24-char hex id, mirroring the Mongo ObjectId style the
// original Node backend used (some client code assumes this shape).
function generate_id(): string {
    return bin2hex(random_bytes(12));
}

function generate_token(): string {
    return bin2hex(random_bytes(32));
}

function generate_team_code(): string {
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    $code = '';
    for ($i = 0; $i < 6; $i++) {
        $code .= $chars[random_int(0, strlen($chars) - 1)];
    }
    return $code;
}

function generate_otp(): string {
    return (string) random_int(100000, 999999);
}

// ---- calendario laboral de Radio Doliv --------------------------------
// La semana laboral es de LUNES A SÁBADO. El domingo es el único día no
// laboral. Cualquier cálculo de días hábiles (permisos/vacaciones,
// asistencia, faltas, justificación de ausencias, recurrencia de tareas)
// debe pasar por aquí para que la regla esté definida en un solo lugar.
function is_working_day(string $date): bool {
    // format('N'): 1 (lunes) .. 7 (domingo).
    return (int) (new DateTimeImmutable($date))->format('N') !== 7;
}

// Primer día con algún registro de asistencia del empleado ('Y-m-d'), o null si
// nunca ha fichado. Las faltas solo se cuentan A PARTIR de esta fecha: los días
// laborales anteriores (antes del alta del empleado o del arranque del control
// de asistencia) no cuentan como falta.
function attendance_first_record_date(PDO $pdo, string $employeeId): ?string {
    $stmt = $pdo->prepare('SELECT MIN(work_date) FROM attendance WHERE employee_id = ?');
    $stmt->execute([$employeeId]);
    $v = $stmt->fetchColumn();
    return ($v === false || $v === null) ? null : (string) $v;
}

// Nº de días laborales (lun-sáb) en [start, end], ambos inclusive.
function working_days_between(string $start, string $end): int {
    $from = new DateTimeImmutable($start);
    $to = new DateTimeImmutable($end);
    if ($to < $from) return 0;
    $n = 0;
    for ($d = $from; $d <= $to; $d = $d->modify('+1 day')) {
        if ((int) $d->format('N') !== 7) $n++;
    }
    return $n;
}

// Máximo permitido para un rango de "un mes de calendario": el mismo día del
// mes siguiente, y si ese día no existe (31-ene -> "31-feb"), el último día
// del mes siguiente. Devuelve 'Y-m-d'.
function one_calendar_month_max_end(string $start): string {
    $s = new DateTimeImmutable($start);
    $max = $s->modify('+1 month');
    // PHP desborda 31-ene +1 mes a 03-mar: detéctalo y retrocede al último
    // día del mes destino.
    if ($max->format('j') !== $s->format('j')) {
        $max = $max->modify('first day of this month')->modify('-1 day');
    }
    return $max->format('Y-m-d');
}

// Envía el código OTP de recuperación de contraseña por correo vía SMTP
// (PHPMailer). Devuelve true si el envío tuvo éxito. Si SMTP no está
// configurado (.env vacío) o el envío falla, no lanza excepción: se limita
// a devolver false y quien llame decide qué hacer (aquí, seguir logueando
// el OTP como respaldo para desarrollo local).
function send_otp_email(string $toEmail, string $otp): bool {
    if (SMTP_HOST === '' || SMTP_USER === '' || SMTP_PASS === '') {
        return false;
    }

    $mail = new PHPMailer(true);
    try {
        $mail->isSMTP();
        $mail->Host = SMTP_HOST;
        $mail->SMTPAuth = true;
        $mail->Username = SMTP_USER;
        $mail->Password = SMTP_PASS;
        $mail->SMTPSecure = SMTP_PORT === 465 ? 'ssl' : 'tls';
        $mail->Port = SMTP_PORT;
        $mail->CharSet = 'UTF-8';

        $mail->setFrom(SMTP_FROM, SMTP_FROM_NAME);
        $mail->addAddress($toEmail);

        $logoPath = __DIR__ . '/../assets/logo/logo.png';
        $hasLogo = file_exists($logoPath);
        if ($hasLogo) {
            $mail->addEmbeddedImage($logoPath, 'app-logo');
        }

        $mail->isHTML(true);
        $mail->Subject = 'Código para recuperar tu contraseña';
        $logoHtml = $hasLogo
            ? '<img src="cid:app-logo" alt="' . htmlspecialchars(SMTP_FROM_NAME) . '" width="72" height="72" style="display:block;margin:0 auto 16px;border-radius:16px;">'
            : '';
        $mail->Body = '<div style="background:#f2f3f7;padding:32px 16px;font-family:Segoe UI,Roboto,Helvetica,Arial,sans-serif;">'
            . '<div style="max-width:420px;margin:0 auto;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.08);">'
            . '<div style="background:#1a1a2e;padding:28px 24px;text-align:center;">'
            . $logoHtml
            . '<h1 style="margin:0;color:#ffffff;font-size:18px;font-weight:600;">' . htmlspecialchars(SMTP_FROM_NAME) . '</h1>'
            . '</div>'
            . '<div style="padding:32px 28px;text-align:center;color:#1f1f1f;">'
            . '<p style="margin:0 0 8px;font-size:15px;color:#3a3a3a;">Recuperación de contraseña</p>'
            . '<p style="margin:0 0 24px;font-size:14px;color:#6b6b6b;">Usa este código para restablecer tu contraseña:</p>'
            . '<div style="display:inline-block;padding:14px 28px;background:#f2f3f7;border-radius:10px;font-size:32px;font-weight:700;letter-spacing:8px;color:#1a1a2e;">'
            . htmlspecialchars($otp) . '</div>'
            . '<p style="margin:24px 0 0;font-size:13px;color:#8a8a8a;">El código vence en 10 minutos.</p>'
            . '<p style="margin:8px 0 0;font-size:13px;color:#8a8a8a;">Si no solicitaste este cambio, ignora este correo.</p>'
            . '</div>'
            . '</div>'
            . '</div>';
        $mail->AltBody = "Tu código para restablecer la contraseña es: $otp (vence en 10 minutos).";

        $mail->send();
        return true;
    } catch (PHPMailerException $e) {
        error_log('[hive-backend] Failed to send OTP email to ' . $toEmail . ': ' . $mail->ErrorInfo);
        return false;
    }
}

// ---- verificación de correo al registrarse ---------------------------
//
// El token viaja SOLO en el enlace del correo; en la base de datos se guarda
// únicamente su hash SHA-256 (email_verifications.token_hash). Un solo uso
// (consumed_at) y caducidad de 24 h (expires_at).

const EMAIL_VERIFICATION_TTL_HOURS = 24;
// Como máximo N correos de verificación por cuenta en la ventana de tiempo.
const EMAIL_VERIFICATION_MAX_PER_WINDOW = 3;
const EMAIL_VERIFICATION_WINDOW_MINUTES = 15;

function hash_verification_token(string $token): string {
    return hash('sha256', $token);
}

// Emite un token nuevo para $userId y devuelve el token EN CLARO (para el
// enlace del correo). No envía nada. Las filas previas se conservan (cada
// token es de un solo uso y caduca a las 24 h); así el límite de reenvíos
// puede contarlas. Un enlace anterior no consumido sigue sirviendo hasta que
// caduque, lo cual es aceptable (aleatorio de 256 bits, de un solo uso).
function issue_email_verification(PDO $pdo, string $userId, ?string $ip): string {
    // Higiene: quita filas caducadas y ya consumidas de hace más de un día.
    $pdo->prepare(
        'DELETE FROM email_verifications
          WHERE user_id = ? AND (consumed_at IS NOT NULL OR expires_at < DATE_SUB(NOW(), INTERVAL 1 DAY))'
    )->execute([$userId]);

    $token = generate_token(); // 64 hex, criptográficamente seguro
    $pdo->prepare(
        'INSERT INTO email_verifications (id, user_id, token_hash, expires_at, requested_ip)
         VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL ' . EMAIL_VERIFICATION_TTL_HOURS . ' HOUR), ?)'
    )->execute([generate_id(), $userId, hash_verification_token($token), $ip]);

    return $token;
}

// ¿Se puede enviar otro correo de verificación a este usuario ahora, o ya se
// alcanzó el límite de la ventana? (Anti-abuso del reenvío.)
function email_verification_send_allowed(PDO $pdo, string $userId): bool {
    $stmt = $pdo->prepare(
        'SELECT COUNT(*) FROM email_verifications
          WHERE user_id = ? AND created_at > DATE_SUB(NOW(), INTERVAL ' . EMAIL_VERIFICATION_WINDOW_MINUTES . ' MINUTE)'
    );
    $stmt->execute([$userId]);
    return (int) $stmt->fetchColumn() < EMAIL_VERIFICATION_MAX_PER_WINDOW;
}

// ---- limpieza automática de cuentas sin verificar --------------------
//
// Una cuenta creada que nunca abrió su enlace de verificación se conserva
// como máximo 72 h; pasado ese plazo se borra (sus filas dependientes se
// van con ella por las FK ON DELETE CASCADE). La condición
// `email_verified_at IS NULL` deja fuera SIEMPRE a cualquier cuenta
// verificada, así que ninguna cuenta activa puede caer aquí.
const UNVERIFIED_ACCOUNT_TTL_HOURS = 72;

// Borra las cuentas sin verificar que ya pasaron UNVERIFIED_ACCOUNT_TTL_HOURS
// y hace higiene de tokens de verificación sueltos. Devuelve cuántas cuentas
// se eliminaron. Idempotente y barata (índice idx_users_unverified).
function cleanup_unverified_accounts(PDO $pdo): int {
    $stmt = $pdo->prepare(
        'DELETE FROM users
          WHERE email_verified_at IS NULL
            AND created_at < DATE_SUB(NOW(), INTERVAL ' . UNVERIFIED_ACCOUNT_TTL_HOURS . ' HOUR)'
    );
    $stmt->execute();
    $removed = $stmt->rowCount();

    // Tokens ya consumidos o caducados hace más de un día que hayan quedado
    // sueltos (los de cuentas borradas se van solos por la FK).
    $pdo->exec(
        'DELETE FROM email_verifications
          WHERE consumed_at IS NOT NULL
             OR expires_at < DATE_SUB(NOW(), INTERVAL 1 DAY)'
    );

    return $removed;
}

// Base pública del backend para armar enlaces que salen por correo (esquema +
// host + ruta). Si PUBLIC_BASE_URL está configurada en .env se usa TAL CUAL:
// esos enlaces llevan un token de verificación y no pueden depender de la
// cabecera Host, que la fija quien hace la petición (host-header poisoning).
// Sin configurar (local/dev) se cae a detectar host y esquema del request,
// igual que UPLOAD_URL_BASE.
function backend_public_base_url(): string {
    if (PUBLIC_BASE_URL !== '') {
        return PUBLIC_BASE_URL;
    }
    $isHttps = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
        || (($_SERVER['SERVER_PORT'] ?? null) == 443)
        || strcasecmp($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '', 'https') === 0;
    $scheme = $isHttps ? 'https://' : 'http://';
    return $scheme . ($_SERVER['HTTP_HOST'] ?? 'localhost') . APP_BASE_PATH;
}

// Corta la petición con 403 code=EMAIL_UNVERIFIED si la cuenta no verificó su
// correo. Se usa en las acciones que lo exigen (crear permisos, justificar
// faltas). El resto de la app funciona sin verificar.
function require_verified_email(array $user): void {
    if (empty($user['email_verified_at'])) {
        json_response([
            'success' => false,
            'code'    => 'EMAIL_UNVERIFIED',
            'message' => 'Verifica tu correo para poder usar esta función. Revisa tu bandeja o pide un nuevo enlace desde el aviso de la app.',
        ], 403);
    }
}

// Envía el correo con el enlace de verificación. Devuelve true si se envió.
// Mismo patrón que send_otp_email(): si SMTP no está configurado o falla, no
// lanza excepción, solo devuelve false (quien llama loguea el enlace como
// respaldo para desarrollo).
function send_verification_email(string $toEmail, string $toName, string $verifyUrl): bool {
    if (SMTP_HOST === '' || SMTP_USER === '' || SMTP_PASS === '') {
        return false;
    }

    $mail = new PHPMailer(true);
    try {
        $mail->isSMTP();
        $mail->Host = SMTP_HOST;
        $mail->SMTPAuth = true;
        $mail->Username = SMTP_USER;
        $mail->Password = SMTP_PASS;
        $mail->SMTPSecure = SMTP_PORT === 465 ? 'ssl' : 'tls';
        $mail->Port = SMTP_PORT;
        $mail->CharSet = 'UTF-8';

        $mail->setFrom(SMTP_FROM, SMTP_FROM_NAME);
        $mail->addAddress($toEmail);

        $logoPath = __DIR__ . '/../assets/logo/logo.png';
        $hasLogo = file_exists($logoPath);
        if ($hasLogo) {
            $mail->addEmbeddedImage($logoPath, 'app-logo');
        }

        $safeUrl = htmlspecialchars($verifyUrl, ENT_QUOTES);
        $greeting = $toName !== '' ? 'Hola, ' . htmlspecialchars($toName) . ':' : 'Hola:';

        $mail->isHTML(true);
        $mail->Subject = 'Verifica tu correo — ' . SMTP_FROM_NAME;
        $logoHtml = $hasLogo
            ? '<img src="cid:app-logo" alt="' . htmlspecialchars(SMTP_FROM_NAME) . '" width="72" height="72" style="display:block;margin:0 auto 16px;border-radius:16px;">'
            : '';
        $mail->Body = '<div style="background:#f2f3f7;padding:32px 16px;font-family:Segoe UI,Roboto,Helvetica,Arial,sans-serif;">'
            . '<div style="max-width:460px;margin:0 auto;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.08);">'
            . '<div style="background:#1a1a2e;padding:28px 24px;text-align:center;">'
            . $logoHtml
            . '<h1 style="margin:0;color:#ffffff;font-size:18px;font-weight:600;">' . htmlspecialchars(SMTP_FROM_NAME) . '</h1>'
            . '</div>'
            . '<div style="padding:32px 28px;color:#1f1f1f;">'
            . '<p style="margin:0 0 12px;font-size:15px;">' . $greeting . '</p>'
            . '<p style="margin:0 0 20px;font-size:14px;color:#4a4a4a;">Confirma que este correo es tuyo para terminar de activar tu cuenta.</p>'
            . '<p style="text-align:center;margin:0 0 20px;">'
            . '<a href="' . $safeUrl . '" style="display:inline-block;padding:14px 28px;background:#1a1a2e;color:#ffffff;border-radius:10px;font-size:15px;font-weight:700;text-decoration:none;">Verificar mi correo</a>'
            . '</p>'
            . '<p style="margin:0 0 6px;font-size:12px;color:#8a8a8a;">Si el botón no funciona, copia y pega este enlace:</p>'
            . '<p style="margin:0 0 20px;font-size:12px;color:#5a5a5a;word-break:break-all;">' . $safeUrl . '</p>'
            . '<p style="margin:0;font-size:13px;color:#8a8a8a;">El enlace vence en ' . EMAIL_VERIFICATION_TTL_HOURS . ' horas. Si no creaste esta cuenta, ignora este correo.</p>'
            . '</div>'
            . '</div>'
            . '</div>';
        $mail->AltBody = "Verifica tu correo abriendo este enlace (vence en "
            . EMAIL_VERIFICATION_TTL_HOURS . " horas):\n$verifyUrl";

        $mail->send();
        return true;
    } catch (PHPMailerException $e) {
        error_log('[hive-backend] Failed to send verification email to ' . $toEmail . ': ' . $mail->ErrorInfo);
        return false;
    }
}

// Página HTML mínima que ve el usuario al abrir el enlace del correo en el
// navegador. $ok controla el color/acento; los textos son genéricos (no se
// revela si el token existía o no más allá de "válido / caducado / usado").
function render_verification_page(string $title, string $message, bool $ok): void {
    http_response_code($ok ? 200 : 400);
    header('Content-Type: text/html; charset=utf-8');
    $accent = $ok ? '#1a7f37' : '#b42318';
    $icon = $ok ? '&#10003;' : '&#33;';
    echo '<!doctype html><html lang="es"><head><meta charset="utf-8">'
        . '<meta name="viewport" content="width=device-width,initial-scale=1">'
        . '<title>' . htmlspecialchars($title) . '</title></head>'
        . '<body style="margin:0;background:#f2f3f7;font-family:Segoe UI,Roboto,Helvetica,Arial,sans-serif;">'
        . '<div style="max-width:420px;margin:12vh auto 0;background:#fff;border-radius:16px;'
        . 'box-shadow:0 2px 16px rgba(0,0,0,.08);overflow:hidden;text-align:center;">'
        . '<div style="background:#1a1a2e;padding:26px;">'
        . '<span style="display:inline-block;width:52px;height:52px;line-height:52px;border-radius:50%;'
        . 'background:' . $accent . ';color:#fff;font-size:24px;">' . $icon . '</span></div>'
        . '<div style="padding:28px 26px;color:#1f1f1f;">'
        . '<h1 style="margin:0 0 10px;font-size:19px;">' . htmlspecialchars($title) . '</h1>'
        . '<p style="margin:0;font-size:14px;color:#4a4a4a;line-height:1.5;">' . htmlspecialchars($message) . '</p>'
        . '</div></div></body></html>';
    exit;
}

// The Flutter client sends either application/json or, when it posts a
// Dart Map without jsonEncode, application/x-www-form-urlencoded. This
// merges both so handlers can read fields the same way regardless.
function request_body(): array {
    $contentType = $_SERVER['CONTENT_TYPE'] ?? '';
    $raw = file_get_contents('php://input');

    if (stripos($contentType, 'application/json') !== false) {
        $decoded = json_decode($raw, true);
        return is_array($decoded) ? $decoded : [];
    }

    if (!empty($_POST)) {
        return $_POST;
    }

    // Fallback: try to parse as urlencoded even without the header, and
    // fall back to JSON if that yields nothing usable.
    parse_str($raw, $parsed);
    if (!empty($parsed)) {
        return $parsed;
    }
    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : [];
}

function get_bearer_or_raw_token(): ?string {
    $headers = getallheaders();
    foreach ($headers as $name => $value) {
        if (strcasecmp($name, 'Authorization') === 0) {
            return trim(str_ireplace('Bearer', '', $value));
        }
    }
    return null;
}

// Looks up the user for the token in the Authorization header, or ends
// the request with 401 if missing/invalid.
function require_auth(PDO $pdo): array {
    $token = get_bearer_or_raw_token();
    if (!$token) {
        error_response('Missing Authorization header', 401);
    }
    $stmt = $pdo->prepare('SELECT * FROM users WHERE token = ?');
    $stmt->execute([$token]);
    $user = $stmt->fetch();
    if (!$user) {
        error_response('Invalid or expired token', 401);
    }
    return $user;
}

// ---- team authorization -------------------------------------------------
// This schema references people by email rather than by user id, so every
// membership check is done on teams.leader_email / team_members.email.

function is_team_member(PDO $pdo, string $teamId, string $email): bool {
    $stmt = $pdo->prepare(
        'SELECT 1 FROM teams t
         LEFT JOIN team_members tm ON tm.team_id = t.id AND tm.email = ?
         WHERE t.id = ? AND (t.leader_email = ? OR tm.email IS NOT NULL)
         LIMIT 1'
    );
    $stmt->execute([$email, $teamId, $email]);
    return (bool) $stmt->fetch();
}

function is_team_leader(PDO $pdo, string $teamId, string $email): bool {
    $stmt = $pdo->prepare('SELECT 1 FROM teams WHERE id = ? AND leader_email = ? LIMIT 1');
    $stmt->execute([$teamId, $email]);
    return (bool) $stmt->fetch();
}

function require_team_member(PDO $pdo, string $teamId, array $user): void {
    if (!is_team_member($pdo, $teamId, $user['email'])) {
        error_response('You do not belong to this team', 403);
    }
}

function require_team_leader(PDO $pdo, string $teamId, array $user): void {
    if (!is_team_leader($pdo, $teamId, $user['email'])) {
        error_response('Only the team leader can perform this action', 403);
    }
}

// tasks are stored against team_code, so authorization has to resolve the
// team id first.
function team_from_code(PDO $pdo, string $teamCode): ?array {
    $stmt = $pdo->prepare('SELECT * FROM teams WHERE team_code = ?');
    $stmt->execute([$teamCode]);
    $team = $stmt->fetch();
    return $team ?: null;
}

// $entityType/$entityId (opcionales) dejan que el cliente sepa a qué pantalla
// ir al tocar la notificación (ver migración 020). Si no se pasan, el cliente
// cae al destino por categoría según $type.
require_once __DIR__ . '/push.php';

function notify_user(
    PDO $pdo,
    string $email,
    ?string $teamId,
    string $type,
    string $message,
    ?string $entityType = null,
    ?string $entityId = null
): void {
    $stmt = $pdo->prepare(
        'INSERT INTO notifications (team_id, email, type, message, entity_type, entity_id)
         VALUES (?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([$teamId, $email, $type, $message, $entityType, $entityId]);
    $notifId = $pdo->lastInsertId();

    // Push best-effort: nunca debe afectar la respuesta ni el flujo que llamó.
    try {
        $collapse = ($type === 'chat' && $entityId)
            ? 'chat:' . $entityId
            : 'notif:' . $notifId;
        push_send_to_user(
            $pdo,
            $email,
            push_title_for_type($type),
            $message,
            [
                'type'       => $type,
                'entityType' => (string) $entityType,
                'entityId'   => (string) $entityId,
            ],
            $collapse
        );
    } catch (Throwable $e) {
        error_log('notify_user push failed: ' . $e->getMessage());
    }
}

// ---- organizational RBAC -------------------------------------------------
// Roles jerárquicos de Radio Doliv. 'employee' es el valor por defecto de
// users.role, así que las cuentas existentes (creadas antes de esta
// migración) quedan como empleados sin romper nada.

const ROLES = ['director', 'manager', 'employee'];

// Corta la petición con 403 si el rol del usuario autenticado no está en
// $allowedRoles. Se usa junto con require_auth(): `require_role($user, ['director'])`.
function require_role(array $user, array $allowedRoles): void {
    if (!in_array($user['role'], $allowedRoles, true)) {
        error_response('No tienes permiso para realizar esta acción', 403);
    }
}

// El manager de un departamento puede gestionar a sus empleados; el
// director puede gestionar cualquier departamento.
function require_department_manager_or_director(PDO $pdo, array $user, string $departmentId): void {
    if ($user['role'] === 'director') {
        return;
    }
    if ($user['role'] === 'manager' && $user['department_id'] === $departmentId) {
        return;
    }
    error_response('Solo el director o el manager del departamento pueden realizar esta acción', 403);
}

// ---- site_content.php helpers --------------------------------------------
// Valida que un enlace externo use un protocolo seguro antes de guardarlo.
// Copiado de RADIODOLIV_PAGINA/inc/helpers/format.php (mismo contrato) para
// que site_content.php pueda validar los enlaces del sitio público sin
// depender de un archivo fuera de este proyecto.
function safe_external_url($url): string {
    $value = trim((string) $url);
    if ($value === '' || strtoupper($value) === 'NULL') {
        return '';
    }
    $parts = parse_url($value);
    if (!isset($parts['scheme'])) {
        return $value;
    }
    $allowed = ['http', 'https', 'mailto', 'tel'];
    return in_array(strtolower($parts['scheme']), $allowed, true) ? $value : '';
}
