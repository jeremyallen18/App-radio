<?php
// La campana: lista las notificaciones de esta persona (mensaje descifrado al
// vuelo, ver crypto.php), marca una / todas como leídas, y "Limpiar" borra
// todas. De paso emite los recordatorios de anuncios y eventos que le tocan
// hoy (ia_dispatch_due_reminders / event_dispatch_due_reminders).

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
    foreach ($rows as &$row) {
        $row['message'] = db_decrypt($row['message']);
    }
    unset($row);

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

// "Limpiar" de verdad: borra TODAS las notificaciones de esta persona (la
// notificación es efímera; la tarea/evento/mensaje real vive en su propia
// tabla). Vacía la pantalla y de paso purga filas — `notifications` no tiene
// otra política de retención. Idempotente: sin filas responde 200 deleted = 0.
function clearNotifications(PDO $pdo) {
    $user = require_auth($pdo);
    $stmt = $pdo->prepare('DELETE FROM notifications WHERE email = ?');
    $stmt->execute([$user['email']]);
    json_response([
        'message' => 'Notifications cleared',
        'deleted' => $stmt->rowCount(),
    ]);
}
