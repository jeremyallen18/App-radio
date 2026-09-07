<?php
require __DIR__ . '/config.php';
require __DIR__ . '/helpers.php';
require __DIR__ . '/site_content.php';
require __DIR__ . '/events.php';
require __DIR__ . '/attendance.php';
require __DIR__ . '/leave_requests.php';
require __DIR__ . '/absences.php';
require __DIR__ . '/dept_tasks.php';
require __DIR__ . '/internal_announcements.php';

// Documentos de equipo: tipos permitidos y tamaño máximo. Van aquí (y no
// junto a sus handlers) porque el dispatcher de rutas corre antes de llegar
// a esa sección del archivo, y `const` a nivel de script no se "hoistea".
const DOCUMENT_ALLOWED_EXT = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
    'txt', 'csv', 'zip', 'rar', '7z',
];
const DOCUMENT_MAX_BYTES = 25 * 1024 * 1024; // 25 MB

// ---- routing -------------------------------------------------------

$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$base = APP_BASE_PATH;
if (strpos($uri, $base) === 0) {
    $uri = substr($uri, strlen($base));
}
if ($uri === '' || $uri === false) {
    $uri = '/';
}
$method = $_SERVER['REQUEST_METHOD'];

$routes = [
    ['GET',  '#^/?$#',                                       'home'],
    ['POST', '#^/user/signup/?$#',                            'signup'],
    ['POST', '#^/user/login/?$#',                             'login'],
    ['GET',  '#^/verify-email/?$#',                           'verifyEmail'],
    ['POST', '#^/user/resendVerification/?$#',                'resendVerification'],
    ['POST', '#^/user/resetPassword/?$#',                     'resetPassword'],
    ['POST', '#^/user/verifyOTP/([^/]+)/?$#',                 'verifyOTP'],
    ['POST', '#^/user/newPassword/([^/]+)/?$#',               'newPassword'],
    ['GET',  '#^/user/sendName/?$#',                          'sendName'],
    ['POST', '#^/user/sendMessage/([^/]+)/?$#',               'sendMessageToLeader'],
    ['GET',  '#^/googleOAuth/?$#',                            'googleOAuthStub'],
    ['POST', '#^/team/createTeam/?$#',                        'createTeam'],
    ['POST', '#^/team/sendTeamcode/([^/]+)/([^/]+)/?$#',      'sendTeamcode'],
    ['POST', '#^/team/joinTeam/?$#',                          'joinTeam'],
    ['GET',  '#^/team/showTeams/?$#',                         'showTeams'],
    // La creación de tareas se unificó en el flujo por departamento
    // (POST /dept-tasks). El endpoint viejo /team/task fue retirado.
    ['POST', '#^/team/taskDone/?$#',                          'taskDone'],
    ['GET',  '#^/team/incompleteTasks/?$#',                   'incompleteTasks'],
    ['GET',  '#^/team/completedTasks/?$#',                    'completedTasks'],
    ['POST', '#^/team/deleteMember/([^/]+)/?$#',              'deleteMember'],
    ['POST', '#^/team/deleteTeam/([^/]+)/?$#',                'deleteTeam'],
    ['POST', '#^/team/leaderResign/([^/]+)/?$#',              'leaderResign'],
    // Mensajería directa 1 a 1 (ver migración 016). Ya no hay sala global:
    // solo se leen las conversaciones en las que participa quien pregunta.
    ['GET',  '#^/chat/conversations/?$#',                     'chatConversations'],
    ['GET',  '#^/chat/thread/([^/]+)/?$#',                    'chatThread'],
    ['POST', '#^/chat/sendMessage/?$#',                       'sendChatMessage'],
    ['GET',  '#^/image/showImage/([^/]+)/?$#',                'showImage'],
    ['POST', '#^/image/addImage/?$#',                         'addImage'],
    ['POST', '#^/text/addText/([^/]+)/?$#',                   'addText'],
    ['GET',  '#^/text/showText/([^/]+)/?$#',                  'showText'],
    // Documentos de equipo (PDF, Word, Excel, ...). Cualquier miembro lista,
    // sube y descarga; borra quien lo subió o el líder.
    ['GET',  '#^/document/list/([^/]+)/?$#',                  'teamDocumentsList'],
    ['POST', '#^/document/upload/?$#',                        'teamDocumentUpload'],
    ['GET',  '#^/document/download/([^/]+)/?$#',              'teamDocumentDownload'],
    ['POST', '#^/document/([^/]+)/delete/?$#',                'teamDocumentDelete'],
    ['POST', '#^/leave/applyLeave/([^/]+)/?$#',                'applyLeave'],
    ['POST', '#^/leave/leaveResult/([^/]+)/?$#',               'leaveResult'],
    ['GET',  '#^/notifications/?$#',                          'listNotifications'],
    ['POST', '#^/notifications/read-all/?$#',                 'markAllNotificationsRead'],
    ['POST', '#^/notifications/([^/]+)/read/?$#',             'markNotificationRead'],
    ['POST', '#^/devices/register/?$#',                       'deviceRegister'],
    ['POST', '#^/devices/unregister/?$#',                     'deviceUnregister'],
    ['GET',  '#^/user/me/?$#',                                'getMe'],
    ['POST', '#^/user/photo/?$#',                             'updateProfilePhoto'],
    // Directorio interno de la empresa: buscar compañeros y abrir la ficha
    // de uno. Van con prefijo propio (/user/directory, /user/profile/{id})
    // para no chocar con /user/me ni /user/photo.
    ['GET',  '#^/user/directory/?$#',                          'listColleagues'],
    ['GET',  '#^/user/profile/([^/]+)/?$#',                    'getColleagueProfile'],
    ['POST', '#^/company/create/?$#',                         'createCompany'],
    ['GET',  '#^/company/info/?$#',                           'getCompany'],
    ['POST', '#^/company/update/?$#',                         'updateCompany'],
    ['POST', '#^/department/create/?$#',                      'createDepartment'],
    ['GET',  '#^/department/list/?$#',                        'listDepartments'],
    ['POST', '#^/department/assignManager/([^/]+)/?$#',       'assignDepartmentManager'],
    ['POST', '#^/department/assignEmployee/([^/]+)/?$#',      'assignDepartmentEmployee'],
    ['POST', '#^/department/removeEmployee/([^/]+)/?$#',      'removeDepartmentEmployee'],

    // ---- Flujo jerárquico de tareas por departamento/equipo -----------
    // Director: cualquier departamento. Manager: tareas y subtareas de su
    // departamento. Empleado: solo cambia el estado (marcar completada).
    ['GET',  '#^/dept-tasks/summary/by-department/?$#',      'deptTasksSummaryByDepartment'],
    ['GET',  '#^/dept-tasks/summary/?$#',                    'deptTasksSummary'],
    ['GET',  '#^/dept-tasks/?$#',                            'deptTasksList'],
    ['POST', '#^/dept-tasks/?$#',                            'deptTaskCreate'],
    ['POST', '#^/dept-tasks/([^/]+)/status/?$#',             'deptTaskSetStatus'],
    ['POST', '#^/dept-tasks/([^/]+)/review/?$#',             'deptTaskReview'],
    ['POST', '#^/dept-tasks/([^/]+)/delete/?$#',             'deptTaskDelete'],
    ['GET',  '#^/dept-tasks/([^/]+)/comments/?$#',           'deptTaskComments'],
    ['POST', '#^/dept-tasks/([^/]+)/comments/?$#',           'deptTaskCommentCreate'],
    ['GET',  '#^/dept-tasks/([^/]+)/evidence/?$#',           'deptTaskEvidence'],
    ['POST', '#^/dept-tasks/([^/]+)/?$#',                    'deptTaskUpdate'],

    // ---- Gestión de contenido del sitio público RADIODOLIV_PAGINA -------
    // Solo director (ver site_content.php). Create/update van como
    // multipart/form-data porque la imagen es opcional en ambos.
    ['GET',  '#^/site/anuncios/?$#',                          'siteAnunciosList'],
    ['POST', '#^/site/anuncios/?$#',                          'siteAnuncioCreate'],
    ['POST', '#^/site/anuncios/([^/]+)/?$#',                  'siteAnuncioUpdate'],
    ['POST', '#^/site/anuncios/([^/]+)/delete/?$#',           'siteAnuncioDelete'],

    ['GET',  '#^/site/eventos/?$#',                           'siteEventosList'],
    ['POST', '#^/site/eventos/?$#',                           'siteEventoCreate'],
    ['POST', '#^/site/eventos/([^/]+)/?$#',                   'siteEventoUpdate'],
    ['POST', '#^/site/eventos/([^/]+)/delete/?$#',            'siteEventoDelete'],

    ['GET',  '#^/site/servicios/?$#',                         'siteServiciosList'],
    ['POST', '#^/site/servicios/?$#',                         'siteServicioCreate'],
    ['POST', '#^/site/servicios/([^/]+)/?$#',                 'siteServicioUpdate'],
    ['POST', '#^/site/servicios/([^/]+)/delete/?$#',          'siteServicioDelete'],

    ['GET',  '#^/site/equipo/?$#',                            'siteEquipoList'],
    ['POST', '#^/site/equipo/?$#',                            'siteEquipoCreate'],
    ['POST', '#^/site/equipo/([^/]+)/?$#',                    'siteEquipoUpdate'],
    ['POST', '#^/site/equipo/([^/]+)/delete/?$#',             'siteEquipoDelete'],

    ['GET',  '#^/site/programas/?$#',                         'siteProgramasList'],
    ['POST', '#^/site/programas/?$#',                         'siteProgramaCreate'],
    ['POST', '#^/site/programas/([^/]+)/?$#',                 'siteProgramaUpdate'],
    ['POST', '#^/site/programas/([^/]+)/delete/?$#',          'siteProgramaDelete'],
    // Lectura de la parrilla para cualquier usuario (ver desde el reproductor).
    ['GET',  '#^/radio/programs/?$#',                         'radioProgramsList'],

    ['GET',  '#^/site/patrocinadores/?$#',                    'sitePatrocinadoresList'],
    ['POST', '#^/site/patrocinadores/?$#',                    'siteSponsorCreate'],
    ['POST', '#^/site/patrocinadores/([^/]+)/?$#',            'siteSponsorUpdate'],
    ['POST', '#^/site/patrocinadores/([^/]+)/delete/?$#',     'siteSponsorDelete'],

    ['GET',  '#^/site/podcasts/?$#',                          'sitePodcastsList'],
    ['POST', '#^/site/podcasts/?$#',                          'sitePodcastCreate'],
    ['POST', '#^/site/podcasts/([^/]+)/?$#',                  'sitePodcastUpdate'],
    ['POST', '#^/site/podcasts/([^/]+)/delete/?$#',           'sitePodcastDelete'],

    // ---- Asistencia y hora de comida (EXCLUSIVO para empleados) ---------
    // El backend rechaza con 403 cualquier operación cuyo rol no sea
    // 'employee' (ver attendance_require_employee en attendance.php).
    ['POST', '#^/attendance/entry/?$#',                       'attendanceEntry'],
    ['POST', '#^/attendance/meal/start/?$#',                  'attendanceMealStart'],
    ['POST', '#^/attendance/meal/skip/?$#',                   'attendanceMealSkip'],
    ['POST', '#^/attendance/meal/end/?$#',                    'attendanceMealEnd'],
    ['POST', '#^/attendance/exit/?$#',                        'attendanceExit'],
    ['GET',  '#^/attendance/today/?$#',                       'attendanceToday'],
    ['GET',  '#^/attendance/status/?$#',                      'attendanceToday'],
    ['GET',  '#^/attendance/history/?$#',                     'attendanceHistory'],
    ['GET',  '#^/attendance/summary/?$#',                     'attendanceSummary'],
    ['GET',  '#^/attendance/corrections/my/?$#',              'attendanceCorrectionsMine'],
    ['POST', '#^/attendance/corrections/?$#',                 'attendanceCorrectionCreate'],

    // ---- Asistencia: panel administrativo (director / manager) ---------
    ['GET',  '#^/admin/attendance-location/?$#',              'adminLocationGet'],
    ['POST', '#^/admin/attendance-location/?$#',              'adminLocationSave'],
    // Rutas específicas ANTES del comodín /admin/attendance/{id}.
    ['GET',  '#^/admin/attendance/summary/?$#',               'adminAttendanceSummary'],
    ['GET',  '#^/admin/attendance/report/?$#',                'attendanceReport'],
    ['GET',  '#^/admin/attendance/corrections/?$#',           'adminAttendanceCorrections'],
    ['POST', '#^/admin/attendance/corrections/([^/]+)/resolve/?$#', 'adminAttendanceCorrectionResolve'],
    ['GET',  '#^/admin/attendance/?$#',                       'adminAttendanceList'],
    ['GET',  '#^/admin/attendance/([^/]+)/?$#',               'adminAttendanceEmployee'],
    ['GET',  '#^/admin/schedules/?$#',                        'adminSchedulesList'],
    // La ruta 'bulk' va ANTES del comodín /admin/schedules/{id}.
    ['POST', '#^/admin/schedules/bulk/?$#',                   'adminScheduleBulkSave'],
    ['GET',  '#^/admin/schedules/([^/]+)/?$#',                'adminScheduleGet'],
    ['POST', '#^/admin/schedules/([^/]+)/?$#',                'adminScheduleSave'],

    // ---- Permisos, vacaciones e incapacidades -------------------------
    // Empleado: crear y consultar las propias. Director: revisar/decidir.
    ['POST', '#^/leave-requests/?$#',                         'leaveRequestCreate'],
    ['GET',  '#^/leave-requests/my/?$#',                      'leaveRequestsMine'],
    ['GET',  '#^/leave-requests/([^/]+)/evidence/?$#',        'leaveRequestEvidence'],
    ['POST', '#^/leave-requests/([^/]+)/cancel/?$#',          'leaveRequestCancelByEmployee'],
    ['GET',  '#^/leave-requests/([^/]+)/?$#',                 'leaveRequestGet'],

    ['GET',  '#^/admin/leave-requests/?$#',                   'adminLeaveRequestsList'],
    ['GET',  '#^/admin/leave-requests/calendar/?$#',          'adminLeaveCalendar'],
    ['POST', '#^/admin/leave-requests/([^/]+)/approve/?$#',   'adminLeaveRequestApprove'],
    ['POST', '#^/admin/leave-requests/([^/]+)/reject/?$#',    'adminLeaveRequestReject'],
    ['POST', '#^/admin/leave-requests/([^/]+)/cancel/?$#',    'adminLeaveRequestCancel'],
    ['GET',  '#^/admin/leave-requests/([^/]+)/?$#',           'adminLeaveRequestGet'],

    // ---- Justificación de faltas pasadas (ver absences.php) ------------
    ['GET',  '#^/absences/mine/?$#',                          'absencesMine'],
    ['POST', '#^/absences/justify/?$#',                       'absenceJustify'],
    ['GET',  '#^/absences/justifications/([^/]+)/evidence/?$#','absenceEvidence'],
    ['GET',  '#^/admin/absences/?$#',                         'adminAbsencesList'],
    ['POST', '#^/admin/absences/([^/]+)/approve/?$#',         'adminAbsenceApprove'],
    ['POST', '#^/admin/absences/([^/]+)/reject/?$#',          'adminAbsenceReject'],

    // ---- Anuncios internos de la empresa (crear/editar/borrar solo director) ----
    // El resto los ve en su tablero de inicio y confirma asistencia si aplica.
    // Las rutas específicas van ANTES del comodín /internal-announcements/{id}.
    ['GET',  '#^/internal-announcements/?$#',                  'internalAnnouncementsList'],
    ['POST', '#^/internal-announcements/?$#',                  'internalAnnouncementCreate'],
    ['GET',  '#^/internal-announcements/([^/]+)/views/?$#',    'internalAnnouncementViews'],
    ['POST', '#^/internal-announcements/([^/]+)/confirm/?$#',  'internalAnnouncementConfirm'],
    ['POST', '#^/internal-announcements/([^/]+)/delete/?$#',   'internalAnnouncementDelete'],
    ['POST', '#^/internal-announcements/([^/]+)/?$#',          'internalAnnouncementUpdate'],

    // ---- Calendario: eventos (crear/editar/borrar solo director) y feed ----
    ['GET',  '#^/events/?$#',                                 'eventsList'],
    ['POST', '#^/events/?$#',                                 'eventCreate'],
    ['POST', '#^/events/([^/]+)/delete/?$#',                  'eventDelete'],
    ['POST', '#^/events/([^/]+)/?$#',                         'eventUpdate'],
    ['GET',  '#^/calendar/?$#',                               'calendarFeed'],
];

