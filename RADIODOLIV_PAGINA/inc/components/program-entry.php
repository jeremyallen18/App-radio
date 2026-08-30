<?php
require_once __DIR__ . '/../helpers/html.php';
// Una entrada del rundown (ver pages/programas.php). Reemplaza al antiguo
// card-program.php: aqui NO hay tarjeta -- la hora vive en un canal propio
// a la izquierda, el arte flota sin marco y el titulo va directo sobre el
// fondo de la pagina, para que la parrilla se lea como el minutado de una
// cabina y no como una rejilla de cajas.
// Espera $program (fila de get_programs()), $programIndex y SITE_BASE_PATH.
$base = SITE_BASE_PATH;
[$scheduleDays, $scheduleTime] = array_map('trim', explode('|', $program['schedule'] . '|'));
$hasSlot = $program['slot_start'] !== null && $program['slot_end'] !== null;

// Etiquetas del programa (categories es texto separado por comas). Al
// filtro viajan NORMALIZADAS (minusculas, sin acentos, ver
// program_tag_keys() en pages/programas.php) para que las variantes de
// escritura de la BD coincidan entre si; visibles solo se pintan las
// primeras 3, con su texto original.
$allTags = array_filter(array_map('trim', explode(',', (string) ($program['categories'] ?? ''))));
$tagList = array_slice($allTags, 0, 3);
$tagKeys = program_tag_keys($program['categories'] ?? '');
?>
<article class="rundown-item" id="programa-<?= h($program['slug']) ?>"
    data-categories="<?= h(implode(',', $tagKeys)) ?>"
    data-title="<?= h($program['title']) ?>"
    data-host="<?= h($program['host']) ?>"
    data-accent="<?= h($program['accent']) ?>"
    data-image="<?= h($base . $program['image']) ?>"
    data-time="<?= h($program['badge_time'] ?? $scheduleTime) ?>"
    <?php if ($hasSlot): ?>
    data-slot-start="<?= (int) $program['slot_start'] ?>"
    data-slot-end="<?= (int) $program['slot_end'] ?>"
    data-slot-weekdays="<?= h($program['weekdays'] ?? '') ?>"
    <?php endif; ?>
    style="--show-accent: <?= h($program['accent']) ?>;">

    <!-- Canal de hora: cifra grande en mono, como el minutado de cabina. -->
    <div class="rundown-item-clock">
        <?php if ($hasSlot): ?>
        <span class="rundown-item-hour"><?= sprintf('%02d', (int) $program['slot_start']) ?><i>:00</i></span>
        <span class="rundown-item-range"><?= h($program['badge_time'] ?? $scheduleTime) ?></span>
        <?php else: ?>
        <span class="rundown-item-hour rundown-item-hour--always">24/7</span>
        <?php endif; ?>
        <span class="rundown-item-live"><span class="pulse-dot"></span> En vivo</span>
    </div>

    <div class="rundown-item-main">
        <p class="rundown-item-kicker">
            <span class="rundown-item-num"><?= str_pad((string) (($programIndex ?? 0) + 1), 2, '0', STR_PAD_LEFT) ?></span>
            <?= h($program['badge_label']) ?>
        </p>

        <h3 class="rundown-item-title"><?= h($program['title']) ?></h3>

        <p class="rundown-item-host"><i data-lucide="mic-2"></i> Con <?= h($program['host']) ?><?= $scheduleDays !== '' ? ' · ' . h($scheduleDays) : '' ?></p>

        <p class="rundown-item-desc"><?= h($program['card_desc']) ?></p>

        <?php if ($tagList): ?>
        <ul class="rundown-item-tags">
            <?php foreach ($tagList as $tag): ?>
            <li><?= h($tag) ?></li>
            <?php endforeach; ?>
        </ul>
        <?php endif; ?>

        <button class="rundown-item-cta show-more-btn"
            data-title="<?= h($program['modal_title']) ?>"
            data-time="<?= h($program['schedule']) ?>"
            data-categories="<?= h($program['categories']) ?>"
            data-summary="<?= h($program['summary']) ?>"
            data-accent="<?= h($program['accent']) ?>">
            Ver detalles del programa <i data-lucide="arrow-up-right"></i>
        </button>
    </div>

    <!-- Arte del programa: sin marco ni tarjeta, flotando sobre un halo del
         color del programa. Los artes son emblemas circulares que pierden
         legibilidad si se recortan, por eso object-fit:contain (ver CSS). -->
    <div class="rundown-item-art">
        <span class="rundown-item-halo" aria-hidden="true"></span>
        <img src="<?= h($base . $program['image']) ?>" alt="<?= h($program['title']) ?>" loading="lazy">
        <span class="rundown-item-badge"><i data-lucide="<?= h($program['icon']) ?>"></i></span>
    </div>
</article>
