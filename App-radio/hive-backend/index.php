<?php
require __DIR__ . '/config.php';
require __DIR__ . '/helpers.php';
require __DIR__ . '/site_content.php';
require __DIR__ . '/events.php';
require __DIR__ . '/attendance.php';
require __DIR__ . '/attendance_admin.php';
require __DIR__ . '/attendance_reports.php';
require __DIR__ . '/leave_requests.php';
require __DIR__ . '/absences.php';
require __DIR__ . '/dept_tasks.php';
require __DIR__ . '/internal_announcements.php';
require __DIR__ . '/auth.php';
require __DIR__ . '/chat.php';
require __DIR__ . '/devices.php';
require __DIR__ . '/documents.php';
require __DIR__ . '/legacy_teams.php';
require __DIR__ . '/notifications.php';
require __DIR__ . '/org.php';
require __DIR__ . '/users.php';

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
    ['POST', '#^/notifications/clear/?$#',                    'clearNotifications'],
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
    // Autoservicio de cuenta (pantalla "Editar cuenta"). Rutas específicas,
    // antes de la comodín /user/{id}/control-number.
    ['POST', '#^/user/account/name/?$#',                       'updateAccountName'],
    ['POST', '#^/user/account/password/?$#',                   'changePassword'],
    ['POST', '#^/user/account/email/?$#',                      'requestEmailChange'],
    ['POST', '#^/user/account/email/cancel/?$#',               'cancelEmailChange'],
    // Solo el director: corregir el número de control de una persona.
    ['POST', '#^/user/([^/]+)/control-number/?$#',             'setControlNumber'],
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

function sendName(PDO $pdo) {
    $user = require_auth($pdo);
    raw_json_response($user['name']);
}