try {
    foreach ($routes as [$routeMethod, $pattern, $handler]) {
        if ($routeMethod !== $method) continue;
        if (preg_match($pattern, $uri, $m)) {
            array_shift($m);
            // REQUEST_URI llega sin decodificar, así que un correo enviado como
            // "a%40b.com" o un área "Machine%20Learning" no coincidirían con lo
            // guardado en la base de datos si se usaran tal cual.
            $m = array_map('urldecode', $m);
            call_user_func($handler, $pdo, ...$m);
            exit;
        }
    }
    error_response('Not found', 404);
} catch (PDOException $e) {
    error_log('DB error: ' . $e->getMessage());
    error_response('Server error', 500);
}

// ---- handlers: misc --------------------------------------------------

function home(PDO $pdo) {
    json_response(['message' => 'Hello World']);
}

function googleOAuthStub(PDO $pdo) {
    text_response('Google OAuth is not available on this local backend.', 501);
}

// ---- handlers: auth ----------------------------------------------------

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

    $pdo->beginTransaction();
    try {
        $pdo->prepare('UPDATE email_verifications SET consumed_at = NOW() WHERE id = ? AND consumed_at IS NULL')
            ->execute([$row['id']]);
        $pdo->prepare('UPDATE users SET email_verified_at = COALESCE(email_verified_at, NOW()) WHERE id = ?')
            ->execute([$row['user_id']]);
        $pdo->commit();
    } catch (Throwable $e) {
        // Si el fallo fue el propio commit() ya no hay transacción activa;
        // rollBack() sin guard lanzaría una segunda excepción que taparía la
        // original. Mismo patrón que el resto del backend.
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $e;
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

function sendName(PDO $pdo) {
    $user = require_auth($pdo);
    raw_json_response($user['name']);
}

function sendMessageToLeader(PDO $pdo, string $teamId) {
    $user = require_auth($pdo);
    require_team_member($pdo, $teamId, $user);
    $body = request_body();
    $email = $body['Correo'] ?? $body['Email'] ?? $body['email'] ?? $user['email'];
    $message = trim($body['message'] ?? '');

    if ($message === '') {
        text_response('Message is required', 400);
    }

    $stmt = $pdo->prepare('INSERT INTO leader_messages (team_id, email, message) VALUES (?, ?, ?)');
    $stmt->execute([$teamId, $email, $message]);

    text_response('Message sent', 200);
}

// ---- handlers: team ----------------------------------------------------

// teamDetail.dart espera el equipo anidado: domains[] -> members[] (correos)
// y tasks[] (description/assignedTo/deadline/completed). 'completed' tiene que
// ser un booleano de verdad porque Dart compara con `== false` y no convierte
// 0/1 automáticamente.
function build_team_payload(PDO $pdo, array $team): array {
    $stmt = $pdo->prepare('SELECT id, name FROM domains WHERE team_id = ? ORDER BY id ASC');
    $stmt->execute([$team['id']]);
    $domains = $stmt->fetchAll();

    $stmt = $pdo->prepare('SELECT domain_name, email, description, deadline, completed FROM tasks WHERE team_code = ? ORDER BY id ASC');
    $stmt->execute([$team['team_code']]);
    $tasksByDomain = [];
    foreach ($stmt->fetchAll() as $t) {
        $tasksByDomain[$t['domain_name']][] = [
            'description' => $t['description'],
            'assignedTo'  => $t['email'],
            'deadline'    => $t['deadline'],
            'completed'   => (bool) $t['completed'],
        ];
    }

    $out = [];
    foreach ($domains as $d) {
        $stmt = $pdo->prepare('SELECT email FROM domain_members WHERE domain_id = ? ORDER BY id ASC');
        $stmt->execute([$d['id']]);
        $out[] = [
            '_id'     => (string) $d['id'],
            'name'    => $d['name'],
            'members' => array_column($stmt->fetchAll(), 'email'),
            'tasks'   => $tasksByDomain[$d['name']] ?? [],
        ];
    }

    return [
        '_id'         => $team['id'],
        'teamName'    => $team['team_name'],
        'teamCode'    => $team['team_code'],
        'leaderEmail' => $team['leader_email'],
        'domains'     => $out,
    ];
}

function createTeam(PDO $pdo) {
    $user = require_auth($pdo);
    $body = request_body();
    $teamName = trim($body['teamName'] ?? '');
    $domains = $body['domains'] ?? [];

    if ($teamName === '') {
        error_response('teamName is required', 400);
    }

    do {
        $teamCode = generate_team_code();
        $stmt = $pdo->prepare('SELECT id FROM teams WHERE team_code = ?');
        $stmt->execute([$teamCode]);
    } while ($stmt->fetch());

    $teamId = generate_id();
    $stmt = $pdo->prepare('INSERT INTO teams (id, team_name, team_code, leader_email) VALUES (?, ?, ?, ?)');
    $stmt->execute([$teamId, $teamName, $teamCode, $user['email']]);

    $stmt = $pdo->prepare('INSERT INTO team_members (team_id, email) VALUES (?, ?)');
    $stmt->execute([$teamId, $user['email']]);

    if (is_array($domains)) {
        foreach ($domains as $domain) {
            $domainName = trim($domain['name'] ?? '');
            if ($domainName === '') continue;
            $stmt = $pdo->prepare('INSERT INTO domains (team_id, name) VALUES (?, ?)');
            $stmt->execute([$teamId, $domainName]);
            $domainId = $pdo->lastInsertId();

            $members = $domain['members'] ?? [];
            if (is_array($members)) {
                foreach ($members as $memberEmail) {
                    if (!is_string($memberEmail) || $memberEmail === '') continue;
                    $stmt = $pdo->prepare('INSERT INTO domain_members (domain_id, email) VALUES (?, ?)');
                    $stmt->execute([$domainId, $memberEmail]);
                    $stmt = $pdo->prepare('INSERT IGNORE INTO team_members (team_id, email) VALUES (?, ?)');
                    $stmt->execute([$teamId, $memberEmail]);
                }
            }
        }
    }

    $stmt = $pdo->prepare('SELECT * FROM teams WHERE id = ?');
    $stmt->execute([$teamId]);
    json_response(['team' => build_team_payload($pdo, $stmt->fetch())]);
}

function sendTeamcode(PDO $pdo, string $teamId, string $domainName) {
    $user = require_auth($pdo);
    require_team_member($pdo, $teamId, $user);
    $body = request_body();
    $recipients = $body['recipients'] ?? [];

    $stmt = $pdo->prepare('SELECT * FROM teams WHERE id = ?');
    $stmt->execute([$teamId]);
    $team = $stmt->fetch();
    if (!$team) {
        json_response(['success' => false, 'message' => 'Team not found'], 404);
    }

    $stmt = $pdo->prepare('SELECT id FROM domains WHERE team_id = ? AND name = ?');
    $stmt->execute([$teamId, $domainName]);
    $domain = $stmt->fetch();
    if (!$domain) {
        $stmt = $pdo->prepare('INSERT INTO domains (team_id, name) VALUES (?, ?)');
        $stmt->execute([$teamId, $domainName]);
        $domainId = $pdo->lastInsertId();
    } else {
        $domainId = $domain['id'];
    }

    if (is_array($recipients)) {
        foreach ($recipients as $email) {
            if (!is_string($email) || $email === '') continue;
            $stmt = $pdo->prepare('INSERT INTO domain_members (domain_id, email) VALUES (?, ?)');
            $stmt->execute([$domainId, $email]);
            $stmt = $pdo->prepare('INSERT IGNORE INTO team_members (team_id, email) VALUES (?, ?)');
            $stmt->execute([$teamId, $email]);
        }
    }

    // No mail server is configured locally, so the code is logged instead
    // of emailed to the recipient.
    error_log('[hive-backend] Team code for ' . $teamId . ' (' . $team['team_name'] . '): ' . $team['team_code']);

    json_response(['success' => true, 'message' => 'Invitation recorded. Team code: ' . $team['team_code']]);
}

function joinTeam(PDO $pdo) {
    $user = require_auth($pdo);
    $body = request_body();
    $teamCode = trim($body['teamCode'] ?? '');

    $stmt = $pdo->prepare('SELECT id FROM teams WHERE team_code = ?');
    $stmt->execute([$teamCode]);
    $team = $stmt->fetch();
    if (!$team) {
        text_response('Invalid team code', 404);
    }

    $stmt = $pdo->prepare('INSERT IGNORE INTO team_members (team_id, email) VALUES (?, ?)');
    $stmt->execute([$team['id'], $user['email']]);

    text_response('Joined team successfully', 200);
}

function showTeams(PDO $pdo) {
    $user = require_auth($pdo);

    $stmt = $pdo->prepare(
        'SELECT t.id, t.team_name, t.team_code, t.leader_email
         FROM teams t
         JOIN team_members tm ON tm.team_id = t.id
         WHERE tm.email = ?'
    );
    $stmt->execute([$user['email']]);
    $rows = $stmt->fetchAll();

    $teams = array_map(fn($r) => build_team_payload($pdo, $r), $rows);

    json_response(['teams' => $teams, 'email' => $user['email']]);
}

// La creación de tareas del sistema viejo (por team_code + domain) se retiró:
// ahora todo pasa por el flujo jerárquico por departamento (dept_tasks.php,
// POST /dept-tasks). `taskDone` se conserva solo para marcar como hechas las
// tareas antiguas que ya existieran.

function taskDone(PDO $pdo) {
    $user = require_auth($pdo);
    $body = request_body();
    $teamCode = trim($body['teamCode'] ?? '');
    $domainName = trim($body['domainName'] ?? '');
    $email = trim($body['email'] ?? '');
    $task = trim($body['task'] ?? '');

    $team = team_from_code($pdo, $teamCode);
    if (!$team) {
        text_response('Team not found', 404);
    }
    require_team_member($pdo, $team['id'], $user);

    $stmt = $pdo->prepare(
        'UPDATE tasks SET completed = 1
         WHERE team_code = ? AND domain_name = ? AND email = ? AND description = ? AND completed = 0
         LIMIT 1'
    );
    $stmt->execute([$teamCode, $domainName, $email, $task]);

    if ($stmt->rowCount() === 0) {
        text_response('Task not found', 404);
    }

    text_response('Task marked as done', 200);
}

// teamCode y domainName viajan además de la descripción porque la lista de
// tareas (home_page/tasks.dart) los necesita para poder marcar una tarea como
// hecha sin tener que entrar al detalle del equipo.
function tasks_for_user(PDO $pdo, string $email, int $completed): array {
    $stmt = $pdo->prepare(
        'SELECT tk.description, tk.email AS assignedTo, tk.deadline,
                tk.team_code AS teamCode, tk.domain_name AS domainName,
                t.team_name AS teamName
         FROM tasks tk
         LEFT JOIN teams t ON t.team_code = tk.team_code
         WHERE tk.email = ? AND tk.completed = ?
         ORDER BY tk.deadline ASC, tk.id ASC'
    );
    $stmt->execute([$email, $completed]);
    return $stmt->fetchAll();
}

function incompleteTasks(PDO $pdo) {
    $user = require_auth($pdo);
    json_response(['incompleteTasks' => tasks_for_user($pdo, $user['email'], 0)]);
}

function completedTasks(PDO $pdo) {
    $user = require_auth($pdo);
    json_response(['completedTasks' => tasks_for_user($pdo, $user['email'], 1)]);
}

function deleteMember(PDO $pdo, string $teamId) {
    $user = require_auth($pdo);
    require_team_leader($pdo, $teamId, $user);
    $body = request_body();
    $memberEmail = trim($body['memberEmail'] ?? '');

    if ($memberEmail === '') {
        text_response('memberEmail is required', 400);
    }
    if (strcasecmp($memberEmail, $user['email']) === 0) {
        text_response('The leader cannot remove themselves; transfer leadership first', 400);
    }

    $stmt = $pdo->prepare('DELETE FROM team_members WHERE team_id = ? AND email = ?');
    $stmt->execute([$teamId, $memberEmail]);
    $removed = $stmt->rowCount();

    $stmt = $pdo->prepare('DELETE dm FROM domain_members dm JOIN domains d ON d.id = dm.domain_id WHERE d.team_id = ? AND dm.email = ?');
    $stmt->execute([$teamId, $memberEmail]);

    if ($removed > 0) {
        $stmt = $pdo->prepare('SELECT team_name FROM teams WHERE id = ?');
        $stmt->execute([$teamId]);
        $team = $stmt->fetch();
        notify_user($pdo, $memberEmail, $teamId, 'member_removed',
            'Fuiste eliminado del equipo "' . ($team['team_name'] ?? '') . '"');
    }

    text_response('Member removed', 200);
}

// Borra el equipo y todo lo que cuelga de él. Solo el líder puede hacerlo.
function deleteTeam(PDO $pdo, string $teamId) {
    $user = require_auth($pdo);
    require_team_leader($pdo, $teamId, $user);

    $stmt = $pdo->prepare('SELECT * FROM teams WHERE id = ?');
    $stmt->execute([$teamId]);
    $team = $stmt->fetch();
    if (!$team) {
        text_response('Team not found', 404);
    }

    // Se leen antes de borrar: los miembros para avisarles y las imágenes para
    // poder limpiar los archivos subidos una vez confirmado el borrado.
    $stmt = $pdo->prepare('SELECT email FROM team_members WHERE team_id = ? AND email <> ?');
    $stmt->execute([$teamId, $user['email']]);
    $members = array_column($stmt->fetchAll(), 'email');

    $stmt = $pdo->prepare('SELECT img_path FROM images WHERE team_id = ?');
    $stmt->execute([$teamId]);
    $imagePaths = array_column($stmt->fetchAll(), 'img_path');

    $pdo->beginTransaction();
    try {
        // tasks se referencia por team_code, no por team_id.
        $stmt = $pdo->prepare('DELETE FROM tasks WHERE team_code = ?');
        $stmt->execute([$team['team_code']]);

        $stmt = $pdo->prepare('DELETE dm FROM domain_members dm JOIN domains d ON d.id = dm.domain_id WHERE d.team_id = ?');
        $stmt->execute([$teamId]);

        foreach (['domains', 'team_members', 'texts', 'images', 'leaves', 'leader_messages'] as $table) {
            $stmt = $pdo->prepare("DELETE FROM $table WHERE team_id = ?");
            $stmt->execute([$teamId]);
        }

        // Las notificaciones ya emitidas se conservan, pero pierden la
        // referencia al equipo porque este deja de existir.
        $stmt = $pdo->prepare('UPDATE notifications SET team_id = NULL WHERE team_id = ?');
        $stmt->execute([$teamId]);

        $stmt = $pdo->prepare('DELETE FROM teams WHERE id = ?');
        $stmt->execute([$teamId]);

        $pdo->commit();
    } catch (Throwable $e) {
        // Guard: si falló el propio commit() no queda transacción que revertir
        // y un rollBack() a secas taparía la excepción original con otra.
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $e;
    }

    foreach ($members as $memberEmail) {
        notify_user($pdo, $memberEmail, null, 'team_deleted',
            'El equipo "' . $team['team_name'] . '" fue eliminado');
    }

    foreach ($imagePaths as $p) {
        $file = UPLOAD_DIR . basename($p);
        if (is_file($file)) {
            @unlink($file);
        }
    }

    text_response('Team deleted', 200);
}

function leaderResign(PDO $pdo, string $teamId) {
    $user = require_auth($pdo);
    require_team_leader($pdo, $teamId, $user);
    $body = request_body();
    // La pantalla LResign.dart manda el campo como "Correo"; se aceptan las
    // tres grafías para no depender de cuál pantalla haga la llamada.
    $newLeaderEmail = trim($body['Correo'] ?? $body['Email'] ?? $body['email'] ?? '');

    if ($newLeaderEmail === '') {
        text_response('Email of the new leader is required', 400);
    }

    $stmt = $pdo->prepare('SELECT id FROM team_members WHERE team_id = ? AND email = ?');
    $stmt->execute([$teamId, $newLeaderEmail]);
    if (!$stmt->fetch()) {
        text_response('The new leader must already be a team member', 400);
    }

    $stmt = $pdo->prepare('UPDATE teams SET leader_email = ? WHERE id = ?');
    $stmt->execute([$newLeaderEmail, $teamId]);

    $stmt = $pdo->prepare('SELECT team_name FROM teams WHERE id = ?');
    $stmt->execute([$teamId]);
    $team = $stmt->fetch();
    notify_user($pdo, $newLeaderEmail, $teamId, 'leader_assigned',
        'Ahora eres el líder del equipo "' . ($team['team_name'] ?? '') . '"');

    text_response('Leadership transferred', 200);
}

// ---- handlers: chat (mensajería directa 1 a 1) ------------------------
//
// Modelo: cada mensaje es privado entre `sender_id` y `recipient_id`.
// `conversation_key` = los dos ids ordenados y unidos por ':' — así la
// autorización es estructural: solo se puede leer un hilo cuyo key contenga
// el id de quien pregunta (chat_convo_key() siempre lo arma con {yo, otro}).

function chat_convo_key(string $a, string $b): string {
    return $a < $b ? "$a:$b" : "$b:$a";
}

// Resuelve a la otra persona por correo o por id. Corta la petición si no
// existe o si es uno mismo.
function chat_resolve_peer(PDO $pdo, string $ref, array $me): array {
    $ref = trim($ref);
    if ($ref === '') {
        error_response('Indica a quién quieres escribir.', 400);
    }
    $stmt = $pdo->prepare('SELECT id, name, email, photo_path FROM users WHERE email = ? OR id = ? LIMIT 1');
    $stmt->execute([$ref, $ref]);
    $peer = $stmt->fetch();
    if (!$peer) {
        error_response('No encontramos a esa persona.', 404);
    }
    if ($peer['id'] === $me['id']) {
        error_response('No puedes enviarte un mensaje a ti mismo.', 400);
    }
    return $peer;
}

// GET /chat/conversations — una fila por persona con la que hay hilo: último
// mensaje, cuándo, si lo mandé yo, y cuántos me faltan por leer.
function chatConversations(PDO $pdo) {
    $me = require_auth($pdo);

    $stmt = $pdo->prepare(
        'SELECT m.conversation_key, m.sender_id, m.recipient_id, m.body, m.created_at
           FROM chat_messages m
           JOIN (
             SELECT conversation_key, MAX(id) AS last_id
               FROM chat_messages
              WHERE sender_id = :me OR recipient_id = :me
              GROUP BY conversation_key
           ) t ON t.last_id = m.id
          ORDER BY m.id DESC'
    );
    $stmt->execute([':me' => $me['id']]);
    $rows = $stmt->fetchAll();

    $peerStmt = $pdo->prepare('SELECT id, name, email, photo_path FROM users WHERE id = ?');
    $unreadStmt = $pdo->prepare(
        'SELECT COUNT(*) FROM chat_messages
          WHERE conversation_key = ? AND recipient_id = ? AND read_at IS NULL'
    );

    $conversations = [];
    foreach ($rows as $r) {
        $peerId = $r['sender_id'] === $me['id'] ? $r['recipient_id'] : $r['sender_id'];
        $peerStmt->execute([$peerId]);
        $peer = $peerStmt->fetch();
        if (!$peer) continue; // la otra persona fue dada de baja
        $unreadStmt->execute([$r['conversation_key'], $me['id']]);
        $conversations[] = [
            'peerId'       => $peer['id'],
            'peerName'     => $peer['name'],
            'peerEmail'    => $peer['email'],
            'peerPhotoUrl' => $peer['photo_path'] ? UPLOAD_URL_BASE . $peer['photo_path'] : null,
            'lastMessage'  => $r['body'],
            'lastAt'       => $r['created_at'],
            'lastFromMe'   => $r['sender_id'] === $me['id'],
            'unread'       => (int) $unreadStmt->fetchColumn(),
        ];
    }

    json_response(['conversations' => $conversations]);
}

// GET /chat/thread/{peerEmailOrId} — el hilo completo con esa persona, en
// orden cronológico. Al abrirlo se marcan como leídos los mensajes que me
// mandó y seguían sin leer.
function chatThread(PDO $pdo, string $peerRef) {
    $me = require_auth($pdo);
    $peer = chat_resolve_peer($pdo, $peerRef, $me);
    $key = chat_convo_key($me['id'], $peer['id']);

    $pdo->prepare(
        'UPDATE chat_messages SET read_at = NOW()
          WHERE conversation_key = ? AND recipient_id = ? AND read_at IS NULL'
    )->execute([$key, $me['id']]);

    $stmt = $pdo->prepare(
        'SELECT id, sender_id, body, created_at, read_at
           FROM chat_messages WHERE conversation_key = ? ORDER BY id ASC'
    );
    $stmt->execute([$key]);
    $messages = array_map(fn($r) => [
        'id'        => (int) $r['id'],
        'message'   => $r['body'],
        'fromMe'    => $r['sender_id'] === $me['id'],
        'createdAt' => $r['created_at'],
        'readAt'    => $r['read_at'],
    ], $stmt->fetchAll());

    json_response([
        'peer' => [
            'id'       => $peer['id'],
            'name'     => $peer['name'],
            'email'    => $peer['email'],
            'photoUrl' => $peer['photo_path'] ? UPLOAD_URL_BASE . $peer['photo_path'] : null,
        ],
        'messages' => $messages,
    ]);
}

// POST /chat/sendMessage — body: { to: <correo|id>, message: <texto> }.
// El remitente sale del token, nunca del body.
function sendChatMessage(PDO $pdo) {
    $me = require_auth($pdo);
    $body = request_body();
    $message = trim($body['message'] ?? '');
    $to = (string) ($body['to'] ?? $body['recipient'] ?? $body['recipientEmail'] ?? '');

    if ($message === '') {
        text_response('message is required', 400);
    }
    if (mb_strlen($message) > 4000) {
        $message = mb_substr($message, 0, 4000);
    }

    $peer = chat_resolve_peer($pdo, $to, $me);
    $key = chat_convo_key($me['id'], $peer['id']);

    $pdo->prepare(
        'INSERT INTO chat_messages (conversation_key, sender_id, recipient_id, body)
         VALUES (?, ?, ?, ?)'
    )->execute([$key, $me['id'], $peer['id'], $message]);

    // entity_id = correo de quien escribe: al tocar la notificación, el
    // cliente abre directamente el hilo con esta persona. Estilo mensajería:
    // el push muestra el nombre de quien escribe como título y el texto (o un
    // adelanto) como cuerpo; la fila in-app guarda "Nombre: texto".
    $preview = mb_substr($message, 0, 200);
    if (mb_strlen($message) > 200) {
        $preview .= '…';
    }
    notify_user($pdo, $peer['email'], null, 'chat',
        $me['name'] . ': ' . $preview, 'user', $me['email'],
        $me['name'], $preview);

    text_response('Message sent', 200);
}

// POST /devices/register — body { token, platform? }. Guarda el token FCM del
// dispositivo para el usuario autenticado. Idempotente por token: si el mismo
// dispositivo lo reenvía (o cambia de cuenta), se reasigna al usuario actual.
function deviceRegister(PDO $pdo) {
    $me = require_auth($pdo);
    $body = request_body();
    $token = trim((string) ($body['token'] ?? ''));
    $platform = (string) ($body['platform'] ?? 'android');
    if (!in_array($platform, ['android', 'ios', 'web'], true)) {
        $platform = 'android';
    }
    if ($token === '') {
        error_response('token is required', 400);
    }
    if (strlen($token) > 512) {
        error_response('token too long', 400);
    }
    $stmt = $pdo->prepare(
        'INSERT INTO device_tokens (email, token, platform)
         VALUES (?, ?, ?)
         ON DUPLICATE KEY UPDATE
             email = VALUES(email),
             platform = VALUES(platform),
             last_seen_at = NOW()'
    );
    $stmt->execute([$me['email'], $token, $platform]);
    json_response(['ok' => true]);
}

// POST /devices/unregister — body { token }. Lo llama el cliente al cerrar
// sesión. Idempotente.
function deviceUnregister(PDO $pdo) {
    $me = require_auth($pdo);
    $body = request_body();
    $token = trim((string) ($body['token'] ?? ''));
    if ($token === '') {
        error_response('token is required', 400);
    }
    // Acotado al dueño: un usuario no puede desregistrar el dispositivo de otro.
    // Sigue siendo idempotente (0 filas borradas => {ok:true}).
    $pdo->prepare('DELETE FROM device_tokens WHERE token = ? AND email = ?')
        ->execute([$token, $me['email']]);
    json_response(['ok' => true]);
}

// ---- handlers: resources ------------------------------------------------

function showImage(PDO $pdo, string $teamId) {
    $user = require_auth($pdo);
    require_team_member($pdo, $teamId, $user);
    $stmt = $pdo->prepare('SELECT img_name, img_path FROM images WHERE team_id = ? ORDER BY id DESC');
    $stmt->execute([$teamId]);
    $rows = $stmt->fetchAll();

    $images = array_map(fn($r) => [
        'imgURL' => UPLOAD_URL_BASE . $r['img_path'],
        'imgName' => $r['img_name'],
    ], $rows);

    // The client expects a bare JSON array, not wrapped in an object.
    raw_json_response($images);
}

function addImage(PDO $pdo) {
    $user = require_auth($pdo);
    $teamId = trim($_POST['teamId'] ?? '');
    $imgName = trim($_POST['imgName'] ?? '');

    if ($teamId === '' || empty($_FILES['photo']) || $_FILES['photo']['error'] !== UPLOAD_ERR_OK) {
        text_response('teamId and photo are required', 400);
    }
    require_team_member($pdo, $teamId, $user);

    $tmpPath = $_FILES['photo']['tmp_name'];
    $originalName = $_FILES['photo']['name'];
    $ext = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));
    $allowed = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

    if (!in_array($ext, $allowed, true) || @getimagesize($tmpPath) === false) {
        text_response('Only image files are allowed', 400);
    }

    $storedName = bin2hex(random_bytes(16)) . '.' . $ext;
    if (!move_uploaded_file($tmpPath, UPLOAD_DIR . $storedName)) {
        text_response('Failed to save the uploaded image', 500);
    }

    $stmt = $pdo->prepare('INSERT INTO images (team_id, img_name, img_path) VALUES (?, ?, ?)');
    $stmt->execute([$teamId, $imgName !== '' ? $imgName : $originalName, $storedName]);

    text_response('Image uploaded successfully', 200);
}

