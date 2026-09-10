<?php
define('SITE_BASE_PATH', '../');
require_once __DIR__ . '/../inc/data/announcements.php';
require_once __DIR__ . '/../inc/helpers/html.php';
require_once __DIR__ . '/../inc/helpers/format.php';

$activePage      = 'anuncios';
$pageTitle       = 'Anuncios | Radio Doliv';
$pageDescription = 'Anuncios activos, promociones y enlaces de contacto de Radio Doliv.';
$pageStylesheet  = ['pages/anuncios', 'pages/anuncios-news'];
$canonicalRelative = 'pages/anuncios.php';

/* Tipografia del diseño portado de news4.html (Tana template): solo se
   carga en esta pagina, sin tocar Inter/Space Grotesk que usa el resto
   del sitio (ver inc/partials/head.php, $pageExtraHead). */
$pageExtraHead = '<link rel="preconnect" href="https://fonts.googleapis.com">'
    . '<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;500;600;700;800&display=swap" rel="stylesheet">';

$result = get_announcements();
$anuncios = $result['items'];
$errorConsulta = $result['error'];
$anunciosJson = json_encode($anuncios, JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_AMP | JSON_HEX_QUOT | JSON_UNESCAPED_UNICODE);

$whatsappAdvertiser = 'https://wa.me/5217131205259?text=' . rawurlencode('Hola, quiero publicar un anuncio en Radio Doliv');

/* normalizarImagen() (inc/helpers/format.php) solo arregla espacios en la
   ruta -- sigue siendo relativa a la RAIZ del sitio (ej.
   "assets/img/anuncios/foo.jpg"), y esta pagina vive un nivel abajo
   (pages/), asi que hace falta anteponer SITE_BASE_PATH igual que hace
   asset_url() para cualquier otro recurso. Las URLs absolutas (http...)
   se dejan tal cual. */
function anw_img(?string $path): string {
    $normalized = normalizarImagen($path ?? '');
    if ($normalized === '' || preg_match('/^https?:\/\//i', $normalized)) return $normalized;
    return SITE_BASE_PATH . $normalized;
}

/* ---------------------------------------------------------------------
   Puede haber muy pocos anuncios activos (a veces uno solo), pero el
   diseño de news4.html tiene bastantes huecos que llenar (sidebar,
   grilla, galeria, categorias). anw_cycle_indexed() repite lo que haya
   -- igual que la maqueta original repetia sus mismas 3-4 noticias de
   muestra en cada seccion -- conservando el INDICE ORIGINAL de cada
   anuncio en $anuncios, porque ese es el numero que anuncios.js usa
   para abrir el modal correcto (ver #announcements-data mas abajo).
   --------------------------------------------------------------------- */
function anw_cycle_indexed(array $items, int $n): array {
    if (!$items) return [];
    $keys = array_keys($items);
    $count = count($keys);
    $out = [];
    for ($i = 0; $i < $n; $i++) {
        $k = $keys[$i % $count];
        $out[] = [$k, $items[$k]];
    }
    return $out;
}

