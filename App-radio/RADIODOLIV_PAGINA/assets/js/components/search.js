/* ============================================
   components/search.js
   Buscador global del sitio.
   Requiere que assets/js/data/search-items.php se haya cargado
   antes (script clasico, sin modulos ES) para que "searchItems"
   ya exista en el scope global. Ese endpoint PHP genera el mismo
   global a partir de inc/data/*.php (fuente unica de verdad,
   reemplaza al viejo data/search-items.js mantenido a mano).
   ============================================ */

/* Normaliza texto para buscar sin distinguir mayúsculas, acentos o espacios extra. */
const normalizeSearchText = window.RadioDoliv.utils.normalizeText;
const escapeSearchHtml = window.RadioDoliv.utils.escapeHtml;

/* Categorías filtrables por chip. "Podcasts" agrupa tanto las fichas de
   podcast como sus episodios (el índice los separa en grupos "Podcasts" /
   "Podcast" porque describen cosas distintas, pero para filtrar el usuario
   solo necesita pensar en una categoría). Solo se pintan los chips cuyo
   grupo realmente tiene resultados en searchItems. */
const SEARCH_FILTER_BUCKETS = [
    { key: "paginas", label: "Páginas", icon: "layout-grid", groups: ["Páginas"] },
    { key: "programas", label: "Programas", icon: "radio", groups: ["Programas"] },
    { key: "podcasts", label: "Podcasts", icon: "mic-2", groups: ["Podcasts", "Podcast"] },
    { key: "servicios", label: "Servicios", icon: "briefcase", groups: ["Servicios"] },
    { key: "eventos", label: "Eventos", icon: "calendar-days", groups: ["Eventos"] },
    { key: "equipo", label: "Equipo", icon: "users", groups: ["Equipo"] },
    { key: "aliados", label: "Aliados", icon: "handshake", groups: ["Aliados"] },
    { key: "anuncios", label: "Anuncios", icon: "megaphone", groups: ["Anuncios"] },
];