function addText(PDO $pdo, string $teamId) {
    $user = require_auth($pdo);
    require_team_member($pdo, $teamId, $user);
    $body = request_body();
    $text = trim($body['text'] ?? '');

    if ($text === '') {
        json_response(['error' => 'text is required'], 400);
    }

    $stmt = $pdo->prepare('INSERT INTO texts (team_id, email, text) VALUES (?, ?, ?)');
    $stmt->execute([$teamId, $user['email'], $text]);

    json_response(['message' => 'Text added successfully'], 201);
}

function showText(PDO $pdo, string $teamId) {
    $user = require_auth($pdo);
    require_team_member($pdo, $teamId, $user);
    $stmt = $pdo->prepare('SELECT email, text FROM texts WHERE team_id = ? ORDER BY created_at ASC');
    $stmt->execute([$teamId]);
    $rows = $stmt->fetchAll();

    $grouped = [];
    foreach ($rows as $row) {
        $email = $row['email'];
        if (!isset($grouped[$email])) {
            $grouped[$email] = ['email' => $email, 'texts' => []];
        }
        $grouped[$email]['texts'][] = ['text' => $row['text']];
    }

    json_response(['data' => array_values($grouped)]);
}

// ---- handlers: documentos de equipo -----------------------------------
//
// Archivos de oficina (PDF, Word, Excel, ...) compartidos dentro de un
// equipo. Se guardan en DOCUMENT_DIR (privado); nunca se sirven estáticos.
// Listar/subir/descargar: cualquier miembro del equipo. Borrar: quien lo
// subió o el líder del equipo. (DOCUMENT_ALLOWED_EXT / DOCUMENT_MAX_BYTES se
// declaran al inicio del archivo porque el dispatcher corre antes que esta
// sección.)

