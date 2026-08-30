<?php
define('SITE_BASE_PATH', '../');
require_once __DIR__ . '/../inc/data/team.php';

$activePage      = 'equipo';
$pageTitle       = 'Equipo | Radio Doliv';
$pageDescription = 'Conoce a las personas detrás de Radio Doliv.';
$pageStylesheet  = ['pages/equipo-hero', 'pages/equipo-roster', 'pages/equipo-modal'];
$canonicalRelative = 'pages/equipo.php';

$team = get_team();
$teamJson = json_encode($team, JSON_UNESCAPED_UNICODE | JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_AMP | JSON_HEX_QUOT);
$locutoresCount = count(array_filter($team, fn(array $member) => $member['category'] === 'locutores'));
$reporterosCount = count(array_filter($team, fn(array $member) => $member['category'] === 'reporteros'));

// Enlace directo "Conóceme": la foto del locutor al aire (home-player en
// index.php) enlaza aqui con ?locutor=slug para abrir su ficha
// automaticamente, sin obligar al oyente a buscarlo en el carrete.
$initialLocutorSlug = isset($_GET['locutor']) ? preg_replace('/[^a-z0-9\-]/', '', strtolower((string) $_GET['locutor'])) : '';
?>
<!DOCTYPE html>
<html lang="es" data-page="<?= $activePage ?? '' ?>">
<?php include __DIR__ . '/../inc/partials/head.php'; ?>
<body data-site-base="<?= h(site_root_url()) ?>">
    <?php include __DIR__ . '/../inc/partials/navbar.php'; ?>

    <div class="team-scroll-progress" aria-hidden="true" data-page-content><span class="team-scroll-progress-bar" id="team-scroll-progress-bar"></span></div>

    <main>
        <!-- ============================================================
             Arquitectura del Equipo v7: "banda editorial" -- portado de
             una referencia de diseño con banda de color solido a todo el
             ancho ("Conoce al equipo") y un panel elevado debajo con la
             grilla de integrantes, superpuesto a la banda. Adaptado a la
             paleta de marca del sitio (cyan/azul sobre navy) en vez del
             amarillo del original. Cada tarjeta es foto en blanco y negro
             (a color al pasar el mouse) + nombre + rol en el color de
             acento del integrante + bio corta + CTA a la ficha completa
             (el mismo modal de siempre, ver equipo-modal.css/equipo.js).
             ============================================================ -->
        <section class="team-hero-band" data-reveal>
            <div class="team-hero-inner">
                <p class="roster-kicker">Voces Radio Doliv</p>
                <h1>Conoce al equipo</h1>
                <div class="team-toggle" role="tablist" aria-label="Filtrar equipo por categoría">
                    <button type="button" class="team-toggle-option is-active" data-filter="locutores" role="tab" aria-selected="true">Locutores</button>
                    <span class="team-toggle-sep" aria-hidden="true">/</span>
                    <button type="button" class="team-toggle-option" data-filter="reporteros" role="tab" aria-selected="false">Reporteros</button>
                </div>
            </div>
        </section>

        <div class="team-panel">
            <div class="team-grid" id="team-reel"></div>
        </div>
    </main>

    <!-- Ficha del integrante: un unico dialogo persistente en el DOM (nunca
         se destruye entre categorias), solo se repinta su contenido -- ver
         showMember() en pages/equipo.js. -->
    <div class="roster-modal" id="roster-modal" aria-hidden="true" data-page-content>
        <div class="roster-modal-overlay" data-close-roster="true"></div>
        <article class="roster-modal-card" role="dialog" aria-modal="true" aria-labelledby="roster-modal-name">
            <!-- Columna de retrato: ocupa toda la altura y repite el recorte
                 diagonal de los spreads del carrete, para que la ficha se
                 lea como una continuacion de la pagina y no como un dialogo
                 generico pegado encima. -->
            <div class="roster-modal-photo">
                <img id="roster-modal-img" src="" alt="">
                <span class="roster-modal-photo-tag" aria-hidden="true">Ficha</span>
                <div class="roster-photo-controls" aria-label="Controles de zoom de fotografía">
                    <button type="button" id="roster-zoom-out" aria-label="Alejar fotografía"><i data-lucide="zoom-out"></i></button>
                    <button type="button" id="roster-zoom-reset" aria-label="Restablecer fotografía"><i data-lucide="maximize"></i></button>
                    <button type="button" id="roster-zoom-in" aria-label="Acercar fotografía"><i data-lucide="zoom-in"></i></button>
                </div>
            </div>

            <div class="roster-modal-scroll">
                <button class="roster-modal-close" id="roster-modal-close" type="button" aria-label="Cerrar ficha">
                    <span>Cerrar</span><i data-lucide="x"></i>
                </button>

                <header class="roster-modal-head">
                    <p class="roster-modal-role" id="roster-modal-role"></p>
                    <h2 id="roster-modal-name">Integrante</h2>
                </header>

                <section class="roster-modal-section">
                    <p class="roster-modal-section-num" aria-hidden="true">01</p>
                    <div class="roster-modal-section-body">
                        <h3>Biografía</h3>
                        <div id="roster-modal-bio"></div>
                    </div>
                </section>

                <section class="roster-modal-section">
                    <p class="roster-modal-section-num" aria-hidden="true">02</p>
                    <div class="roster-modal-section-body">
                        <h3>Trayectoria</h3>
                        <ul id="roster-modal-path" class="roster-modal-list"></ul>
                    </div>
                </section>

                <section class="roster-modal-section">
                    <p class="roster-modal-section-num" aria-hidden="true">03</p>
                    <div class="roster-modal-section-body">
                        <h3>Intereses</h3>
                        <ul id="roster-modal-interests" class="roster-modal-chips"></ul>
                    </div>
                </section>
            </div>
        </article>
    </div>

    <?php $footerExtended = false; include __DIR__ . '/../inc/partials/footer.php'; ?>
    <?php include __DIR__ . '/../inc/partials/scripts.php'; ?>
    <script type="application/json" id="team-data" data-page-content><?= $teamJson ?: '[]' ?></script>
    <script type="application/json" id="initial-locutor-data" data-page-content><?= json_encode($initialLocutorSlug, JSON_UNESCAPED_UNICODE) ?></script>
    <script src="<?= asset_url('assets/js/pages/equipo.js') ?>" data-page-script></script>
</body>
</html>
