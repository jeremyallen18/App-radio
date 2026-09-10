<?php
// Endpoint de la caja "Comentarios en vivo" del hero de Inicio.
//
//   GET  ?since=<id>              -> comentarios de la franja horaria actual con id > since
//   POST {name, body, client_id}  -> publica un comentario y lo devuelve
//
// La respuesta siempre incluye "bucket" (la hora en punto vigente): cuando el
// cliente detecta que cambió, vacía la lista en pantalla -> ese es el
// "reinicio cada hora". Lo consume assets/js/pages/index.js por polling.

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

require_once __DIR__ . '/../../config/db.php';
require_once __DIR__ . '/../data/live_comments.php';

function live_comments_send(array $data, int $status = 200): void {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

// Forma pública de un comentario: sin client_id ni created_at crudo, y con la
// hora ya formateada (HH:MM) como la espera el markup.
function live_comment_shape(array $row): array {
    return [
        'id' => (int) $row['id'],
        'name' => (string) $row['name'],
        'body' => (string) $row['body'],
        'time' => (string) ($row['time'] ?? ''),
    ];
}

try {
    $pdo = get_pdo();
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

    if ($method === 'POST') {
        $raw = file_get_contents('php://input') ?: '';
        $payload = json_decode($raw, true);
        if (!is_array($payload)) {
            $payload = $_POST;
        }

        $comment = add_live_comment(
            (string) ($payload['name'] ?? ''),
            (string) ($payload['body'] ?? ''),
            isset($payload['client_id']) ? (string) $payload['client_id'] : null
        );

        live_comments_send([
            'success' => true,
            'bucket' => live_comments_bucket($pdo),
            'comment' => live_comment_shape($comment),
        ], 201);
    }

    // GET
    $since = (int) ($_GET['since'] ?? 0);
    $rows = get_live_comments($since);

    live_comments_send([
        'success' => true,
        'bucket' => live_comments_bucket($pdo),
        'server_time' => date('c'),
        'count' => count_live_comments($pdo),
        'comments' => array_map('live_comment_shape', $rows),
    ]);
} catch (InvalidArgumentException $e) {
    live_comments_send(['success' => false, 'error' => $e->getMessage()], 400);
} catch (RuntimeException $e) {
    live_comments_send(['success' => false, 'error' => $e->getMessage()], 429);
} catch (Throwable $e) {
    live_comments_send(['success' => false, 'error' => 'No se pudo cargar los comentarios. Intenta de nuevo.'], 500);
}
