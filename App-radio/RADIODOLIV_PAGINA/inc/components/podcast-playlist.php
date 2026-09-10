<?php
require_once __DIR__ . '/../helpers/html.php';
// Espera $podcast (fila de get_podcasts(), con su array 'episodes').
// Renderiza la tarjeta completa de un programa: cabecera (portada,
// titulo, boton "Seguir programa"), lista de capitulos y SU PROPIA
// barra de reproduccion con SU PROPIO <audio> (cada programa es
// independiente, ver assets/js/pages/podcast.js -- reproducir uno
// pausa el audio de los demas, igual que antes del rediseno).
// Arranca visible ("is-active"): el filtro por defecto es "Todos"
// (catalogo completo, una tarjeta por programa); podcast.js oculta el
// resto en cuanto se elige un programa especifico.
$base = SITE_BASE_PATH;
$episodes = $podcast['episodes'];
$hasEpisodes = count($episodes) > 0;
$episodeLabel = $hasEpisodes
    ? sprintf('%d capítulo%s disponible%s', count($episodes), count($episodes) === 1 ? '' : 's', count($episodes) === 1 ? '' : 's')
    : 'Próximamente';
?>
<article class="podcast-program is-active" id="podcast-<?= h($podcast['slug']) ?>" data-category="<?= h($podcast['slug']) ?>">
    <header class="podcast-program-header">
        <img src="<?= h($base . $podcast['cover']) ?>" class="podcast-program-logo" alt="" loading="lazy">
        <div class="podcast-program-heading">
            <h2><?= h($podcast['title']) ?></h2>
            <p><?= h($episodeLabel) ?></p>
        </div>
        <button type="button" class="podcast-follow-btn">
            <i data-lucide="heart" aria-hidden="true"></i> Seguir programa
        </button>
    </header>

    <?php if ($hasEpisodes): ?>
    <ol class="podcast-episode-list">
        <?php foreach ($episodes as $index => $episode): ?>
        <li>
            <button type="button" class="podcast-episode"
                data-src="<?= h($base . $episode['audio_url']) ?>"
                data-title="<?= h($episode['title']) ?>"
                data-cover="<?= h($base . $podcast['cover']) ?>"
                aria-label="Reproducir <?= h($episode['title']) ?>">
                <span class="podcast-episode-play" aria-hidden="true">
                    <i data-lucide="play" class="icon-play"></i>
                    <i data-lucide="pause" class="icon-pause"></i>
                </span>
                <span class="podcast-episode-thumb" aria-hidden="true"></span>
                <span class="podcast-episode-meta">
                    <span class="podcast-episode-title"><?= h($episode['title']) ?></span>
                    <span class="podcast-episode-sub"><?= h($episode['description']) ?></span>
                </span>
                <span class="podcast-episode-duration" data-duration>--:--</span>
                <span class="podcast-episode-menu" aria-hidden="true"><i data-lucide="more-horizontal"></i></span>
            </button>
        </li>
        <?php endforeach; ?>
    </ol>

    <div class="podcast-player-bar">
        <span class="podcast-player-cover" data-player-cover aria-hidden="true"></span>
        <div class="podcast-player-meta">
            <span class="podcast-player-eyebrow">Reproduciendo</span>
            <span class="podcast-player-title" data-player-title>&mdash;</span>
            <span class="podcast-player-program" data-player-program><?= h($podcast['title']) ?></span>
        </div>
        <div class="podcast-player-controls">
            <button type="button" class="podcast-player-btn" data-player-action="rewind" aria-label="Retroceder 10 segundos">
                <i data-lucide="rotate-ccw" aria-hidden="true"></i><span>10</span>
            </button>
            <button type="button" class="podcast-player-btn podcast-player-toggle" data-player-action="toggle" aria-label="Reproducir">
                <i data-lucide="play" aria-hidden="true"></i>
            </button>
            <button type="button" class="podcast-player-btn" data-player-action="forward" aria-label="Adelantar 10 segundos">
                <i data-lucide="rotate-cw" aria-hidden="true"></i><span>10</span>
            </button>
        </div>
        <div class="podcast-player-progress">
            <span class="podcast-player-time" data-player-current>00:00</span>
            <input type="range" class="podcast-player-seek" data-player-seek value="0" min="0" max="100" step="0.1" aria-label="Progreso del episodio">
            <span class="podcast-player-time" data-player-duration>00:00</span>
        </div>
        <div class="podcast-player-volume">
            <i data-lucide="volume-2" aria-hidden="true"></i>
            <input type="range" class="podcast-player-volume-slider" data-player-volume value="80" min="0" max="100" step="1" aria-label="Volumen">
        </div>
        <audio class="podcast-audio" data-player-audio preload="none"></audio>
    </div>
    <?php else: ?>
    <div class="playlist-placeholder">
        <i data-lucide="hourglass" aria-hidden="true"></i> Audio próximamente
    </div>
    <?php endif; ?>
</article>
