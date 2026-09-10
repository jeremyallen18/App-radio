/* ============================================
   core/page-router.js
   Navegacion AJAX ("pjax"): intercepta clicks en enlaces internos,
   trae la pagina destino con fetch(), y reemplaza solo <main> --
   navbar, footer, CSS compartido (core.css) y JS global (namespace,
   utils, theme, radio, sticky-player, search, chatbot, mobile-menu)
   NO se recargan ni se re-ejecutan. El historial se mantiene con
   pushState/popstate. El acceso directo a una URL y la recarga de
   pagina siguen funcionando exactamente igual que siempre, porque
   cada ruta sigue siendo un documento PHP real y completo -- este
   script es una mejora progresiva sobre esos enlaces normales, no un
   reemplazo: si algo falla (red caida, respuesta rara), cae a una
   navegacion dura normal en vez de dejar al usuario colgado.

   Que SI se reemplaza en cada navegacion, ademas de <main>:
   - La hoja de estilos especifica de la pagina (<link data-page-css>,
     ver inc/partials/head.php) y su(s) script(s) especifico(s)
     (<script data-page-script>, ver el final de cada pages/*.php).
   - Cualquier nodo fuera de <main> pero propio de esa pagina, como
     modales o islas de datos JSON (<... data-page-content>, ver p.ej.
     inc/components/modal-announcement.php o el bloque de
     #events-data en pages/eventos.php) -- si no se refrescaran
     tambien, quedarian con datos de la PRIMERA visita para siempre.

   Transiciones: usa la View Transitions API del MISMO documento
   (document.startViewTransition) cuando esta disponible. Cada pagina
   ya define su propio par ::view-transition-old(root) /
   ::view-transition-new(root) en su propia hoja (ver
   assets/css/pages/*.css) -- como solo la hoja de la pagina activa
   esta cargada en cada momento (ver removeStalePageStylesheets, que
   se ejecuta DESPUES de que termina la transicion, nunca antes), esas
   reglas siguen resolviendo igual que con la transicion nativa entre
   documentos que ya existia para carga dura (ver
   assets/css/components/page-transitions.css). Sin soporte nativo
   (o con prefers-reduced-motion), cae al fallback de fade por clases
   en <body> que ya definia ese mismo archivo.
   ============================================ */