/* Crea y conecta el panel global de búsqueda. */
function initSiteSearch() {
    /* Busca los puntos de entrada existentes en desktop y móvil. */
    const desktopSearch = document.querySelector(".search-input");
    const searchContainers = document.querySelectorAll(".search-container");

    /* Si no hay buscador en esta página, evita trabajo innecesario. */
    if (!desktopSearch) return;

    // OJO: `searchItems` es un `const` de nivel superior declarado por
    // search-items.php como script clasico -- eso lo deja accesible como
    // identificador global, pero NUNCA como propiedad de `window` (los
    // const/let de nivel superior no se enganchan a window, a diferencia de
    // `var`). Por eso se lee la variable directa y no `window.searchItems`
    // (ese bug dejaba el buscador siempre vacío, sin chips ni resultados).
    const allSearchItems = typeof searchItems !== "undefined" && Array.isArray(searchItems) ? searchItems : [];

    /* Solo ofrece chips de categorías que de verdad tienen contenido. */
    const availableGroups = new Set(allSearchItems.map((item) => item.group));
    const activeBuckets = SEARCH_FILTER_BUCKETS.filter((bucket) => bucket.groups.some((g) => availableGroups.has(g)));

    /* Crea el overlay que oscurece el fondo al buscar. */
    const overlay = document.createElement("div");
    overlay.className = "site-search-overlay";
    overlay.setAttribute("aria-hidden", "true");

    /* Crea el panel principal del buscador. */
    const panel = document.createElement("section");
    panel.className = "site-search-panel";
    panel.setAttribute("role", "dialog");
    panel.setAttribute("aria-modal", "true");
    panel.setAttribute("aria-label", "Buscar en Radio Doliv");

    /* Coloca el input grande, los chips de categoría y el contenedor de resultados. */
    panel.innerHTML = `
        <div class="site-search-box">
            <i data-lucide="search"></i>
            <input class="site-search-input" type="search" placeholder="Buscar en Radio Doliv..." autocomplete="off">
            <button class="site-search-close" type="button" aria-label="Cerrar buscador">
                <i data-lucide="x"></i>
            </button>
        </div>
        ${activeBuckets.length ? `
        <div class="site-search-filters" role="group" aria-label="Filtrar por categoría">
            <button type="button" class="site-search-filter is-active" data-filter="todos">
                <i data-lucide="sparkles"></i>Todos
            </button>
            ${activeBuckets.map((bucket) => `
                <button type="button" class="site-search-filter" data-filter="${bucket.key}">
                    <i data-lucide="${bucket.icon}"></i>${bucket.label}
                </button>
            `).join("")}
        </div>` : ""}
        <div class="site-search-results" aria-live="polite"></div>
    `;

    /* Inserta overlay y panel al final del body para que no dependan del HTML de cada página. */
    document.body.appendChild(overlay);
    document.body.appendChild(panel);

    /* Guarda referencias internas del panel. */
    const panelInput = panel.querySelector(".site-search-input");
    const resultsBox = panel.querySelector(".site-search-results");
    const closeButton = panel.querySelector(".site-search-close");
    const filterButtons = Array.from(panel.querySelectorAll(".site-search-filter"));

    /* Categoría activa ("todos" o la key de un bucket) y foco por teclado. */
    let activeFilterKey = "todos";
    let activeIndex = -1;

    /* Devuelve los grupos reales que corresponden al chip activo, o null si es "todos". */
    function getActiveGroups() {
        if (activeFilterKey === "todos") return null;
        const bucket = SEARCH_FILTER_BUCKETS.find((b) => b.key === activeFilterKey);
        return bucket ? bucket.groups : null;
    }

    /* Envuelve las coincidencias del texto buscado en <mark> (con el HTML ya escapado). */
    function highlight(rawText, query) {
        const safe = escapeSearchHtml(rawText);
        const terms = query.trim().split(/\s+/).filter((part) => part.length > 1);
        if (!terms.length) return safe;
        const pattern = terms.map((term) => term.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|");
        return safe.replace(new RegExp(`(${pattern})`, "ig"), "<mark>$1</mark>");
    }

    /* Pinta el estado inicial antes de que el usuario escriba (sin categoría activa). */
    function renderInitialState() {
        activeIndex = -1;
        resultsBox.innerHTML = `
            <div class="site-search-empty">
                <i data-lucide="search"></i>
                <h3>Escribe al menos 2 caracteres para buscar</h3>
                <p>O elige una categoría arriba para explorar sin escribir.</p>
            </div>
        `;
        window.RadioDoliv.utils.repaintIcons();
    }

    /* Pinta el estado visual cuando no hay coincidencias útiles. */
    function renderNoResults(query) {
        activeIndex = -1;
        resultsBox.innerHTML = `
            <div class="site-search-empty">
                <i data-lucide="search"></i>
                <h3>Sin resultados para "${escapeSearchHtml(query)}"</h3>
                <p>Intenta con otra categoría o palabras como podcast, servicios, eventos o equipo.</p>
            </div>
        `;
        window.RadioDoliv.utils.repaintIcons();
    }

    /* Agrupa y pinta resultados encontrados, con conteo y coincidencias resaltadas. */
    function renderResults(items, query) {
        activeIndex = -1;
        const grouped = items.reduce((groups, item) => {
            if (!groups[item.group]) groups[item.group] = [];
            groups[item.group].push(item);
            return groups;
        }, {});

        const countLabel = items.length === 1 ? "1 resultado" : `${items.length} resultados`;
        const countHtml = `<div class="site-search-count">${countLabel}</div>`;

        const groupsHtml = Object.entries(grouped).map(([group, itemsInGroup]) => `
            <div class="site-search-group">
                <div class="site-search-group-title"><span>${escapeSearchHtml(group)}</span></div>
                ${itemsInGroup.map((item) => `
                    <a class="site-search-result" href="${(window.SITE_BASE || "")}${item.url}">
                        <span class="site-search-result-icon"><i data-lucide="${item.icon}"></i></span>
                        <span class="site-search-result-copy">
                            <strong>${highlight(item.title, query)}</strong>
                            <span>${highlight(item.subtitle, query)}</span>
                            <small>${highlight(item.description, query)}</small>
                        </span>
                    </a>
                `).join("")}
            </div>
        `).join("");

        resultsBox.innerHTML = countHtml + groupsHtml;
        window.RadioDoliv.utils.repaintIcons();
    }

    /* Ejecuta la búsqueda local, combinando texto libre y categoría activa. */
    function runSearch() {
        const query = panelInput.value.trim();
        const normalizedQuery = normalizeSearchText(query);
        const activeGroups = getActiveGroups();

        const today = new Date();
        const localDateKey = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;
        let pool = allSearchItems.filter((item) => !item.eventDate || item.eventDate >= localDateKey);
        if (activeGroups) pool = pool.filter((item) => activeGroups.includes(item.group));

        if (normalizedQuery.length < 2) {
            /* Sin texto: si hay una categoría activa, se navega libremente por ella. */
            if (activeGroups) {
                if (pool.length === 0) {
                    renderNoResults(query);
                } else {
                    renderResults(pool.slice(0, 30), "");
                }
            } else {
                renderInitialState();
            }
            return;
        }

        const results = pool
            .map((item) => {
                const haystack = normalizeSearchText(`${item.title} ${item.subtitle} ${item.description} ${item.group} ${item.keywords}`);
                const title = normalizeSearchText(item.title);
                let score = 0;

                if (title === normalizedQuery) score += 40;
                if (title.startsWith(normalizedQuery)) score += 25;
                if (haystack.includes(normalizedQuery)) score += 10;
                normalizedQuery.split(/\s+/).forEach((part) => {
                    if (part.length > 1 && haystack.includes(part)) score += 4;
                });

                return { ...item, score };
            })
            .filter((item) => item.score > 0)
            .sort((a, b) => b.score - a.score || a.title.localeCompare(b.title))
            .slice(0, activeGroups ? 30 : 12);

        if (results.length === 0) {
            renderNoResults(query);
            return;
        }

        renderResults(results, query);
    }

    /* Mueve el foco visual entre resultados con flechas de teclado. */
    function moveActiveResult(delta) {
        const items = Array.from(resultsBox.querySelectorAll(".site-search-result"));
        if (!items.length) return;
        items[activeIndex]?.classList.remove("is-active");
        activeIndex = (activeIndex + delta + items.length) % items.length;
        const current = items[activeIndex];
        current.classList.add("is-active");
        current.scrollIntoView({ block: "nearest" });
    }

    /* Abre el panel y opcionalmente coloca texto inicial. */
    function openSearch(initialValue = "") {
        overlay.classList.add("is-open");
        panel.classList.add("is-open");
        overlay.setAttribute("aria-hidden", "false");
        document.body.classList.add("search-open");
        searchContainers.forEach((container) => container.classList.add("search-active"));
        panelInput.value = initialValue;
        runSearch();
        window.setTimeout(() => panelInput.focus(), 0);
        window.RadioDoliv.utils.repaintIcons();
        /* Atrapa el foco de teclado dentro del panel mientras esta abierto
           (antes Tab podia salirse hacia el contenido de fondo). */
        releaseFocusTrap = window.RadioDoliv.utils.trapFocus(panel);
    }

    /* Referencia del elemento que abrio el buscador, para devolverle el foco al cerrar. */
    let searchTrigger = null;
    let releaseFocusTrap = null;

    /* Cuando el trigger es el input de escritorio, devolverle el foco al
       cerrar dispara su propio listener de "focus" (mas abajo), que vuelve
       a abrir el panel de inmediato -- el boton "X" (y Escape, y el click
       en el overlay) parecian no hacer nada porque el panel se cerraba y
       se reabria en el mismo instante. Esta bandera le dice a ese listener
       que ignore el proximo foco porque lo provoco closeSearch(), no el
       usuario. */
    let suppressNextFocusOpen = false;

    /* Cierra el panel y limpia estados visuales. Devuelve el foco a quien
       abrio la busqueda (antes se perdia al cerrar). */
    function closeSearch() {
        overlay.classList.remove("is-open");
        panel.classList.remove("is-open");
        overlay.setAttribute("aria-hidden", "true");
        document.body.classList.remove("search-open");
        searchContainers.forEach((container) => container.classList.remove("search-active"));
        desktopSearch.value = "";
        if (releaseFocusTrap) {
            releaseFocusTrap();
            releaseFocusTrap = null;
        }
        if (searchTrigger) {
            // Solo activa la bandera si focus() realmente va a disparar un
            // evento "focus" nuevo (si el input ya estaba enfocado, focus()
            // no hace nada y la bandera se quedaria en true para siempre,
            // bloqueando la proxima apertura legitima).
            if (searchTrigger === desktopSearch && document.activeElement !== desktopSearch) {
                suppressNextFocusOpen = true;
            }
            searchTrigger.focus();
        }
    }

    /* Abre buscador desde el input de escritorio. */
    desktopSearch.addEventListener("focus", () => {
        if (suppressNextFocusOpen) { suppressNextFocusOpen = false; return; }
        searchTrigger = desktopSearch; openSearch(desktopSearch.value);
    });
    desktopSearch.addEventListener("input", () => { searchTrigger = desktopSearch; openSearch(desktopSearch.value); });

    /* Conecta cierre por botón y fondo. */
    closeButton.addEventListener("click", closeSearch);
    overlay.addEventListener("click", closeSearch);

    /* Cambia de categoría al tocar un chip, sin perder el texto ya escrito. */
    filterButtons.forEach((button) => {
        button.addEventListener("click", () => {
            activeFilterKey = button.dataset.filter;
            filterButtons.forEach((btn) => btn.classList.toggle("is-active", btn === button));
            runSearch();
        });
    });

    /* Ejecuta búsqueda al escribir en el panel grande, con debounce para no
       recalcular en cada tecla (antes corria sin limitar). */
    panelInput.addEventListener("input", window.RadioDoliv.utils.debounce(runSearch, 120));

    /* Navegación por teclado dentro del input: flechas mueven la selección,
       Enter abre el resultado activo (o el primero si aún no se navegó). */
    panelInput.addEventListener("keydown", (event) => {
        const items = resultsBox.querySelectorAll(".site-search-result");
        if (!items.length) return;

        if (event.key === "ArrowDown") {
            event.preventDefault();
            moveActiveResult(1);
        } else if (event.key === "ArrowUp") {
            event.preventDefault();
            moveActiveResult(-1);
        } else if (event.key === "Enter") {
            const target = activeIndex >= 0 ? items[activeIndex] : items[0];
            if (target) {
                event.preventDefault();
                target.click();
            }
        }
    });

    /* Cierra con Escape y abre con Ctrl+K o Cmd+K. */
    window.addEventListener("keydown", (event) => {
        const isShortcut = (event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k";
        if (isShortcut) {
            event.preventDefault();
            openSearch();
        }

        if (event.key === "Escape" && panel.classList.contains("is-open")) {
            closeSearch();
        }
    });

    /* Estado inicial listo para cuando se abra por primera vez. */
    renderInitialState();
}

/* Activa el buscador global. */
initSiteSearch();
