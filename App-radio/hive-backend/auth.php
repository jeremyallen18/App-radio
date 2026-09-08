<?php
// Alta de cuenta, inicio de sesión, verificación de correo y recuperación de
// contraseña (OTP). El token que devuelve login viaja como string plano por
// compatibilidad; email_verifications guarda solo el hash del token (ver
// helpers.php / migración 023).

function googleOAuthStub(PDO $pdo) {
    text_response('Google OAuth is not available on this local backend.', 501);
}

// Manda el correo de verificación a $user y, si SMTP no está disponible o
// falla, deja el enlace en el log del backend como respaldo para desarrollo.
function dispatch_verification_email(PDO $pdo, array $user): bool {
    $token = issue_email_verification($pdo, $user['id'], $_SERVER['REMOTE_ADDR'] ?? null);
    $link = backend_public_base_url() . '/verify-email?token=' . $token;
    $sent = send_verification_email($user['email'], $user['name'] ?? '', $link);
    error_log('[hive-backend] Email verification link for ' . $user['email'] . ': ' . $link
        . ($sent ? ' (emailed)' : ' (NOT emailed)'));
    return $sent;
}

function signup(PDO $pdo) {
    $body = request_body();
    $name = trim($body['name'] ?? '');
    $email = trim($body['email'] ?? '');
    $password = $body['password'] ?? '';

    if ($name === '' || $email === '' || $password === '') {
        text_response('All fields are required', 400);
    }

    // Barrido perezoso: si el cron del host no está configurado, cada alta
    // nueva limpia las cuentas sin verificar que ya pasaron las 72 h. Nunca
    // debe impedir el registro, así que cualquier fallo se traga y se loguea.
    try {
        cleanup_unverified_accounts($pdo);
    } catch (Throwable $e) {
        error_log('[hive-backend] cleanup_unverified_accounts failed: ' . $e->getMessage());
    }

    $stmt = $pdo->prepare('SELECT * FROM users WHERE email = ?');
    $stmt->execute([$email]);
    $existing = $stmt->fetch();
    if ($existing) {
        // Si la cuenta existe pero nunca verificó el correo, se reenvía el
        // enlace en vez de solo rechazar: cubre a quien se registró y perdió
        // el correo. Una cuenta ya verificada sí se rechaza tal cual.
        if (empty($existing['email_verified_at'])) {
            if (email_verification_send_allowed($pdo, $existing['id'])) {
                dispatch_verification_email($pdo, $existing);
            }
            text_response('Ese correo ya está registrado pero sin verificar. Revisa tu bandeja: te enviamos el enlace de verificación.', 409);
        }
        text_response('Email already registered', 409);
    }

    $userId = generate_id();
    $stmt = $pdo->prepare('INSERT INTO users (id, name, email, password) VALUES (?, ?, ?, ?)');
    $stmt->execute([$userId, $name, $email, password_hash($password, PASSWORD_BCRYPT)]);

    // Número de control único e intransferible. Un fallo aquí no debe impedir
    // el alta: el director puede corregirlo luego desde la app.
    try {
        assign_next_control_number($pdo, $userId);
    } catch (Throwable $e) {
        error_log('[hive-backend] assign_next_control_number failed: ' . $e->getMessage());
    }

    dispatch_verification_email($pdo, ['id' => $userId, 'name' => $name, 'email' => $email]);

    text_response('Cuenta creada. Te enviamos un correo para verificar tu dirección: ábrela para poder iniciar sesión.', 200);
}

