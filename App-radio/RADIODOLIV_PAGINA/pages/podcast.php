<?php
define('SITE_BASE_PATH', '../');
require_once __DIR__ . '/../inc/data/podcasts.php';

$activePage      = 'podcast';
$pageTitle       = 'Podcast | Radio Doliv';
$pageDescription = 'Episodios, audios y conversaciones disponibles en el catálogo de podcasts de Radio Doliv.';
$pageStylesheet  = 'pages/podcast';
$canonicalRelative = 'pages/podcast.php';

$podcasts = get_podcasts();
$episodeCount = array_sum(array_map(fn($podcast) => count($podcast['episodes']), $podcasts));
?>
<!DOCTYPE html>
<html lang="es" data-page="<?= $activePage ?? '' ?>">
<?php include __DIR__ . '/../inc/partials/head.php'; ?>
<body data-site-base="<?= h(site_root_url()) ?>">
    <?php include __DIR__ . '/../inc/partials/navbar.php'; ?>

    <main class="podcast-main">
        <section class="podcast-hero">
            <div class="podcast-hero-grid">
                <div class="podcast-hero-copy">
                    <p class="podcast-kicker"><i data-lucide="headphones" aria-hidden="true"></i> Radio Doliv Podcast</p>
                    <h1>Escucha nuestras <span class="text-gradient">historias, voces</span> y conversaciones</h1>
                    <p class="podcast-hero-desc">Elige un programa, reproduce sus episodios y descubre los espacios que ya están disponibles o llegarán muy pronto.</p>
                    <p class="podcast-tally">
                        <span class="podcast-tally-item"><i data-lucide="headphones" aria-hidden="true"></i> <b><?= h((string) count($podcasts)) ?></b> programas</span>
                        <span class="podcast-tally-dot" aria-hidden="true">&middot;</span>
                        <span class="podcast-tally-item"><i data-lucide="disc-3" aria-hidden="true"></i> <b><?= h((string) $episodeCount) ?></b> capítulos</span>
                    </p>
                </div>

                <div class="podcast-hero-card">
                    <img src="<?= h(asset_url('assets/img/servicios/PODCAST1.jpg')) ?>" alt="" class="podcast-hero-img" loading="lazy">
                    <div class="podcast-hero-quote">
                        <span class="podcast-hero-quote-mark" aria-hidden="true">&ldquo;</span>
                        <p>Cada voz tiene una historia, cada historia <span>conecta.</span></p>
                        <div class="podcast-hero-wave" aria-hidden="true">
                            <?php for ($i = 0; $i < 28; $i++): ?><span></span><?php endfor; ?>
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <nav class="podcast-tabs" aria-label="Filtrar podcasts por programa">
            <button class="podcast-filter is-active" type="button" data-filter="todos">
                <i data-lucide="layout-grid" aria-hidden="true"></i> Todos
            </button>
            <?php foreach ($podcasts as $podcast): ?>
            <button class="podcast-filter" type="button" data-filter="<?= h($podcast['slug']) ?>">
                <i data-lucide="<?= h($podcast['filter_icon']) ?>" aria-hidden="true"></i> <?= h($podcast['title']) ?>
            </button>
            <?php endforeach; ?>
        </nav>

        <div class="podcast-layout">
            <section class="podcast-programs" id="podcast-programs" aria-live="polite">
                <?php foreach ($podcasts as $podcast): ?>
                    <?php include __DIR__ . '/../inc/components/podcast-playlist.php'; ?>
                <?php endforeach; ?>
            </section>

            <aside class="podcast-sidebar">
                <div class="podcast-discover">
                    <h2>Descubre más programas</h2>
                    <p>Explora otras voces y temáticas</p>
                    <div class="podcast-discover-grid" id="podcast-discover-grid">
                        <?php foreach ($podcasts as $podcast): ?>
                        <button type="button" class="podcast-discover-item" data-filter="<?= h($podcast['slug']) ?>" title="<?= h($podcast['title']) ?>">
                            <img src="<?= h(asset_url($podcast['cover'])) ?>" alt="<?= h($podcast['title']) ?>" loading="lazy">
                        </button>
                        <?php endforeach; ?>
                    </div>
                    <a class="podcast-discover-link" href="<?= h(site_root_url()) ?>pages/programas.php">
                        Ver todos los programas <i data-lucide="arrow-right" aria-hidden="true"></i>
                    </a>
                </div>

                <div class="podcast-cta">
                    <span class="podcast-cta-icon" aria-hidden="true"><i data-lucide="headphones"></i></span>
                    <h2>¿Tienes una historia que merece ser escuchada?</h2>
                    <p>Pronto abriremos convocatorias para nuevas voces.</p>
                    <button type="button" class="podcast-cta-btn">
                        <i data-lucide="bell" aria-hidden="true"></i> Mantente atento
                    </button>
                </div>
            </aside>
        </div>
    </main>

    <?php $footerExtended = false; include __DIR__ . '/../inc/partials/footer.php'; ?>
    <?php include __DIR__ . '/../inc/partials/scripts.php'; ?>
    <!-- GSAP solo se carga aqui (no en scripts.php): unicamente esta pagina
         anima el scroll de las tarjetas de podcast. -->
    <script src="<?= asset_url('assets/js/vendor/gsap.min.js') ?>" data-page-script></script>
    <script src="<?= asset_url('assets/js/pages/podcast.js') ?>" data-page-script></script>
</body>
</html>