function document_payload(array $r): array {
    return [
        'id'           => $r['id'],
        'docName'      => $r['doc_name'],
        'originalName' => $r['original_name'],
        'mime'         => $r['mime'],
        'fileSize'     => (int) $r['file_size'],
        'uploadedBy'   => $r['uploaded_by'],
        'createdAt'    => $r['created_at'],
    ];
}

function teamDocumentsList(PDO $pdo, string $teamId) {
    $user = require_auth($pdo);
    require_team_member($pdo, $teamId, $user);
    $stmt = $pdo->prepare(
        'SELECT * FROM documents WHERE team_id = ? ORDER BY created_at DESC, id DESC'
    );
    $stmt->execute([$teamId]);
    json_response([
        'success' => true,
        'documents' => array_map('document_payload', $stmt->fetchAll()),
    ]);
}

function teamDocumentUpload(PDO $pdo) {
    $user = require_auth($pdo);
    $teamId = trim($_POST['teamId'] ?? '');
    $docName = trim($_POST['docName'] ?? '');

    if ($teamId === '' || empty($_FILES['document']) || $_FILES['document']['error'] === UPLOAD_ERR_NO_FILE) {
        text_response('teamId y el archivo son obligatorios', 400);
    }
    require_team_member($pdo, $teamId, $user);

    $file = $_FILES['document'];
    if ($file['error'] !== UPLOAD_ERR_OK) {
        text_response('No se pudo subir el documento. Inténtalo de nuevo.', 400);
    }
    $size = (int) $file['size'];
    if ($size <= 0 || $size > DOCUMENT_MAX_BYTES) {
        text_response('El documento supera el tamaño máximo permitido (25 MB).', 400);
    }
    $originalName = $file['name'];
    $ext = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));
    if (!in_array($ext, DOCUMENT_ALLOWED_EXT, true)) {
        text_response('Tipo de archivo no permitido.', 400);
    }

    $mime = null;
    if (function_exists('finfo_open')) {
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mime = finfo_file($finfo, $file['tmp_name']) ?: null;
        finfo_close($finfo);
    }

    // Nombre generado por el servidor: nunca se confía en el original.
    $stored = bin2hex(random_bytes(16)) . '.' . $ext;
    if (!move_uploaded_file($file['tmp_name'], DOCUMENT_DIR . $stored)) {
        text_response('No se pudo guardar el documento en el servidor.', 500);
    }

    $id = generate_id();
    $stmt = $pdo->prepare(
        'INSERT INTO documents
           (id, team_id, doc_name, stored_path, original_name, mime, file_size, uploaded_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $id, $teamId,
        $docName !== '' ? mb_substr($docName, 0, 255) : $originalName,
        $stored, mb_substr($originalName, 0, 255), $mime, $size, $user['email'],
    ]);

    $stmt = $pdo->prepare('SELECT * FROM documents WHERE id = ?');
    $stmt->execute([$id]);
    json_response([
        'success' => true,
        'message' => 'Documento subido correctamente.',
        'document' => document_payload($stmt->fetch()),
    ]);
}

