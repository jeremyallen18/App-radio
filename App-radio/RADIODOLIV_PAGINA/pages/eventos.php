<?php
define('SITE_BASE_PATH', '../');
require_once __DIR__ . '/../inc/data/events.php';
require_once __DIR__ . '/../inc/helpers/html.php';

$activePage      = 'eventos';
$pageTitle       = 'Eventos | Radio Doliv';
$pageDescription = 'Cartelera de conciertos, shows y actividades especiales de Radio Doliv, con boletos oficiales.';
$pageStylesheet  = ['pages/eventos-base', 'pages/eventos-hero', 'pages/eventos-cartelera', 'pages/eventos-modal'];
$canonicalRelative = 'pages/eventos.php';

/* Toda la derivacion de datos ocurre en la capa de datos (ver
   get_events_for_display() en inc/data/events.php): la pagina recibe la lista
   ya ordenada y con 'index' + 'countdown' calculados. */
$events     = get_events_for_display();
$ticketLink = get_event_ticket_link();

$eventsJson = json_encode(array_map(fn($e) => [
    'title'       => $e['title'],
    'artist'      => $e['artist'],
    'location'    => $e['location'],
    'image'       => $e['image'],
    'weekday'     => $e['weekday'],
    'day'         => $e['day'],
    'month'       => $e['month'],
    'year'        => $e['year'],
    'time'        => $e['time'],
    'description' => $e['description'],
    'event_date'  => $e['event_date'],
], $events), JSON_UNESCAPED_UNICODE | JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_AMP | JSON_HEX_QUOT);

/* El escenario del capitulo 2 rota entre los primeros 5; cada cara cuesta una
   imagen grande en eager, y mas de cinco nadie las ve pasar. */
$stageEvents = array_slice($events, 0, 5);
$nextEvent   = $events[0] ?? null;

