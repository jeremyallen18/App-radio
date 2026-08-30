<?php
define('SITE_BASE_PATH', '../');
require_once __DIR__ . '/../inc/data/services.php';

$activePage      = 'servicios';
$pageTitle       = 'Servicios | Radio Doliv';
$pageDescription = 'Publicidad, contenido, transmisiones, redes, podcast y activaciones para negocios y proyectos.';
$pageStylesheet  = ['pages/servicios-hero', 'pages/servicios-cards'];
$canonicalRelative = 'pages/servicios.php';

// Servicios agrupados por categoria (ver inc/data/services.php) para que la
// pagina cuente una historia por bloque tematico en vez de una sola rejilla
// plana de 10 tarjetas identicas.
$serviceGroups = get_services_by_category();
$categoryMeta = [
    'Contenido y transmisión'  => ['icon' => 'clapperboard', 'summary' => 'Todo lo que se produce, se graba o se transmite desde la cabina.'],
    'Para tu negocio'          => ['icon' => 'trending-up', 'summary' => 'Campañas y paquetes pensados para posicionar tu marca.'],
    'Presencia y activaciones' => ['icon' => 'sparkles', 'summary' => 'Momentos en vivo que conectan con la comunidad cara a cara.'],
];

// Convierte cada nombre de categoria en un id de seccion estable (ej.
// "Para tu negocio" -> "cat-para-tu-negocio"), usado tanto por el nav de
// pildoras de abajo como por el id real de cada <section>.
function services_category_id(string $categoryName): string {
    $slug = strtolower(trim($categoryName));
    $slug = preg_replace('/[^a-z0-9]+/u', '-', $slug);
    return 'cat-' . trim($slug, '-');
}
?>
<!DOCTYPE html>
<html lang="es" data-page="<?= $activePage ?? '' ?>">
<?php include __DIR__ . '/../inc/partials/head.php'; ?>
<body data-site-base="<?= h(site_root_url()) ?>">
    <?php include __DIR__ . '/../inc/partials/navbar.php'; ?>

    <main class="services-main">
        <section class="services-hero">
            <p class="services-kicker">Servicios Radio Doliv</p>
            <h1>Impulsamos tu marca con estrategia, contenido y sonido</h1>
            <p>
                Conoce nuestras soluciones para negocios, emprendedores, artistas y proyectos que quieren crecer con presencia digital y alcance real.
            </p>
        </section>

        <?php if (count($serviceGroups) > 1): ?>
        <!-- ============================================
             NAV DE CATEGORIAS — pildoras que saltan a cada
             bloque tematico y se marcan solas segun la seccion
             visible (scroll-spy), al estilo del selector de
             unidades de negocio de grupoexpansion.com.
             ============================================ -->
        <nav class="services-catnav" aria-label="Ir a una categoria de servicios">
            <a href="#services-top" class="services-catnav-pill is-active" data-catnav-target="services-top">
                <i data-lucide="layout-grid"></i> Todo
            </a>
            <?php foreach ($serviceGroups as $categoryName => $categoryServices): ?>
                <?php $meta = $categoryMeta[$categoryName] ?? ['icon' => 'star', 'summary' => '']; ?>
                <a href="#<?= h(services_category_id($categoryName)) ?>" class="services-catnav-pill" data-catnav-target="<?= h(services_category_id($categoryName)) ?>">
                    <i data-lucide="<?= h($meta['icon']) ?>"></i> <?= h($categoryName) ?>
                    <span class="services-catnav-count"><?= count($categoryServices) ?></span>
                </a>
            <?php endforeach; ?>
        </nav>
        <?php endif; ?>

        <span id="services-top" class="services-anchor" aria-hidden="true"></span>

        <?php $catIndex = 0; ?>
        <?php foreach ($serviceGroups as $categoryName => $categoryServices): ?>
            <?php
                $meta = $categoryMeta[$categoryName] ?? ['icon' => 'star', 'summary' => ''];
                $isReverse = ($catIndex % 2 === 1);
                $featured = $categoryServices[0] ?? null;
            ?>
            <section class="services-category<?= $isReverse ? ' services-category--reverse' : '' ?>" id="<?= h(services_category_id($categoryName)) ?>" data-reveal>
                <?php if ($featured): ?>
                <div class="services-category-visual">
                    <div class="services-category-visual-frame">
                        <img src="<?= h(SITE_BASE_PATH . $featured['image']) ?>" alt="<?= h($featured['title']) ?>" loading="lazy">
                    </div>
                    <span class="services-category-badge"><i data-lucide="<?= h($meta['icon']) ?>"></i></span>
                </div>
                <?php endif; ?>
                <div class="services-category-content">
                    <span class="services-category-ghost-num" aria-hidden="true"><?= sprintf('%02d', $catIndex + 1) ?></span>
                    <span class="services-category-eyebrow"><i data-lucide="<?= h($meta['icon']) ?>"></i> <?= h($categoryName) ?></span>
                    <h2><?= h($categoryName) ?></h2>
                    <?php if ($meta['summary'] !== ''): ?>
                    <p class="services-category-summary"><?= h($meta['summary']) ?></p>
                    <?php endif; ?>
                    <ol class="services-list">
                        <?php foreach ($categoryServices as $serviceIndex => $service): ?>
                        <li class="services-list-item" data-stagger="<?= (int) $serviceIndex ?>">
                            <span class="services-list-num"><?= sprintf('%02d', $serviceIndex + 1) ?></span>
                            <div class="services-list-body">
                                <h3><?= h($service['title']) ?></h3>
                                <p><?= h($service['description']) ?></p>
                            </div>
                            <a class="services-list-cta" href="<?= h($service['whatsapp_url']) ?>" target="_blank" rel="noopener noreferrer" aria-label="Cotizar &quot;<?= h($service['title']) ?>&quot; por WhatsApp" data-ripple>
                                <i data-lucide="message-circle"></i>
                            </a>
                        </li>
                        <?php endforeach; ?>
                    </ol>
                </div>
            </section>
            <?php $catIndex++; ?>
        <?php endforeach; ?>
    </main>

    <?php $footerExtended = false; include __DIR__ . '/../inc/partials/footer.php'; ?>
    <?php include __DIR__ . '/../inc/partials/scripts.php'; ?>
    <script src="<?= asset_url('assets/js/pages/servicios.js') ?>" data-page-script></script>
</body>
</html>