function teamDocumentDownload(PDO $pdo, string $documentId) {
    $user = require_auth($pdo);
    $stmt = $pdo->prepare('SELECT * FROM documents WHERE id = ?');
    $stmt->execute([$documentId]);
    $doc = $stmt->fetch();
    if (!$doc) {
        error_response('Documento no encontrado', 404);
    }
    require_team_member($pdo, $doc['team_id'], $user);

    $path = DOCUMENT_DIR . basename($doc['stored_path']);
    if (!is_file($path)) {
        error_response('El archivo ya no está disponible en el servidor.', 404);
    }

    // Fuerza la descarga con el nombre original, no el aleatorio del disco.
    header('Content-Type: ' . ($doc['mime'] ?: 'application/octet-stream'));
    header('Content-Disposition: attachment; filename="' . str_replace('"', '', $doc['original_name']) . '"');
    header('Content-Length: ' . filesize($path));
    header('X-Content-Type-Options: nosniff');
    header('Cache-Control: private, no-store');
    readfile($path);
    exit;
}

function teamDocumentDelete(PDO $pdo, string $documentId) {
    $user = require_auth($pdo);
    $stmt = $pdo->prepare('SELECT * FROM documents WHERE id = ?');
    $stmt->execute([$documentId]);
    $doc = $stmt->fetch();
    if (!$doc) {
        error_response('Documento no encontrado', 404);
    }
    require_team_member($pdo, $doc['team_id'], $user);

    // Lo borra quien lo subió o el líder del equipo.
    $isUploader = strcasecmp($doc['uploaded_by'], $user['email']) === 0;
    if (!$isUploader && !is_team_leader($pdo, $doc['team_id'], $user['email'])) {
        error_response('Solo quien subió el documento o el líder pueden eliminarlo.', 403);
    }

    $pdo->prepare('DELETE FROM documents WHERE id = ?')->execute([$documentId]);
    $path = DOCUMENT_DIR . basename($doc['stored_path']);
    if (is_file($path)) {
        @unlink($path);
    }

    json_response(['success' => true, 'message' => 'Documento eliminado.']);
}

