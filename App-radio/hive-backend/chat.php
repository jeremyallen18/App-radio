<?php
// Mensajería directa 1 a 1 entre usuarios (ver migración 016). No hay sala
// global: cada quien solo ve las conversaciones en las que participa. El
// cuerpo del mensaje se guarda cifrado en reposo (db_encrypt, ver crypto.php).

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
            'lastMessage'  => db_decrypt($r['body']),
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
        'message'   => db_decrypt($r['body']),
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
    )->execute([$key, $me['id'], $peer['id'], db_encrypt($message)]);

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
