/* ============================================
   core/namespace.js
   Namespace compartido del sitio. Se carga primero, antes que
   cualquier otro script. Reemplaza progresivamente los globals
   sueltos (como "body", que hoy declara core/theme.js y del que
   dependen radio.js y mobile-menu.js solo por convencion/orden
   de carga) por referencias explicitas bajo RadioDoliv.

   SITE_BASE se lee UNA vez aqui y nunca se vuelve a actualizar (este
   script no se re-ejecuta en la navegacion AJAX, ver
   core/page-router.js) -- por eso data-site-base ahora lo escribe
   cada pagina como una URL absoluta desde la raiz del sitio (ver
   site_root_url() en inc/helpers/html.php), no como una ruta relativa
   al directorio del script ('' / '../'): esa relativa cambiaba de
   significado en cuanto se navegaba a una URL de otra "profundidad"
   (index.php en la raiz vs. pages/*.php un nivel abajo), rompiendo
   los enlaces/imagenes que arman chatbot.js, search.js y varias
   paginas a partir de este valor.
   ============================================ */
window.SITE_BASE = document.body.dataset.siteBase || "";

window.RadioDoliv = window.RadioDoliv || {
    body: document.body,
    utils: {},
};