// ---- handlers: leave ----------------------------------------------------

function applyLeave(PDO $pdo, string $teamId) {
    $user = require_auth($pdo);
    require_team_member($pdo, $teamId, $user);
    $body = request_body();
    $leaves = $body['leaves'] ?? [];
    $leave = is_array($leaves) && count($leaves) > 0 ? $leaves[0] : null;

    if (!$leave || empty($leave['startDate']) || empty($leave['endDate'])) {
        json_response(['error' => 'startDate and endDate are required'], 400);
    }

    // Mismas reglas de negocio que el flujo nuevo (/leave-requests):
    // no se piden permisos para fechas ya pasadas y las fechas deben caer en
    // un día laboral (lunes a sábado; el domingo no).
    $ls = date('Y-m-d', strtotime((string) $leave['startDate']));
    $le = date('Y-m-d', strtotime((string) $leave['endDate']));
    if ($le < $ls) {
        json_response(['error' => 'La fecha de término no puede ser anterior a la de inicio.'], 400);
    }
    if ($ls < date('Y-m-d')) {
        json_response(['error' => 'No puedes solicitar un permiso para una fecha que ya pasó.'], 400);
    }
    if (!is_working_day($ls) || !is_working_day($le)) {
        json_response(['error' => 'El inicio y el término deben ser un día laboral (lunes a sábado).'], 400);
    }

    $leaveId = generate_id();
    $stmt = $pdo->prepare(
        'INSERT INTO leaves (id, team_id, email, start_date, end_date, reason, status) VALUES (?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $leaveId,
        $teamId,
        $user['email'],
        $leave['startDate'],
        $leave['endDate'],
        $leave['reason'] ?? '',
        'pending',
    ]);

    json_response([
        '_id' => $leaveId,
        'teamId' => $teamId,
        'email' => $user['email'],
        'startDate' => $leave['startDate'],
        'endDate' => $leave['endDate'],
        'reason' => $leave['reason'] ?? '',
        'status' => 'pending',
    ]);
}

function leaveResult(PDO $pdo, string $leaveId) {
    $user = require_auth($pdo);

    $stmt = $pdo->prepare(
        'SELECT l.email, t.leader_email FROM leaves l
         LEFT JOIN teams t ON t.id = l.team_id
         WHERE l.id = ?'
    );
    $stmt->execute([$leaveId]);
    $leave = $stmt->fetch();
    if (!$leave) {
        json_response(['error' => 'Leave request not found'], 404);
    }
    if ($leave['email'] !== $user['email'] && $leave['leader_email'] !== $user['email']) {
        error_response('You cannot access this leave request', 403);
    }

    $stmt = $pdo->prepare("UPDATE leaves SET status = 'submitted' WHERE id = ?");
    $stmt->execute([$leaveId]);
    json_response(['message' => 'Leave application submitted']);
}

// ---- handlers: notifications --------------------------------------------

