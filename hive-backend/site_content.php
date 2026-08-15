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

function site_require_director(PDO $pdo): array {
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

function siteEquipoList(PDO $pdo) {
    site_require_director($pdo);
    $rows = $pdo->query('SELECT * FROM radio_team ORDER BY sort_order ASC, id ASC')->fetchAll();
    json_response(['items' => $rows]);
}

function site_equipo_text(string $field): string {
    return trim(str_replace("\r\n", "\n", $_POST[$field] ?? ''));
}

function siteEquipoCreate(PDO $pdo) {
    site_require_director($pdo);
    $name = trim($_POST['name'] ?? '');
    if ($name === '') error_response('name es requerido', 400);

    $image = site_handle_image('image', 'locutores', $name, '');
    $slug = site_unique_slug($pdo, 'radio_team', $name);

    $stmt = $pdo->prepare('INSERT INTO radio_team (slug, name, role, category, accent, image, short_desc, bio, path, interests, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
    $stmt->execute([
        $slug,
        $name,
        trim($_POST['role'] ?? ''),
        trim($_POST['category'] ?? ''),
        trim($_POST['accent'] ?? ''),
        $image,
        trim($_POST['short_desc'] ?? ''),
        site_equipo_text('bio'),
        site_equipo_text('path'),
        site_equipo_text('interests'),
        (int) ($_POST['sort_order'] ?? 0),
    ]);

    $id = (int) $pdo->lastInsertId();
    $stmt = $pdo->prepare('SELECT * FROM radio_team WHERE id = ?');
    $stmt->execute([$id]);
    json_response(['item' => $stmt->fetch()], 201);
}

function siteEquipoUpdate(PDO $pdo, string $id) {
    site_require_director($pdo);
    $stmt = $pdo->prepare('SELECT * FROM radio_team WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Integrante no encontrado', 404);

    $name = trim($_POST['name'] ?? '');
    if ($name === '') error_response('name es requerido', 400);

    $image = site_handle_image('image', 'locutores', $name, $existing['image'] ?? '');
    $stmt = $pdo->prepare('UPDATE radio_team SET name=?, role=?, category=?, accent=?, image=?, short_desc=?, bio=?, path=?, interests=?, sort_order=? WHERE id=?');
    $stmt->execute([
        $name,
        trim($_POST['role'] ?? ''),
        trim($_POST['category'] ?? ''),
        trim($_POST['accent'] ?? ''),
        $image,
        trim($_POST['short_desc'] ?? ''),
        site_equipo_text('bio'),
        site_equipo_text('path'),
        site_equipo_text('interests'),
        (int) ($_POST['sort_order'] ?? 0),
        $id,
    ]);

    $stmt = $pdo->prepare('SELECT * FROM radio_team WHERE id = ?');
    $stmt->execute([$id]);
    json_response(['item' => $stmt->fetch()]);
}

function siteEquipoDelete(PDO $pdo, string $id) {
    site_require_director($pdo);
    $pdo->prepare('DELETE FROM radio_team WHERE id = ?')->execute([$id]);
    json_response(['ok' => true]);
}

// ---- programas (radio_programs) --------------------------------------------

function siteProgramasList(PDO $pdo) {
    site_require_director($pdo);
    $rows = $pdo->query('SELECT * FROM radio_programs ORDER BY sort_order ASC, id ASC')->fetchAll();
    json_response(['items' => $rows]);
}

function site_programa_fields(): array {
    return [
        trim($_POST['modal_title'] ?? ''),
        trim($_POST['host'] ?? ''),
        trim($_POST['schedule'] ?? ''),
        $_POST['slot_start'] !== '' && isset($_POST['slot_start']) ? (int) $_POST['slot_start'] : null,
        $_POST['slot_end'] !== '' && isset($_POST['slot_end']) ? (int) $_POST['slot_end'] : null,
        trim($_POST['weekdays'] ?? '') ?: null,
        trim($_POST['badge_icon'] ?? ''),
        trim($_POST['badge_time'] ?? ''),
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

function siteProgramaCreate(PDO $pdo) {
    site_require_director($pdo);
    $title = trim($_POST['title'] ?? '');
    if ($title === '') error_response('title es requerido', 400);

    [$modalTitle, $host, $schedule, $slotStart, $slotEnd, $weekdays, $badgeIcon, $badgeTime, $badgeLabel, $accent, $icon, $categories, $cardDesc, $indexDesc, $summary, $sortOrder] = site_programa_fields();
    $image = site_handle_image('image', 'programas', $title, '');
    $slug = site_unique_slug($pdo, 'radio_programs', $title);

    $stmt = $pdo->prepare('INSERT INTO radio_programs (slug, title, modal_title, host, schedule, slot_start, slot_end, weekdays, badge_icon, badge_time, badge_label, accent, icon, image, categories, card_desc, index_desc, summary, sort_order) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
    $stmt->execute([$slug, $title, $modalTitle, $host, $schedule, $slotStart, $slotEnd, $weekdays, $badgeIcon, $badgeTime, $badgeLabel, $accent, $icon, $image, $categories, $cardDesc, $indexDesc, $summary, $sortOrder]);

    $id = (int) $pdo->lastInsertId();
    $stmt = $pdo->prepare('SELECT * FROM radio_programs WHERE id = ?');
    $stmt->execute([$id]);
    json_response(['item' => $stmt->fetch()], 201);
}

function siteProgramaUpdate(PDO $pdo, string $id) {
    site_require_director($pdo);
    $stmt = $pdo->prepare('SELECT * FROM radio_programs WHERE id = ?');
    $stmt->execute([$id]);
    $existing = $stmt->fetch();
    if (!$existing) error_response('Programa no encontrado', 404);

    $title = trim($_POST['title'] ?? '');
    if ($title === '') error_response('title es requerido', 400);

    [$modalTitle, $host, $schedule, $slotStart, $slotEnd, $weekdays, $badgeIcon, $badgeTime, $badgeLabel, $accent, $icon, $categories, $cardDesc, $indexDesc, $summary, $sortOrder] = site_programa_fields();
    $image = site_handle_image('image', 'programas', $title, $existing['image'] ?? '');

    $stmt = $pdo->prepare('UPDATE radio_programs SET title=?, modal_title=?, host=?, schedule=?, slot_start=?, slot_end=?, weekdays=?, badge_icon=?, badge_time=?, badge_label=?, accent=?, icon=?, image=?, categories=?, card_desc=?, index_desc=?, summary=?, sort_order=? WHERE id=?');
    $stmt->execute([$title, $modalTitle, $host, $schedule, $slotStart, $slotEnd, $weekdays, $badgeIcon, $badgeTime, $badgeLabel, $accent, $icon, $image, $categories, $cardDesc, $indexDesc, $summary, $sortOrder, $id]);

    $stmt = $pdo->prepare('SELECT * FROM radio_programs WHERE id = ?');
    $stmt->execute([$id]);
    json_response(['item' => $stmt->fetch()]);
}

function siteProgramaDelete(PDO $pdo, string $id) {
    site_require_director($pdo);
    $pdo->prepare('DELETE FROM radio_programs WHERE id = ?')->execute([$id]);
    json_response(['ok' => true]);
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
        $insert->execute([
            $podcastId,
            $title,
            trim((string) ($row['description'] ?? '')),
            trim((string) ($row['audio_url'] ?? '')),
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
