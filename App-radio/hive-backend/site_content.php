<?php
// Gestión del contenido del sitio público RADIODOLIV_PAGINA (anuncios,
// eventos, patrocinadores, podcasts, servicios, equipo, programas),
// exclusiva para el rol 'director' desde la app Flutter. Las tablas ya
// existen en hive_db (compartida con RADIODOLIV_PAGINA) y ya son leídas
// por inc/data/*.php de ese proyecto; aquí solo se agrega la escritura.
//
// Cada recurso expone 4 endpoints (list/create/update/delete), todos
// protegidos con require_auth()+require_role(['director']). Create/update
// siempre llegan como multipart/form-data (la imagen es opcional en
// ambos), así que leen $_POST/$_FILES directamente en vez de
// request_body() (que no sirve para multipart).

// ---- helpers compartidos --------------------------------------------------

function site_slugify(string $value): string {
    $value = strtolower(trim($value));
    $value = strtr($value, [
        'á' => 'a', 'é' => 'e', 'í' => 'i', 'ó' => 'o', 'ú' => 'u', 'ñ' => 'n', 'ü' => 'u',
    ]);
    $value = preg_replace('/[^a-z0-9]+/', '-', $value);
    $value = trim($value, '-');
    return $value !== '' ? $value : 'item';
}

// $table siempre viene de una llamada fija en este archivo, nunca de
// entrada del cliente, así que interpolarlo en la consulta es seguro.
function site_unique_slug(PDO $pdo, string $table, string $base): string {
    $slug = site_slugify($base);
    $candidate = $slug;
    $suffix = 2;
    $check = $pdo->prepare("SELECT 1 FROM `$table` WHERE slug = ?");
    while (true) {
        $check->execute([$candidate]);
        if (!$check->fetch()) {
            return $candidate;
        }
        $candidate = $slug . '-' . $suffix++;
    }
}

// Procesa $_FILES[$field] si el usuario adjuntó una imagen nueva; si no,
// conserva $existingPath. Guarda el archivo directamente dentro del
// proyecto público (RADIODOLIV_PAGINA_PATH, ver config.php) para que
// inc/data/*.php lo sirva sin ningún paso intermedio.
function site_handle_image(string $field, string $subdir, string $labelForName, string $existingPath): string {
    if (empty($_FILES[$field]) || $_FILES[$field]['error'] === UPLOAD_ERR_NO_FILE) {
        return $existingPath;
    }

    $file = $_FILES[$field];
    if ($file['error'] !== UPLOAD_ERR_OK) {
        error_response('No se pudo subir la imagen', 400);
    }

    $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    $allowed = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    if (!in_array($ext, $allowed, true) || @getimagesize($file['tmp_name']) === false) {
        error_response('Solo se permiten imágenes jpg, jpeg, png, gif o webp', 400);
    }

    $targetDir = RADIODOLIV_PAGINA_PATH . '/assets/img/' . $subdir;
    if (!is_dir($targetDir) && !mkdir($targetDir, 0755, true) && !is_dir($targetDir)) {
        error_response('No se pudo preparar la carpeta de destino de la imagen', 500);
    }

    $base = site_slugify($labelForName !== '' ? $labelForName : pathinfo($file['name'], PATHINFO_FILENAME));
    $fileName = $base . '-' . substr(bin2hex(random_bytes(4)), 0, 8) . '.' . $ext;

    if (!move_uploaded_file($file['tmp_name'], $targetDir . '/' . $fileName)) {
        error_response('No se pudo guardar la imagen en el servidor', 500);
    }

    return 'assets/img/' . $subdir . '/' . $fileName;
}

// Igual que site_handle_image pero para archivos de audio (episodios de
// podcast). Guarda en assets/audio/$subdir dentro de RADIODOLIV_PAGINA_PATH.
function site_handle_audio(string $field, string $subdir, string $labelForName, string $existingPath): string {
    if (empty($_FILES[$field]) || $_FILES[$field]['error'] === UPLOAD_ERR_NO_FILE) {
        return $existingPath;
    }

    $file = $_FILES[$field];
    if ($file['error'] !== UPLOAD_ERR_OK) {
        error_response('No se pudo subir el audio', 400);
    }

    $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    $allowed = ['mp3', 'wav', 'm4a', 'ogg'];
    if (!in_array($ext, $allowed, true)) {
        error_response('Solo se permiten archivos de audio mp3, wav, m4a u ogg', 400);
    }

    $targetDir = RADIODOLIV_PAGINA_PATH . '/assets/audio/' . $subdir;
    if (!is_dir($targetDir) && !mkdir($targetDir, 0755, true) && !is_dir($targetDir)) {
        error_response('No se pudo preparar la carpeta de destino del audio', 500);
    }

    $base = site_slugify($labelForName !== '' ? $labelForName : pathinfo($file['name'], PATHINFO_FILENAME));
    $fileName = $base . '-' . substr(bin2hex(random_bytes(4)), 0, 8) . '.' . $ext;

    if (!move_uploaded_file($file['tmp_name'], $targetDir . '/' . $fileName)) {
        error_response('No se pudo guardar el audio en el servidor', 500);
    }

    return 'assets/audio/' . $subdir . '/' . $fileName;
}

// Devuelve el valor de la cabecera X-Api-Key sin importar cómo la exponga el
// servidor (variable $_SERVER o getallheaders()), o null si no vino.
function site_request_api_key(): ?string {
    if (isset($_SERVER['HTTP_X_API_KEY']) && $_SERVER['HTTP_X_API_KEY'] !== '') {
        return trim((string) $_SERVER['HTTP_X_API_KEY']);
    }
    if (function_exists('getallheaders')) {
        foreach (getallheaders() as $name => $value) {
            if (strcasecmp($name, 'X-Api-Key') === 0) {
                return trim((string) $value);
            }
        }
    }
    return null;
}