function listNotifications(PDO $pdo) {
    $user = require_auth($pdo);
    // Aprovecha el sondeo de la campana para emitir los recordatorios que le
    // tocan hoy a esta persona: de anuncios (internal_announcements.php) y de
    // eventos próximos del calendario (events.php).
    ia_dispatch_due_reminders($pdo, $user['id']);
    event_dispatch_due_reminders($pdo, $user['id']);
    $stmt = $pdo->prepare(
        'SELECT id, team_id AS teamId, type,
                entity_type AS entityType, entity_id AS entityId,
                message, read_at AS readAt, created_at AS createdAt
         FROM notifications WHERE email = ? ORDER BY created_at DESC, id DESC LIMIT 100'
    );
    $stmt->execute([$user['email']]);
    $rows = $stmt->fetchAll();

    // Conteo real de no leídas (no el de la página de 100): la campana y
    // cualquier contador de la app deben mostrar el mismo número.
    $countStmt = $pdo->prepare(
        'SELECT COUNT(*) FROM notifications WHERE email = ? AND read_at IS NULL'
    );
    $countStmt->execute([$user['email']]);

    json_response([
        'notifications' => $rows,
        'unreadCount' => (int) $countStmt->fetchColumn(),
    ]);
}

function markNotificationRead(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    $stmt = $pdo->prepare('UPDATE notifications SET read_at = NOW() WHERE id = ? AND email = ? AND read_at IS NULL');
    $stmt->execute([$id, $user['email']]);
    if ($stmt->rowCount() === 0) {
        json_response(['error' => 'Notification not found'], 404);
    }
    json_response(['message' => 'Notification marked as read']);
}

// "Limpiar" la pantalla de notificaciones: marca como leídas SOLO las que
// todavía están sin leer de esta persona. Idempotente: si no hay ninguna sin
// leer, responde 200 con updated = 0 (no es error).
function markAllNotificationsRead(PDO $pdo) {
    $user = require_auth($pdo);
    $stmt = $pdo->prepare('UPDATE notifications SET read_at = NOW() WHERE email = ? AND read_at IS NULL');
    $stmt->execute([$user['email']]);
    json_response([
        'message' => 'Notifications marked as read',
        'updated' => $stmt->rowCount(),
    ]);
}

// ---- handlers: organizational structure (companies/departments/roles) --
// Base RBAC para Radio Doliv: un único registro en `companies`, N
// `departments` colgando de él, y cada usuario con role/position/department_id.
// El resto de módulos (dashboards por rol, anuncios, reportes, workflow de
// tareas director->manager->employee) se construyen sobre esta base — ver
// Actualizacion.md para el resto del alcance, todavía pendiente.

function build_department_payload(PDO $pdo, array $dept): array {
    $stmt = $pdo->prepare('SELECT COUNT(*) AS n FROM users WHERE department_id = ?');
    $stmt->execute([$dept['id']]);
    $count = (int) $stmt->fetch()['n'];

    return [
        'id'            => $dept['id'],
        'companyId'     => $dept['company_id'],
        'name'          => $dept['name'],
        'description'   => $dept['description'],
        'managerEmail'  => $dept['manager_email'],
        'employeeCount' => $count,
    ];
}

// Forma pública de un usuario: lo único que se le puede mostrar a otra
// persona de la empresa. Deliberadamente NO incluye password, token ni otp —
// todo lo que sale de `users` hacia el cliente pasa por aquí (perfil propio,
// directorio y ficha de un compañero).
function build_public_user_payload(array $user, ?array $department): array {
    return [
        'id'            => $user['id'],
        'name'          => $user['name'],
        'email'         => $user['email'],
        'role'          => $user['role'],
        'position'      => $user['position'],
        'photoUrl'      => $user['photo_path'] ? UPLOAD_URL_BASE . $user['photo_path'] : null,
        'department'    => $department,
        // Verificación de correo (023): la app la usa para el aviso.
        'emailVerified' => !empty($user['email_verified_at']),
    ];
}

function build_user_profile_payload(PDO $pdo, array $user): array {
    $department = null;
    if ($user['department_id']) {
        $stmt = $pdo->prepare('SELECT * FROM departments WHERE id = ?');
        $stmt->execute([$user['department_id']]);
        $dept = $stmt->fetch();
        if ($dept) {
            $department = build_department_payload($pdo, $dept);
        }
    }

    return build_public_user_payload($user, $department);
}

// La app llama esto justo después de login para saber qué dashboard mostrar
// (Director / Manager / Employee) — el token en sí no lleva el rol.
function getMe(PDO $pdo) {
    $user = require_auth($pdo);
    json_response(build_user_profile_payload($pdo, $user));
}

// Sube/reemplaza la foto de perfil del usuario autenticado. Misma validación
// de tipo de archivo que addImage(); a diferencia de esa, aquí se borra el
// archivo anterior porque solo tiene sentido conservar una foto por usuario.
function updateProfilePhoto(PDO $pdo) {
    $user = require_auth($pdo);

    if (empty($_FILES['photo']) || $_FILES['photo']['error'] !== UPLOAD_ERR_OK) {
        error_response('photo is required', 400);
    }

    $tmpPath = $_FILES['photo']['tmp_name'];
    $originalName = $_FILES['photo']['name'];
    $ext = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));
    $allowed = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

    if (!in_array($ext, $allowed, true) || @getimagesize($tmpPath) === false) {
        error_response('Only image files are allowed', 400);
    }

    $storedName = bin2hex(random_bytes(16)) . '.' . $ext;
    if (!move_uploaded_file($tmpPath, UPLOAD_DIR . $storedName)) {
        error_response('Failed to save the uploaded image', 500);
    }

    $oldPath = $user['photo_path'];
    $stmt = $pdo->prepare('UPDATE users SET photo_path = ? WHERE id = ?');
    $stmt->execute([$storedName, $user['id']]);

    if ($oldPath) {
        $oldFile = UPLOAD_DIR . basename($oldPath);
        if (is_file($oldFile)) {
            @unlink($oldFile);
        }
    }

    $user['photo_path'] = $storedName;
    json_response(build_user_profile_payload($pdo, $user));
}

// ---- handlers: directorio de compañeros ---------------------------------
// Directorio interno de Radio Doliv. Cualquier usuario autenticado puede
// buscar a sus compañeros y abrir su ficha; solo se exponen los datos de
// contacto de trabajo que ya se comparten dentro de la empresa (nombre,
// correo, puesto, departamento, foto) — nunca credenciales.

// Todos los departamentos con su número de empleados, indexados por id. El
// directorio los necesita para adjuntar el departamento de cada persona: se
// resuelven de una sola vez en vez de una consulta por usuario listado.
function departments_by_id(PDO $pdo): array {
    $stmt = $pdo->query(
        'SELECT d.*, (SELECT COUNT(*) FROM users u WHERE u.department_id = d.id) AS employee_count
         FROM departments d'
    );
    $byId = [];
    foreach ($stmt->fetchAll() as $dept) {
        $byId[$dept['id']] = [
            'id'            => $dept['id'],
            'companyId'     => $dept['company_id'],
            'name'          => $dept['name'],
            'description'   => $dept['description'],
            'managerEmail'  => $dept['manager_email'],
            'employeeCount' => (int) $dept['employee_count'],
        ];
    }
    return $byId;
}

// GET /user/directory?scope=&q=
//
// `scope`: 'department' (por defecto, "mi área"), 'company' para toda la
// empresa, o el id de un departamento concreto. Quien todavía no tiene
// departamento asignado (el director, o una cuenta recién creada) no tiene
// "mi área" que filtrar, así que en ese caso el default cae a toda la
// empresa en vez de devolver una lista vacía.
//
// `q`: texto libre; busca en nombre, correo y puesto.
function listColleagues(PDO $pdo) {
    $user = require_auth($pdo);

    $scope = trim($_GET['scope'] ?? 'department');
    $query = trim($_GET['q'] ?? '');

    $where = [];
    $params = [];

    if ($scope === 'department') {
        if ($user['department_id']) {
            $where[] = 'department_id = ?';
            $params[] = $user['department_id'];
        }
    } elseif ($scope !== 'company' && $scope !== '') {
        $where[] = 'department_id = ?';
        $params[] = $scope;
    }

    if ($query !== '') {
        // Los comodines van escapados para que un "%" tecleado por el usuario
        // se busque literalmente en vez de traer a toda la empresa.
        $like = '%' . addcslashes($query, '%_\\') . '%';
        $where[] = '(name LIKE ? OR email LIKE ? OR position LIKE ?)';
        array_push($params, $like, $like, $like);
    }

    $sql = 'SELECT * FROM users';
    if ($where) {
        $sql .= ' WHERE ' . implode(' AND ', $where);
    }
    // Jerarquía primero (director, manager) y luego alfabético: así el
    // responsable del área queda arriba, que es a quien más se busca.
    $sql .= " ORDER BY FIELD(role, 'director', 'manager', 'employee'), name ASC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll();

    $departments = departments_by_id($pdo);
    $colleagues = [];
    foreach ($rows as $row) {
        $dept = $row['department_id'] ? ($departments[$row['department_id']] ?? null) : null;
        $colleagues[] = build_public_user_payload($row, $dept);
    }

    json_response([
        'colleagues'     => $colleagues,
        'departments'    => array_values($departments),
        'scope'          => $scope,
        'myDepartmentId' => $user['department_id'],
    ]);
}

