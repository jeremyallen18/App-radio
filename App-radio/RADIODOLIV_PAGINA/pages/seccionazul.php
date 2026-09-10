<?php
define('SITE_BASE_PATH', '../');
require_once __DIR__ . '/../inc/data/sponsors.php';
require_once __DIR__ . '/../inc/helpers/html.php';

$activePage      = 'seccionazul';
$pageTitle       = 'Sección Azul | Radio Doliv';
$pageDescription = 'Directorio de aliados de Radio Doliv: escuelas, negocios, instituciones y proyectos de Santiago Tilapa y la región.';
$pageStylesheet  = ['pages/seccionazul-hero', 'pages/seccionazul-grid', 'pages/seccionazul-dossier'];
$canonicalRelative = 'pages/seccionazul.php';

// Archivo Narrow: condensada, que es como se componen las entradas de un
// directorio impreso para que quepan en columna. JetBrains Mono para los
// datos (conteos, pie de edicion, codigos de giro). Solo en esta pagina.
$pageExtraHead = <<<HTML
    <link href="https://fonts.googleapis.com/css2?family=Archivo+Narrow:wght@600;700&family=JetBrains+Mono:wght@400;500;700&display=swap" rel="stylesheet">
HTML;

$sponsors = get_sponsors();
$sponsorsJson = json_encode($sponsors, JSON_UNESCAPED_UNICODE | JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_AMP | JSON_HEX_QUOT);

// Catalogo fijo de giros (icono + etiqueta + tono). Todos dentro de la
// familia azul: el sitio solo usa azul/negro/blanco, asi que las secciones
// se distinguen por tono y luminosidad, no por matiz.
$categoryCatalog = [
    'escuelas'    => ['label' => 'Escuelas',        'icon' => 'graduation-cap',  'accent' => '#3b82f6'],
    'mascotas'    => ['label' => 'Mascotas',        'icon' => 'paw-print',       'accent' => '#0ea5e9'],
    'comida'      => ['label' => 'Comida y dulces', 'icon' => 'utensils',        'accent' => '#2563eb'],
    'bienestar'   => ['label' => 'Bienestar',       'icon' => 'heart-pulse',     'accent' => '#0891b2'],
    'servicios'   => ['label' => 'Servicios',       'icon' => 'briefcase',       'accent' => '#1e40af'],
    'social'      => ['label' => 'Social',          'icon' => 'heart-handshake', 'accent' => '#38bdf8'],
    'tecnologia'  => ['label' => 'Tecnología',      'icon' => 'smartphone',      'accent' => '#06b6d4'],
];

// Un directorio se lee alfabeticamente dentro de cada giro -- el orden de
// captura en la BD (sort_order) no le sirve a nadie que venga a buscar un
// negocio por su nombre. Se ordena sin acentos para que "Súper Dulce" caiga
// en la S y no despues de la Z.
// Marcas de contacto del renglon. Se componen como CODIGOS ABREVIADOS y no
// como logotipos por dos razones: es lo que hace un directorio impreso
// (abreviaturas al final del renglon, no marcas comerciales), y ademas los
// iconos de marca ya no existen en la version actual de Lucide -- facebook,
// instagram y youtube se quedaban como <i> vacios e invisibles, que en esta
// pagina significaba dejar sin destino a la linea de puntos de casi todos
// los aliados (la mayoria solo tiene Facebook).
function sz_social_code(string $label): string {
    $map = [
        'facebook'  => 'FB',
        'instagram' => 'IG',
        'tiktok'    => 'TT',
        'youtube'   => 'YT',
        'whatsapp'  => 'WA',
        'app'       => 'APP',
        'x'         => 'X',
        'twitter'   => 'X',
        'web'       => 'WEB',
        'sitio web' => 'WEB',
    ];
    $key = strtolower(trim($label));
    if (isset($map[$key])) return $map[$key];
    // Cualquier red nueva que se registre en la BD entra con sus dos
    // primeras letras en vez de quedarse sin marca.
    return strtoupper(substr($key, 0, 2));
}

function sz_sort_key(string $name): string {
    $plain = strtr($name, [
        'Á' => 'A', 'á' => 'a', 'É' => 'E', 'é' => 'e', 'Í' => 'I', 'í' => 'i',
        'Ó' => 'O', 'ó' => 'o', 'Ú' => 'U', 'ú' => 'u', 'Ü' => 'U', 'ü' => 'u',
        'Ñ' => 'N', 'ñ' => 'n',
    ]);
    return strtolower($plain);
}

