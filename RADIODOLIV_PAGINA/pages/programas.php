<?php
define('SITE_BASE_PATH', '../');
require_once __DIR__ . '/../inc/data/programs.php';

$activePage      = 'programas';
$pageTitle       = 'Programas | Radio Doliv';
$pageDescription = 'Horarios, categorías y detalles de cada programa al aire en Radio Doliv.';
$pageStylesheet  = ['pages/programas-hero', 'pages/programas-list', 'pages/programas-modal'];
$canonicalRelative = 'pages/programas.php';

// Tipografia propia de esta pagina: "Space Grotesk" para titulares (voz de
// cabina) y "JetBrains Mono" para los horarios (lectura tipo dial/reloj de
// transmision). No se cargan globalmente, solo aqui via $pageExtraHead.
$pageExtraHead = <<<HTML
    <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=JetBrains+Mono:wght@400;500;600;700&display=swap" rel="stylesheet">
HTML;

$programs = get_programs();

// ---------------------------------------------------------------------
// CATALOGO DE GENEROS. En la BD la misma etiqueta viene escrita de varias
// formas ("Musica", "Música", "música"), asi que agrupar por el texto
// crudo producia filtros duplicados que ademas no se encontraban entre si
// (comparar "musica" con "música" nunca coincide). Se agrupa por una
// clave normalizada -- minusculas y sin acentos -- que es la que viaja al
// markup en data-filter/data-categories, y se muestra la variante mejor
// escrita de cada grupo.
// ---------------------------------------------------------------------
function program_tag_key(string $tag): string {
    $lower = strtr($tag, [
        'Á' => 'a', 'á' => 'a', 'É' => 'e', 'é' => 'e', 'Í' => 'i', 'í' => 'i',
        'Ó' => 'o', 'ó' => 'o', 'Ú' => 'u', 'ú' => 'u', 'Ü' => 'u', 'ü' => 'u',
        'Ñ' => 'n', 'ñ' => 'n',
    ]);
    return strtolower(trim($lower));
}

// Puntua que tan "presentable" es una variante: se prefiere la que empieza
// en mayuscula y, entre esas, la que conserva los acentos.
function program_tag_score(string $tag): int {
    $startsUpper = preg_match('/^[A-ZÁÉÍÓÚÑ]/u', $tag) === 1;
    $hasAccent = preg_match('/[áéíóúüñÁÉÍÓÚÜÑ]/u', $tag) === 1;
    return ($startsUpper ? 2 : 0) + ($hasAccent ? 1 : 0);
}

// Devuelve las claves normalizadas de un programa (para data-categories).
function program_tag_keys(?string $categories): array {
    $tags = array_filter(array_map('trim', explode(',', (string) $categories)));
    return array_values(array_unique(array_map('program_tag_key', $tags)));
}

$categoryLabels = [];
foreach ($programs as $program) {
    foreach (array_filter(array_map('trim', explode(',', (string) ($program['categories'] ?? '')))) as $tag) {
        $key = program_tag_key($tag);
        if (!isset($categoryLabels[$key]) || program_tag_score($tag) > program_tag_score($categoryLabels[$key])) {
            $categoryLabels[$key] = $tag;
        }
    }
}
ksort($categoryLabels, SORT_NATURAL);

// ---------------------------------------------------------------------
// BLOQUES DEL DIA. La bibliografia de programacion radiofonica coincide
// en que una parrilla se entiende mejor partida en franjas con caracter
// propio (despertar / compania / desconexion) que como una tabla plana de
// 24 horas -- asi que los programas se agrupan por la hora en que salen
// al aire y cada franja se presenta como su propio capitulo.
// ---------------------------------------------------------------------
$daypartMeta = [
    'madrugada' => ['label' => 'Madrugada', 'range' => '00 — 06 h', 'note' => 'Música continua para las horas silenciosas.'],
    'manana'    => ['label' => 'Mañana',    'range' => '06 — 12 h', 'note' => 'El arranque del día: energía, cultura y compañía.'],
    'tarde'     => ['label' => 'Tarde',     'range' => '12 — 19 h', 'note' => 'Conversación y ritmo para la jornada larga.'],
    'noche'     => ['label' => 'Noche',     'range' => '19 — 24 h', 'note' => 'Historias, calma y música para cerrar.'],
    'siempre'   => ['label' => 'Siempre al aire', 'range' => '24/7', 'note' => 'Suena cuando no hay programa en vivo.'],
];