// GET /verify-email?token=...  — el usuario abre este enlace desde su correo.
// Responde una página HTML (no JSON). Mensajes genéricos: válido / caducado /
// ya usado; no se confirma si el token existía.
function verifyEmail(PDO $pdo) {
    $token = trim($_GET['token'] ?? '');
    if ($token === '') {
        render_verification_page('Enlace no válido',
            'Falta el código de verificación. Abre el enlace completo desde tu correo.', false);
    }

    $stmt = $pdo->prepare('SELECT * FROM email_verifications WHERE token_hash = ? LIMIT 1');
    $stmt->execute([hash_verification_token($token)]);
    $row = $stmt->fetch();

    if (!$row) {
        render_verification_page('Enlace no válido',
            'Este enlace de verificación no es válido. Pide uno nuevo desde la app.', false);
    }
    if (!empty($row['consumed_at'])) {
        render_verification_page('Correo ya verificado',
            'Este enlace ya se usó. Tu correo está verificado; puedes cerrar esta página.', true);
    }
    if (strtotime($row['expires_at']) < time()) {
        render_verification_page('Enlace caducado',
            'Este enlace de verificación caducó. Pide uno nuevo desde el aviso de la app.', false);
    }

    // new_email != NULL (migración 029): esta fila confirma un CAMBIO de correo,
    // no el alta. Se revisa la unicidad justo aquí (otra cuenta pudo tomar esa
    // dirección entre la solicitud y ahora).
    $newEmail = $row['new_email'] ?? null;
    if ($newEmail !== null && $newEmail !== '') {
        $stmt = $pdo->prepare('SELECT id FROM users WHERE email = ? AND id <> ?');
        $stmt->execute([$newEmail, $row['user_id']]);
        if ($stmt->fetch()) {
            render_verification_page('No se pudo cambiar el correo',
                'Ese correo ya está en uso por otra cuenta. Pide el cambio de nuevo con otra dirección.', false);
        }
    }

    $pdo->beginTransaction();
    try {
        $pdo->prepare('UPDATE email_verifications SET consumed_at = NOW() WHERE id = ? AND consumed_at IS NULL')
            ->execute([$row['id']]);
        if ($newEmail !== null && $newEmail !== '') {
            $pdo->prepare('UPDATE users SET email = ?, pending_email = NULL, email_verified_at = NOW() WHERE id = ?')
                ->execute([$newEmail, $row['user_id']]);
            // Invalida cualquier otro enlace pendiente del mismo usuario para
            // que un cambio anterior sin confirmar deje de poder aplicarse.
            $pdo->prepare('DELETE FROM email_verifications WHERE user_id = ? AND consumed_at IS NULL AND id <> ?')
                ->execute([$row['user_id'], $row['id']]);
        } else {
            $pdo->prepare('UPDATE users SET email_verified_at = COALESCE(email_verified_at, NOW()) WHERE id = ?')
                ->execute([$row['user_id']]);
        }
        $pdo->commit();
    } catch (Throwable $e) {
        // Si el fallo fue el propio commit() ya no hay transacción activa;
        // rollBack() sin guard lanzaría una segunda excepción que taparía la
        // original. Mismo patrón que el resto del backend.
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $e;
    }

    if ($newEmail !== null && $newEmail !== '') {
        render_verification_page('¡Correo actualizado!',
            'Tu nuevo correo quedó confirmado. Úsalo la próxima vez que inicies sesión.', true);
    }
    render_verification_page('¡Correo verificado!',
        'Listo. Ya puedes volver a la app y usar tu cuenta con normalidad.', true);
}

// POST /user/resendVerification  — body: { email }. Siempre responde 200 con
// un mensaje neutro (no revela si el correo existe). Con límite de envíos.
function resendVerification(PDO $pdo) {
    $body = request_body();
    $email = trim($body['email'] ?? '');
    $neutral = ['success' => true,
        'message' => 'Si la cuenta existe y aún no está verificada, te enviamos un nuevo enlace.'];

    if ($email === '') {
        json_response($neutral);
    }
    $stmt = $pdo->prepare('SELECT * FROM users WHERE email = ?');
    $stmt->execute([$email]);
    $user = $stmt->fetch();

    if ($user && empty($user['email_verified_at'])
        && email_verification_send_allowed($pdo, $user['id'])) {
        dispatch_verification_email($pdo, $user);
    }
    json_response($neutral);
}

function login(PDO $pdo) {
    $body = request_body();
    $email = trim($body['email'] ?? '');
    $password = $body['password'] ?? '';

    $stmt = $pdo->prepare('SELECT * FROM users WHERE email = ?');
    $stmt->execute([$email]);
    $user = $stmt->fetch();

    if (!$user || !password_verify($password, $user['password'])) {
        error_response('Invalid email or password', 401);
    }

    // Correo sin verificar: NO se emite token. Se reenvía el enlace (con el
    // límite anti-abuso de siempre) y se responde con un código que el
    // cliente reconoce para mostrar el aviso de "verifica tu correo".
    if (empty($user['email_verified_at'])) {
        if (email_verification_send_allowed($pdo, $user['id'])) {
            dispatch_verification_email($pdo, $user);
        }
        json_response([
            'success' => false,
            'code'    => 'EMAIL_UNVERIFIED',
            'message' => 'Verifica tu correo antes de iniciar sesión. Te reenviamos el enlace; revisa tu bandeja y la carpeta de spam.',
        ], 403);
    }

    $token = generate_token();
    $stmt = $pdo->prepare('UPDATE users SET token = ? WHERE id = ?');
    $stmt->execute([$token, $user['id']]);

    // Contrato histórico: el cliente decodifica el cuerpo entero como el token.
    // Los builds ya instalados (anteriores a la verificación de correo) hacen
    // jsonDecode(body) y lo guardan tal cual, así que NO se puede devolver un
    // objeto por defecto sin dejarlos fuera. Solo se manda {token, emailVerified}
    // cuando el cliente lo pide con la cabecera X-Client-Features: login-object.
    // El login NO se bloquea aunque el correo no esté verificado.
    $features = $_SERVER['HTTP_X_CLIENT_FEATURES'] ?? '';
    if (strpos($features, 'login-object') !== false) {
        json_response([
            'token'         => $token,
            'emailVerified' => !empty($user['email_verified_at']),
        ], 200);
    }
    raw_json_response($token, 200);
}

