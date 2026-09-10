<?php
require_once __DIR__ . '/../helpers/html.php';
// Variables esperadas del controlador: $activePage (slug: 'inicio','conocenos',
// 'servicios','programas','podcast','anuncios','eventos','equipo','seccionazul').
// OJO: usa site_root_url() (absoluta, "/RADIODOLIV_PAGINA/"), NO
// SITE_BASE_PATH (relativa al directorio del script, '' / '../') -- el
// navbar no se vuelve a pintar en cada navegacion AJAX (ver
// core/page-router.js), asi que sus enlaces deben seguir apuntando al
// lugar correcto sin importar desde que URL este viendo el visitante en
// ese momento.
$base = site_root_url();
$isActive = fn(string $slug) => ($activePage ?? '') === $slug ? ' class="active"' : '';
?>
<nav class="nav-glass" id="siteNavbar">
    <?php if (($activePage ?? '') === 'inicio'): ?>
    <div class="nav-ribbon" aria-hidden="true">
        <span class="nav-ribbon-badge">On air</span>
        Radio Doliv &mdash; transmisión en vivo 24 horas
    </div>
    <?php endif; ?>
    <div class="nav-container">
        <a class="logo" href="<?= h($base) ?>index.php" aria-label="Ir al inicio de Radio Doliv">
            <img src="<?= h($base) ?>assets/img/logo/radiologo.svg" alt="Radio Doliv" class="logo-img">
        </a>

        <ul class="nav-links">
            <li><a href="<?= h($base) ?>index.php" data-page-link="inicio"<?= $isActive('inicio') ?>>Inicio</a></li>
            <li><a href="<?= h($base) ?>pages/conocenos.php" data-page-link="conocenos"<?= $isActive('conocenos') ?>>Conócenos</a></li>
            <li><a href="<?= h($base) ?>pages/servicios.php" data-page-link="servicios"<?= $isActive('servicios') ?>>Servicios</a></li>
            <li><a href="<?= h($base) ?>pages/programas.php" data-page-link="programas"<?= $isActive('programas') ?>>Programas</a></li>
            <li><a href="<?= h($base) ?>pages/podcast.php" data-page-link="podcast"<?= $isActive('podcast') ?>>Podcast</a></li>
            <li><a href="<?= h($base) ?>pages/anuncios.php" data-page-link="anuncios"<?= $isActive('anuncios') ?>>Anuncios</a></li>
            <li><a href="<?= h($base) ?>pages/eventos.php" data-page-link="eventos"<?= $isActive('eventos') ?>>Eventos</a></li>
            <li><a href="<?= h($base) ?>pages/equipo.php" data-page-link="equipo"<?= $isActive('equipo') ?>>Equipo</a></li>
            <li><a href="<?= h($base) ?>pages/seccionazul.php" data-page-link="seccionazul"<?= $isActive('seccionazul') ?>>Sección azul</a></li>
        </ul>

        <div class="nav-actions">
            <div class="search-container">
                <i data-lucide="search" class="search-icon"></i>
                <input type="text" placeholder="Buscar..." class="search-input" aria-label="Buscar en Radio Doliv">
            </div>

            <button class="theme-toggle" id="theme-toggle" aria-label="Cambiar tema" aria-pressed="false">
                <i data-lucide="sun" id="theme-icon"></i>
            </button>
        </div>
    </div>
</nav>
