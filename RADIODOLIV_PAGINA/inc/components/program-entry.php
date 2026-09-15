<?php
require_once __DIR__ . '/../helpers/html.php';
// Una entrada del rundown (ver pages/programas.php). Reemplaza al antiguo
// card-program.php: aqui NO hay tarjeta -- la hora vive en un canal propio
// a la izquierda, el arte flota sin marco y el titulo va directo sobre el
// fondo de la pagina, para que la parrilla se lea como el minutado de una
// cabina y no como una rejilla de cajas.
// Espera $program (un programa completo con slots[]), $programIndex y
// SITE_BASE_PATH. La cabina/dial usan ocurrencias por franja; esta vista
// publica agrupa esas franjas dentro de una sola ficha para no repetir el
// mismo programa como si fueran programas diferentes.
$base = SITE_BASE_PATH;
[$scheduleDays, $scheduleTime] = array_map('trim', explode('|', $program['schedule'] . '|'));
$slots = $program['slots'] ?? [];
$hasSlot = !empty($slots) || ($program['slot_start'] !== null && $program['slot_end'] !== null);
$weekdayShort = [1 => 'Lun', 2 => 'Mar', 3 => 'Mié', 4 => 'Jue', 5 => 'Vie', 6 => 'Sáb', 7 => 'Dom'];

if (!$slots && $program['slot_start'] !== null && $program['slot_end'] !== null) {
    $slotDays = array_values(array_filter(array_map('intval', explode(',', (string) ($program['weekdays'] ?? '')))));
    if (!$slotDays) $slotDays = range(1, 7);
    foreach ($slotDays as $weekday) {
        $slots[] = [
            'weekday' => $weekday,
            'start_hour' => (int) $program['slot_start'],
            'end_hour' => (int) $program['slot_end'],
        ];
    }
}

$slotGroups = [];
foreach ($slots as $slot) {
    $key = ((int) $slot['start_hour']) . '-' . ((int) $slot['end_hour']);
    $slotGroups[$key]['start'] ??= (int) $slot['start_hour'];
    $slotGroups[$key]['end'] ??= (int) $slot['end_hour'];
    $slotGroups[$key]['days'][] = (int) $slot['weekday'];
}

$programSlotsJson = array_map(fn(array $slot) => [
    'weekday' => (int) $slot['weekday'],
    'start' => (int) $slot['start_hour'],
    'end' => (int) $slot['end_hour'],
], $slots);

$firstSlot = $slots[0] ?? null;
$primaryRange = $firstSlot
    ? sprintf('%02d:00 - %02d:00', (int) $firstSlot['start_hour'], (int) $firstSlot['end_hour'])
    : ($program['badge_time'] ?? $scheduleTime);

// Etiquetas del programa (categories es texto separado por comas). Al
// filtro viajan NORMALIZADAS (minusculas, sin acentos, ver
// program_tag_keys() en pages/programas.php) para que las variantes de
// escritura de la BD coincidan entre si; visibles solo se pintan las
// primeras 3, con su texto original.
$allTags = array_filter(array_map('trim', explode(',', (string) ($program['categories'] ?? ''))));
$tagList = array_slice($allTags, 0, 3);
$tagKeys = program_tag_keys($program['categories'] ?? '');
?>
<article class="rundown-item<?= !empty($programHiddenToday) ? ' is-hidden-day' : '' ?>" id="programa-<?= h($program['slug']) ?>"
    data-categories="<?= h(implode(',', $tagKeys)) ?>"
    data-title="<?= h($program['title']) ?>"
    data-host="<?= h($program['host']) ?>"
    data-accent="<?= h($program['accent']) ?>"
    data-image="<?= h($base . $program['image']) ?>"
    data-time="<?= h($program['badge_time'] ?: $primaryRange) ?>"
    data-schedule="<?= h($program['schedule']) ?>"
    <?php if ($programSlotsJson): ?>
    data-slots="<?= h(json_encode($programSlotsJson, JSON_UNESCAPED_UNICODE)) ?>"
    data-slot-start="<?= (int) $programSlotsJson[0]['start'] ?>"
    data-slot-end="<?= (int) $programSlotsJson[0]['end'] ?>"
    data-slot-weekdays="<?= h($program['weekdays'] ?? '') ?>"
    <?php endif; ?>
    style="--show-accent: <?= h($program['accent']) ?>;">

    <!-- Canal de hora: cifra grande en mono, como el minutado de cabina. -->
    <div class="rundown-item-clock">
        <?php if ($hasSlot): ?>
        <span class="rundown-item-hour"><?= sprintf('%02d', (int) ($firstSlot['start_hour'] ?? $program['slot_start'])) ?><i>:00</i></span>
        <span class="rundown-item-range"><?= h($program['badge_time'] ?: $primaryRange) ?></span>
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

        <?php if ($slotGroups): ?>
        <div class="rundown-item-schedule" aria-label="Horarios de <?= h($program['title']) ?>">
            <?php foreach ($slotGroups as $group): ?>
            <span class="rundown-slot-group">
                <strong><?= h(implode(', ', array_map(fn(int $day) => $weekdayShort[$day] ?? '', $group['days']))) ?></strong>
                <em><?= sprintf('%02d:00 - %02d:00', (int) $group['start'], (int) $group['end']) ?></em>
            </span>
            <?php endforeach; ?>
        </div>
        <?php endif; ?>

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