// Autoriza la edición del contenido del sitio público. Dos formas de entrar:
//
//   1. App Flutter del director (App-radio): sesión + rol 'director'.
//   2. App interna de Sistemas (proyecto beta_web): NO tiene login. Se
//      identifica con una llave estática en la cabecera X-Api-Key que debe
//      coincidir con SITE_CONTENT_KEY del .env. Si SITE_CONTENT_KEY está
//      vacío o no está definido, esta vía queda deshabilitada y todo sigue
//      exactamente como antes (solo director por sesión).
function site_require_director(PDO $pdo): array {
    $configuredKey = (string) env_get('SITE_CONTENT_KEY', '');
    if ($configuredKey !== '') {
        $sentKey = site_request_api_key();
        if ($sentKey !== null && hash_equals($configuredKey, $sentKey)) {
            return ['email' => 'sistemas@radiodoliv', 'role' => 'director'];
        }
    }

    $user = require_auth($pdo);
    require_role($user, ['director']);
    return $user;
}

// ---- anuncios --------------------------------------------------------------

function siteAnunciosList(PDO $pdo) {
    site_require_director($pdo);
    $rows = $pdo->query('SELECT * FROM anuncios ORDER BY fecha_publicacion DESC, id DESC')->fetchAll();
    json_response(['items' => $rows]);
}

function siteAnuncioCreate(PDO $pdo) {
    site_require_director($pdo);
    $titulo = trim($_POST['titulo'] ?? '');
    if ($titulo === '') error_response('titulo es requerido', 400);

    $imagenUrl = site_handle_image('imagen', 'anuncios', $titulo, '');
    $stmt = $pdo->prepare('INSERT INTO anuncios (titulo, descripcion, imagen_url, link_web, link_facebook, link_whatsapp, fecha_publicacion) VALUES (?, ?, ?, ?, ?, ?, ?)');
    $stmt->execute([
        $titulo,
        trim($_POST['descripcion'] ?? ''),
        $imagenUrl,
        safe_external_url($_POST['link_web'] ?? ''),
        safe_external_url($_POST['link_facebook'] ?? ''),
        safe_external_url($_POST['link_whatsapp'] ?? ''),
        trim($_POST['fecha_publicacion'] ?? '') ?: null,
    ]);

    $id = (int) $pdo->lastInsertId();
    $stmt = $pdo->prepare('SELECT * FROM anuncios WHERE id = ?');
    $stmt->execute([$id]);
    json_response(['item' => $stmt->fetch()], 201);
}

function siteAnuncioUpdate(PDO $pdo, string $id) {
    site_require_director($pdo);
    $stmt = $pdo->prepare('SELECT * FROM anuncios WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Anuncio no encontrado', 404);

    $titulo = trim($_POST['titulo'] ?? '');
    if ($titulo === '') error_response('titulo es requerido', 400);

    $imagenUrl = site_handle_image('imagen', 'anuncios', $titulo, $existing['imagen_url'] ?? '');
    $stmt = $pdo->prepare('UPDATE anuncios SET titulo=?, descripcion=?, imagen_url=?, link_web=?, link_facebook=?, link_whatsapp=?, fecha_publicacion=? WHERE id=?');
    $stmt->execute([
        $titulo,
        trim($_POST['descripcion'] ?? ''),
        $imagenUrl,
        safe_external_url($_POST['link_web'] ?? ''),
        safe_external_url($_POST['link_facebook'] ?? ''),
        safe_external_url($_POST['link_whatsapp'] ?? ''),
        trim($_POST['fecha_publicacion'] ?? '') ?: null,
        $id,
    ]);

    $stmt = $pdo->prepare('SELECT * FROM anuncios WHERE id = ?');
    $stmt->execute([$id]);
    json_response(['item' => $stmt->fetch()]);
}

function siteAnuncioDelete(PDO $pdo, string $id) {
    site_require_director($pdo);
    $pdo->prepare('DELETE FROM anuncios WHERE id = ?')->execute([$id]);
    json_response(['ok' => true]);
}

// ---- eventos (radio_events) ------------------------------------------------

function siteEventosList(PDO $pdo) {
    site_require_director($pdo);
    $rows = $pdo->query('SELECT * FROM radio_events ORDER BY sort_order ASC, id ASC')->fetchAll();
    json_response(['items' => $rows]);
}

function site_evento_fields(): array {
    return [
        trim($_POST['title'] ?? ''),
        trim($_POST['artist'] ?? ''),
        trim($_POST['location'] ?? ''),
        trim($_POST['weekday'] ?? ''),
        trim($_POST['day'] ?? ''),
        trim($_POST['month'] ?? ''),
        trim($_POST['year'] ?? ''),
        trim($_POST['event_date'] ?? '') ?: null,
        trim($_POST['time_label'] ?? ''),
        trim($_POST['description'] ?? ''),
        (int) ($_POST['sort_order'] ?? 0),
    ];
}