function resetPassword(PDO $pdo) {
    $body = request_body();
    $email = trim($body['email'] ?? '');

    $stmt = $pdo->prepare('SELECT id FROM users WHERE email = ?');
    $stmt->execute([$email]);
    $user = $stmt->fetch();
    if (!$user) {
        json_response(['error' => 'No account found for that email'], 404);
    }

    $otp = generate_otp();
    $stmt = $pdo->prepare('UPDATE users SET otp = ?, otp_expires = DATE_ADD(NOW(), INTERVAL 10 MINUTE), otp_verified = 0 WHERE id = ?');
    $stmt->execute([$otp, $user['id']]);

    $sent = send_otp_email($email, $otp);

    // El OTP también se loguea como respaldo: si SMTP no está configurado
    // (desarrollo local) o el envío falla, se puede leer aquí igualmente.
    error_log("[hive-backend] Password reset OTP for $email: $otp" . ($sent ? ' (emailed)' : ' (NOT emailed)'));

    json_response(['message' => $sent
        ? 'OTP enviado a tu correo'
        : 'OTP generado, pero no se pudo enviar el correo (revisa la configuración SMTP o el log del backend)']);
}

function verifyOTP(PDO $pdo, string $email) {
    $body = request_body();
    $otp = trim($body['OTP'] ?? '');

    if ($otp === '') {
        json_response(['error' => 'Invalid or expired OTP'], 400);
    }

    // La caducidad se compara dentro de SQL a propósito: PHP y MySQL pueden
    // estar en zonas horarias distintas, y comparar strtotime() contra un
    // timestamp generado por MySQL daba el OTP por expirado siempre.
    $stmt = $pdo->prepare(
        'SELECT * FROM users
         WHERE email = ? AND otp = ? AND otp IS NOT NULL AND otp_expires > NOW()'
    );
    $stmt->execute([$email, $otp]);
    $user = $stmt->fetch();

    if (!$user) {
        json_response(['error' => 'Invalid or expired OTP'], 400);
    }

    $stmt = $pdo->prepare('UPDATE users SET otp_verified = 1 WHERE id = ?');
    $stmt->execute([$user['id']]);

    json_response(['message' => 'OTP verified']);
}

function newPassword(PDO $pdo, string $email) {
    $body = request_body();
    $newPassword = $body['newPassword'] ?? '';
    $confirmPassword = $body['confirmPassword'] ?? '';

    if ($newPassword === '' || $newPassword !== $confirmPassword) {
        json_response(['error' => 'Passwords do not match'], 400);
    }

    // Misma razón que en verifyOTP: la caducidad se evalúa en SQL.
    $stmt = $pdo->prepare(
        'SELECT * FROM users
         WHERE email = ? AND otp_verified = 1 AND otp_expires > NOW()'
    );
    $stmt->execute([$email]);
    $user = $stmt->fetch();

    if (!$user) {
        json_response(['error' => 'OTP verification required or expired'], 400);
    }

    // token = NULL invalida cualquier sesión abierta: si alguien recupera su
    // contraseña porque sospecha que su cuenta está comprometida, el token que
    // pudiera tener un tercero deja de funcionar de inmediato (antes seguía
    // válido hasta el siguiente login). El usuario vuelve a la pantalla de
    // login tras cambiar la contraseña, así que esto es transparente para él.
    $stmt = $pdo->prepare('UPDATE users SET password = ?, token = NULL, otp = NULL, otp_expires = NULL, otp_verified = 0 WHERE id = ?');
    $stmt->execute([password_hash($newPassword, PASSWORD_BCRYPT), $user['id']]);

    json_response(['message' => 'Password updated successfully']);
}

// ---- autoservicio de cuenta (pantalla "Editar cuenta", migración 029) ----
// Todo autenticado. El cambio de correo NO es inmediato: se guarda como
// pendiente y lo aplica verifyEmail() cuando el usuario abre el enlace que se
// envía a la dirección nueva.

