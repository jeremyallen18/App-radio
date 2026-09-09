<?php
// Comentarios de la transmisión en vivo (widget del hero de Inicio), leídos
// desde la BD compartida (hive_db, tabla radio_live_comments).
//
// La caja "se reinicia cada hora": cada comentario pertenece a la franja de
// la hora en punto (10:00:00, 11:00:00, ...). Solo se muestran los de la
// franja actual; los de franjas anteriores se borran en cuanto alguien
// vuelve a tocar la tabla (no hace falta cron).
//
// Todo el cálculo de tiempo se hace con el reloj de MySQL (NOW()), nunca con
// date() de PHP: si el servidor web y MySQL tienen zonas horarias distintas,
// mezclarlos deja la franja descuadrada y se borran filas recién insertadas.
//
// Lo consumen: index.php (estado inicial que pinta el servidor) e
// inc/api/live-comments.php (polling desde assets/js/pages/index.js).

// Expresión SQL con el inicio de la franja horaria actual. Todo lo anterior
// es "de la hora pasada" y se descarta.
const LIVE_COMMENTS_BUCKET_SQL = "DATE_FORMAT(NOW(), '%Y-%m-%d %H:00:00')";

// Inicio de la franja horaria actual como cadena (para data-bucket y la
// respuesta JSON), resuelto por MySQL.
function live_comments_bucket(PDO $pdo): string {
    return (string) $pdo->query('SELECT ' . LIVE_COMMENTS_BUCKET_SQL)->fetchColumn();
}

// Borra los comentarios de franjas horarias ya cerradas. Se llama antes de
// cada lectura/escritura para que la tabla nunca crezca sin límite y para
// que el "reinicio cada hora" sea automático.
function purge_stale_live_comments(PDO $pdo): void {
    $pdo->exec('DELETE FROM radio_live_comments WHERE created_at < ' . LIVE_COMMENTS_BUCKET_SQL);
}

// Comentarios de la franja horaria actual, en orden cronológico.
// $sinceId > 0 devuelve solo los más nuevos que ese id (polling incremental);
// 0 devuelve toda la franja (máx. 200, tope defensivo).
function get_live_comments(int $sinceId = 0): array {
    require_once __DIR__ . '/../../config/db.php';
    $pdo = get_pdo();
    purge_stale_live_comments($pdo);

    $stmt = $pdo->prepare('
        SELECT id, name, body,
               DATE_FORMAT(created_at, \'%H:%i\') AS time,
               created_at
        FROM radio_live_comments
        WHERE created_at >= ' . LIVE_COMMENTS_BUCKET_SQL . ' AND id > :since
        ORDER BY id ASC
        LIMIT 200
    ');
    $stmt->execute(['since' => max(0, $sinceId)]);
    return $stmt->fetchAll();
}

// Número de comentarios en la franja horaria actual.
function count_live_comments(PDO $pdo): int {
    $stmt = $pdo->query('
        SELECT COUNT(*) FROM radio_live_comments
        WHERE created_at >= ' . LIVE_COMMENTS_BUCKET_SQL . '
    ');
    return (int) $stmt->fetchColumn();
}

// Inserta un comentario nuevo y devuelve su fila ya normalizada.
// Lanza InvalidArgumentException si el texto no es válido y RuntimeException
// si el mismo client_id está enviando demasiado rápido (anti-flood simple).
function add_live_comment(string $name, string $body, ?string $clientId): array {
    require_once __DIR__ . '/../../config/db.php';
    require_once __DIR__ . '/../helpers/moderation.php';
    $pdo = get_pdo();

    $clientId = $clientId !== null ? substr(trim($clientId), 0, 40) : null;
    if ($clientId === '') {
        $clientId = null;
    }

    // Filtro de seguridad: limpia HTML/invisibles, bloquea enlaces, datos de
    // contacto, gritos y spam, y enmascara groserías. Lanza
    // InvalidArgumentException si el contenido no se puede publicar.
    $clean = mod_filter_comment($name, $body);
    $name = $clean['name'];
    $body = $clean['body'];

    if ($name === '') {
        $name = 'Oyente';
    }
    if (mb_strlen($name) > 60) {
        $name = mb_substr($name, 0, 60);
    }
    if ($body === '') {
        throw new InvalidArgumentException('El comentario está vacío.');
    }
    if (mb_strlen($body) > 240) {
        $body = mb_substr($body, 0, 240);
    }

    // Controles anti-spam por navegador (client_id). Van ANTES del purge para
    // que no dependan de que la franja horaria siga viva.
    if ($clientId) {
        // 1 comentario cada 3 segundos como máximo.
        $recent = $pdo->prepare('
            SELECT COUNT(*) FROM radio_live_comments
            WHERE client_id = :cid AND created_at > (NOW() - INTERVAL 3 SECOND)
        ');
        $recent->execute(['cid' => $clientId]);
        if ((int) $recent->fetchColumn() > 0) {
            throw new RuntimeException('Espera un momento antes de enviar otro comentario.');
        }

        // No más de 5 comentarios por minuto.
        $perMinute = $pdo->prepare('
            SELECT COUNT(*) FROM radio_live_comments
            WHERE client_id = :cid AND created_at > (NOW() - INTERVAL 1 MINUTE)
        ');
        $perMinute->execute(['cid' => $clientId]);
        if ((int) $perMinute->fetchColumn() >= 5) {
            throw new RuntimeException('Estás enviando demasiados comentarios. Espera un minuto.');
        }

        // Nada de repetir el mismo mensaje en los últimos 10 minutos.
        $dup = $pdo->prepare('
            SELECT COUNT(*) FROM radio_live_comments
            WHERE client_id = :cid AND body = :body AND created_at > (NOW() - INTERVAL 10 MINUTE)
        ');
        $dup->execute(['cid' => $clientId, 'body' => $body]);
        if ((int) $dup->fetchColumn() > 0) {
            throw new InvalidArgumentException('Ya enviaste ese comentario.');
        }
    }

    purge_stale_live_comments($pdo);

    $insert = $pdo->prepare('
        INSERT INTO radio_live_comments (name, body, client_id)
        VALUES (:name, :body, :client_id)
    ');
    $insert->execute(['name' => $name, 'body' => $body, 'client_id' => $clientId]);
    $id = (int) $pdo->lastInsertId();

    $row = $pdo->prepare('
        SELECT id, name, body,
               DATE_FORMAT(created_at, \'%H:%i\') AS time,
               created_at
        FROM radio_live_comments WHERE id = :id
    ');
    $row->execute(['id' => $id]);
    return $row->fetch();
}
