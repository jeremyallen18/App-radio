/* ============================================
   core/utils.js
   Utilidades compartidas para evitar la logica duplicada que
   hoy existe entre components/search.js y components/chatbot.js
   (normalizacion de texto identica, repintado de iconos Lucide
   repetido en 6+ lugares, apertura/cierre de paneles flotantes
   reimplementado dos veces).
   ============================================ */
(function (ns) {
    // Quita acentos y pasa a minusculas, para comparar texto de busqueda.
    // Antes vivia duplicada como normalizeSearchText (search.js) y
    // normalizeDolivBotText (chatbot.js) con el mismo cuerpo exacto.
    ns.utils.normalizeText = function (value) {
        return String(value || "")
            .toLowerCase()
            .normalize("NFD")
            .replace(/[\u0300-\u036f]/g, "")
            .trim();
    };

    // Escapa HTML antes de interpolar texto dinamico en innerHTML (usado por
    // el resaltado de coincidencias del buscador, que antes insertaba
    // titulos/descripciones sin escapar).
    ns.utils.escapeHtml = function (value) {
        return String(value || "").replace(/[&<>"']/g, (char) => ({
            "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
        }[char]));
    };

    // Debounce simple: retrasa la ejecucion de fn hasta que pasen "wait" ms
    // sin nuevas llamadas. Se usa en busqueda (tecleo) y en el listener de
    // resize del menu movil, que hoy corren en cada evento sin limitar.
    ns.utils.debounce = function (fn, wait) {
        let timer = null;
        return function (...args) {
            clearTimeout(timer);
            timer = setTimeout(() => fn.apply(this, args), wait);
        };
    };

    // Repinta los iconos Lucide si la libreria ya cargo. Reemplaza el
    // patron "if (window.lucide) lucide.createIcons();" repetido en
    // theme.js, radio.js, mobile-menu.js, search.js y chatbot.js.
    ns.utils.repaintIcons = function () {
        if (window.lucide) {
            window.lucide.createIcons();
        }
    };

    // Atrapa el foco de teclado (Tab/Shift+Tab) dentro de containerEl
    // mientras esta abierto. Devuelve una funcion de limpieza que quita
    // el listener. Usado por components/flyout-panel.js para el panel de
    // busqueda y el chatbot, que hoy no atrapan el foco.
    ns.utils.trapFocus = function (containerEl) {
        function getFocusable() {
            return Array.from(
                containerEl.querySelectorAll(
                    'a[href], button:not([disabled]), input:not([disabled]), textarea:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])'
                )
            ).filter((el) => el.offsetParent !== null);
        }

        function onKeydown(event) {
            if (event.key !== "Tab") return;
            const focusable = getFocusable();
            if (!focusable.length) return;
            const first = focusable[0];
            const last = focusable[focusable.length - 1];
            if (event.shiftKey && document.activeElement === first) {
                event.preventDefault();
                last.focus();
            } else if (!event.shiftKey && document.activeElement === last) {
                event.preventDefault();
                first.focus();
            }
        }

        containerEl.addEventListener("keydown", onKeydown);
        return function cleanup() {
            containerEl.removeEventListener("keydown", onKeydown);
        };
    };

    // Aparicion progresiva por scroll: agrega .is-visible a cada elemento que
    // entra en el viewport y deja de observarlo. Reemplaza el bloque
    // IntersectionObserver que estaba copiado casi identico al final de
    // pages/index.js, conocenos.js, podcast.js y eventos.js.
    //
    // rootMargin negativo SOLO arriba (no abajo, como hacia la copia de
    // eventos.js con "0px 0px -38% 0px"): con margen negativo INFERIOR el
    // elemento tiene que subir un 38% de la ventana antes de contar como
    // visible, y la ultima seccion de una pagina corta nunca llega tan
    // arriba -- se quedaba en opacity:0 para siempre. Recortando por arriba
    // se consigue lo que se buscaba (que no se revele nada tapado por la
    // navbar) sin ese punto muerto al final de la pagina.
    //
    // Sin IntersectionObserver, o con prefers-reduced-motion, todo se marca
    // visible de inmediato: el contenido nunca depende del efecto.
    //
    // options.once (por defecto true): con false el gesto es REVERSIBLE --
    // el elemento vuelve a su estado oculto al salir del area de disparo,
    // asi la animacion se puede ver otra vez subiendo y bajando. Es el
    // comportamiento que ya usaba pages/conocenos.js a mano, y el que
    // necesita cualquier pagina de capitulos a pantalla completa.
    ns.utils.observeReveal = function (targets, options) {
        const elements = Array.from(targets || []);
        if (!elements.length) return null;

        const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
        if (reduced || !("IntersectionObserver" in window)) {
            elements.forEach((el) => el.classList.add("is-visible"));
            return null;
        }

        const once = !options || options.once !== false;

        const observer = new IntersectionObserver((entries, self) => {
            entries.forEach((entry) => {
                if (!once) {
                    entry.target.classList.toggle("is-visible", entry.isIntersecting);
                    return;
                }
                if (!entry.isIntersecting) return;
                entry.target.classList.add("is-visible");
                self.unobserve(entry.target);
            });
        }, {
            threshold: (options && options.threshold) || 0.08,
            rootMargin: (options && options.rootMargin) || "-80px 0px 0px 0px",
        });

        elements.forEach((el) => observer.observe(el));

        // El router AJAX destruye <main> en cada navegacion; sin esto el
        // observer seguiria vivo apuntando a nodos ya descartados.
        const signal = options && options.signal;
        if (signal) signal.addEventListener("abort", () => observer.disconnect(), { once: true });

        return observer;
    };

    // Envuelve una funcion "close" para que, al ejecutarse, regrese el foco
    // al elemento que abrio el panel (hoy el foco se pierde al cerrar el
    // buscador o el chatbot).
    ns.utils.restoreFocusOn = function (closeFn, triggerEl) {
        return function (...args) {
            const result = closeFn.apply(this, args);
            if (triggerEl && typeof triggerEl.focus === "function") {
                triggerEl.focus();
            }
            return result;
        };
    };
})(window.RadioDoliv);
