<?php
require_once __DIR__ . '/../helpers/html.php';

// =========================================================
// inc/partials/mobile-dock.php
// "Dock" persistente SOLO para movil (<=768px): mini-reproductor +
// barra inferior de 5 pestanas. Se incluye desde inc/partials/footer.php
// para que quede fuera de <main> y sobreviva a la navegacion AJAX
// (ver core/page-router.js). Todo su CSS vive en
// assets/css/components/mobile-dock.css bajo @media (max-width: 768px):
// en escritorio el marcado se renderiza pero queda display:none.
//
// Enlaces: usan site_root_url() (absoluta) como el navbar/footer,
// porque este bloque tampoco se vuelve a pintar en cada navegacion.
// El estado "activo" de cada pestana se resuelve por CSS contra
// <html data-page="..."> (que el router SI actualiza en cada swap),
// asi que no necesita JS. Ver mobile-dock.css.
// =========================================================

$base = site_root_url();

// Icono de cada pestana como SVG en linea (trazo, rejilla 24, estilo
// unico) -- no via Lucide para no depender de su tiempo de carga ni de
// un repaint tras la navegacion AJAX.
$dockTabs = [
    'inicio' => [
        'label' => 'Inicio',
        'href'  => $base . 'index.php',
        'icon'  => '<path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.5V21h14V9.5"/>',
    ],
    'programas' => [
        'label' => 'Programas',
        'href'  => $base . 'pages/programas.php',
        'icon'  => '<rect x="3" y="4.5" width="18" height="17" rx="2"/><path d="M3 9.5h18M8 3v4M16 3v4"/>',
    ],
    'podcast' => [
        'label' => 'Podcast',
        'href'  => $base . 'pages/podcast.php',
        'icon'  => '<path d="M4 14v-2a8 8 0 0 1 16 0v2"/><rect x="2.5" y="14" width="4.5" height="7" rx="1.6"/><rect x="17" y="14" width="4.5" height="7" rx="1.6"/>',
    ],
    'eventos' => [
        'label' => 'Eventos',
        'href'  => $base . 'pages/eventos.php',
        'icon'  => '<path d="M3 8a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2 2 2 0 0 0 0 4 2 2 0 0 1-2 2H5a2 2 0 0 1-2-2 2 2 0 0 0 0-4Z"/><path d="M15 6.5v11"/>',
    ],
    'equipo' => [
        'label' => 'Equipo',
        'href'  => $base . 'pages/equipo.php',
        'icon'  => '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6"/><path d="M16.5 5.2A3.5 3.5 0 0 1 16.5 12M21.5 20c0-3-1.8-5.2-4.3-5.9"/>',
    ],
];
?>
<div class="mobile-dock" id="mobileDock" aria-label="Reproductor y navegación de Radio Doliv">
    <div class="mobile-dock-player">
        <span class="mobile-dock-art" aria-hidden="true">
            <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="2.5" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21M8.5 21h7"/></svg>
        </span>
        <span class="mobile-dock-meta">
            <span class="mobile-dock-title">Radio Doliv <span class="mobile-dock-live"><span class="pulse-dot" aria-hidden="true"></span> EN VIVO</span></span>
            <span class="mobile-dock-status" id="mobileDockStatus">Toca para escuchar en vivo</span>
        </span>
        <button type="button" class="mobile-dock-play" id="mobileDockPlay" aria-label="Reproducir radio en vivo">
            <svg class="mobile-dock-ico-play" viewBox="0 0 24 24" width="20" height="20" fill="currentColor" aria-hidden="true"><path d="M7 4.5 19 12 7 19.5Z"/></svg>
            <svg class="mobile-dock-ico-pause" viewBox="0 0 24 24" width="20" height="20" fill="currentColor" aria-hidden="true"><rect x="6.5" y="5" width="4" height="14" rx="1"/><rect x="13.5" y="5" width="4" height="14" rx="1"/></svg>
        </button>
    </div>
    <nav class="mobile-dock-tabs" aria-label="Navegación principal">
        <?php foreach ($dockTabs as $slug => $tab): ?>
        <a class="mobile-dock-tab" data-tab="<?= h($slug) ?>" data-page-link="<?= h($slug) ?>" href="<?= h($tab['href']) ?>">
            <svg viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><?= $tab['icon'] ?></svg>
            <span><?= h($tab['label']) ?></span>
        </a>
        <?php endforeach; ?>
    </nav>
</div>