function siteEventoCreate(PDO $pdo) {
    site_require_director($pdo);
    $title = trim($_POST['title'] ?? '');
    if ($title === '') error_response('title es requerido', 400);

    [, $artist, $location, $weekday, $day, $month, $year, $eventDate, $timeLabel, $description, $sortOrder] = site_evento_fields();
    $image = site_handle_image('image', 'eventos', $title, '');
    $slug = site_unique_slug($pdo, 'radio_events', $title);

    $stmt = $pdo->prepare('INSERT INTO radio_events (slug, title, artist, location, image, weekday, day, month, year, event_date, time_label, description, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
    $stmt->execute([$slug, $title, $artist, $location, $image, $weekday, $day, $month, $year, $eventDate, $timeLabel, $description, $sortOrder]);

    $id = (int) $pdo->lastInsertId();
    $stmt = $pdo->prepare('SELECT * FROM radio_events WHERE id = ?');
    $stmt->execute([$id]);
    json_response(['item' => $stmt->fetch()], 201);
}

function siteEventoUpdate(PDO $pdo, string $id) {
    site_require_director($pdo);
    $stmt = $pdo->prepare('SELECT * FROM radio_events WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Evento no encontrado', 404);

    $title = trim($_POST['title'] ?? '');
    if ($title === '') error_response('title es requerido', 400);

    [, $artist, $location, $weekday, $day, $month, $year, $eventDate, $timeLabel, $description, $sortOrder] = site_evento_fields();
    $image = site_handle_image('image', 'eventos', $title, $existing['image'] ?? '');

    $stmt = $pdo->prepare('UPDATE radio_events SET title=?, artist=?, location=?, image=?, weekday=?, day=?, month=?, year=?, event_date=?, time_label=?, description=?, sort_order=? WHERE id=?');
    $stmt->execute([$title, $artist, $location, $image, $weekday, $day, $month, $year, $eventDate, $timeLabel, $description, $sortOrder, $id]);

    $stmt = $pdo->prepare('SELECT * FROM radio_events WHERE id = ?');
    $stmt->execute([$id]);
    json_response(['item' => $stmt->fetch()]);
}

function siteEventoDelete(PDO $pdo, string $id) {
    site_require_director($pdo);
    $pdo->prepare('DELETE FROM radio_events WHERE id = ?')->execute([$id]);
    json_response(['ok' => true]);
}

// ---- servicios (radio_services) --------------------------------------------

function siteServiciosList(PDO $pdo) {
    site_require_director($pdo);
    $rows = $pdo->query('SELECT * FROM radio_services ORDER BY sort_order ASC, id ASC')->fetchAll();
    json_response(['items' => $rows]);
}

function siteServicioCreate(PDO $pdo) {
    site_require_director($pdo);
    $title = trim($_POST['title'] ?? '');
    if ($title === '') error_response('title es requerido', 400);

    $image = site_handle_image('image', 'servicios', $title, '');
    $stmt = $pdo->prepare('INSERT INTO radio_services (title, image, description, whatsapp_url, category, icon, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?)');
    $stmt->execute([
        $title,
        $image,
        trim($_POST['description'] ?? ''),
        safe_external_url($_POST['whatsapp_url'] ?? ''),
        trim($_POST['category'] ?? ''),
        trim($_POST['icon'] ?? ''),
        (int) ($_POST['sort_order'] ?? 0),
    ]);

    $id = (int) $pdo->lastInsertId();
    $stmt = $pdo->prepare('SELECT * FROM radio_services WHERE id = ?');
    $stmt->execute([$id]);
    json_response(['item' => $stmt->fetch()], 201);
}

function siteServicioUpdate(PDO $pdo, string $id) {
    site_require_director($pdo);
    $stmt = $pdo->prepare('SELECT * FROM radio_services WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Servicio no encontrado', 404);

    $title = trim($_POST['title'] ?? '');
    if ($title === '') error_response('title es requerido', 400);

    $image = site_handle_image('image', 'servicios', $title, $existing['image'] ?? '');
    $stmt = $pdo->prepare('UPDATE radio_services SET title=?, image=?, description=?, whatsapp_url=?, category=?, icon=?, sort_order=? WHERE id=?');
    $stmt->execute([
        $title,
        $image,
        trim($_POST['description'] ?? ''),
        safe_external_url($_POST['whatsapp_url'] ?? ''),
        trim($_POST['category'] ?? ''),
        trim($_POST['icon'] ?? ''),
        (int) ($_POST['sort_order'] ?? 0),
        $id,
    ]);

    $stmt = $pdo->prepare('SELECT * FROM radio_services WHERE id = ?');
    $stmt->execute([$id]);
    json_response(['item' => $stmt->fetch()]);
}

function siteServicioDelete(PDO $pdo, string $id) {
    site_require_director($pdo);
    $pdo->prepare('DELETE FROM radio_services WHERE id = ?')->execute([$id]);
    json_response(['ok' => true]);
}

// ---- equipo (radio_team) ----------------------------------------------------
// bio/path/interests se guardan tal cual llegan (con sus \n) porque
// RADIODOLIV_PAGINA/inc/data/team.php las separa con explode("\n\n"/"\n")
// al leerlas — el cliente Flutter manda un textarea por línea, igual que
// hacía el panel web descartado.

function site_team_with_socials(PDO $pdo, int $id): array {
    $stmt = $pdo->prepare('SELECT * FROM radio_team WHERE id = ?');
    $stmt->execute([$id]);
    $member = $stmt->fetch();
    $socialsStmt = $pdo->prepare('SELECT label, icon, url FROM team_socials WHERE team_id = ? ORDER BY sort_order ASC, id ASC');
    $socialsStmt->execute([$id]);
    $member['socials'] = $socialsStmt->fetchAll();
    $programsStmt = $pdo->prepare('SELECT program_id FROM radio_program_hosts WHERE team_id = ? ORDER BY sort_order ASC, id ASC');
    $programsStmt->execute([$id]);
    $member['program_ids'] = array_map('intval', $programsStmt->fetchAll(PDO::FETCH_COLUMN));
    return $member;
}

// Reemplaza por completo las redes sociales de un integrante con las que
// llegaron en $_POST['socials_json'] (array JSON de {label,icon,url}) --
// mismo enfoque que site_save_sponsor_socials().
function site_save_team_socials(PDO $pdo, int $teamId): void {
    $pdo->prepare('DELETE FROM team_socials WHERE team_id = ?')->execute([$teamId]);

    $raw = $_POST['socials_json'] ?? '[]';
    $rows = json_decode($raw, true);
    if (!is_array($rows)) return;

    $insert = $pdo->prepare('INSERT INTO team_socials (team_id, label, icon, url, sort_order) VALUES (?, ?, ?, ?, ?)');
    $order = 0;
    foreach ($rows as $row) {
        $label = trim((string) ($row['label'] ?? ''));
        $url = safe_external_url($row['url'] ?? '');
        if ($label === '' && $url === '') continue;
        $insert->execute([$teamId, $label, trim((string) ($row['icon'] ?? '')), $url, $order++]);
    }
}

function siteEquipoList(PDO $pdo) {
    site_require_director($pdo);
    $rows = $pdo->query('SELECT * FROM radio_team ORDER BY sort_order ASC, id ASC')->fetchAll();
    $socialsStmt = $pdo->query('SELECT team_id, label, icon, url FROM team_socials ORDER BY team_id ASC, sort_order ASC');
    $byMember = [];
    foreach ($socialsStmt->fetchAll() as $s) {
        $byMember[$s['team_id']][] = ['label' => $s['label'], 'icon' => $s['icon'], 'url' => $s['url']];
    }
    $byHost = site_team_program_ids_by_team($pdo);
    foreach ($rows as &$row) {
        $row['socials'] = $byMember[$row['id']] ?? [];
        $row['program_ids'] = $byHost[$row['id']] ?? [];
    }
    json_response(['items' => $rows]);
}

function site_equipo_text(string $field): string {
    return trim(str_replace("\r\n", "\n", $_POST[$field] ?? ''));
}

// Ids de radio_programs vinculados a cada integrante (radio_program_hosts),
// en un solo query — se usa para listar y para armar la respuesta de un
// integrante.
function site_team_program_ids_by_team(PDO $pdo): array {
    $rows = $pdo->query('SELECT team_id, program_id FROM radio_program_hosts ORDER BY sort_order ASC, id ASC')->fetchAll();
    $byTeam = [];
    foreach ($rows as $row) {
        $byTeam[(int) $row['team_id']][] = (int) $row['program_id'];
    }
    return $byTeam;
}

// Recalcula el texto libre `host` de un programa a partir de TODOS sus
// locutores vinculados actualmente (radio_program_hosts), uniendo sus
// nombres con site_join_names_with_y(). Si ya no queda ninguno vinculado,
// deja `host` tal cual estaba (no borra un nombre escrito a mano).
function site_recompute_program_host(PDO $pdo, int $programId): void {
    $stmt = $pdo->prepare('
        SELECT t.name FROM radio_program_hosts rph
        JOIN radio_team t ON t.id = rph.team_id
        WHERE rph.program_id = ?
        ORDER BY rph.sort_order ASC, rph.id ASC
    ');
    $stmt->execute([$programId]);
    $names = $stmt->fetchAll(PDO::FETCH_COLUMN);
    if ($names === []) return;
    $pdo->prepare('UPDATE radio_programs SET host = ? WHERE id = ?')
        ->execute([site_join_names_with_y($names), $programId]);
}

// Aplica la selección de "programas que conduce" enviada desde el formulario
// de equipo ($_POST['program_ids'], ids separados por coma). Vincula este
// integrante como (co-)conductor de los programas elegidos, sin tocar a los
// demás locutores que ya tuvieran esos programas, y lo desvincula de los que
// ya no estén en la lista; en ambos casos recalcula el `host` combinado del
// programa afectado. Si el campo no llega en la petición, no toca los
// vínculos existentes.
function site_sync_team_programs(PDO $pdo, int $teamId): void {
    if (!array_key_exists('program_ids', $_POST)) return;

    $raw = trim((string) $_POST['program_ids']);
    $ids = $raw === '' ? [] : array_values(array_unique(array_filter(
        array_map('intval', explode(',', $raw)),
        fn($n) => $n > 0
    )));

    if ($ids !== []) {
        $placeholders = implode(',', array_fill(0, count($ids), '?'));
        $valid = $pdo->prepare("SELECT id FROM radio_programs WHERE id IN ($placeholders)");
        $valid->execute($ids);
        $ids = array_map('intval', $valid->fetchAll(PDO::FETCH_COLUMN));
    }

    $currentStmt = $pdo->prepare('SELECT program_id FROM radio_program_hosts WHERE team_id = ?');
    $currentStmt->execute([$teamId]);
    $current = array_map('intval', $currentStmt->fetchAll(PDO::FETCH_COLUMN));

    $toLink = array_values(array_diff($ids, $current));
    $toUnlink = array_values(array_diff($current, $ids));

    $maxOrderStmt = $pdo->prepare('SELECT COALESCE(MAX(sort_order), -1) FROM radio_program_hosts WHERE program_id = ?');
    $insert = $pdo->prepare('INSERT INTO radio_program_hosts (program_id, team_id, sort_order) VALUES (?, ?, ?)');
    foreach ($toLink as $programId) {
        $maxOrderStmt->execute([$programId]);
        $insert->execute([$programId, $teamId, (int) $maxOrderStmt->fetchColumn() + 1]);
    }

    if ($toUnlink !== []) {
        $placeholders = implode(',', array_fill(0, count($toUnlink), '?'));
        $pdo->prepare("DELETE FROM radio_program_hosts WHERE team_id = ? AND program_id IN ($placeholders)")
            ->execute(array_merge([$teamId], $toUnlink));
    }

    // Recalcula tambien los programas que ya lo tenian y lo siguen teniendo
    // (no solo los que cambiaron de vinculo): si el nombre del integrante se
    // edito en esta misma peticion, su `host` combinado debe reflejarlo.
    foreach (array_unique(array_merge($current, $ids)) as $programId) {
        site_recompute_program_host($pdo, $programId);
    }
}

// Únicas categorías válidas para un integrante del equipo (ver
// RADIODOLIV_PAGINA/pages/equipo.php y assets/js/pages/equipo.js, que
// filtran exactamente por estos dos valores).
const SITE_EQUIPO_CATEGORIES = ['locutores', 'reporteros'];

function site_equipo_category(): string {
    $category = trim($_POST['category'] ?? '');
    if (!in_array($category, SITE_EQUIPO_CATEGORIES, true)) {
        error_response('category debe ser "locutores" o "reporteros".', 400);
    }
    return $category;
}

function siteEquipoCreate(PDO $pdo) {
    site_require_director($pdo);
    $name = trim($_POST['name'] ?? '');
    if ($name === '') error_response('name es requerido', 400);
    $category = site_equipo_category();

    $image = site_handle_image('image', 'locutores', $name, '');
    $slug = site_unique_slug($pdo, 'radio_team', $name);

    $pdo->beginTransaction();
    // El integrante más reciente siempre aparece primero: recorre a todos
    // los demás una posición y este entra en sort_order = 0.
    $pdo->exec('UPDATE radio_team SET sort_order = sort_order + 1');
    $stmt = $pdo->prepare('INSERT INTO radio_team (slug, name, role, category, accent, image, short_desc, bio, path, interests, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)');
    $stmt->execute([
        $slug,
        $name,
        trim($_POST['role'] ?? ''),
        $category,
        trim($_POST['accent'] ?? ''),
        $image,
        trim($_POST['short_desc'] ?? ''),
        site_equipo_text('bio'),
        site_equipo_text('path'),
        site_equipo_text('interests'),
    ]);

    $id = (int) $pdo->lastInsertId();
    site_save_team_socials($pdo, $id);
    site_sync_team_programs($pdo, $id);
    $pdo->commit();

    json_response(['item' => site_team_with_socials($pdo, $id)], 201);
}

function siteEquipoUpdate(PDO $pdo, string $id) {
    site_require_director($pdo);
    $stmt = $pdo->prepare('SELECT * FROM radio_team WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Integrante no encontrado', 404);

    $name = trim($_POST['name'] ?? '');
    if ($name === '') error_response('name es requerido', 400);
    $category = site_equipo_category();

    $image = site_handle_image('image', 'locutores', $name, $existing['image'] ?? '');
    $pdo->beginTransaction();
    // sort_order no se toca aquí a propósito: editar un integrante no debe
    // reordenar la lista (solo crear uno nuevo la reordena, ver Create).
    $stmt = $pdo->prepare('UPDATE radio_team SET name=?, role=?, category=?, accent=?, image=?, short_desc=?, bio=?, path=?, interests=? WHERE id=?');
    $stmt->execute([
        $name,
        trim($_POST['role'] ?? ''),
        $category,
        trim($_POST['accent'] ?? ''),
        $image,
        trim($_POST['short_desc'] ?? ''),
        site_equipo_text('bio'),
        site_equipo_text('path'),
        site_equipo_text('interests'),
        $id,
    ]);
    site_save_team_socials($pdo, (int) $id);
    site_sync_team_programs($pdo, (int) $id);
    $pdo->commit();

    json_response(['item' => site_team_with_socials($pdo, (int) $id)]);
}

function siteEquipoDelete(PDO $pdo, string $id) {
    site_require_director($pdo);
    // team_socials tiene ON DELETE CASCADE hacia radio_team.
    $pdo->prepare('DELETE FROM radio_team WHERE id = ?')->execute([$id]);
    json_response(['ok' => true]);
}

// ---- programas (radio_programs) --------------------------------------------

function siteProgramasList(PDO $pdo) {
    site_require_director($pdo);
    $rows = $pdo->query('SELECT * FROM radio_programs ORDER BY sort_order ASC, id ASC')->fetchAll();
    $byProgram = site_program_host_ids_by_program($pdo);
    foreach ($rows as &$row) {
        $row['host_team_ids'] = $byProgram[$row['id']] ?? [];
    }
    json_response(['items' => $rows]);
}

// Ids de radio_team vinculados a cada programa (host_team_ids), en un solo
// query — se usa para listar y para armar la respuesta de un programa.
function site_program_host_ids_by_program(PDO $pdo): array {
    $rows = $pdo->query('SELECT program_id, team_id FROM radio_program_hosts ORDER BY program_id ASC, sort_order ASC, id ASC')->fetchAll();
    $byProgram = [];
    foreach ($rows as $row) {
        $byProgram[(int) $row['program_id']][] = (int) $row['team_id'];
    }
    return $byProgram;
}

function site_program_with_hosts(PDO $pdo, int $id): array {
    $stmt = $pdo->prepare('SELECT * FROM radio_programs WHERE id = ?');
    $stmt->execute([$id]);
    $program = $stmt->fetch();
    $hostsStmt = $pdo->prepare('SELECT team_id FROM radio_program_hosts WHERE program_id = ? ORDER BY sort_order ASC, id ASC');
    $hostsStmt->execute([$id]);
    $program['host_team_ids'] = array_map('intval', $hostsStmt->fetchAll(PDO::FETCH_COLUMN));
    return $program;
}

// Reemplaza por completo los locutores vinculados a un programa con los ids
// que llegaron en $_POST['host_team_ids'] -- mismo enfoque que
// site_save_team_socials(): borrar todo y re-insertar es más simple y
// robusto que calcular un diff fila por fila.
function site_sync_program_hosts(PDO $pdo, int $programId, array $hostTeamIds): void {
    $pdo->prepare('DELETE FROM radio_program_hosts WHERE program_id = ?')->execute([$programId]);
    $insert = $pdo->prepare('INSERT INTO radio_program_hosts (program_id, team_id, sort_order) VALUES (?, ?, ?)');
    foreach (array_values($hostTeamIds) as $order => $teamId) {
        $insert->execute([$programId, $teamId, $order]);
    }
}

// Une nombres de locutores en un solo texto legible: "Fernanda" con uno,
// "Fernanda y Amanda" con dos, "Fernanda, Amanda y Diego" con tres o más.
function site_join_names_with_y(array $names): string {
    $count = count($names);
    if ($count === 0) return '';
    if ($count === 1) return $names[0];
    $last = array_pop($names);
    return implode(', ', $names) . ' y ' . $last;
}

function site_programa_fields(PDO $pdo): array {
    $slotStart = site_programa_hour('slot_start');
    $slotEnd = site_programa_hour('slot_end');
    if (($slotStart === null) !== ($slotEnd === null)) {
        error_response('Indica la hora de inicio y la hora final, o deja ambas vacías.', 400);
    }
    if ($slotStart !== null && $slotStart === $slotEnd) {
        error_response('La hora de inicio y la hora final no pueden ser iguales.', 400);
    }

    [$hostTeamIds, $host] = site_programa_host($pdo);

    $weekdays = site_programa_weekdays();
    $schedule = trim($_POST['schedule'] ?? '');
    $badgeTime = trim($_POST['badge_time'] ?? '');
    if ($slotStart !== null && $slotEnd !== null) {
        $timeRange = sprintf('%02d:00 - %02d:00', $slotStart, $slotEnd);
        $daysLabel = site_programa_days_label($weekdays);
        $schedule = $daysLabel . ' | ' . $timeRange;
        $badgeTime = $timeRange;
    }

    return [
        trim($_POST['modal_title'] ?? ''),
        $host,
        $hostTeamIds,
        $schedule,
        $slotStart,
        $slotEnd,
        $weekdays === [] ? null : implode(',', $weekdays),
        trim($_POST['badge_icon'] ?? ''),
        $badgeTime,
        trim($_POST['badge_label'] ?? ''),
        trim($_POST['accent'] ?? ''),
        trim($_POST['icon'] ?? ''),
        trim($_POST['categories'] ?? ''),
        trim($_POST['card_desc'] ?? ''),
        trim($_POST['index_desc'] ?? ''),
        trim($_POST['summary'] ?? ''),
        (int) ($_POST['sort_order'] ?? 0),
    ];
}

// Resuelve el/los conductor(es) del programa. Si llegan `host_team_ids`, se
// vinculan a integrantes reales de `radio_team` y el nombre mostrado (`host`)
// se arma siempre a partir de sus nombres, para que nunca queden
// desincronizados. Sin `host_team_ids`, `host` sigue siendo texto libre
// (compatibilidad con programas antiguos o sin locutor todavía dado de alta
// en Equipo).
function site_programa_host(PDO $pdo): array {
    $raw = trim((string) ($_POST['host_team_ids'] ?? ''));
    if ($raw === '') {
        return [[], trim($_POST['host'] ?? '')];
    }
    $ids = array_values(array_unique(array_filter(
        array_map('intval', explode(',', $raw)),
        fn($n) => $n > 0
    )));
    if ($ids === []) {
        return [[], trim($_POST['host'] ?? '')];
    }

    $placeholders = implode(',', array_fill(0, count($ids), '?'));
    $stmt = $pdo->prepare("SELECT id, name FROM radio_team WHERE id IN ($placeholders)");
    $stmt->execute($ids);
    $namesById = [];
    foreach ($stmt->fetchAll() as $row) {
        $namesById[(int) $row['id']] = $row['name'];
    }
    if (count($namesById) !== count($ids)) {
        error_response('Alguno de los locutores seleccionados ya no existe.', 400);
    }
    $names = array_map(fn($id) => $namesById[$id], $ids);
    return [$ids, site_join_names_with_y($names)];
}

function site_programa_hour(string $field): ?int {
    $raw = trim((string) ($_POST[$field] ?? ''));
    if ($raw === '') return null;
    if (filter_var($raw, FILTER_VALIDATE_INT) === false) {
        error_response("$field debe ser una hora entera entre 0 y 23.", 400);
    }
    $hour = (int) $raw;
    if ($hour < 0 || $hour > 23) {
        error_response("$field debe estar entre 0 y 23.", 400);
    }
    return $hour;
}

function site_programa_weekdays(): array {
    $raw = trim((string) ($_POST['weekdays'] ?? ''));
    if ($raw === '') return [];
    $days = array_values(array_unique(array_map('intval', explode(',', $raw))));
    foreach ($days as $day) {
        if ($day < 1 || $day > 7) {
            error_response('Los días de transmisión deben estar entre 1 (lunes) y 7 (domingo).', 400);
        }
    }
    sort($days, SORT_NUMERIC);
    return $days;
}

function site_programa_days_label(array $days): string {
    if ($days === []) return 'Todos los días';
    $labels = [1 => 'Lun', 2 => 'Mar', 3 => 'Mié', 4 => 'Jue', 5 => 'Vie', 6 => 'Sáb', 7 => 'Dom'];
    return implode(', ', array_map(fn(int $day) => $labels[$day], $days));
}

function siteProgramaCreate(PDO $pdo) {
    site_require_director($pdo);
    $title = trim($_POST['title'] ?? '');
    if ($title === '') error_response('title es requerido', 400);

    [$modalTitle, $host, $hostTeamIds, $schedule, $slotStart, $slotEnd, $weekdays, $badgeIcon, $badgeTime, $badgeLabel, $accent, $icon, $categories, $cardDesc, $indexDesc, $summary, $sortOrder] = site_programa_fields($pdo);
    $image = site_handle_image('image', 'programas', $title, '');
    $slug = site_unique_slug($pdo, 'radio_programs', $title);

    $pdo->beginTransaction();
    $stmt = $pdo->prepare('INSERT INTO radio_programs (slug, title, modal_title, host, schedule, slot_start, slot_end, weekdays, badge_icon, badge_time, badge_label, accent, icon, image, categories, card_desc, index_desc, summary, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
    $stmt->execute([$slug, $title, $modalTitle, $host, $schedule, $slotStart, $slotEnd, $weekdays, $badgeIcon, $badgeTime, $badgeLabel, $accent, $icon, $image, $categories, $cardDesc, $indexDesc, $summary, $sortOrder]);

    $id = (int) $pdo->lastInsertId();
    site_sync_program_hosts($pdo, $id, $hostTeamIds);
    $pdo->commit();

    json_response(['item' => site_program_with_hosts($pdo, $id)], 201);
}

function siteProgramaUpdate(PDO $pdo, string $id) {
    site_require_director($pdo);
    $stmt = $pdo->prepare('SELECT * FROM radio_programs WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Programa no encontrado', 404);

    $title = trim($_POST['title'] ?? '');
    if ($title === '') error_response('title es requerido', 400);

    [$modalTitle, $host, $hostTeamIds, $schedule, $slotStart, $slotEnd, $weekdays, $badgeIcon, $badgeTime, $badgeLabel, $accent, $icon, $categories, $cardDesc, $indexDesc, $summary, $sortOrder] = site_programa_fields($pdo);
    $image = site_handle_image('image', 'programas', $title, $existing['image'] ?? '');

    $pdo->beginTransaction();
    $stmt = $pdo->prepare('UPDATE radio_programs SET title=?, modal_title=?, host=?, schedule=?, slot_start=?, slot_end=?, weekdays=?, badge_icon=?, badge_time=?, badge_label=?, accent=?, icon=?, image=?, categories=?, card_desc=?, index_desc=?, summary=?, sort_order=? WHERE id=?');
    $stmt->execute([$title, $modalTitle, $host, $schedule, $slotStart, $slotEnd, $weekdays, $badgeIcon, $badgeTime, $badgeLabel, $accent, $icon, $image, $categories, $cardDesc, $indexDesc, $summary, $sortOrder, $id]);
    site_sync_program_hosts($pdo, (int) $id, $hostTeamIds);
    $pdo->commit();

    json_response(['item' => site_program_with_hosts($pdo, (int) $id)]);
}

function siteProgramaDelete(PDO $pdo, string $id) {
    site_require_director($pdo);
    $pdo->prepare('DELETE FROM radio_programs WHERE id = ?')->execute([$id]);
    json_response(['ok' => true]);
}

// GET /radio/programs — lista de la programación de la radio para verla desde
// la app (cualquier usuario autenticado, no solo el director). Ordena por
// franja horaria para que se lea como una parrilla del día.
function radioProgramsList(PDO $pdo) {
    require_auth($pdo);
    $rows = $pdo->query(
        'SELECT id, title, host, schedule, slot_start, slot_end, weekdays,
                badge_time, accent, image
           FROM radio_programs
          ORDER BY (slot_start IS NULL), slot_start ASC, sort_order ASC, id ASC'
    )->fetchAll();

    $items = array_map(function ($r) {
        $weekdays = array_values(array_filter(array_map(
            'intval',
            $r['weekdays'] !== null && $r['weekdays'] !== ''
                ? explode(',', $r['weekdays']) : []
        ), fn($n) => $n >= 1 && $n <= 7));
        return [
            'id'        => (int) $r['id'],
            'title'     => $r['title'],
            'host'      => $r['host'],
            'schedule'  => $r['schedule'],
            'badgeTime' => $r['badge_time'],
            'slotStart' => $r['slot_start'] !== null ? (int) $r['slot_start'] : null,
            'slotEnd'   => $r['slot_end'] !== null ? (int) $r['slot_end'] : null,
            'weekdays'  => $weekdays,
            'accent'    => $r['accent'],
            'image'     => $r['image'] ?: null,
        ];
    }, $rows);

    json_response(['items' => $items]);
}

// ---- patrocinadores (sponsors + sponsor_socials) ---------------------------

function site_sponsor_with_socials(PDO $pdo, int $id): array {
    $stmt = $pdo->prepare('SELECT * FROM sponsors WHERE id = ?');
    $stmt->execute([$id]);
    $sponsor = $stmt->fetch();
    $socialsStmt = $pdo->prepare('SELECT label, icon, url FROM sponsor_socials WHERE sponsor_id = ? ORDER BY sort_order ASC, id ASC');
    $socialsStmt->execute([$id]);
    $sponsor['socials'] = $socialsStmt->fetchAll();
    return $sponsor;
}

// Reemplaza por completo las redes sociales de un patrocinador con las
// que llegaron en $_POST['socials_json'] (array JSON de {label,icon,url}).
// Más simple y robusto que calcular un diff fila por fila.
function site_save_sponsor_socials(PDO $pdo, int $sponsorId): void {
    $pdo->prepare('DELETE FROM sponsor_socials WHERE sponsor_id = ?')->execute([$sponsorId]);

    $raw = $_POST['socials_json'] ?? '[]';
    $rows = json_decode($raw, true);
    if (!is_array($rows)) return;

    $insert = $pdo->prepare('INSERT INTO sponsor_socials (sponsor_id, label, icon, url, sort_order) VALUES (?, ?, ?, ?, ?)');
    $order = 0;
    foreach ($rows as $row) {
        $label = trim((string) ($row['label'] ?? ''));
        $url = safe_external_url($row['url'] ?? '');
        if ($label === '' && $url === '') continue;
        $insert->execute([$sponsorId, $label, trim((string) ($row['icon'] ?? '')), $url, $order++]);
    }
}

function sitePatrocinadoresList(PDO $pdo) {
    site_require_director($pdo);
    $rows = $pdo->query('SELECT * FROM sponsors ORDER BY sort_order ASC, id ASC')->fetchAll();
    $socialsStmt = $pdo->query('SELECT sponsor_id, label, icon, url FROM sponsor_socials ORDER BY sponsor_id ASC, sort_order ASC');
    $bySponsor = [];
    foreach ($socialsStmt->fetchAll() as $s) {
        $bySponsor[$s['sponsor_id']][] = ['label' => $s['label'], 'icon' => $s['icon'], 'url' => $s['url']];
    }
    foreach ($rows as &$row) {
        $row['socials'] = $bySponsor[$row['id']] ?? [];
    }
    json_response(['items' => $rows]);
}

function siteSponsorCreate(PDO $pdo) {
    site_require_director($pdo);
    $name = trim($_POST['name'] ?? '');
    if ($name === '') error_response('name es requerido', 400);

    $image = site_handle_image('image', 'patrocinadores', $name, '');
    $pdo->beginTransaction();
    $stmt = $pdo->prepare('INSERT INTO sponsors (name, category, category_label, icon, image, subtitle, summary, description, map, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
    $stmt->execute([
        $name,
        trim($_POST['category'] ?? ''),
        trim($_POST['category_label'] ?? ''),
        trim($_POST['icon'] ?? ''),
        $image,
        trim($_POST['subtitle'] ?? ''),
        trim($_POST['summary'] ?? ''),
        trim(str_replace("\r\n", "\n", $_POST['description'] ?? '')),
        trim($_POST['map'] ?? ''),
        (int) ($_POST['sort_order'] ?? 0),
    ]);
    $id = (int) $pdo->lastInsertId();
    site_save_sponsor_socials($pdo, $id);
    $pdo->commit();

    json_response(['item' => site_sponsor_with_socials($pdo, $id)], 201);
}

function siteSponsorUpdate(PDO $pdo, string $id) {
    site_require_director($pdo);
    $stmt = $pdo->prepare('SELECT * FROM sponsors WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Patrocinador no encontrado', 404);

    $name = trim($_POST['name'] ?? '');
    if ($name === '') error_response('name es requerido', 400);

    $image = site_handle_image('image', 'patrocinadores', $name, $existing['image'] ?? '');
    $pdo->beginTransaction();
    $stmt = $pdo->prepare('UPDATE sponsors SET name=?, category=?, category_label=?, icon=?, image=?, subtitle=?, summary=?, description=?, map=?, sort_order=? WHERE id=?');
    $stmt->execute([
        $name,
        trim($_POST['category'] ?? ''),
        trim($_POST['category_label'] ?? ''),
        trim($_POST['icon'] ?? ''),
        $image,
        trim($_POST['subtitle'] ?? ''),
        trim($_POST['summary'] ?? ''),
        trim(str_replace("\r\n", "\n", $_POST['description'] ?? '')),
        trim($_POST['map'] ?? ''),
        (int) ($_POST['sort_order'] ?? 0),
        $id,
    ]);
    site_save_sponsor_socials($pdo, (int) $id);
    $pdo->commit();

    json_response(['item' => site_sponsor_with_socials($pdo, (int) $id)]);
}

function siteSponsorDelete(PDO $pdo, string $id) {
    site_require_director($pdo);
    // sponsor_socials tiene ON DELETE CASCADE hacia sponsors.
    $pdo->prepare('DELETE FROM sponsors WHERE id = ?')->execute([$id]);
    json_response(['ok' => true]);
}

// ---- podcasts (radio_podcasts + radio_podcast_episodes) --------------------

function site_podcast_with_episodes(PDO $pdo, int $id): array {
    $stmt = $pdo->prepare('SELECT * FROM radio_podcasts WHERE id = ?');
    $stmt->execute([$id]);
    $podcast = $stmt->fetch();
    $episodesStmt = $pdo->prepare('SELECT title, description, audio_url, category_label FROM radio_podcast_episodes WHERE podcast_id = ? ORDER BY sort_order ASC, id ASC');
    $episodesStmt->execute([$id]);
    $podcast['episodes'] = $episodesStmt->fetchAll();
    return $podcast;
}

// Reemplaza por completo los episodios de un podcast con los que llegaron
// en $_POST['episodes_json'] (array JSON de {title,description,audio_url,category_label}).
function site_save_podcast_episodes(PDO $pdo, int $podcastId): void {
    $pdo->prepare('DELETE FROM radio_podcast_episodes WHERE podcast_id = ?')->execute([$podcastId]);

    $raw = $_POST['episodes_json'] ?? '[]';
    $rows = json_decode($raw, true);
    if (!is_array($rows)) return;

    $insert = $pdo->prepare('INSERT INTO radio_podcast_episodes (podcast_id, title, description, audio_url, category_label, sort_order) VALUES (?, ?, ?, ?, ?, ?)');
    $order = 0;
    foreach ($rows as $row) {
        $title = trim((string) ($row['title'] ?? ''));
        if ($title === '') continue;
        $existingAudio = trim((string) ($row['audio_url'] ?? ''));
        $audioUrl = site_handle_audio("episode_audio_$order", 'podcasts', $title, $existingAudio);
        $insert->execute([
            $podcastId,
            $title,
            trim((string) ($row['description'] ?? '')),
            $audioUrl,
            trim((string) ($row['category_label'] ?? '')),
            $order++,
        ]);
    }
}

function sitePodcastsList(PDO $pdo) {
    site_require_director($pdo);
    $rows = $pdo->query('SELECT * FROM radio_podcasts ORDER BY sort_order ASC, id ASC')->fetchAll();
    $episodesStmt = $pdo->query('SELECT podcast_id, title, description, audio_url, category_label FROM radio_podcast_episodes ORDER BY podcast_id ASC, sort_order ASC');
    $byPodcast = [];
    foreach ($episodesStmt->fetchAll() as $e) {
        $byPodcast[$e['podcast_id']][] = ['title' => $e['title'], 'description' => $e['description'], 'audio_url' => $e['audio_url'], 'category_label' => $e['category_label']];
    }
    foreach ($rows as &$row) {
        $row['episodes'] = $byPodcast[$row['id']] ?? [];
    }
    json_response(['items' => $rows]);
}

function sitePodcastCreate(PDO $pdo) {
    site_require_director($pdo);
    $title = trim($_POST['title'] ?? '');
    if ($title === '') error_response('title es requerido', 400);

    $cover = site_handle_image('cover', 'portadas', $title, '');
    $slug = site_unique_slug($pdo, 'radio_podcasts', $title);

    $pdo->beginTransaction();
    $stmt = $pdo->prepare('INSERT INTO radio_podcasts (slug, title, filter_icon, cover, sort_order) VALUES (?, ?, ?, ?, ?)');
    $stmt->execute([$slug, $title, trim($_POST['filter_icon'] ?? ''), $cover, (int) ($_POST['sort_order'] ?? 0)]);
    $id = (int) $pdo->lastInsertId();
    site_save_podcast_episodes($pdo, $id);
    $pdo->commit();

    json_response(['item' => site_podcast_with_episodes($pdo, $id)], 201);
}

function sitePodcastUpdate(PDO $pdo, string $id) {
    site_require_director($pdo);
    $stmt = $pdo->prepare('SELECT * FROM radio_podcasts WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Podcast no encontrado', 404);

    $title = trim($_POST['title'] ?? '');
    if ($title === '') error_response('title es requerido', 400);

    $cover = site_handle_image('cover', 'portadas', $title, $existing['cover'] ?? '');

    $pdo->beginTransaction();
    $stmt = $pdo->prepare('UPDATE radio_podcasts SET title=?, filter_icon=?, cover=?, sort_order=? WHERE id=?');
    $stmt->execute([$title, trim($_POST['filter_icon'] ?? ''), $cover, (int) ($_POST['sort_order'] ?? 0), $id]);
    site_save_podcast_episodes($pdo, (int) $id);
    $pdo->commit();

    json_response(['item' => site_podcast_with_episodes($pdo, (int) $id)]);
}

function sitePodcastDelete(PDO $pdo, string $id) {
    site_require_director($pdo);
    // radio_podcast_episodes tiene ON DELETE CASCADE hacia radio_podcasts.
    $pdo->prepare('DELETE FROM radio_podcasts WHERE id = ?')->execute([$id]);
    json_response(['ok' => true]);
}