function program_daypart(?int $slotStart): string {
    if ($slotStart === null) return 'siempre';
    if ($slotStart < 6)  return 'madrugada';
    if ($slotStart < 12) return 'manana';
    if ($slotStart < 19) return 'tarde';
    return 'noche';
}

$grouped = [];
foreach ($programs as $index => $program) {
    $program['_index'] = $index;
    $grouped[program_daypart($program['slot_start'] !== null ? (int) $program['slot_start'] : null)][] = $program;
}
// Orden de lectura del dia completo, saltando franjas sin programas.
$daypartOrder = array_values(array_filter(
    ['madrugada', 'manana', 'tarde', 'noche', 'siempre'],
    fn(string $key) => !empty($grouped[$key])
));

// Programas con horario fijo: alimentan los segmentos del dial de 24 h.
$dialPrograms = array_values(array_filter(
    $programs,
    fn(array $p) => $p['slot_start'] !== null && $p['slot_end'] !== null
));
?>
<!DOCTYPE html>
<html lang="es" data-page="<?= $activePage ?? '' ?>">
<?php include __DIR__ . '/../inc/partials/head.php'; ?>
<body data-site-base="<?= h(site_root_url()) ?>">
    <?php include __DIR__ . '/../inc/partials/navbar.php'; ?>

    <main class="shows-main">
        <!-- ============================================================
             CABINA EN VIVO — el encabezado no es un titulo decorativo
             sino el estado real de la emisora: que suena AHORA, con que
             locutor, cuanto lleva y cuanto le queda. La bibliografia de
             parrillas insiste en que una programacion "debe sentirse
             viva" y destacar el programa en curso en vez de mostrar una
             tabla congelada; el bloque completo lo repinta el JS con la
             hora LOCAL del visitante (ver pages/programas.js).
             ============================================================ -->
        <section class="booth" id="booth" data-empty-title="Radio Doliv Music" data-empty-host="Selección continua">
            <div class="booth-glow" aria-hidden="true"></div>

            <div class="booth-body">
                <p class="booth-status">
                    <span class="pulse-dot" aria-hidden="true"></span>
                    <span id="booth-status-label">Al aire ahora</span>
                    <span class="booth-clock" id="booth-clock" aria-label="Hora local">--:--</span>
                </p>

                <h1 class="booth-title" id="booth-title">Radio Doliv Music</h1>
                <p class="booth-host" id="booth-host">Selección continua</p>

                <div class="booth-progress" id="booth-progress" aria-hidden="true">
                    <span class="booth-progress-from" id="booth-progress-from"></span>
                    <span class="booth-progress-track"><span class="booth-progress-bar" id="booth-progress-bar"></span></span>
                    <span class="booth-progress-to" id="booth-progress-to"></span>
                </div>

                <p class="booth-next" id="booth-next" hidden>
                    <span>A continuación</span>
                    <strong id="booth-next-name"></strong>
                    <em id="booth-next-time"></em>
                </p>
            </div>

            <div class="booth-art" id="booth-art" aria-hidden="true">
                <img id="booth-art-img" src="" alt="">
            </div>
        </section>

        <?php if (count($dialPrograms)): ?>
        <!-- ============================================================
             DIAL DE 24 HORAS — visualizacion y navegacion a la vez: cada
             programa es un segmento coloreado ubicado en su hora real
             dentro de la linea del dia, con una aguja que marca el
             momento actual. Reemplaza a los chips genericos de filtro
             como elemento principal de orientacion: de un vistazo se ve
             como se reparte el dia y, al hacer click, salta al programa.
             ============================================================ -->
        <div class="dial" id="dial">
            <div class="dial-track" id="dial-track">
                <?php foreach ($dialPrograms as $program):
                    $start = (int) $program['slot_start'];
                    $end = (int) $program['slot_end'];
                    // Los programas que cruzan la medianoche se dibujan hasta el
                    // final del dia; su tramo despues de las 00 h ya queda
                    // representado por la franja "Madrugada" de mas abajo.
                    $span = $end <= $start ? (24 - $start) : ($end - $start);
                ?>
                <button type="button" class="dial-seg"
                        data-dial-target="programa-<?= h($program['slug']) ?>"
                        style="--from: <?= $start ?>; --span: <?= $span ?>; --show-accent: <?= h($program['accent']) ?>;"
                        title="<?= h($program['title']) ?> · <?= h($program['badge_time'] ?? '') ?>">
                    <span class="dial-seg-name"><?= h($program['title']) ?></span>
                </button>
                <?php endforeach; ?>
                <span class="dial-needle" id="dial-needle" aria-hidden="true"></span>
            </div>
            <div class="dial-hours" aria-hidden="true">
                <?php foreach ([0, 3, 6, 9, 12, 15, 18, 21, 24] as $hour): ?>
                <span style="--at: <?= $hour ?>;"><?= sprintf('%02d', $hour % 24) ?></span>
                <?php endforeach; ?>
            </div>
        </div>
        <?php endif; ?>

        <?php if (count($categoryLabels) > 1): ?>
        <!-- Filtro por genero: texto subrayado, no pastillas -- la
             orientacion principal ya la da el dial de arriba. -->
        <div class="rundown-filters" role="group" aria-label="Filtrar programas por género">
            <span class="rundown-filters-label">Filtrar</span>
            <button type="button" class="rundown-filter is-active" data-filter="todos">Todos</button>
            <?php foreach ($categoryLabels as $key => $label): ?>
            <button type="button" class="rundown-filter" data-filter="<?= h($key) ?>"><?= h($label) ?></button>
            <?php endforeach; ?>
        </div>
        <?php endif; ?>

        <div class="rundown" id="rundown">
            <?php foreach ($daypartOrder as $daypartKey):
                $meta = $daypartMeta[$daypartKey];
            ?>
            <section class="rundown-block" data-daypart="<?= h($daypartKey) ?>">
                <header class="rundown-block-head">
                    <h2><?= h($meta['label']) ?></h2>
                    <span class="rundown-block-range"><?= h($meta['range']) ?></span>
                    <p class="rundown-block-note"><?= h($meta['note']) ?></p>
                </header>

                <?php foreach ($grouped[$daypartKey] as $program):
                    $programIndex = $program['_index'];
                    include __DIR__ . '/../inc/components/program-entry.php';
                endforeach; ?>
            </section>
            <?php endforeach; ?>

            <p class="rundown-empty" id="rundown-empty" hidden>Ningún programa coincide con ese género por ahora.</p>
        </div>
    </main>

    <div class="show-modal" id="show-modal" aria-hidden="true" data-page-content>
        <div class="show-modal-overlay" data-close-modal="true"></div>
        <div class="show-modal-card" role="dialog" aria-modal="true" aria-labelledby="show-modal-title">
            <button class="show-modal-close" id="show-modal-close" aria-label="Cerrar ventana">
                <span>Cerrar</span><i data-lucide="x"></i>
            </button>
            <p class="show-modal-time" id="show-modal-time"></p>
            <h3 id="show-modal-title">Programa</h3>
            <p class="show-modal-summary" id="show-modal-summary"></p>
            <ul class="show-modal-cats" id="show-modal-cats"></ul>
        </div>
    </div>

    <?php $footerExtended = false; include __DIR__ . '/../inc/partials/footer.php'; ?>
    <?php include __DIR__ . '/../inc/partials/scripts.php'; ?>
    <script src="<?= asset_url('assets/js/pages/programas.js') ?>" data-page-script></script>
</body>
</html>
