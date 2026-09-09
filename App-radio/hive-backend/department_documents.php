<?php
// Documentos por departamento (Radio Doliv) — paralelo a documents.php (que
// es por equipo legacy). Siguen el RBAC de la organización:
//
//   Director  -> lista / sube / renombra / elimina en CUALQUIER departamento.
//   Manager   -> lo mismo, SOLO en su propio departamento.
//   Empleado  -> solo lista, busca (en el cliente) y descarga los de SU
//                departamento.
//
// Los archivos viven en private/department_documents/ y solo se entregan por
// GET /department-documents/{id}/download tras validar la pertenencia.
//
// Endpoints (registrados en index.php):
//   GET  /department-documents?departmentId=          (director: cualquiera / opcional)
//   POST /department-documents                        (director / manager del depto)
//   POST /department-documents/{id}                   (renombrar — director / manager)
//   GET  /department-documents/{id}/download          (miembro del depto / director)
//   POST /department-documents/{id}/delete            (director / manager del depto)

const DEPT_DOCUMENT_ALLOWED_EXT = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
    'txt', 'csv', 'zip', 'rar', '7z',
];
const DEPT_DOCUMENT_MAX_BYTES = 25 * 1024 * 1024; // 25 MB

function dept_document_payload(array $r): array {
    return [
        'id'           => $r['id'],
        'docName'      => $r['doc_name'],
        'originalName' => $r['original_name'],
        'mime'         => $r['mime'],
        'fileSize'     => (int) $r['file_size'],
        'uploadedBy'   => $r['uploaded_by'],
        'createdAt'    => $r['created_at'],
        'updatedAt'    => $r['updated_at'] ?? $r['created_at'],
    ];
}

// ¿Puede este usuario VER (listar/descargar) los documentos de $deptId?
//   - director: siempre.
//   - manager/empleado: solo su propio departamento.
function dept_document_can_view(array $user, string $deptId): bool {
    return $user['role'] === 'director'
        || (($user['department_id'] ?? null) === $deptId);
}

// Departamento objetivo según el rol:
//   director -> el que venga en la petición; si no manda ninguno al LISTAR,
//               se devuelve null y se listan todos.
//   manager/empleado -> SIEMPRE el suyo; si piden otro distinto, 403. Si no
//               tienen departamento, 409.
function dept_document_scope(array $user, ?string $requested, bool $allowNullForDirector): ?string {
    if ($user['role'] === 'director') {
        if ($requested === null || $requested === '') {
            if ($allowNullForDirector) return null;
            error_response('Indica el departamento (departmentId).', 400);
        }
        return $requested;
    }
    $own = $user['department_id'] ?? null;
    if (!$own) {
        error_response('Todavía no perteneces a ningún departamento.', 409);
    }
    if ($requested !== null && $requested !== '' && $requested !== $own) {
        error_response('Solo puedes ver los documentos de tu departamento.', 403);
    }
    return $own;
}

function dept_document_or_404(PDO $pdo, string $id): array {
    $stmt = $pdo->prepare('SELECT * FROM department_documents WHERE id = ?');
    $stmt->execute([$id]);
    $doc = $stmt->fetch();
    if (!$doc) {
        error_response('Documento no encontrado', 404);
    }
    return $doc;
}

// ---- GET /department-documents?departmentId= ------------------------------

function deptDocumentsList(PDO $pdo) {
    $user = require_auth($pdo);
    $requested = isset($_GET['departmentId']) ? trim((string) $_GET['departmentId']) : null;
    $deptId = dept_document_scope($user, $requested, true);

    if ($deptId === null) {
        // Director sin filtro: todos los departamentos.
        $stmt = $pdo->query(
            'SELECT * FROM department_documents ORDER BY created_at DESC, id DESC'
        );
    } else {
        $stmt = $pdo->prepare(
            'SELECT * FROM department_documents WHERE department_id = ?
             ORDER BY created_at DESC, id DESC'
        );
        $stmt->execute([$deptId]);
    }
    json_response([
        'success'   => true,
        'documents' => array_map('dept_document_payload', $stmt->fetchAll()),
    ]);
}

// ---- POST /department-documents (multipart) ------------------------------

