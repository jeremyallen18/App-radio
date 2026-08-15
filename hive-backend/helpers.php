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

function notify_user(PDO $pdo, string $email, ?string $teamId, string $type, string $message): void {
    $stmt = $pdo->prepare('INSERT INTO notifications (team_id, email, type, message) VALUES (?, ?, ?, ?)');
    $stmt->execute([$teamId, $email, $type, $message]);
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
