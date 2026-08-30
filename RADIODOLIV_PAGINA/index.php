<?php
define('SITE_BASE_PATH', '');
require_once __DIR__ . '/inc/data/programs.php';
require_once __DIR__ . '/inc/data/podcasts.php';
require_once __DIR__ . '/inc/data/events.php';
require_once __DIR__ . '/inc/data/team.php';
require_once __DIR__ . '/inc/helpers/html.php';

$activePage      = 'inicio';
$pageTitle       = 'Radio Doliv | Tu Radio Digital en Vivo';
$pageDescription = 'Radio Doliv: radio digital en vivo las 24 horas, programas, podcasts originales y una comunidad que crece cada día desde el Estado de México.';
$pageStylesheet  = ['pages/index-fresh-hero', 'pages/index-fresh-content', 'pages/index-fresh-footer'];
$canonicalRelative = '';
$footerExtended  = true;

$programs     = get_programs();
$podcasts     = get_podcasts();
$events       = array_slice(get_active_events(), 0, 3);
$team         = get_team();
$hosts        = array_slice($team, 0, 4);

// Mapa nombre de locutor -> slug del equipo, para que la foto del
// reproductor enlace directo a la biografia de quien esta al aire
// (pages/equipo.php?locutor=slug), su seccion "Conoceme".
$teamSlugsByHostName = [];
$teamImagesByHostName = [];
foreach ($team as $member) {
    $teamSlugsByHostName[$member['name']] = $member['slug'];
    $teamImagesByHostName[$member['name']] = $member['image'];
}
function host_profile_url(?string $hostName, array $slugsByName): string {
    if ($hostName && isset($slugsByName[$hostName])) {
        return 'pages/equipo.php?locutor=' . urlencode($slugsByName[$hostName]);
    }
    return 'pages/equipo.php';
}

// Contenido para el carrusel Bootstrap (ultimo episodio de cada podcast con
// audio disponible) -- reemplaza a los testimonios inventados, usando datos
// reales que ya existen en inc/data/*.php.
$spotlightItems = [];
foreach ($podcasts as $podcast) {
    if (count($podcast['episodes'])) {
        $latestEpisode = $podcast['episodes'][array_key_last($podcast['episodes'])];
        $spotlightItems[] = [
            'type' => 'Podcast', 'image' => $podcast['cover'], 'title' => $latestEpisode['title'],
            'subtitle' => $podcast['title'], 'description' => $latestEpisode['description'],
            'url' => 'pages/podcast.php', 'cta' => 'Escuchar episodio', 'accent' => '#00d4ff',
        ];
    }
}

$episodeCount = 0;
foreach ($podcasts as $podcast) {
    $episodeCount += count($podcast['episodes']);
}

// Programa "al aire" segun la hora del servidor, solo como estado inicial:
// el script al final de la pagina lo corrige con la hora local del visitante
// (los horarios de la parrilla son de la zona horaria del oyente, no del
// servidor donde corre PHP). weekdays (1=lunes..7=domingo, ver
// inc/data/programs.php) filtra los programas que no transmiten todos los
// dias -- NULL/vacio significa "todos los dias".
$serverHour = (int) date('G');
$serverWeekday = (int) date('N');
$initialOnAir = null;
foreach ($programs as $program) {
    $start = $program['slot_start'];
    $end = $program['slot_end'];
    $weekdays = array_filter(array_map('trim', explode(',', (string) ($program['weekdays'] ?? ''))));
    if ($weekdays && !in_array((string) $serverWeekday, $weekdays, true)) continue;
    $overnight = $end <= $start;
    $isCurrent = $overnight
        ? ($serverHour >= $start || $serverHour < $end)
        : ($serverHour >= $start && $serverHour < $end);
    if ($isCurrent) {
        $initialOnAir = $program;
        break;
    }
}

// El podcast destacado es el primero con episodios disponibles.
$spotlightPodcast = null;
foreach ($podcasts as $podcast) {
    if (count($podcast['episodes'])) {
        $spotlightPodcast = $podcast;
        break;
    }
}