// GET /user/profile/{id} — ficha de un compañero. Sobre el perfil público
// agrega los equipos a los que pertenece y desde cuándo está en la empresa,
// que es lo que hace que valga la pena abrir la ficha en vez de quedarse con
// la fila del listado.
function getColleagueProfile(PDO $pdo, string $userId) {
    require_auth($pdo);

    $stmt = $pdo->prepare('SELECT * FROM users WHERE id = ?');
    $stmt->execute([$userId]);
    $target = $stmt->fetch();
    if (!$target) {
        error_response('No encontramos a esa persona', 404);
    }

    $stmt = $pdo->prepare(
        'SELECT t.id, t.team_name, t.leader_email
         FROM teams t
         LEFT JOIN team_members tm ON tm.team_id = t.id AND tm.email = ?
         WHERE t.leader_email = ? OR tm.email IS NOT NULL
         ORDER BY t.team_name ASC'
    );
    $stmt->execute([$target['email'], $target['email']]);
    $teams = array_map(fn($t) => [
        'id'       => $t['id'],
        'teamName' => $t['team_name'],
        'isLeader' => $t['leader_email'] === $target['email'],
    ], $stmt->fetchAll());

    $payload = build_user_profile_payload($pdo, $target);
    $payload['teams'] = $teams;
    $payload['joinedAt'] = $target['created_at'];

    json_response($payload);
}

function get_the_company(PDO $pdo): ?array {
    $stmt = $pdo->query('SELECT * FROM companies ORDER BY created_at ASC LIMIT 1');
    $company = $stmt->fetch();
    return $company ?: null;
}

// Solo existe una empresa (Radio Doliv). El primer usuario autenticado que
// la crea queda promovido a director; llamadas posteriores fallan con 409
// porque ya existe — para editarla está POST /company/update.
function createCompany(PDO $pdo) {
    $user = require_auth($pdo);
    if (get_the_company($pdo) !== null) {
        error_response('La empresa ya fue creada', 409);
    }

    $body = request_body();
    $name = trim($body['name'] ?? '');
    if ($name === '') {
        error_response('name es requerido', 400);
    }

    $companyId = generate_id();
    $stmt = $pdo->prepare('INSERT INTO companies (id, name, description, logo) VALUES (?, ?, ?, ?)');
    $stmt->execute([$companyId, $name, trim($body['description'] ?? '') ?: null, trim($body['logo'] ?? '') ?: null]);

    $stmt = $pdo->prepare("UPDATE users SET role = 'director' WHERE id = ?");
    $stmt->execute([$user['id']]);

    $stmt = $pdo->prepare('SELECT * FROM companies WHERE id = ?');
    $stmt->execute([$companyId]);
    json_response(['company' => $stmt->fetch()]);
}

function getCompany(PDO $pdo) {
    require_auth($pdo);
    $company = get_the_company($pdo);
    if (!$company) {
        error_response('La empresa aún no ha sido creada', 404);
    }
    json_response(['company' => $company]);
}

function updateCompany(PDO $pdo) {
    $user = require_auth($pdo);
    require_role($user, ['director']);
    $company = get_the_company($pdo);
    if (!$company) {
        error_response('La empresa aún no ha sido creada', 404);
    }

    $body = request_body();
    $name = trim($body['name'] ?? $company['name']);
    if ($name === '') {
        error_response('name no puede estar vacío', 400);
    }

    $stmt = $pdo->prepare('UPDATE companies SET name = ?, description = ?, logo = ? WHERE id = ?');
    $stmt->execute([
        $name,
        array_key_exists('description', $body) ? (trim($body['description']) ?: null) : $company['description'],
        array_key_exists('logo', $body) ? (trim($body['logo']) ?: null) : $company['logo'],
        $company['id'],
    ]);

    $stmt = $pdo->prepare('SELECT * FROM companies WHERE id = ?');
    $stmt->execute([$company['id']]);
    json_response(['company' => $stmt->fetch()]);
}

function createDepartment(PDO $pdo) {
    $user = require_auth($pdo);
    require_role($user, ['director']);
    $company = get_the_company($pdo);
    if (!$company) {
        error_response('Crea la empresa antes de agregar departamentos', 400);
    }

    $body = request_body();
    $name = trim($body['name'] ?? '');
    if ($name === '') {
        error_response('name es requerido', 400);
    }

    $stmt = $pdo->prepare('SELECT id FROM departments WHERE company_id = ? AND name = ?');
    $stmt->execute([$company['id'], $name]);
    if ($stmt->fetch()) {
        error_response('Ya existe un departamento con ese nombre', 409);
    }

    $deptId = generate_id();
    $stmt = $pdo->prepare('INSERT INTO departments (id, company_id, name, description) VALUES (?, ?, ?, ?)');
    $stmt->execute([$deptId, $company['id'], $name, trim($body['description'] ?? '') ?: null]);

    $stmt = $pdo->prepare('SELECT * FROM departments WHERE id = ?');
    $stmt->execute([$deptId]);
    json_response(['department' => build_department_payload($pdo, $stmt->fetch())]);
}

function listDepartments(PDO $pdo) {
    require_auth($pdo);
    $stmt = $pdo->query('SELECT * FROM departments ORDER BY name ASC');
    $departments = array_map(fn($d) => build_department_payload($pdo, $d), $stmt->fetchAll());
    json_response(['departments' => $departments]);
}

// Asigna (o reemplaza) el manager de un departamento. El usuario destino
// debe existir; queda con role='manager' y department_id apuntando a este
// departamento. Solo el director puede hacerlo.
function assignDepartmentManager(PDO $pdo, string $departmentId) {
    $user = require_auth($pdo);
    require_role($user, ['director']);

    $stmt = $pdo->prepare('SELECT * FROM departments WHERE id = ?');
    $stmt->execute([$departmentId]);
    $dept = $stmt->fetch();
    if (!$dept) {
        error_response('Departamento no encontrado', 404);
    }

    $body = request_body();
    $email = trim($body['email'] ?? '');
    if ($email === '') {
        error_response('email es requerido', 400);
    }

    $stmt = $pdo->prepare('SELECT * FROM users WHERE email = ?');
    $stmt->execute([$email]);
    $target = $stmt->fetch();
    if (!$target) {
        error_response('No existe un usuario con ese correo', 404);
    }
    if ($target['role'] === 'director') {
        error_response('No se puede reasignar al director general', 400);
    }

    $stmt = $pdo->prepare('UPDATE departments SET manager_email = ? WHERE id = ?');
    $stmt->execute([$email, $departmentId]);

    $stmt = $pdo->prepare("UPDATE users SET role = 'manager', department_id = ? WHERE id = ?");
    $stmt->execute([$departmentId, $target['id']]);

    notify_user($pdo, $email, null, 'department_manager_assigned',
        'Ahora eres el manager del departamento "' . $dept['name'] . '"');

    $stmt = $pdo->prepare('SELECT * FROM departments WHERE id = ?');
    $stmt->execute([$departmentId]);
    json_response(['department' => build_department_payload($pdo, $stmt->fetch())]);
}

// Agrega (o mueve) a un empleado dentro de un departamento. El director
// puede hacerlo sobre cualquier departamento; el manager, solo sobre el
// suyo. No permite tocar a un director ni a otro manager por esta vía.
function assignDepartmentEmployee(PDO $pdo, string $departmentId) {
    $user = require_auth($pdo);

    $stmt = $pdo->prepare('SELECT * FROM departments WHERE id = ?');
    $stmt->execute([$departmentId]);
    $dept = $stmt->fetch();
    if (!$dept) {
        error_response('Departamento no encontrado', 404);
    }
    require_department_manager_or_director($pdo, $user, $departmentId);

    $body = request_body();
    $email = trim($body['email'] ?? '');
    $position = trim($body['position'] ?? '');
    if ($email === '') {
        error_response('email es requerido', 400);
    }

    $stmt = $pdo->prepare('SELECT * FROM users WHERE email = ?');
    $stmt->execute([$email]);
    $target = $stmt->fetch();
    if (!$target) {
        error_response('No existe un usuario con ese correo', 404);
    }
    if (in_array($target['role'], ['director', 'manager'], true)) {
        error_response('No se puede reasignar a un director o manager por esta vía', 400);
    }

    $stmt = $pdo->prepare('UPDATE users SET department_id = ?, position = ? WHERE id = ?');
    $stmt->execute([$departmentId, $position ?: null, $target['id']]);

    notify_user($pdo, $email, null, 'department_assigned',
        'Fuiste asignado al departamento "' . $dept['name'] . '"');

    $stmt = $pdo->prepare('SELECT * FROM departments WHERE id = ?');
    $stmt->execute([$departmentId]);
    json_response(['department' => build_department_payload($pdo, $stmt->fetch())]);
}