$heroItems    = anw_cycle_indexed($anuncios, min(count($anuncios) ?: 0, 5)) ?: anw_cycle_indexed($anuncios, 1);
$sidebarLeft  = anw_cycle_indexed($anuncios, 5);
$mainPool     = anw_cycle_indexed($anuncios, 8);
$mainChunks   = array_chunk($mainPool, 4);
$sidebarRight = anw_cycle_indexed(array_reverse($anuncios, true), 4);
$galleryItems = anw_cycle_indexed($anuncios, max(count($anuncios), 3));
$catCol1      = anw_cycle_indexed($anuncios, 6);
$catCol2      = anw_cycle_indexed(array_reverse($anuncios, true), 6);
$catCol3      = anw_cycle_indexed($anuncios, 5);
?>
<!DOCTYPE html>
<html lang="es" data-page="<?= $activePage ?? '' ?>">
<?php include __DIR__ . '/../inc/partials/head.php'; ?>
<body data-site-base="<?= h(site_root_url()) ?>">
    <?php include __DIR__ . '/../inc/partials/navbar.php'; ?>

    <?php /* ============================================================
         Diseño portado de news4.html (Tana - Magazine/News HTML
         Template): la portada de "noticias" del template se convierte
         aqui en la cartelera de anuncios de Radio Doliv, seccion por
         seccion (hero -> bloque editorial de 3 columnas -> galeria de
         fotos -> filas de categorias), con las clases .anw-* propias
         para no chocar con nada del sitio. Navbar, reproductor flotante
         (inyectado por sticky-player.js) y footer son los del sitio, sin
         tocar (ver inc/partials/navbar.php y footer.php). Cada tarjeta
         sigue abriendo el MISMO modal de siempre (inc/components/
         modal-announcement.php + assets/js/pages/anuncios.js), sin
         tocar esa pieza. ============================================================ */ ?>
    <main class="announcements-main">
        <div class="anw">

            <?php if ($errorConsulta !== null): ?>
            <div class="anw-shell">
                <section class="announcements-empty">
                    <h2>No se pudieron cargar los anuncios</h2>
                    <p><?= h($errorConsulta) ?></p>
                </section>
            </div>
            <?php elseif (count($anuncios) === 0): ?>
            <div class="anw-shell">
                <section class="announcements-empty">
                    <h2>Aún no hay anuncios publicados</h2>
                    <p>Cuando se registren anuncios en la base de datos aparecerán aquí automáticamente.</p>
                </section>
            </div>
            <?php else: ?>

            <!-- ============================================
                 HERO -- equivalente al "news-slider" con MasterSlider
                 de news4.html: anuncio a pantalla ancha con velo y caja
                 de texto.
                 ============================================ -->
            <section class="anw-hero" data-reveal aria-label="Anuncios destacados">
                <?php foreach ($heroItems as $slot => [$idx, $a]): ?>
                <div class="anw-hero-slide<?= $slot === 0 ? ' is-active' : '' ?>" data-slide="<?= $slot ?>">
                    <img class="anw-hero-bg" src="<?= h(anw_img($a['imagen_url'] ?? '')) ?>" alt=""
                         loading="<?= $slot === 0 ? 'eager' : 'lazy' ?>" <?= $slot === 0 ? 'fetchpriority="high"' : '' ?>>
                    <div class="anw-hero-tint" aria-hidden="true"></div>
                    <div class="anw-hero-box">
                        <div class="anw-meta">
                            <span class="anw-meta-a">Radio Doliv</span>
                            <span class="anw-meta-b"><?= h(formatearFecha($a['fecha_publicacion'] ?? '')) ?></span>
                        </div>
                        <h2 class="anw-hero-title"><?= h($a['titulo'] ?? 'Anuncio') ?></h2>
                        <p class="anw-hero-lead"><?= h($a['descripcion'] ?? '') ?></p>
                        <button type="button" class="anw-cta" data-announcement-index="<?= (int) $idx ?>">Ver información</button>
                    </div>
                </div>
                <?php endforeach; ?>

                <?php if (count($heroItems) > 1): ?>
                <div class="anw-hero-nav">
                    <button type="button" class="anw-arrow" id="anwHeroPrev" aria-label="Anuncio anterior">&larr;</button>
                    <div class="anw-hero-dots" id="anwHeroDots">
                        <?php foreach ($heroItems as $slot => $pair): ?>
                        <button type="button" class="anw-dot<?= $slot === 0 ? ' is-active' : '' ?>" data-goto="<?= $slot ?>" aria-label="Ir al anuncio <?= $slot + 1 ?>"></button>
                        <?php endforeach; ?>
                    </div>
                    <button type="button" class="anw-arrow" id="anwHeroNext" aria-label="Anuncio siguiente">&rarr;</button>
                </div>
                <?php endif; ?>
            </section>

            <!-- ============================================
                 BLOQUE EDITORIAL -- equivalente a "news-block" de
                 news4.html: sidebar izquierda (Recientes), grilla
                 central de 2 columnas (category-block) y sidebar
                 derecha (Más anuncios) con anuncio propio.
                 ============================================ -->
            <div class="anw-shell">
                <section class="anw-block">
                    <div class="anw-grid anw-grid--3col">

                        <aside class="anw-col anw-col--side" data-reveal>
                            <h3 class="anw-title-mid">Recientes</h3>
                            <div class="anw-list">
                                <?php foreach ($sidebarLeft as [$idx, $a]): ?>
                                <button type="button" class="anw-post anw-post--list" data-announcement-index="<?= (int) $idx ?>">
                                    <h4><?= h($a['titulo'] ?? 'Anuncio') ?></h4>
                                    <p><?= h($a['descripcion'] ?? '') ?></p>
                                    <div class="anw-meta">
                                        <span class="anw-meta-a">Radio Doliv</span>
                                        <span class="anw-meta-b"><?= h(formatearFecha($a['fecha_publicacion'] ?? '')) ?></span>
                                    </div>
                                </button>
                                <?php endforeach; ?>
                            </div>
                        </aside>

                        <div class="anw-col anw-col--main" data-reveal>
                            <div class="anw-subgrid">
                                <?php foreach ($mainChunks as $chunk): if (!$chunk) continue; [$featIdx, $feature] = $chunk[0]; $rest = array_slice($chunk, 1); ?>
                                <div class="anw-category-block">
                                    <button type="button" class="anw-post anw-post--feature" data-announcement-index="<?= (int) $featIdx ?>">
                                        <div class="anw-post-image"><img src="<?= h(anw_img($feature['imagen_url'] ?? '')) ?>" alt="" loading="lazy"></div>
                                        <div class="anw-meta">
                                            <span class="anw-meta-a">Radio Doliv</span>
                                            <span class="anw-meta-b"><?= h(formatearFecha($feature['fecha_publicacion'] ?? '')) ?></span>
                                        </div>
                                        <h4><?= h($feature['titulo'] ?? 'Anuncio') ?></h4>
                                        <p><?= h($feature['descripcion'] ?? '') ?></p>
                                    </button>
                                    <?php foreach ($rest as [$idx, $a]): ?>
                                    <button type="button" class="anw-post anw-post--thumb" data-announcement-index="<?= (int) $idx ?>">
                                        <div class="anw-post-thumb"><img src="<?= h(anw_img($a['imagen_url'] ?? '')) ?>" alt="" loading="lazy"></div>
                                        <h4><?= h($a['titulo'] ?? 'Anuncio') ?></h4>
                                        <p><?= h($a['descripcion'] ?? '') ?></p>
                                        <div class="anw-meta">
                                            <span class="anw-meta-a">Radio Doliv</span>
                                            <span class="anw-meta-b"><?= h(formatearFecha($a['fecha_publicacion'] ?? '')) ?></span>
                                        </div>
                                    </button>
                                    <?php endforeach; ?>
                                </div>
                                <?php endforeach; ?>
                            </div>
                        </div>

                        <aside class="anw-col anw-col--side" data-reveal>
                            <h3 class="anw-title-mid">Más anuncios</h3>
                            <div class="anw-list">
                                <?php foreach ($sidebarRight as [$idx, $a]): ?>
                                <button type="button" class="anw-post anw-post--list" data-announcement-index="<?= (int) $idx ?>">
                                    <h4><?= h($a['titulo'] ?? 'Anuncio') ?></h4>
                                    <p><?= h($a['descripcion'] ?? '') ?></p>
                                    <div class="anw-meta">
                                        <span class="anw-meta-a">Radio Doliv</span>
                                        <span class="anw-meta-b"><?= h(formatearFecha($a['fecha_publicacion'] ?? '')) ?></span>
                                    </div>
                                </button>
                                <?php endforeach; ?>
                            </div>

                            <a class="anw-ad" href="<?= h($whatsappAdvertiser) ?>" target="_blank" rel="noopener">
                                <span class="anw-ad-kicker">Anúnciate aquí</span>
                                <span class="anw-ad-title">¿Quieres publicar<br>tu anuncio?</span>
                            </a>
                        </aside>

                    </div>
                    <div class="anw-border-line" data-reveal></div>
                </section>

                <!-- ============================================
                     GALERIA -- equivalente al "photo-news-slider" ("In
                     Pictures") de news4.html: todos los anuncios en un
                     carrusel con tira de miniaturas.
                     ============================================ -->
                <section class="anw-gallery" aria-label="Anuncios en imágenes">
                    <h2 class="anw-block-title" data-title="Anuncios" data-reveal>
                        Anuncios en imágenes
                    </h2>

                    <div class="anw-gallery-slider" id="anwGallerySlider" data-reveal>
                        <div class="anw-gallery-main">
                            <?php foreach ($galleryItems as $slot => [$idx, $a]): ?>
                            <div class="anw-slide<?= $slot === 0 ? ' is-active' : '' ?>" data-slide="<?= $slot ?>">
                                <img src="<?= h(anw_img($a['imagen_url'] ?? '')) ?>" alt="<?= h($a['titulo'] ?? 'Anuncio') ?>" loading="lazy">
                                <div class="anw-slide-box">
                                    <div class="anw-meta">
                                        <span class="anw-meta-a">Radio Doliv</span>
                                        <span class="anw-meta-b"><?= h(formatearFecha($a['fecha_publicacion'] ?? '')) ?></span>
                                    </div>
                                    <h4><?= h($a['titulo'] ?? 'Anuncio') ?></h4>
                                    <p><?= h($a['descripcion'] ?? '') ?></p>
                                </div>
                                <button type="button" class="anw-slide-hit" data-announcement-index="<?= (int) $idx ?>" aria-label="Ver información de <?= h($a['titulo'] ?? 'este anuncio') ?>"></button>
                            </div>
                            <?php endforeach; ?>
                        </div>

                        <?php if (count($galleryItems) > 1): ?>
                        <div class="anw-gallery-thumbs" id="anwGalleryThumbs">
                            <?php foreach ($galleryItems as $slot => [$idx, $a]): ?>
                            <button type="button" class="anw-gallery-thumb<?= $slot === 0 ? ' is-active' : '' ?>" data-goto="<?= $slot ?>">
                                <img src="<?= h(anw_img($a['imagen_url'] ?? '')) ?>" alt="">
                            </button>
                            <?php endforeach; ?>
                        </div>
                        <?php endif; ?>
                    </div>
                </section>

                <div class="anw-border-line" data-reveal></div>

                <!-- ============================================
                     CATEGORIAS -- equivalente a la fila final de 3
                     columnas de news4.html (bloques con titulo + post
                     grande + posts chicos, y "You may also like" con
                     anuncio).
                     ============================================ -->
                <section class="anw-categories">
                    <div class="anw-grid anw-grid--even">

                        <div class="anw-col" data-reveal>
                            <?php foreach (array_chunk($catCol1, 3) as $group): if (!$group) continue; [$featIdx, $feature] = $group[0]; $rest = array_slice($group, 1); ?>
                            <div class="anw-category-block anw-category-block--compact">
                                <h3 class="anw-title-mid">Destacado</h3>
                                <button type="button" class="anw-post anw-post--thumb" data-announcement-index="<?= (int) $featIdx ?>">
                                    <div class="anw-post-thumb"><img src="<?= h(anw_img($feature['imagen_url'] ?? '')) ?>" alt="" loading="lazy"></div>
                                    <h4><?= h($feature['titulo'] ?? 'Anuncio') ?></h4>
                                    <p><?= h($feature['descripcion'] ?? '') ?></p>
                                    <div class="anw-meta">
                                        <span class="anw-meta-a">Radio Doliv</span>
                                        <span class="anw-meta-b"><?= h(formatearFecha($feature['fecha_publicacion'] ?? '')) ?></span>
                                    </div>
                                </button>
                                <?php foreach ($rest as [$idx, $a]): ?>
                                <button type="button" class="anw-post anw-post--mini" data-announcement-index="<?= (int) $idx ?>">
                                    <div class="anw-meta">
                                        <span class="anw-meta-a">Radio Doliv</span>
                                        <span class="anw-meta-b"><?= h(formatearFecha($a['fecha_publicacion'] ?? '')) ?></span>
                                    </div>
                                    <h6><?= h($a['titulo'] ?? 'Anuncio') ?></h6>
                                </button>
                                <?php endforeach; ?>
                            </div>
                            <?php endforeach; ?>
                        </div>

                        <div class="anw-col" data-reveal>
                            <?php foreach (array_chunk($catCol2, 3) as $group): if (!$group) continue; [$featIdx, $feature] = $group[0]; $rest = array_slice($group, 1); ?>
                            <div class="anw-category-block anw-category-block--compact">
                                <h3 class="anw-title-mid">Del archivo</h3>
                                <button type="button" class="anw-post anw-post--thumb" data-announcement-index="<?= (int) $featIdx ?>">
                                    <div class="anw-post-thumb"><img src="<?= h(anw_img($feature['imagen_url'] ?? '')) ?>" alt="" loading="lazy"></div>
                                    <h4><?= h($feature['titulo'] ?? 'Anuncio') ?></h4>
                                    <p><?= h($feature['descripcion'] ?? '') ?></p>
                                    <div class="anw-meta">
                                        <span class="anw-meta-a">Radio Doliv</span>
                                        <span class="anw-meta-b"><?= h(formatearFecha($feature['fecha_publicacion'] ?? '')) ?></span>
                                    </div>
                                </button>
                                <?php foreach ($rest as [$idx, $a]): ?>
                                <button type="button" class="anw-post anw-post--mini" data-announcement-index="<?= (int) $idx ?>">
                                    <div class="anw-meta">
                                        <span class="anw-meta-a">Radio Doliv</span>
                                        <span class="anw-meta-b"><?= h(formatearFecha($a['fecha_publicacion'] ?? '')) ?></span>
                                    </div>
                                    <h6><?= h($a['titulo'] ?? 'Anuncio') ?></h6>
                                </button>
                                <?php endforeach; ?>
                            </div>
                            <?php endforeach; ?>
                        </div>

                        <div class="anw-col" data-reveal>
                            <h3 class="anw-title-mid">También te puede interesar</h3>
                            <div class="anw-list">
                                <?php foreach ($catCol3 as [$idx, $a]): ?>
                                <button type="button" class="anw-post anw-post--mini" data-announcement-index="<?= (int) $idx ?>">
                                    <div class="anw-meta">
                                        <span class="anw-meta-a">Radio Doliv</span>
                                        <span class="anw-meta-b"><?= h(formatearFecha($a['fecha_publicacion'] ?? '')) ?></span>
                                    </div>
                                    <h6><?= h($a['titulo'] ?? 'Anuncio') ?></h6>
                                </button>
                                <?php endforeach; ?>
                            </div>

                            <a class="anw-ad" href="<?= h($whatsappAdvertiser) ?>" target="_blank" rel="noopener">
                                <span class="anw-ad-kicker">Para negocios</span>
                                <span class="anw-ad-title">Anuncia tu marca<br>con Radio Doliv</span>
                            </a>
                        </div>

                    </div>
                </section>
            </div>
            <?php endif; ?>

        </div>
    </main>

    <?php include __DIR__ . '/../inc/components/modal-announcement.php'; ?>

    <?php $footerExtended = false; include __DIR__ . '/../inc/partials/footer.php'; ?>
    <?php include __DIR__ . '/../inc/partials/scripts.php'; ?>
    <script type="application/json" id="announcements-data" data-page-content><?= $anunciosJson ?: '[]' ?></script>
    <script src="<?php require_once __DIR__ . '/../inc/helpers/assets.php'; echo asset_url('assets/js/pages/anuncios.js'); ?>" data-page-script></script>
    <script src="<?= asset_url('assets/js/pages/anuncios-news.js') ?>" data-page-script></script>
</body>
</html>
