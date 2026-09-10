<?php
require_once __DIR__ . '/../helpers/html.php';
require_once __DIR__ . '/../data/events.php';
/* ---------------------------------------------------------------------------
   Fila de la cartelera.

   Reemplaza a inc/components/card-event.php. No es una tarjeta: es una fila
   editorial (numero de orden + titulo gigante + metadatos), separada de la
   siguiente por una linea fina, siguiendo el mismo criterio que la rejilla de
   "proposito" y la lista de "valores" de Conocenos — ahi el comentario del CSS
   lo dice explicito: texto puro, columnas separadas por una linea fina en vez
   de una caja con fondo y borde, "para que el reveal de scroll se sienta en el
   texto mismo y no en un contenedor".

   El cartel no desaparece: se muestra en el visor flotante que sigue al cursor
   sobre la lista (ver .ev-peek en eventos.js) y, en pantallas sin hover, en la
   miniatura que la propia fila lleva a la izquierda.

   Contrato:
     $event       fila de get_events_for_display(), con 'index' y 'countdown'
                  ya calculados por la capa de datos.
     $rowNumber   posicion visible (1, 2, 3...) para el numero de orden.
     $ticketLink  (opcional) enlace de compra; si falta se pide a la capa de
                  datos, asi el componente sirve incluido desde cualquier pagina.
   --------------------------------------------------------------------------- */
$base       = defined('SITE_BASE_PATH') ? SITE_BASE_PATH : '';
$countdown  = $event['countdown'] ?? event_countdown($event);
$eventIndex = (int) ($event['index'] ?? 0);
$ticketLink = $ticketLink ?? get_event_ticket_link();
$hasDate    = !empty($event['event_date']);
$rowNumber  = $rowNumber ?? ($eventIndex + 1);
?>
<article class="ev-row<?= $countdown['urgent'] ? ' is-urgent' : '' ?>"
         data-ev-bucket="<?= h($countdown['bucket']) ?>"
         data-ev-poster="<?= h($base . $event['image']) ?>"
         style="--row: <?= (int) $rowNumber ?>">

    <span class="ev-row-index" aria-hidden="true"><?= str_pad((string) $rowNumber, 2, '0', STR_PAD_LEFT) ?></span>

    <?php /* Miniatura solo para pantallas sin hover: en escritorio el cartel
             se ve mucho mas grande en el visor que sigue al cursor. */ ?>
    <span class="ev-row-thumb" aria-hidden="true">
        <img src="<?= h($base . $event['image']) ?>" alt="" loading="lazy" decoding="async">
    </span>

    <span class="ev-row-main">
        <h3 class="ev-row-title"><?= h($event['title']) ?></h3>
        <span class="ev-row-artist"><?= h($event['artist']) ?></span>
    </span>

    <span class="ev-row-meta">
        <span class="ev-row-date<?= $hasDate ? '' : ' is-tbd' ?>">
            <?= h($event['weekday']) ?> <?= h($event['day']) ?> <?= h($event['month']) ?><?= $hasDate ? ' ' . h($event['year']) : '' ?>
        </span>
        <span class="ev-row-place"><?= h($event['location']) ?></span>
    </span>

    <span class="ev-row-countdown<?= $hasDate ? '' : ' is-tbd' ?>"><?= h($countdown['label']) ?></span>

    <span class="ev-row-actions">
        <a class="ev-row-buy" href="<?= h($ticketLink) ?>" target="_blank" rel="noopener" data-ev-stop>
            Boletos<i data-lucide="arrow-up-right" aria-hidden="true"></i>
        </a>
    </span>

    <?php /* Toda la fila abre el detalle. El enlace de boletos vive encima y se
             excluye desde el JS con [data-ev-stop], asi no hace falta que cada
             control recuerde llamar a stopPropagation. */ ?>
    <button type="button" class="ev-row-open" data-event-index="<?= $eventIndex ?>">
        <span class="sr-only">Ver detalles de <?= h($event['title']) ?></span>
    </button>
</article>
