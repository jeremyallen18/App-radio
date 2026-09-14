<?php
// Chat grupal: uno para toda la empresa y uno por departamento (migración
// 038, spec docs/superpowers/specs/2026-09-13-chat-grupal-design.md).
//
// La membresía NO se guarda en una tabla: se calcula en vivo desde
// companies/departments + users.department_id, igual que ya hacen los
// permisos de tareas de departamento. Así, si alguien cambia de área, pierde
// acceso automáticamente al chat viejo y gana el nuevo sin tocar nada aquí.
// El Director solo entra al chat de un departamento si él mismo pertenece a
// ese departamento; siempre participa en el chat de empresa.

// Trae (o crea, primera vez que se pide) la fila de chat_groups para
// ($kind, $refId). Perezoso: no hace falta backfill ni tocar
// createCompany/createDepartment.
function chat_group_get_or_create(PDO $pdo, string $kind, string $refId): array {
    $stmt = $pdo->prepare('SELECT * FROM chat_groups WHERE kind = ? AND ref_id = ?');
    $stmt->execute([$kind, $refId]);
    $group = $stmt->fetch();
    if ($group) return $group;

    $id = generate_id();
    try {
        $pdo->prepare('INSERT INTO chat_groups (id, kind, ref_id) VALUES (?, ?, ?)')
            ->execute([$id, $kind, $refId]);
    } catch (PDOException $e) {
        // Carrera: otra petición lo creó primero (UNIQUE kind+ref_id).
        if ($e->getCode() !== '23000') throw $e;
    }

    $stmt->execute([$kind, $refId]);
    return $stmt->fetch();
}

// Grupos a los que pertenece $user ahora mismo: el de empresa (si la empresa
// ya existe) y el de su departamento (si tiene uno asignado).
function chat_user_groups(PDO $pdo, array $user): array {
    $groups = [];

    $company = get_the_company($pdo);
    if ($company) {
        $groups[] = chat_group_get_or_create($pdo, 'company', $company['id']);
    }

    if (!empty($user['department_id'])) {
        $groups[] = chat_group_get_or_create($pdo, 'department', $user['department_id']);
    }

    return $groups;
}

// ¿Puede $user leer/escribir en $group ahora mismo?
function chat_group_membership_check(PDO $pdo, array $user, array $group): bool {
    if ($group['kind'] === 'company') {
        $company = get_the_company($pdo);
        return $company !== null && $company['id'] === $group['ref_id'];
    }
    // department
    return !empty($user['department_id']) && $user['department_id'] === $group['ref_id'];
}

// Correos de todos los miembros actuales de $group (para el broadcast de push).
function chat_group_member_emails(PDO $pdo, array $group): array {
    if ($group['kind'] === 'company') {
        $stmt = $pdo->query('SELECT email FROM users WHERE ' . SQL_USER_VERIFIED);
        return array_column($stmt->fetchAll(), 'email');
    }
    $stmt = $pdo->prepare(
        'SELECT email FROM users WHERE department_id = ? AND ' . SQL_USER_VERIFIED
    );
    $stmt->execute([$group['ref_id']]);
    return array_column($stmt->fetchAll(), 'email');
}

// Nombre a mostrar del grupo: siempre resuelto en el momento (nunca cacheado
// en chat_groups), para no desincronizarse si renombran la empresa o el área.
function chat_group_display_name(PDO $pdo, array $group): string {
    if ($group['kind'] === 'company') {
        $company = get_the_company($pdo);
        return $company['name'] ?? 'Empresa';
    }
    $stmt = $pdo->prepare('SELECT name FROM departments WHERE id = ?');
    $stmt->execute([$group['ref_id']]);
    return $stmt->fetchColumn() ?: 'Departamento';
}

// Resuelve el grupo por id o corta la petición (404). No valida membresía;
// eso lo hace cada endpoint con chat_group_membership_check().
function chat_group_require(PDO $pdo, string $groupId): array {
    $stmt = $pdo->prepare('SELECT * FROM chat_groups WHERE id = ?');
    $stmt->execute([$groupId]);
    $group = $stmt->fetch();
    if (!$group) {
        error_response('El chat no existe.', 404);
    }
    return $group;
}

// GET /chat/group/{id}/thread — historial del grupo, marca como leído.
function chatGroupThread(PDO $pdo, string $groupId) {
    $me = require_auth($pdo);
    $group = chat_group_require($pdo, $groupId);
    if (!chat_group_membership_check($pdo, $me, $group)) {
        error_response('No perteneces a este chat.', 403);
    }

    $pdo->prepare(
        'INSERT INTO chat_group_reads (group_id, user_id, last_read_message_id)
         SELECT ?, ?, COALESCE(MAX(id), 0) FROM chat_group_messages WHERE group_id = ?
         ON DUPLICATE KEY UPDATE last_read_message_id = VALUES(last_read_message_id)'
    )->execute([$groupId, $me['id'], $groupId]);

    $stmt = $pdo->prepare(
        'SELECT m.id, m.sender_id, m.body, m.created_at, u.name AS sender_name
           FROM chat_group_messages m
           JOIN users u ON u.id = m.sender_id
          WHERE m.group_id = ?
          ORDER BY m.id ASC'
    );
    $stmt->execute([$groupId]);
    $messages = array_map(fn($r) => [
        'id'         => (int) $r['id'],
        'message'    => db_decrypt($r['body']),
        'senderName' => $r['sender_name'],
        'fromMe'     => $r['sender_id'] === $me['id'],
        'createdAt'  => $r['created_at'],
    ], $stmt->fetchAll());

    json_response([
        'group' => [
            'id'   => $group['id'],
            'kind' => $group['kind'],
            'name' => chat_group_display_name($pdo, $group),
        ],
        'messages' => $messages,
    ]);
}

// POST /chat/group/{id}/sendMessage — body: { message }.
function sendChatGroupMessage(PDO $pdo, string $groupId) {
    $me = require_auth($pdo);
    enforce_rate_limit($pdo, 'chat_send_message', $me['id'], 20, 60);
    $group = chat_group_require($pdo, $groupId);
    if (!chat_group_membership_check($pdo, $me, $group)) {
        error_response('No perteneces a este chat.', 403);
    }

    $body = request_body();
    $message = trim($body['message'] ?? '');
    if ($message === '') {
        text_response('message is required', 400);
    }
    if (mb_strlen($message) > 4000) {
        $message = mb_substr($message, 0, 4000);
    }

    $pdo->prepare(
        'INSERT INTO chat_group_messages (group_id, sender_id, body) VALUES (?, ?, ?)'
    )->execute([$groupId, $me['id'], db_encrypt($message)]);

    $preview = mb_substr($message, 0, 200);
    if (mb_strlen($message) > 200) {
        $preview .= '…';
    }
    foreach (chat_group_member_emails($pdo, $group) as $email) {
        if ($email === $me['email']) continue;
        notify_user($pdo, $email, null, 'chat_group',
            $me['name'] . ': ' . $preview, 'group', $groupId,
            $me['name'], $preview);
    }

    text_response('Message sent', 200);
}
