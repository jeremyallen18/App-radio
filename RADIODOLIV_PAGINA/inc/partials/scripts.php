<?php
require_once __DIR__ . '/../helpers/assets.php';
// Orden de carga documentado en un solo lugar (antes se copiaba a mano en las
// 9 páginas). namespace.js/utils.js se agregan primero, de forma aditiva:
// no reemplazan aún los globals de theme/radio/mobile-menu (eso ocurre en la
// fase de consolidación JS), solo quedan disponibles sin romper nada.
?>
<script src="<?= asset_url('assets/js/core/namespace.js') ?>"></script>
<script src="<?= asset_url('assets/js/core/utils.js') ?>"></script>
<script src="<?= asset_url('assets/js/core/theme.js') ?>"></script>
<script src="<?= asset_url('assets/js/core/radio.js') ?>"></script>
<script src="<?= asset_url('assets/js/core/sticky-player.js') ?>"></script>
<script src="<?= asset_url('assets/js/data/search-items.php') ?>"></script>
<script src="<?= asset_url('assets/js/components/search.js') ?>"></script>
<script src="<?= asset_url('assets/js/components/chatbot.js') ?>"></script>
<script src="<?= asset_url('assets/js/core/mobile-menu.js') ?>"></script>
<script src="<?= asset_url('assets/js/core/interactions.js') ?>"></script>
<!-- page-router.js va al final: para cuando corre, RadioDoliv.radio
     (expuesto por radio.js) ya existe, y el pageSignal que expone
     queda listo justo antes de que arranque el <script data-page-script>
     especifico de cada pagina (ver el final de cada pages/*.php). -->
<script src="<?= asset_url('assets/js/core/page-router.js') ?>"></script>