// Agrupa por giro conservando el indice original de cada aliado: el dossier
// lo usa para encontrar sus datos completos en la isla JSON.
$grouped = [];
foreach ($sponsors as $index => $sponsor) {
    $sponsor['_index'] = $index;
    $grouped[$sponsor['category']][] = $sponsor;
}
foreach ($grouped as &$list) {
    usort($list, fn(array $a, array $b) => sz_sort_key($a['name']) <=> sz_sort_key($b['name']));
}
unset($list);

$categoryCounts = array_map('count', $grouped);
$locationCount = count(array_filter($sponsors, fn($s) => !empty($s['map'])));
$activeCategories = array_values(array_filter(
    array_keys($categoryCatalog),
    fn(string $slug) => !empty($grouped[$slug])
));
?>
<!DOCTYPE html>
<html lang="es" data-page="<?= $activePage ?? '' ?>">
<?php include __DIR__ . '/../inc/partials/head.php'; ?>
<body data-site-base="<?= h(site_root_url()) ?>">
    <?php include __DIR__ . '/../inc/partials/navbar.php'; ?>

    <main class="dir" id="main-content">
        <!-- ============================================================
             La pagina se llama Seccion Azul por la Seccion Amarilla, el
             directorio impreso mexicano. Asi que se compone como uno:
             portada con pie de edicion, indice de giros, y entradas
             alfabetizadas dentro de cada giro unidas a sus contactos por
             una linea de puntos -- el artefacto tipografico que hace
             reconocible a un directorio. Nada de tarjetas.
             ============================================================ -->
        <header class="dir-masthead">
            <div class="dir-masthead-glow" aria-hidden="true"></div>
            <p class="dir-masthead-over dir-anim" style="--anim-order: 0">
                <i data-lucide="gem" aria-hidden="true"></i> Radio Doliv &mdash; Patrocinadores
            </p>
            <h1 class="dir-masthead-title">
                <span class="dir-reveal-sweep">Sección Azul</span>
            </h1>
            <p class="dir-masthead-sub">
                <?php
                // Animacion palabra por palabra: cada <span> lleva su propio
                // retraso (--w) para que el parrafo se "escriba" en cascada
                // en vez de aparecer en bloque, sin depender de scroll (esta
                // arriba del pliegue, siempre visible al cargar).
                $subtitleWords = explode(' ', 'El directorio de quienes hacen posible la radio: escuelas, negocios, instituciones y proyectos de Santiago Tilapa y la región.');
                foreach ($subtitleWords as $wordIndex => $word):
                ?><span class="dir-word" style="--w: <?= (int) $wordIndex ?>"><?= h($word) ?></span> <?php
                endforeach;
                ?>
            </p>
            <dl class="dir-colophon">
                <div class="dir-anim" style="--anim-order: 6"><dt>Aliados</dt><dd data-count="<?= count($sponsors) ?>">0</dd></div>
                <div class="dir-anim" style="--anim-order: 7"><dt>Giros</dt><dd data-count="<?= count($activeCategories) ?>">0</dd></div>
                <div class="dir-anim" style="--anim-order: 8"><dt>Con ubicación</dt><dd data-count="<?= $locationCount ?>">0</dd></div>
                <div class="dir-anim" style="--anim-order: 9"><dt>Edición</dt><dd data-count="<?= date('Y') ?>">0</dd></div>
            </dl>
        </header>

        <!-- Indice de giros: las pestañas de un directorio impreso. -->
        <nav class="dir-index" aria-label="Ir a un giro del directorio">
            <button class="dir-index-tab is-active" type="button" data-filter="todos">
                Todos <b><?= count($sponsors) ?></b>
            </button>
            <?php foreach ($activeCategories as $slug): $meta = $categoryCatalog[$slug]; ?>
            <button class="dir-index-tab" type="button" data-filter="<?= h($slug) ?>" style="--dir-accent: <?= h($meta['accent']) ?>;">
                <?= h($meta['label']) ?> <b><?= (int) $categoryCounts[$slug] ?></b>
            </button>
            <?php endforeach; ?>
        </nav>

        <div class="dir-body" id="dir-body">
            <?php foreach ($activeCategories as $slug):
                $meta = $categoryCatalog[$slug];
            ?>
            <section class="dir-section" data-category="<?= h($slug) ?>" style="--dir-accent: <?= h($meta['accent']) ?>;">
                <h2 class="dir-section-head">
                    <span class="dir-section-icon"><i data-lucide="<?= h($meta['icon']) ?>" aria-hidden="true"></i></span>
                    <span class="dir-section-name"><?= h($meta['label']) ?></span>
                    <span class="dir-section-rule" aria-hidden="true"></span>
                    <span class="dir-section-count"><?= (int) $categoryCounts[$slug] ?></span>
                </h2>

                <ul class="dir-entries">
                    <?php foreach ($grouped[$slug] as $position => $sponsor): ?>
                    <li class="dir-entry" style="--stagger: <?= (int) $position ?>;">
                        <button type="button" class="dir-entry-btn" data-sponsor-index="<?= (int) $sponsor['_index'] ?>">
                            <span class="dir-entry-plate">
                                <img src="<?= h(SITE_BASE_PATH . $sponsor['image']) ?>" alt="" loading="lazy">
                            </span>

                            <span class="dir-entry-line">
                                <span class="dir-entry-name"><?= h($sponsor['name']) ?></span>
                                <span class="dir-entry-leader" aria-hidden="true"></span>
                                <span class="dir-entry-marks">
                                    <?php foreach ($sponsor['socials'] as $social): ?>
                                    <span class="dir-mark"><?= h(sz_social_code($social['label'])) ?></span>
                                    <?php endforeach; ?>
                                    <?php if (!empty($sponsor['map'])): ?>
                                    <span class="dir-mark dir-mark--place" title="Tiene ubicación registrada"><i data-lucide="map-pin" aria-hidden="true"></i></span>
                                    <?php endif; ?>
                                    <?php if (empty($sponsor['socials']) && empty($sponsor['map'])): ?>
                                    <span class="dir-entry-nomark">—</span>
                                    <?php endif; ?>
                                </span>
                            </span>

                            <span class="dir-entry-sub"><?= h($sponsor['subtitle']) ?></span>
                            <span class="dir-entry-summary"><?= h($sponsor['summary']) ?></span>
                            <span class="dir-entry-open">Ver ficha <i data-lucide="arrow-right" aria-hidden="true"></i></span>
                        </button>
                    </li>
                    <?php endforeach; ?>
                </ul>
            </section>
            <?php endforeach; ?>

            <p class="dir-empty" id="dir-empty" hidden>Aún no hay aliados registrados en ese giro.</p>
        </div>

        <!-- Cierre: la pagina tambien vende el espacio. Un directorio que no
             dice como aparecer en el esta a medias. -->
        <aside class="dir-join">
            <p class="dir-join-label">¿Falta tu negocio?</p>
            <p class="dir-join-text">La Sección Azul está abierta a los negocios e instituciones de la región. Escríbenos y te contamos cómo aparecer aquí.</p>
            <a class="dir-join-cta" href="<?= h(site_root_url()) ?>pages/servicios.php" data-page-link="servicios">
                Ver paquetes de publicidad <i data-lucide="arrow-right" aria-hidden="true"></i>
            </a>
        </aside>
    </main>

    <!-- Ficha completa del aliado. -->
    <div class="sz-dossier" id="sz-dossier" aria-hidden="true" data-page-content>
        <div class="sz-dossier-overlay" data-close-sz="true"></div>
        <article class="sz-dossier-card" role="dialog" aria-modal="true" aria-labelledby="sz-dossier-title">
            <button class="sz-dossier-close" type="button" id="sz-dossier-close" aria-label="Cerrar ficha">
                <span>Cerrar</span><i data-lucide="x"></i>
            </button>

            <div class="sz-dossier-plate">
                <img id="sz-dossier-img" src="" alt="">
            </div>

            <div class="sz-dossier-head">
                <p class="sz-dossier-tag" id="sz-dossier-category"></p>
                <h2 id="sz-dossier-title">Aliado</h2>
                <p id="sz-dossier-subtitle"></p>
            </div>

            <div class="sz-dossier-body">
                <section class="sz-dossier-block">
                    <span class="sz-dossier-label">Sobre este aliado</span>
                    <div id="sz-dossier-description"></div>
                </section>
                <section class="sz-dossier-block">
                    <span class="sz-dossier-label">Dónde encontrarlo</span>
                    <div class="sz-dossier-socials" id="sz-dossier-socials"></div>
                </section>
                <section class="sz-dossier-block">
                    <span class="sz-dossier-label">Ubicación</span>
                    <div class="sz-dossier-map" id="sz-dossier-map"></div>
                </section>
            </div>
        </article>
    </div>

    <?php $footerExtended = false; include __DIR__ . '/../inc/partials/footer.php'; ?>
    <?php include __DIR__ . '/../inc/partials/scripts.php'; ?>
    <script type="application/json" id="sponsors-data" data-page-content><?= $sponsorsJson ?: '[]' ?></script>
    <script src="<?= asset_url('assets/js/pages/seccionazul.js') ?>" data-page-script></script>
</body>
</html>
