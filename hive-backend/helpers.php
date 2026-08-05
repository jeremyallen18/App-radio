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

        $mail->isHTML(true);
        $mail->Subject = 'Código para recuperar tu contraseña';
        $mail->Body = '<p>Usa este código para restablecer tu contraseña:</p>'
            . '<p style="font-size:28px;font-weight:bold;letter-spacing:4px;">' . htmlspecialchars($otp) . '</p>'
            . '<p>El código vence en 10 minutos. Si no solicitaste este cambio, ignora este correo.</p>';
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