function deptDocumentUpload(PDO $pdo) {
    $user = require_auth($pdo);
    $deptId = trim($_POST['departmentId'] ?? '');
    $docName = trim($_POST['docName'] ?? '');

    if ($deptId === '' || empty($_FILES['document'])
        || $_FILES['document']['error'] === UPLOAD_ERR_NO_FILE) {
        text_response('departmentId y el archivo son obligatorios', 400);
    }
    // RBAC: solo director o el manager de ESE departamento.
    require_department_manager_or_director($pdo, $user, $deptId);

    $file = $_FILES['document'];
    if ($file['error'] !== UPLOAD_ERR_OK) {
        text_response('No se pudo subir el documento. Inténtalo de nuevo.', 400);
    }
    $size = (int) $file['size'];
    if ($size <= 0 || $size > DEPT_DOCUMENT_MAX_BYTES) {
        text_response('El documento supera el tamaño máximo permitido (25 MB).', 400);
    }
    $originalName = $file['name'];
    $ext = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));
    if (!in_array($ext, DEPT_DOCUMENT_ALLOWED_EXT, true)) {
        text_response('Tipo de archivo no permitido.', 400);
    }

    $mime = null;
    if (function_exists('finfo_open')) {
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mime = finfo_file($finfo, $file['tmp_name']) ?: null;
        finfo_close($finfo);
    }

    $stored = bin2hex(random_bytes(16)) . '.' . $ext;
    if (!move_uploaded_file($file['tmp_name'], DEPARTMENT_DOCUMENT_DIR . $stored)) {
        text_response('No se pudo guardar el documento en el servidor.', 500);
    }

    $id = generate_id();
    $stmt = $pdo->prepare(
        'INSERT INTO department_documents
           (id, department_id, doc_name, stored_path, original_name, mime, file_size, uploaded_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    );
    $stmt->execute([
        $id, $deptId,
        $docName !== '' ? mb_substr($docName, 0, 255) : $originalName,
        $stored, mb_substr($originalName, 0, 255), $mime, $size, $user['email'],
    ]);

    json_response([
        'success'  => true,
        'message'  => 'Documento subido correctamente.',
        'document' => dept_document_payload(dept_document_or_404($pdo, $id)),
    ]);
}

// ---- POST /department-documents/{id} (renombrar) ------------------------

function deptDocumentUpdate(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    $doc = dept_document_or_404($pdo, $id);
    require_department_manager_or_director($pdo, $user, $doc['department_id']);

    $body = request_body();
    $docName = trim($body['docName'] ?? '');
    if ($docName === '') {
        text_response('El nombre no puede quedar vacío.', 400);
    }

    $stmt = $pdo->prepare(
        'UPDATE department_documents SET doc_name = ? WHERE id = ?'
    );
    $stmt->execute([mb_substr($docName, 0, 255), $id]);

    json_response([
        'success'  => true,
        'message'  => 'Documento actualizado.',
        'document' => dept_document_payload(dept_document_or_404($pdo, $id)),
    ]);
}

// ---- GET /department-documents/{id}/download --------------------------

function deptDocumentDownload(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    $doc = dept_document_or_404($pdo, $id);
    if (!dept_document_can_view($user, $doc['department_id'])) {
        error_response('Solo puedes descargar los documentos de tu departamento.', 403);
    }

    $path = DEPARTMENT_DOCUMENT_DIR . basename($doc['stored_path']);
    if (!is_file($path)) {
        error_response('El archivo ya no está disponible en el servidor.', 404);
    }

    header('Content-Type: ' . ($doc['mime'] ?: 'application/octet-stream'));
    header('Content-Disposition: attachment; filename="'
        . str_replace('"', '', $doc['original_name']) . '"');
    header('Content-Length: ' . filesize($path));
    header('X-Content-Type-Options: nosniff');
    header('Cache-Control: private, no-store');
    readfile($path);
    exit;
}

// ---- POST /department-documents/{id}/delete --------------------------

function deptDocumentDelete(PDO $pdo, string $id) {
    $user = require_auth($pdo);
    $doc = dept_document_or_404($pdo, $id);
    require_department_manager_or_director($pdo, $user, $doc['department_id']);

    $pdo->prepare('DELETE FROM department_documents WHERE id = ?')->execute([$id]);
    $path = DEPARTMENT_DOCUMENT_DIR . basename($doc['stored_path']);
    if (is_file($path)) {
        @unlink($path);
    }

    json_response(['success' => true, 'message' => 'Documento eliminado.']);
}
