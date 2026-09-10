<?php
// Documentos de equipo (PDF, Word, Excel, ...). Cualquier miembro lista, sube
// y descarga; borra quien lo subió o el líder. Los archivos viven en un
// directorio privado servido solo a través de estos handlers.

// Tipos permitidos y tamaño máximo para los documentos de equipo.
const DOCUMENT_ALLOWED_EXT = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
    'txt', 'csv', 'zip', 'rar', '7z',
];
const DOCUMENT_MAX_BYTES = 25 * 1024 * 1024; // 25 MB

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