(function (ns) {
    const CSS_ATTR = "data-page-css";
    const SCRIPT_ATTR = "data-page-script";
    const CONTENT_ATTR = "data-page-content";
    const NAV_LINK_ATTR = "data-page-link";
    const FADE_MS = 180;
    const STYLESHEET_TIMEOUT_MS = 600;

    /* --------------------------------------------------------------
       Senal de ciclo de vida de pagina: cada script especifico de
       pagina (pages/*.js) la lee al arrancar y la pasa como `signal`
       a sus listeners en window/document, para no acumular
       duplicados en visitas repetidas (window y document nunca se
       destruyen entre navegaciones AJAX). Se aborta -- limpiando esos
       listeners solos -- justo antes de aplicar cada nueva pagina.
       -------------------------------------------------------------- */
    let pageController = new AbortController();
    ns.pageSignal = pageController.signal;

    function resetPageSignal() {
        pageController.abort();
        pageController = new AbortController();
        ns.pageSignal = pageController.signal;
    }

    const supportsViewTransitions = typeof document.startViewTransition === "function";
    function prefersReducedMotion() {
        return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    }

    function wait(ms) {
        return new Promise((resolve) => setTimeout(resolve, ms));
    }

    /* --------------------------------------------------------------
       Elegibilidad de enlaces: solo interceptamos clicks simples
       (boton izquierdo, sin modificadoras) sobre enlaces internos
       "de pagina" -- se deja pasar todo lo demas (anclas #, mailto,
       tel, target=_blank, descargas, dominios externos, o cualquier
       enlace marcado explicitamente con data-no-ajax) para que el
       navegador lo maneje normal.
       -------------------------------------------------------------- */
    function isEligibleLink(link) {
        if (!link || !link.href) return false;
        if (link.hasAttribute("data-no-ajax")) return false;
        if (link.target && link.target !== "_self") return false;
        if (link.hasAttribute("download")) return false;
        if (link.origin !== window.location.origin) return false;
        const href = link.getAttribute("href") || "";
        if (!href || href.charAt(0) === "#" || /^(mailto|tel|javascript):/i.test(href)) return false;
        return true;
    }

    function isSamePage(url) {
        return url.pathname === window.location.pathname && url.search === window.location.search;
    }

    document.addEventListener("click", (event) => {
        if (event.defaultPrevented || event.button !== 0) return;
        if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
        const link = event.target.closest ? event.target.closest("a[href]") : null;
        if (!isEligibleLink(link)) return;

        const url = new URL(link.href, window.location.href);
        if (isSamePage(url) && url.hash) return; // deja que el navegador haga scroll al ancla
        if (isSamePage(url)) { event.preventDefault(); return; } // ya estamos aqui, no hay nada que hacer

        event.preventDefault();
        navigate(url.href, { push: true });
    });

    window.addEventListener("popstate", () => {
        navigate(window.location.href, { push: false });
    });

    // Estado inicial consistente, para que el primer popstate tenga con que comparar.
    history.replaceState({ url: window.location.href }, "", window.location.href);
    // El scroll lo maneja applyPage() en cada navegacion, no el navegador.
    if ("scrollRestoration" in history) history.scrollRestoration = "manual";

    /* --------------------------------------------------------------
       Orquestacion de una navegacion.
       -------------------------------------------------------------- */
    let navToken = 0;
    let inFlightController = null;

    async function navigate(url, { push }) {
        const token = ++navToken;
        if (inFlightController) inFlightController.abort();
        const fetchController = new AbortController();
        inFlightController = fetchController;

        let html;
        try {
            const response = await fetch(url, {
                signal: fetchController.signal,
                headers: { "X-Requested-With": "fetch" },
            });
            if (!response.ok) throw new Error("bad status " + response.status);
            html = await response.text();
        } catch (error) {
            if (error.name === "AbortError") return; // otra navegacion mas nueva la reemplazo
            window.location.href = url; // red caida / error real: navegacion dura, nunca deja al usuario colgado
            return;
        }
        if (token !== navToken) return;

        const doc = new DOMParser().parseFromString(html, "text/html");
        const newMain = doc.querySelector("main");
        if (!newMain) {
            window.location.href = url; // respuesta irreconocible: navega normal
            return;
        }

        await applyPage(doc, newMain, url, push);
    }

    /* --------------------------------------------------------------
       CSS especifico de pagina: se agrega ANTES de tocar el DOM (para
       que <main> nunca se muestre sin estilos) y se quita DESPUES de
       que termina la transicion (para que ::view-transition-old(root)
       siga usando la hoja de la pagina de salida mientras se captura
       su "foto" inicial). Las hojas ajenas a data-page-css (fuentes
       via $pageExtraHead, etc.) solo se agregan si faltan y nunca se
       quitan -- no chocan entre paginas.
       -------------------------------------------------------------- */
    /* Resuelve el href del <link> tal como lo veria el navegador (URL
       absoluta), comparando siempre contra eso -- nunca contra el
       string crudo del atributo: index.php y pages/*.php escriben la
       MISMA hoja con una ruta relativa distinta (SITE_BASE_PATH: ''
       vs '../'), asi que comparar el string crudo no detectaria que
       ya esta cargada al navegar entre esos dos contextos. `doc` es
       el documento recien parseado por DOMParser (sin URL propia),
       por eso su href se resuelve a mano contra `baseUrl` (la URL
       que se acaba de fetch()ear). */
    function resolveHref(link, baseUrl) {
        const raw = link.getAttribute("href");
        if (!raw) return null;
        try {
            return new URL(raw, baseUrl).href;
        } catch (error) {
            return null;
        }
    }

    function preloadPageStylesheets(doc, baseUrl) {
        const currentHrefs = Array.from(document.querySelectorAll(`link[${CSS_ATTR}]`)).map((link) => link.href);
        const wanted = Array.from(doc.querySelectorAll(`link[${CSS_ATTR}]`));
        const loads = [];

        wanted.forEach((sourceLink) => {
            const resolved = resolveHref(sourceLink, baseUrl);
            if (!resolved || currentHrefs.includes(resolved)) return;
            const link = document.createElement("link");
            link.rel = "stylesheet";
            link.href = resolved;
            link.setAttribute(CSS_ATTR, "");
            loads.push(new Promise((resolve) => {
                link.addEventListener("load", resolve, { once: true });
                link.addEventListener("error", resolve, { once: true });
            }));
            document.head.appendChild(link);
        });

        // Hojas "extra" propias de una pagina (Bootstrap, fuentes puntuales
        // via $pageExtraHead): en el documento servido por PHP van ANTES de
        // core.css a proposito (ver inc/partials/head.php), para que el
        // reset/reboot de una libreria como Bootstrap no le gane por orden
        // de cascada a los estilos compartidos del sitio. Si aqui se
        // insertaran con appendChild quedarian al FINAL del <head> --
        // despues de core.css y de la hoja de la pagina -- invirtiendo ese
        // orden (por ejemplo, el "body { color: #212529 }" de Bootstrap le
        // ganaria al "body { color: white }" de core.css). Por eso se
        // insertan antes del <link data-core-css>.
        const coreCssLink = document.querySelector("link[data-core-css]");
        const currentExtraHrefs = Array.from(document.querySelectorAll('head link[rel="stylesheet"]')).map((link) => link.href);
        Array.from(doc.querySelectorAll(`head link[rel="stylesheet"]:not([${CSS_ATTR}]):not([data-core-css])`)).forEach((sourceLink) => {
            const resolved = resolveHref(sourceLink, baseUrl);
            if (!resolved || currentExtraHrefs.includes(resolved)) return;
            const link = document.createElement("link");
            link.rel = "stylesheet";
            link.href = resolved;
            if (coreCssLink) {
                document.head.insertBefore(link, coreCssLink);
            } else {
                document.head.appendChild(link);
            }
        });

        const keepHrefs = wanted.map((link) => resolveHref(link, baseUrl)).filter(Boolean);
        if (!loads.length) return Promise.resolve(keepHrefs);
        return Promise.race([Promise.all(loads), wait(STYLESHEET_TIMEOUT_MS)]).then(() => keepHrefs);
    }

    function removeStalePageStylesheets(keepHrefs) {
        document.querySelectorAll(`link[${CSS_ATTR}]`).forEach((link) => {
            if (!keepHrefs.includes(link.href)) link.remove();
        });
    }

    /* --------------------------------------------------------------
       Nodos fuera de <main> propios de la pagina (modales, islas
       JSON): se quitan todos los viejos y se insertan los nuevos tal
       cual, en el mismo orden -- no necesitan logica de carga.
       -------------------------------------------------------------- */
    function swapPageContent(doc) {
        document.querySelectorAll(`[${CONTENT_ATTR}]`).forEach((el) => el.remove());
        Array.from(doc.querySelectorAll(`[${CONTENT_ATTR}]`)).forEach((sourceEl) => {
            document.body.appendChild(document.importNode(sourceEl, true));
        });
    }

    function updateNavActiveState(pageSlug) {
        document.querySelectorAll(`.nav-links a[${NAV_LINK_ATTR}]`).forEach((a) => {
            a.classList.toggle("active", a.getAttribute(NAV_LINK_ATTR) === pageSlug);
        });
    }

    function updateDocumentMeta(doc) {
        if (doc.title) document.title = doc.title;
        const newCanonical = doc.querySelector('link[rel="canonical"]');
        const curCanonical = document.querySelector('link[rel="canonical"]');
        if (newCanonical && curCanonical) curCanonical.setAttribute("href", newCanonical.getAttribute("href"));
        const newDesc = doc.querySelector('meta[name="description"]');
        const curDesc = document.querySelector('meta[name="description"]');
        if (newDesc && curDesc) curDesc.setAttribute("content", newDesc.getAttribute("content") || "");
    }

    function swapMain(newMain, doc) {
        const currentMain = document.querySelector("main");
        if (currentMain) currentMain.replaceWith(newMain);
        swapPageContent(doc);
        updateDocumentMeta(doc);
        const pageSlug = doc.documentElement.getAttribute("data-page") || "";
        document.documentElement.setAttribute("data-page", pageSlug);
        updateNavActiveState(pageSlug);
        return pageSlug;
    }

    /* --------------------------------------------------------------
       Scripts especificos de pagina: se quitan los viejos y se
       reinyectan los nuevos EN ORDEN (bootstrap antes de index.js,
       gsap antes de podcast.js), esperando cada "load" antes de
       insertar el siguiente. Reinyectar un <script src> siempre
       vuelve a ejecutarlo (a diferencia de type="module", que solo
       corre una vez por URL) -- por eso cada pages/*.js esta envuelto
       en una IIFE, para no chocar con sus propias declaraciones de la
       visita anterior.
       -------------------------------------------------------------- */
    function runPageScripts(doc) {
        document.querySelectorAll(`script[${SCRIPT_ATTR}]`).forEach((el) => el.remove());
        const sources = Array.from(doc.querySelectorAll(`script[${SCRIPT_ATTR}]`));

        return sources.reduce((chain, sourceScript) => chain.then(() => new Promise((resolve) => {
            const script = document.createElement("script");
            Array.from(sourceScript.attributes).forEach((attr) => script.setAttribute(attr.name, attr.value));
            // getAttribute(), no `.src`: `doc` viene de DOMParser y no tiene
            // una URL base real, asi que la propiedad IDL resuelta (.src)
            // no es confiable -- el atributo crudo si sirve, y al insertar
            // `script` en el documento vivo se resuelve solo, contra la URL
            // ya actualizada por pushState.
            if (sourceScript.getAttribute("src")) {
                script.addEventListener("load", resolve, { once: true });
                script.addEventListener("error", resolve, { once: true });
                document.body.appendChild(script);
            } else {
                script.textContent = sourceScript.textContent;
                document.body.appendChild(script);
                resolve();
            }
        })), Promise.resolve());
    }

    function focusMain() {
        const main = document.querySelector("main");
        if (!main) return;
        main.setAttribute("tabindex", "-1");
        main.focus({ preventScroll: true });
    }

    async function applyPage(doc, newMain, baseUrl, push) {
        resetPageSignal(); // limpia listeners/timers globales de la pagina anterior

        // Si la pagina anterior se fue con un modal abierto, su propio
        // codigo (que ya no correra) nunca soltaria esto.
        document.body.style.overflow = "";

        // preloadPageStylesheets compara los <link> ya presentes contra los
        // de la pagina destino usando su propiedad .href, que el navegador
        // recalcula contra la URL ACTUAL del documento. Por eso el cambio de
        // URL (pushState) se hace DESPUES de esta comparacion: si se hiciera
        // antes, los <link> ya presentes (escritos con rutas relativas segun
        // SITE_BASE_PATH de la pagina de origen) resolverian mal contra la
        // URL nueva y la deduplicacion fallaria, duplicando hojas como
        // core.css fuera de orden (rompiendo la cascada para la pagina que
        // recien entra).
        const keepHrefs = await preloadPageStylesheets(doc, baseUrl);

        if (push) history.pushState({ url: baseUrl }, "", baseUrl);

        let pageSlug;
        const doSwap = () => { pageSlug = swapMain(newMain, doc); };

        if (supportsViewTransitions && !prefersReducedMotion()) {
            const transition = document.startViewTransition(doSwap);
            await transition.finished.catch(() => {});
        } else {
            document.body.classList.remove("page-transition-ready");
            document.body.classList.add("page-transition-out");
            await wait(FADE_MS);
            doSwap();
            document.body.classList.remove("page-transition-out");
            document.body.classList.add("page-transition-ready");
        }

        removeStalePageStylesheets(keepHrefs); // ya no hace falta la hoja de la pagina anterior

        window.scrollTo(0, 0);
        focusMain();
        ns.utils.repaintIcons();

        await runPageScripts(doc);
        ns.utils.repaintIcons();
        if (ns.radio && ns.radio.onNavigate) ns.radio.onNavigate();
    }
})(window.RadioDoliv);