// POST /user/account/name  — body { name }.
function updateAccountName(PDO $pdo) {
    $user = require_auth($pdo);
    $body = request_body();
    $name = trim($body['name'] ?? '');
    if ($name === '') {
        error_response('El nombre no puede estar vacío', 400);
    }
    if (mb_strlen($name) > 255) {
        error_response('El nombre es demasiado largo', 400);
    }
    $pdo->prepare('UPDATE users SET name = ? WHERE id = ?')->execute([$name, $user['id']]);

    $stmt = $pdo->prepare('SELECT * FROM users WHERE id = ?');
    $stmt->execute([$user['id']]);
    json_response(build_user_profile_payload($pdo, $stmt->fetch()));
}

// POST /user/account/password  — body { currentPassword, newPassword,
// confirmPassword }. Emite un token NUEVO (se mantiene la sesión en este
// dispositivo; cualquier otra queda invalidada) y lo devuelve.
function changePassword(PDO $pdo) {
    $user = require_auth($pdo);
    $body = request_body();
    $current = $body['currentPassword'] ?? '';
    $new = $body['newPassword'] ?? '';
    $confirm = $body['confirmPassword'] ?? '';

    if (!password_verify($current, $user['password'])) {
        error_response('La contraseña actual no es correcta', 400);
    }
    if (mb_strlen($new) < 6) {
        error_response('La nueva contraseña debe tener al menos 6 caracteres', 400);
    }
    if ($new !== $confirm) {
        error_response('La confirmación no coincide con la nueva contraseña', 400);
    }
    if (password_verify($new, $user['password'])) {
        error_response('La nueva contraseña debe ser distinta de la actual', 400);
    }

    $token = generate_token();
    $pdo->prepare('UPDATE users SET password = ?, token = ? WHERE id = ?')
        ->execute([password_hash($new, PASSWORD_BCRYPT), $token, $user['id']]);

    json_response(['token' => $token]);
}

// POST /user/account/email  — body { currentPassword, newEmail }. Guarda el
// correo nuevo como pendiente y envía el enlace de confirmación a ESA
// dirección. El correo actual y la sesión siguen válidos entretanto.
function requestEmailChange(PDO $pdo) {
    $user = require_auth($pdo);
    $body = request_body();
    $current = $body['currentPassword'] ?? '';
    $newEmail = strtolower(trim($body['newEmail'] ?? ''));

    if (!password_verify($current, $user['password'])) {
        error_response('La contraseña actual no es correcta', 400);
    }
    if ($newEmail === '' || !filter_var($newEmail, FILTER_VALIDATE_EMAIL)) {
        error_response('Correo inválido', 400);
    }
    if ($newEmail === strtolower(trim($user['email']))) {
        error_response('Ese ya es tu correo actual', 400);
    }

    $stmt = $pdo->prepare('SELECT id FROM users WHERE email = ? AND id <> ?');
    $stmt->execute([$newEmail, $user['id']]);
    if ($stmt->fetch()) {
        error_response('Ese correo ya está en uso por otra cuenta', 409);
    }

    if (!email_verification_send_allowed($pdo, $user['id'])) {
        error_response('Has pedido demasiados correos de verificación. Espera unos minutos e inténtalo de nuevo.', 429);
    }

    $pdo->prepare('UPDATE users SET pending_email = ? WHERE id = ?')->execute([$newEmail, $user['id']]);

    $token = issue_email_verification($pdo, $user['id'], $_SERVER['REMOTE_ADDR'] ?? null, $newEmail);
    $link = backend_public_base_url() . '/verify-email?token=' . $token;
    $sent = send_verification_email($newEmail, $user['name'] ?? '', $link);
    error_log('[hive-backend] Email change link for ' . $user['email'] . ' -> ' . $newEmail . ': ' . $link
        . ($sent ? ' (emailed)' : ' (NOT emailed)'));

    json_response(['message' => $sent
        ? 'Te enviamos un enlace a ' . $newEmail . '. Ábrelo para confirmar el cambio.'
        : 'No se pudo enviar el correo de confirmación. Revisa la configuración SMTP o el log del backend.']);
}

// POST /user/account/email/cancel  — descarta el cambio de correo pendiente.
function cancelEmailChange(PDO $pdo) {
    $user = require_auth($pdo);
    $pdo->prepare('UPDATE users SET pending_email = NULL WHERE id = ?')->execute([$user['id']]);
    $pdo->prepare('DELETE FROM email_verifications WHERE user_id = ? AND new_email IS NOT NULL AND consumed_at IS NULL')
        ->execute([$user['id']]);

    $stmt = $pdo->prepare('SELECT * FROM users WHERE id = ?');
    $stmt->execute([$user['id']]);
    json_response(build_user_profile_payload($pdo, $stmt->fetch()));
}