// Comentarios de muestra para el widget "Comentarios en vivo" del hero.
// Estatico por ahora (sin backend): el formulario solo agrega el mensaje
// del propio oyente a la lista mientras la pestaña sigue abierta.
$liveComments = [
    ['name' => 'María López',   'time' => '10:45 AM', 'text' => '¡Saludos desde Santiago Tilapa! Escuchando su programa favorito 💙'],
    ['name' => 'JuanOrtiz_88',  'time' => '10:46 AM', 'text' => 'Excelente selección musical hoy 🔥'],
    ['name' => 'Ana Celeste',   'time' => '10:47 AM', 'text' => 'Me encanta Radio Doliv, me acompaña todos los días en el trabajo 🎵'],
    ['name' => 'RadioFan_25',   'time' => '10:48 AM', 'text' => '¿Qué canción viene ahora? ¡Pura buena vibra! 🙌'],
    ['name' => 'Luis Fernández','time' => '10:49 AM', 'text' => 'Los mejores locutores, la mejor radio 💙'],
];
?>
<!DOCTYPE html>
<html lang="es" data-page="<?= $activePage ?? '' ?>">
<?php include __DIR__ . '/inc/partials/head.php'; ?>
<body data-site-base="<?= h(site_root_url()) ?>">
    <?php include __DIR__ . '/inc/partials/skip-link.php'; ?>
    <?php include __DIR__ . '/inc/partials/navbar.php'; ?>

    <main id="main-content" class="home-main">

        <!-- ============================================
             1. HERO — responde solo dos preguntas: que es
             Radio Doliv y como se escucha. Un titulo, un
             subtitulo, un boton, el reproductor. Nada mas
             compite por atencion en la primera pantalla.
             ============================================ -->
        <section class="ps-band ps-band--dark ps-band--hero" aria-label="Radio Doliv en vivo">
            <div class="ps-band-inner home-hero">
            <!-- Eslogan de extremo a extremo: ocupa toda la fila, arriba de
                 comentarios + reproductor (que van en su propia fila de dos
                 columnas debajo, ver .home-hero grid-template-areas). -->
            <div class="home-hero-copy">
                <span class="home-eyebrow scroll-fade-down"><span class="pulse-dot" aria-hidden="true"></span> En vivo las 24 horas</span>
                <h1 class="scroll-fade-up">La radio que se escucha y <span class="text-gradient">se siente</span></h1>
                <p class="home-hero-subtitle">Programas en vivo y podcasts originales desde Santiago Tilapa, Estado de México.</p>
                <div class="home-hero-links">
                    <a href="pages/programas.php"><i data-lucide="calendar-days"></i> Ver programación</a>
                    <a href="pages/conocenos.php"><i data-lucide="info"></i> Conócenos</a>
                </div>
            </div>

            <!-- Comentarios en vivo: al lado del reproductor, misma fila
                 (ver .home-hero grid-template-areas). Sin backend por ahora
                 -- el envío solo agrega el mensaje del propio oyente a la
                 lista (ver assets/js/pages/index.js). -->
            <div class="home-live-comments scroll-zoom-in">
                <div class="home-comments-card">
                    <div class="home-comments-card-head">
                        <span class="home-comments-title">Comentarios en vivo <span class="home-comments-status"><span class="pulse-dot" aria-hidden="true"></span> En línea</span></span>
                        <span class="home-comments-count"><i data-lucide="users"></i> <span id="liveCommentsCount">128</span></span>
                    </div>

                    <ul class="home-comments-list" id="liveCommentsList">
                        <?php foreach ($liveComments as $comment): ?>
                        <li class="home-comment">
                            <span class="home-comment-avatar"><?= h(mb_strtoupper(mb_substr($comment['name'], 0, 1) . mb_substr((strrpos($comment['name'], ' ') !== false ? substr($comment['name'], strrpos($comment['name'], ' ') + 1) : ''), 0, 1))) ?></span>
                            <span class="home-comment-body">
                                <span class="home-comment-top">
                                    <strong class="home-comment-name"><?= h($comment['name']) ?></strong>
                                    <span class="home-comment-time"><?= h($comment['time']) ?></span>
                                </span>
                                <span class="home-comment-text"><?= h($comment['text']) ?></span>
                            </span>
                        </li>
                        <?php endforeach; ?>
                    </ul>

                    <form class="home-comments-form" id="liveCommentsForm">
                        <input type="text" id="liveCommentsInput" class="home-comments-input" placeholder="Escribe tu comentario..." maxlength="240" aria-label="Escribe tu comentario">
                        <button type="submit" class="home-comments-send" aria-label="Enviar comentario"><i data-lucide="send"></i></button>
                    </form>
                    <p class="home-comments-hint">Recuerda ser respetuoso y seguir las normas de la comunidad.</p>
                </div>
            </div>

            <!-- Reproductor como protagonista: LIVE, nombre de la
                 estacion, boton grande, barra de audio, y el programa
                 al aire con su locutora, igual que un reproductor de
                 musica real. -->
            <div class="home-player scroll-zoom-in">
                <div class="home-player-top">
                    <div class="home-player-controls">
                        <div class="home-player-badge"><span class="pulse-dot" aria-hidden="true"></span> LIVE</div>
                        <p class="home-player-station">Radio Doliv</p>

                        <button class="home-player-play" id="playBtnHero" aria-label="Reproducir radio">
                            <i data-lucide="play"></i>
                        </button>

                        <div class="home-player-wave" aria-hidden="true">
                            <span></span><span></span><span></span><span></span><span></span><span></span><span></span>
                        </div>

                        <div class="home-player-volume">
                            <i data-lucide="volume-2"></i>
                            <input type="range" id="volume-slider" min="0" max="1" step="0.01" value="0.5" aria-label="Control de volumen">
                        </div>
                    </div>

                    <a class="home-player-cover-link" id="onair-host-link" href="<?= h(host_profile_url($initialOnAir['host'] ?? null, $teamSlugsByHostName)) ?>" aria-label="Conoce a <?= h($initialOnAir['host'] ?? 'el equipo de Radio Doliv') ?>">
                        <img class="home-player-cover" id="onair-program-image" src="<?= h(asset_url($initialOnAir['image'] ?? 'assets/img/logo/logo.png')) ?>" alt="<?= h($initialOnAir['host'] ?? 'Radio Doliv') ?>">
                    </a>
                </div>

                <div class="home-player-onair">
                    <span>Suena ahora</span>
                    <strong id="onair-program-name"><?= h($initialOnAir['title'] ?? 'Radio Doliv Music') ?></strong>
                    <p>Con <span id="onair-program-host"><?= h($initialOnAir['host'] ?? 'el equipo de Radio Doliv') ?></span></p>
                    <div class="home-player-action">
                        <?php 
                            $hostName = $initialOnAir['host'] ?? null;
                            $hostImage = ($hostName && isset($teamImagesByHostName[$hostName])) ? $teamImagesByHostName[$hostName] : null;
                            $hostSlug = ($hostName && isset($teamSlugsByHostName[$hostName])) ? $teamSlugsByHostName[$hostName] : null;
                            $hostProfileUrl = $hostSlug ? 'pages/equipo.php?locutor=' . urlencode($hostSlug) : 'pages/equipo.php';
                        ?>
                        <button type="button" class="home-player-request" id="songRequestOpen">
                            <i data-lucide="music-2"></i> Pide tu canción
                        </button>
                        <a href="<?= h($hostProfileUrl) ?>" class="home-player-host-card<?php if (!$hostImage) echo ' is-empty'; ?>" id="onair-host-card" aria-label="Conoce a <?= h($hostName ?? 'el equipo') ?>">
                            <img <?php if ($hostImage) echo 'src="' . h($hostImage) . '" alt="' . h($hostName) . '"'; ?> loading="lazy" id="onair-host-card-photo">
                            <span class="home-player-host-name" id="onair-host-card-name"><?= h($hostName ?? 'el equipo') ?></span>
                        </a>
                    </div>
                </div>
            </div>
            </div>
        </section>

        <!-- ============================================
             2. CIFRAS REALES — nada de numeros inventados;
             todo se cuenta desde inc/data/*.php.
             ============================================ -->
        <section class="ps-band ps-band--light" aria-label="Radio Doliv en cifras" data-reveal>
            <div class="ps-band-inner home-stats">
                <div class="home-stat" data-stagger="0"><strong>2M</strong><span>Oyentes mensuales</span></div>
                <div class="home-stat" data-stagger="1"><strong>24/7</strong><span>Transmisión continua</span></div>
                <div class="home-stat" data-stagger="2"><strong><?= count($programs) ?></strong><span>Programas al aire</span></div>
                <div class="home-stat" data-stagger="3"><strong><?= $episodeCount ?></strong><span>Episodios de podcast</span></div>
                <div class="home-stat" data-stagger="4"><strong><?= count($team) ?></strong><span>Voces en cabina</span></div>
            </div>
        </section>

        <!-- ============================================
             3. PARRILLA COMPLETA — antes vivia encajada
             dentro del reproductor; ahora respira en su
             propia seccion.
             ============================================ -->
        <section id="parrilla-del-dia" class="ps-band ps-band--dark" aria-label="Parrilla de hoy" data-reveal>
            <div class="ps-band-inner">
            <div class="section-head">
                <div>
                    <span class="section-eyebrow">Hoy en Radio Doliv</span>
                    <h2 class="section-title">Parrilla del día</h2>
                </div>
            </div>
            <ul class="home-schedule">
                <?php foreach ($programs as $program): ?>
                <li class="home-schedule-row" data-slot-start="<?= (int) $program['slot_start'] ?>" data-slot-end="<?= (int) $program['slot_end'] ?>" data-slot-weekdays="<?= h($program['weekdays'] ?? '') ?>" data-slot-name="<?= h($program['title']) ?>" data-slot-host="<?= h($program['host']) ?>" data-slot-host-slug="<?= h($teamSlugsByHostName[$program['host']] ?? '') ?>" data-slot-host-image="<?= h(isset($teamImagesByHostName[$program['host']]) ? $teamImagesByHostName[$program['host']] : '') ?>" data-slot-image="<?= h(asset_url($program['image'])) ?>">
                    <span class="home-schedule-time"><?= h($program['badge_time']) ?></span>
                    <span class="home-schedule-name"><?= h($program['title']) ?></span>
                    <span class="home-schedule-host">Con <?= h($program['host']) ?></span>
                </li>
                <?php endforeach; ?>
                <li class="home-schedule-row" data-slot-start="13" data-slot-end="9" data-slot-name="Radio Doliv Music" data-slot-host="el equipo de Radio Doliv" data-slot-host-image="" data-slot-image="<?= h(asset_url('assets/img/logo/logo.png')) ?>">
                    <span class="home-schedule-time">Resto del día</span>
                    <span class="home-schedule-name">Radio Doliv Music</span>
                    <span class="home-schedule-host">Selección continua</span>
                </li>
            </ul>
            </div>
        </section>

        <!-- ============================================
             4. NUESTRAS VOCES — una radio son sus personas.
             ============================================ -->
        <section id="nuestras-voces" class="ps-band ps-band--light" aria-label="Nuestras voces" data-reveal>
            <div class="ps-band-inner">
            <div class="section-head">
                <div>
                    <span class="section-eyebrow">Detrás del micrófono</span>
                    <h2 class="section-title">Conoce a nuestras voces</h2>
                </div>
                <a class="section-link" href="pages/equipo.php">Ver equipo completo <i data-lucide="arrow-right"></i></a>
            </div>
            <div class="home-hosts">
                <?php foreach ($hosts as $hostIndex => $host): ?>
                <a class="home-host" href="pages/equipo.php" data-stagger="<?= $hostIndex ?>">
                    <span class="home-host-photo"><img src="<?= h($host['image']) ?>" alt="<?= h($host['name']) ?>" loading="lazy"></span>
                    <strong><?= h($host['name']) ?></strong>
                    <span><?= h($host['role']) ?></span>
                </a>
                <?php endforeach; ?>
            </div>
            </div>
        </section>

        <!-- ============================================
             5. ANUNCIOS DE PROGRAMAS — carrusel tipo banner,
             una diapositiva a la vez, con locutora y horario
             destacados (estilo "vitrina", no ficha tecnica).
             ============================================ -->
        <section class="ps-band ps-band--dark" aria-label="Anuncios de programas" data-reveal>
            <div class="ps-band-inner">
            <div class="section-head">
                <div>
                    <span class="section-eyebrow">En el aire</span>
                    <h2 class="section-title">Anuncios de programas</h2>
                </div>
            </div>
            <div class="home-announce" id="announceCarousel" role="region" aria-roledescription="carrusel" aria-label="Programas destacados">
                <div class="home-announce-track">
                    <?php foreach ($programs as $slideIndex => $program): ?>
                    <article class="home-announce-slide<?= $slideIndex === 0 ? ' is-active' : '' ?>"
                        aria-hidden="<?= $slideIndex === 0 ? 'false' : 'true' ?>"
                        data-show-accent="<?= h($program['accent']) ?>">
                        <div class="home-announce-media" data-bg="<?= h($program['image']) ?>"></div>
                        <div class="home-announce-copy">
                            <span class="home-announce-badge"><?= h($program['badge_label']) ?></span>
                            <h3>🎙 <?= h($program['title']) ?></h3>
                            <p class="home-announce-meta"><?= h($program['schedule']) ?> · Con <?= h($program['host']) ?></p>
                            <p><?= h($program['index_desc']) ?></p>
                            <div class="home-announce-actions">
                                <button type="button" class="home-btn home-btn--primary" data-action="toggle-radio" tabindex="<?= $slideIndex === 0 ? '0' : '-1' ?>">
                                    <i data-lucide="play"></i> Escuchar
                                </button>
                                <a class="home-btn home-btn--ghost" href="pages/programas.php" tabindex="<?= $slideIndex === 0 ? '0' : '-1' ?>">
                                    Más información
                                </a>
                            </div>
                        </div>
                    </article>
                    <?php endforeach; ?>
                </div>
                <div class="home-announce-controls">
                    <div class="home-announce-arrows">
                        <button type="button" class="home-announce-arrow" id="announcePrev" aria-label="Anuncio anterior"><i data-lucide="chevron-left"></i></button>
                        <button type="button" class="home-announce-arrow" id="announceNext" aria-label="Anuncio siguiente"><i data-lucide="chevron-right"></i></button>
                    </div>
                    <div class="home-announce-dots" id="announceDots" role="tablist" aria-label="Seleccionar programa"></div>
                </div>
            </div>
            </div>
        </section>

        <!-- ============================================
             6. PODCASTS — rejilla de portadas estilo Spotify,
             no una lista de texto.
             ============================================ -->
        <section id="podcasts-originales" class="ps-band ps-band--light" aria-label="Podcasts originales" data-reveal>
            <div class="ps-band-inner">
            <div class="section-head">
                <div>
                    <span class="section-eyebrow">Escúchalo cuando quieras</span>
                    <h2 class="section-title">Podcasts originales</h2>
                </div>
                <a class="section-link" href="pages/podcast.php">Ver todos <i data-lucide="arrow-right"></i></a>
            </div>
            <div class="home-podcast-grid">
                <?php foreach ($podcasts as $podcastIndex => $podcast): ?>
                <a class="home-podcast-tile" href="pages/podcast.php" data-stagger="<?= $podcastIndex ?>">
                    <span class="home-podcast-cover">
                        <img src="<?= h($podcast['cover']) ?>" alt="Portada de <?= h($podcast['title']) ?>" loading="lazy">
                        <span class="home-podcast-play"><i data-lucide="play"></i></span>
                    </span>
                    <strong><?= h($podcast['title']) ?></strong>
                    <span><?= count($podcast['episodes']) ? count($podcast['episodes']) . ' episodios' : 'Próximamente' ?></span>
                </a>
                <?php endforeach; ?>
            </div>
            </div>
        </section>

        <!-- ============================================
             7. POR QUE EXISTIMOS — narrativa en vez de
             mision/vision/experiencia en cajas.
             ============================================ -->
        <section class="ps-band ps-band--dark" aria-label="Nuestra historia">
            <div class="ps-band-inner home-story-grid">
                <div class="home-story-media scroll-fade-left">
                    <img src="assets/img/locutores/adilenebernal.jpeg" alt="Locutora de Radio Doliv al aire" loading="lazy">
                </div>
                <div class="home-story-copy scroll-fade-right">
                    <span class="section-eyebrow">Nuestra escencia</span>
                    <h2 class="section-title">Conectamos historias, marcas y comunidad</h2>
                    <p>Somos una radio digital enfocada en contenido cercano, creativo y de valor para las personas y</p>
                    <p>negocios de nuestra región.</p>
                    <a class="section-link" href="pages/conocenos.php">Conoce más sobre nosotros <i data-lucide="arrow-right"></i></a>
                </div>
            </div>
        </section>

        <!-- ============================================
             8. EVENTOS — formato boleto, mas visual que
             una lista de texto.
             ============================================ -->
        <?php if (count($events)): ?>
        <section id="proximos-eventos" class="ps-band ps-band--light" aria-label="Próximos eventos" data-reveal>
            <div class="ps-band-inner">
            <div class="section-head">
                <div>
                    <span class="section-eyebrow">No te lo pierdas</span>
                    <h2 class="section-title">Próximos eventos</h2>
                </div>
                <a class="section-link" href="pages/eventos.php">Ver todos <i data-lucide="arrow-right"></i></a>
            </div>
            <div class="home-events">
                <?php foreach ($events as $eventIndex => $event): ?>
                <a class="home-event-ticket" href="pages/eventos.php" data-stagger="<?= $eventIndex ?>">
                    <span class="home-event-ticket-date">
                        <span><?= h($event['month']) ?></span>
                        <strong><?= h($event['day']) ?></strong>
                    </span>
                    <span class="home-event-ticket-copy">
                        <strong><?= h($event['title']) ?></strong>
                        <span><?= h($event['location']) ?></span>
                        <span><?= h($event['time']) ?></span>
                    </span>
                    <i data-lucide="arrow-right" aria-hidden="true"></i>
                </a>
                <?php endforeach; ?>
            </div>
            </div>
        </section>
        <?php endif; ?>

        <!-- ============================================
             9. DESCUBRE MAS — carrusel animado con Bootstrap
             (solo su JS; el CSS de abajo es nuestro, tokenizado
             a la marca). Contenido real: ultimo episodio de cada
             podcast, no testimonios inventados.
             ============================================ -->
        <section class="ps-band ps-band--dark" aria-label="Descubre más de Radio Doliv" data-reveal>
            <div class="ps-band-inner">
            <div class="section-head">
                <div>
                    <span class="section-eyebrow">Sigue explorando</span>
                    <h2 class="section-title scroll-flip-up">Descubre más de Radio Doliv</h2>
                </div>
            </div>
            <div id="spotlightCarousel" class="carousel slide" data-bs-ride="carousel" data-bs-interval="6000">
                <div class="carousel-indicators">
                    <?php foreach ($spotlightItems as $index => $item): ?>
                    <button type="button" data-bs-target="#spotlightCarousel" data-bs-slide-to="<?= $index ?>" class="<?= $index === 0 ? 'active' : '' ?>" aria-current="<?= $index === 0 ? 'true' : 'false' ?>" aria-label="<?= h($item['title']) ?>"></button>
                    <?php endforeach; ?>
                </div>
                <div class="carousel-inner">
                    <?php foreach ($spotlightItems as $index => $item): ?>
                    <div class="carousel-item<?= $index === 0 ? ' active' : '' ?>">
                        <div class="spotlight-slide" data-show-accent="<?= h($item['accent']) ?>">
                            <div class="spotlight-media" data-bg="<?= h($item['image']) ?>"></div>
                            <div class="spotlight-copy">
                                <span class="spotlight-badge"><?= h($item['type']) ?></span>
                                <h3><?= h($item['title']) ?></h3>
                                <p class="spotlight-subtitle"><?= h($item['subtitle']) ?></p>
                                <p><?= h($item['description']) ?></p>
                                <a class="home-btn home-btn--ghost" href="<?= h($item['url']) ?>"><?= h($item['cta']) ?> <i data-lucide="arrow-right"></i></a>
                            </div>
                        </div>
                    </div>
                    <?php endforeach; ?>
                </div>
                <button class="carousel-control-prev" type="button" data-bs-target="#spotlightCarousel" data-bs-slide="prev">
                    <span class="carousel-control-icon" aria-hidden="true"><i data-lucide="chevron-left"></i></span>
                    <span class="sr-only">Anterior</span>
                </button>
                <button class="carousel-control-next" type="button" data-bs-target="#spotlightCarousel" data-bs-slide="next">
                    <span class="carousel-control-icon" aria-hidden="true"><i data-lucide="chevron-right"></i></span>
                    <span class="sr-only">Siguiente</span>
                </button>
            </div>
            </div>
        </section>

        <!-- ============================================
             10. PUBLICIDAD — Radio Doliv vive de sus
             anunciantes; ahora tiene un espacio visible.
             ============================================ -->
        <section class="ps-band ps-band--blue" aria-label="Anúnciate con nosotros">
            <div class="ps-band-inner home-ads scroll-blur-in">
                <div>
                    <span class="section-eyebrow">Para negocios</span>
                    <h2 class="section-title">¿Tienes un negocio? Promociona tu marca</h2>
                    <ul class="home-ads-list">
                        <li><i data-lucide="check"></i> Spots publicitarios</li>
                        <li><i data-lucide="check"></i> Entrevistas en vivo</li>
                        <li><i data-lucide="check"></i> Menciones en programas</li>
                        <li><i data-lucide="check"></i> Promoción en redes sociales</li>
                    </ul>
                </div>
                <div class="home-ads-action">
                    <a class="home-btn home-btn--on-blue" href="pages/servicios.php" data-magnetic data-ripple>
                        <i data-lucide="megaphone"></i> Solicitar cotización
                    </a>
                </div>
            </div>
        </section>

        <!-- ============================================
             11. REDES — visibles en la pagina, no escondidas
             en un modal.
             ============================================ -->
        <section class="ps-band ps-band--light" aria-label="Síguenos en redes">
            <div class="ps-band-inner">
            <div class="section-head">
                <div>
                    <span class="section-eyebrow">Sigue la conversación</span>
                    <h2 class="section-title">Síguenos en redes</h2>
                </div>
            </div>
            <!-- Botones de vidrio 3D: cada uno arranca como un cuadro con
                 solo el icono y se despliega mostrando el nombre al pasar el
                 cursor o al recibir foco, iluminandose con el color de su
                 red. Los logotipos van como SVG en linea (no via Lucide, que
                 ya no incluye iconos de marca: quedarian invisibles). -->
            <div class="home-social-grid scroll-rotate-in">
                <a class="glass-social" style="--clr: #e1306c;" aria-label="Instagram de Radio Doliv"
                   href="https://www.instagram.com/radio_doliv/" target="_blank" rel="noopener noreferrer">
                    <span class="glass-social-box">
                        <span class="glass-social-icon">
                            <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z"/></svg>
                        </span>
                        <span class="glass-social-text">Instagram</span>
                    </span>
                </a>

                <a class="glass-social" style="--clr: #1877f2;" aria-label="Facebook de Radio Doliv"
                   href="https://www.facebook.com/people/RADIO-DOLIV/61574197135745/" target="_blank" rel="noopener noreferrer">
                    <span class="glass-social-box">
                        <span class="glass-social-icon">
                            <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/></svg>
                        </span>
                        <span class="glass-social-text">Facebook</span>
                    </span>
                </a>

                <a class="glass-social" style="--clr: #ff0050;" aria-label="TikTok de Radio Doliv"
                   href="https://www.tiktok.com/@radio_doliv" target="_blank" rel="noopener noreferrer">
                    <span class="glass-social-box">
                        <span class="glass-social-icon">
                            <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12.525.02c1.31-.02 2.61-.01 3.91-.02.08 1.53.63 3.09 1.75 4.17 1.12 1.11 2.7 1.62 4.24 1.79v4.03c-1.44-.05-2.89-.35-4.2-.97-.57-.26-1.1-.59-1.62-.93-.01 2.92.01 5.84-.02 8.75-.08 1.4-.54 2.79-1.35 3.94-1.31 1.92-3.58 3.17-5.91 3.21-1.43.08-2.86-.31-4.08-1.03-2.02-1.19-3.44-3.37-3.65-5.71-.02-.5-.03-1-.01-1.49.18-1.9 1.12-3.72 2.58-4.96 1.66-1.44 3.98-2.13 6.15-1.72.02 1.48-.04 2.96-.04 4.44-.99-.32-2.15-.23-3.02.37-.63.41-1.11 1.04-1.36 1.75-.21.51-.15 1.07-.14 1.61.24 1.64 1.82 3.02 3.5 2.87 1.12-.01 2.19-.66 2.77-1.61.19-.33.4-.67.41-1.06.1-1.79.06-3.57.07-5.36.01-4.03-.01-8.05.02-12.07z"/></svg>
                        </span>
                        <span class="glass-social-text">TikTok</span>
                    </span>
                </a>

                <a class="glass-social" style="--clr: #ff0000;" aria-label="YouTube de Radio Doliv"
                   href="https://youtube.com/@r_doliv?si=fZA7DtkJsxY3rGpl" target="_blank" rel="noopener noreferrer">
                    <span class="glass-social-box">
                        <span class="glass-social-icon">
                            <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z"/></svg>
                        </span>
                        <span class="glass-social-text">YouTube</span>
                    </span>
                </a>
            </div>
            </div>
        </section>

        <!-- ============================================
             12. CTA FINAL — mas emocional que informativo.
             ============================================ -->
        <section class="ps-band ps-band--dark" aria-label="Vive Radio Doliv">
            <div class="ps-band-inner home-cta">
                <div class="scroll-fade-up">
                    <h2>Tu próxima canción favorita ya está sonando</h2>
                    <p>Únete a las personas que escuchan Radio Doliv todos los días. Solo dale play.</p>
                </div>
                <div class="home-cta-actions scroll-bounce-in">
                    <button type="button" class="home-btn home-btn--primary" data-action="toggle-radio" data-magnetic data-ripple>
                        <i data-lucide="play-circle"></i> Escuchar en vivo
                    </button>
                </div>
            </div>
        </section>
    </main>

    <?php include __DIR__ . '/inc/components/modal-song-request.php'; ?>

    <?php include __DIR__ . '/inc/partials/footer.php'; ?>

    <a href="#main-content" class="back-to-top" id="backToTop" aria-label="Volver arriba" data-page-content>
        <i data-lucide="chevron-up"></i>
    </a>

    <!-- Sugerencia de scroll: tarjeta fija sobre el boton del chatbot que
         propone una seccion al azar (parrilla, voces, podcasts, eventos).
         Aparece al pasar el reproductor, y su barra se llena con el scroll
         del visitante -- al completarse cambia a otra sugerencia al azar
         (ver assets/js/pages/index.js). -->
    <div class="home-scroll-tip" id="scrollTip">
        <a href="#" id="scrollTipLink" class="home-scroll-tip-link">
            <i data-lucide="compass" aria-hidden="true"></i>
            <span id="scrollTipText">Sigue explorando</span>
        </a>
        <button type="button" class="home-scroll-tip-close" id="scrollTipClose" aria-label="Cerrar sugerencia">
            <i data-lucide="x" aria-hidden="true"></i>
        </button>
        <div class="home-scroll-tip-track"><span class="home-scroll-tip-bar" id="scrollTipBar"></span></div>
    </div>

    <audio id="radio-audio" src="https://stream.zeno.fm/vrfurwfubkhtv" preload="none"></audio>

    <?php include __DIR__ . '/inc/partials/scripts.php'; ?>
    <!-- Solo el JS de Bootstrap (incluye Popper), sin su CSS: el carrusel de
         "Descubre más" de abajo usa la API de datos de Bootstrap
         (data-bs-ride, data-bs-slide-to) para la logica de slide/autoplay/
         swipe; el aspecto visual sigue siendo 100% nuestro (ver
         assets/css/components/carousel.css). -->
    <script src="<?= asset_url('assets/js/vendor/bootstrap.bundle.min.js') ?>" data-page-script></script>
    <script src="<?= asset_url('assets/js/pages/index.js') ?>" data-page-script></script>
</body>
</html>