$imgBase = SITE_BASE_PATH;
$whatsappOrganizer = 'https://wa.me/5217131205259?text=' . rawurlencode('Hola, quiero registrar un evento en la cartelera de Radio Doliv');
?>
<!DOCTYPE html>
<html lang="es" data-page="<?= $activePage ?? '' ?>">
<?php include __DIR__ . '/../inc/partials/head.php'; ?>
<body data-site-base="<?= h(site_root_url()) ?>">
    <?php include __DIR__ . '/../inc/partials/navbar.php'; ?>

    <?php /* ============================================================
         Estructura de CAPITULOS a pantalla completa, no de bandas de
         color con tarjetas: mismo patron que pages/conocenos.php, donde
         cada seccion ocupa un viewport y el titulo es el protagonista.
         El fondo es el continuo del sitio mas la capa ambiental de
         eventos.js (luces de escenario tenidas con el color del cartel
         que se este mirando).
         ============================================================ */ ?>
    <main class="ev-main">
        <script type="application/json" id="events-data"><?= $eventsJson ?></script>
        <script type="application/json" id="event-ticket-link-data"><?= json_encode($ticketLink, JSON_UNESCAPED_SLASHES) ?></script>

        <!-- ============================================
             CAPITULO 1 — Portada. Solo tipografia.
             ============================================ -->
        <section class="ev-chapter ev-chapter--cover" aria-label="Cartelera">
            <div class="ev-chapter-inner ev-cover">
                <span class="ev-badge" data-reveal-item data-reveal-type="fade" style="--row: 0">Cartelera Radio Doliv</span>
                <h1 class="ev-cover-title" data-reveal-item data-reveal-type="text" style="--row: 1">
                    <span class="ev-reveal-sweep">Vive los <span class="ev-gradient">próximos eventos</span></span>
                </h1>
                <p class="ev-cover-lead" data-reveal-item data-reveal-type="up" style="--row: 2">
                    Conciertos, shows y actividades especiales de la región, con boletos
                    100&nbsp;% oficiales y fechas confirmadas en un solo lugar.
                </p>

                <?php if ($nextEvent): ?>
                <?php /* Dato vivo en la portada: quien es el proximo, sin abrir
                         una caja para decirlo. */ ?>
                <p class="ev-cover-next" data-reveal-item data-reveal-type="fade" style="--row: 3">
                    <span class="pulse-dot" aria-hidden="true"></span>
                    Lo próximo &mdash;
                    <a href="#ev-escenario"><?= h($nextEvent['title']) ?></a>
                    <em><?= h($nextEvent['countdown']['label']) ?></em>
                </p>
                <?php endif; ?>
            </div>

            <a class="ev-scroll-cue" href="#ev-escenario" aria-label="Ir al próximo evento">
                <span></span>
            </a>
        </section>

        <?php if ($stageEvents): ?>
        <!-- ============================================
             CAPITULO 2 — Escenario. El cartel a tamano real (son
             cuadrados, 1080x1080) junto a la cuenta regresiva escrita
             como tipografia, no como celdas de un widget.
             ============================================ -->
        <section class="ev-chapter ev-chapter--stage" id="ev-escenario" aria-label="Próximo evento">
            <div class="ev-chapter-inner ev-stage-grid">
                <div class="ev-stage-copy" data-reveal-item style="--row: 0">
                    <p class="ev-kicker" data-stage-kicker>Próximo evento</p>

                    <?php /* Solo la cara activa esta en el flujo; el JS alterna
                             .is-active y el resto queda inerte. */ ?>
                    <div class="ev-stage-titles">
                        <?php foreach ($stageEvents as $slideNumber => $stageEvent): ?>
                        <div class="ev-stage-title-slot<?= $slideNumber === 0 ? ' is-active' : '' ?>"
                             data-stage-slot="<?= (int) $slideNumber ?>"
                             <?= $slideNumber === 0 ? '' : 'inert' ?>>
                            <h2 class="ev-stage-title"><?= h($stageEvent['title']) ?></h2>
                            <p class="ev-stage-where">
                                <?= h($stageEvent['location']) ?><span aria-hidden="true"> / </span><?= h($stageEvent['time']) ?>
                            </p>
                        </div>
                        <?php endforeach; ?>
                    </div>

                    <?php /* Cuenta regresiva tipografica: numeros enormes
                             separados por lineas finas, sin celdas ni cajas. */ ?>
                    <div class="ev-count" id="evCount" role="timer">
                        <span class="ev-count-unit"><b data-clock="d">--</b><small>días</small></span>
                        <span class="ev-count-unit"><b data-clock="h">--</b><small>horas</small></span>
                        <span class="ev-count-unit"><b data-clock="m">--</b><small>min</small></span>
                        <span class="ev-count-unit"><b data-clock="s">--</b><small>seg</small></span>
                        <span class="ev-count-tbd">Fecha por confirmar</span>
                    </div>

                    <div class="ev-stage-actions">
                        <a class="ev-link ev-link--strong" href="<?= h($ticketLink) ?>" target="_blank" rel="noopener" data-magnetic data-ripple>
                            Comprar boletos<i data-lucide="arrow-up-right" aria-hidden="true"></i>
                        </a>
                        <button type="button" class="ev-link" id="evStageDetail">
                            Ver detalle<i data-lucide="plus" aria-hidden="true"></i>
                        </button>
                    </div>
                </div>

                <div class="ev-stage-visual" data-reveal-item data-reveal-type="zoom" style="--row: 1">
                    <div class="ev-posters" id="evPosters">
                        <?php foreach ($stageEvents as $slideNumber => $stageEvent): ?>
                            <?php $isFirst = $slideNumber === 0; ?>
                        <?php /* eager en todas: son las caras del escenario y con
                                 loading lazy la entrante llegaria vacia al primer
                                 cambio. Solo la primera es prioritaria. */ ?>
                        <figure class="ev-poster<?= $isFirst ? ' is-active' : '' ?>"
                                data-event-index="<?= (int) $stageEvent['index'] ?>"
                                data-poster-slot="<?= (int) $slideNumber ?>">
                            <img src="<?= h($imgBase . $stageEvent['image']) ?>"
                                 alt="Cartel de <?= h($stageEvent['title']) ?>"
                                 loading="eager"
                                 <?= $isFirst ? 'fetchpriority="high"' : 'fetchpriority="low"' ?>>
                            <?php if ($stageEvent['countdown']['urgent']): ?>
                            <figcaption class="ev-poster-flag"><?= h($stageEvent['countdown']['label']) ?></figcaption>
                            <?php endif; ?>
                        </figure>
                        <?php endforeach; ?>
                    </div>

                    <?php if (count($stageEvents) > 1): ?>
                    <div class="ev-stage-nav">
                        <button type="button" class="ev-stage-arrow" id="evStagePrev" aria-label="Evento anterior">
                            <i data-lucide="arrow-left" aria-hidden="true"></i>
                        </button>
                        <span class="ev-stage-counter">
                            <b id="evStageCurrent">01</b><span aria-hidden="true"> / </span><span><?= str_pad((string) count($stageEvents), 2, '0', STR_PAD_LEFT) ?></span>
                        </span>
                        <button type="button" class="ev-stage-arrow" id="evStageNext" aria-label="Evento siguiente">
                            <i data-lucide="arrow-right" aria-hidden="true"></i>
                        </button>
                    </div>
                    <?php endif; ?>
                </div>
            </div>
        </section>
        <?php endif; ?>

        <!-- ============================================
             CAPITULO 3 — Cartelera completa como indice editorial:
             filas numeradas separadas por lineas finas, con el cartel
             en un visor que sigue al cursor (ver .ev-peek).
             ============================================ -->
        <section class="ev-chapter ev-chapter--index" id="ev-cartelera" aria-label="Cartelera completa">
            <div class="ev-chapter-inner">
                <header class="ev-index-head">
                    <h2 class="ev-section-title" data-reveal-item data-reveal-type="text"><span class="ev-reveal-sweep">Cartelera<br><span class="ev-gradient">completa</span></span></h2>

                    <?php if ($events): ?>
                    <?php /* Filtros como enlaces de texto con un subrayado que
                             se desliza a la pestana activa, no como pildoras. */ ?>
                    <div class="ev-filters" role="tablist" aria-label="Filtrar cartelera por fecha">
                        <span class="ev-filters-ink" id="evFiltersInk" aria-hidden="true"></span>
                        <button type="button" class="ev-filter is-active" data-ev-filter="all" role="tab" aria-selected="true">
                            Todos<sup><?= count($events) ?></sup>
                        </button>
                        <button type="button" class="ev-filter" data-ev-filter="week" role="tab" aria-selected="false">Esta semana</button>
                        <button type="button" class="ev-filter" data-ev-filter="month" role="tab" aria-selected="false">Este mes</button>
                        <button type="button" class="ev-filter" data-ev-filter="tbd" role="tab" aria-selected="false">Por confirmar</button>
                    </div>
                    <?php endif; ?>
                </header>

                <?php if ($events): ?>
                <div class="ev-index" id="evIndex" data-reveal>
                    <?php foreach ($events as $rowNumber => $event): ?>
                        <?php $rowNumber = $rowNumber + 1; ?>
                        <?php include __DIR__ . '/../inc/components/event-row.php'; ?>
                    <?php endforeach; ?>
                </div>
                <p class="ev-note" id="evFilterEmpty" role="status" hidden>No hay eventos en ese rango.</p>
                <?php else: ?>
                <p class="ev-note">Aún no hay eventos activos. Vuelve pronto.</p>
                <?php endif; ?>
            </div>

            <?php /* Visor flotante del cartel: lo posiciona el cursor desde
                     eventos.js. Solo se activa con puntero fino. */ ?>
            <div class="ev-peek" id="evPeek" aria-hidden="true">
                <img id="evPeekImage" src="" alt="">
            </div>
        </section>

        <!-- ============================================
             CAPITULO 4 — Cierre. Tipografia grande y un enlace, sin caja.
             ============================================ -->
        <section class="ev-chapter ev-chapter--close" aria-label="Registra tu evento">
            <div class="ev-chapter-inner ev-close">
                <p class="ev-kicker" data-reveal-item data-reveal-type="fade" style="--row: 0">Para organizadores</p>
                <h2 class="ev-section-title" data-reveal-item data-reveal-type="text" style="--row: 1">
                    <span class="ev-reveal-sweep">¿Tienes un evento?<br><span class="ev-gradient">Lo ponemos al aire.</span></span>
                </h2>
                <p class="ev-close-lead" data-reveal-item data-reveal-type="up" style="--row: 2">
                    Súmalo a la cartelera de Radio Doliv y llega a toda nuestra audiencia.
                    Escríbenos y te ayudamos a promocionarlo.
                </p>
                <a class="ev-link ev-link--strong ev-link--xl" data-reveal-item data-reveal-type="zoom" style="--row: 3"
                   href="<?= h($whatsappOrganizer) ?>" target="_blank" rel="noopener" data-magnetic data-ripple>
                    Registrar mi evento<i data-lucide="arrow-up-right" aria-hidden="true"></i>
                </a>

                <ul class="ev-close-trust" data-reveal-item data-reveal-type="fade" style="--row: 4">
                    <li>Boletos 100&nbsp;% oficiales &mdash; Guru Shows</li>
                    <li>Nuevas fechas cada mes</li>
                </ul>
            </div>
        </section>
    </main>

    <!-- ============================================
         MODAL DE DETALLE — ver assets/js/pages/eventos.js.
         ============================================ -->
    <div class="ev-modal" id="event-detail-modal" aria-hidden="true" data-page-content>
        <div class="ev-modal-card" role="dialog" aria-modal="true" aria-labelledby="event-detail-title">
            <button type="button" class="ev-modal-close" aria-label="Cerrar detalle del evento">
                <i data-lucide="x" aria-hidden="true"></i>
            </button>
            <div class="ev-modal-poster">
                <img id="event-detail-image" src="" alt="">
            </div>
            <div class="ev-modal-body">
                <p class="ev-modal-when" id="event-detail-when"></p>
                <h2 class="ev-modal-title" id="event-detail-title"></h2>
                <p class="ev-modal-artist" id="event-detail-artist"></p>

                <dl class="ev-modal-facts">
                    <div>
                        <dt>Lugar</dt>
                        <dd id="event-detail-location"></dd>
                    </div>
                    <div>
                        <dt>Horario</dt>
                        <dd id="event-detail-schedule"></dd>
                    </div>
                </dl>

                <p class="ev-modal-description" id="event-detail-description"></p>

                <div class="ev-modal-actions">
                    <a href="#" id="event-ticket-link" class="ev-link ev-link--strong" target="_blank" rel="noopener" data-ripple>
                        Comprar boletos<i data-lucide="arrow-up-right" aria-hidden="true"></i>
                    </a>
                    <button type="button" class="ev-link" id="event-copy-link">
                        <span data-copy-label>Copiar enlace</span><i data-lucide="link" aria-hidden="true"></i>
                    </button>
                </div>
            </div>
        </div>
    </div>

    <?php $footerExtended = false; include __DIR__ . '/../inc/partials/footer.php'; ?>
    <?php include __DIR__ . '/../inc/partials/scripts.php'; ?>
    <script src="<?= asset_url('assets/js/pages/eventos.js') ?>" data-page-script></script>
</body>
</html>
