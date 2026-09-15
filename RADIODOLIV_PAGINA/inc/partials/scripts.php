<?php
require_once __DIR__ . '/../helpers/assets.php';
// Orden de carga documentado en un solo lugar (antes se copiaba a mano en las
// 9 páginas). namespace.js/utils.js se agregan primero, de forma aditiva:
// no reemplazan aún los globals de theme/radio/mobile-menu (eso ocurre en la
// fase de consolidación JS), solo quedan disponibles sin romper nada.
//
// "defer" en las 9 etiquetas: sin esto, el navegador las descarga Y EJECUTA
// una por una en serie (script 2 ni empieza a pedirse hasta que el 1 termino
// de bajar Y correr) -- en localhost es instantaneo y no se nota, pero en
// una red movil real cada script es un viaje de ida y vuelta aparte (no hay
// bundler, ver ESQUEMA_PROYECTO.md) y la cadena completa puede tardar un par
// de segundos DESPUES de que la pagina ya se ve y se puede hacer scroll. En
// ese hueco, el boton del chatbot (lo crea chatbot.js, script 9 de 9) y la
// tarjeta de sugerencia (la controla pages/index.js, que carga aun despues)
// simplemente no existen todavia -- no es que esten mal alineados, es que
// el usuario ya hizo scroll antes de que el JS que los crea/activa
// terminara de llegar. "defer" deja que el navegador pida las 9 en paralelo
// en cuanto las ve (sin bloquear el parseo, que aqui ya da igual por ir al
// final del body) y las ejecuta en el mismo orden de siempre una vez
// terminado el documento -- mismo comportamiento, mucho menos tiempo muerto.
?>
<script src="<?= asset_url('assets/js/core/namespace.js') ?>" defer></script>
<script src="<?= asset_url('assets/js/core/utils.js') ?>" defer></script>
<script src="<?= asset_url('assets/js/core/theme.js') ?>" defer></script>
<script src="<?= asset_url('assets/js/core/radio.js') ?>" defer></script>
<script src="<?= asset_url('assets/js/core/sticky-player.js') ?>" defer></script>
<script src="<?= asset_url('assets/js/core/mobile-dock.js') ?>" defer></script>
<script src="<?= asset_url('assets/js/data/search-items.php') ?>" defer></script>
<script src="<?= asset_url('assets/js/components/search.js') ?>" defer></script>
<script src="<?= asset_url('assets/js/components/chatbot.js') ?>" defer></script>
<script src="<?= asset_url('assets/js/core/mobile-menu.js') ?>" defer></script>
<script src="<?= asset_url('assets/js/core/interactions.js') ?>" defer></script>
<!-- page-router.js va al final: para cuando corre, RadioDoliv.radio
     (expuesto por radio.js) ya existe, y el pageSignal que expone
     queda listo justo antes de que arranque el <script data-page-script>
     especifico de cada pagina (ver el final de cada pages/*.php). "defer"
     preserva ese orden (se ejecuta en el orden del documento, no en el que
     terminen de bajar), asi que esta garantia no cambia. -->
<script src="<?= asset_url('assets/js/core/page-router.js') ?>" defer></script>
