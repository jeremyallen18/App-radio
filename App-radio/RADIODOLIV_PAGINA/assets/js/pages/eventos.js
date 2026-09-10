/* ============================================
   pages/eventos.js
   Comportamiento de la cartelera:
     - capa ambiental (luces de escenario tenidas con el color del
       cartel que se este mirando),
     - escenario rotativo con cuenta regresiva tipografica,
     - indice editorial con visor del cartel siguiendo al cursor,
     - filtros con subrayado deslizante,
     - modal de detalle.

   Los datos vienen de PHP por las islas JSON #events-data /
   #event-ticket-link-data (ver pages/eventos.php).

   Envuelto en IIFE: el router de navegacion (ver core/page-router.js)
   reinyecta este script en cada visita, y sin la IIFE las
   declaraciones de nivel superior chocarian en la segunda visita.
   TODO lo que se ata a window/document usa RadioDoliv.pageSignal, y
   los timers, rAF y observadores se cancelan en su "abort": window
   nunca se destruye entre navegaciones AJAX, asi que cualquier cosa
   que quede viva seguiria corriendo sobre la pagina siguiente.
   ============================================ */
(function () {
    const ns = window.RadioDoliv;
    const pageSignal = ns.pageSignal;
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
    const finePointer = window.matchMedia("(hover: hover) and (pointer: fine)");

    /* --- Registro central de limpieza ------------------------------- */
    const cleanups = [];
    function onLeave(fn) { cleanups.push(fn); }
    pageSignal.addEventListener("abort", () => {
        cleanups.forEach((fn) => { try { fn(); } catch (error) { /* nada que hacer al salir */ } });
    }, { once: true });

    function everyTick(fn, ms) {
        const id = window.setInterval(fn, ms);
        onLeave(() => window.clearInterval(id));
        return id;
    }

    function readJson(id, fallback) {
        const el = document.getElementById(id);
        if (!el) return fallback;
        try {
            return JSON.parse(el.textContent || "null") ?? fallback;
        } catch (error) {
            return fallback;
        }
    }

    const events = readJson("events-data", []);
    const ticketLink = readJson("event-ticket-link-data", "#") || "#";

    /* ============================================================
       1. CAPA AMBIENTAL
       Canvas a pantalla completa detras del contenido, creado y
       destruido aqui (sin HTML nuevo en el PHP), igual que Conocenos
       hace con su globo de Vanta. Pinta tres focos de luz difusos con
       los colores dominantes del cartel activo.

       Se dibuja a MUY baja resolucion (unos 240px de ancho) y se estira
       por CSS al viewport: el propio escalado del navegador hace de
       desenfoque, asi que no hace falta ni filtro blur ni WebGL, y
       repintar tres degradados radiales por frame en un lienzo de ese
       tamano no se nota en el presupuesto de la pagina.
       ============================================================ */
    const ambient = (function () {
        const BRAND = [[0, 212, 255], [0, 112, 209], [10, 25, 49]];
        const RENDER_WIDTH = 240;

        let host = null;
        let canvas = null;
        let ctx = null;
        let frame = null;
        let palette = BRAND;
        let targetPalette = BRAND;
        let scrollEased = 0;
        let started = 0;

        function mount() {
            host = document.createElement("div");
            host.id = "ev-ambient";
            host.setAttribute("aria-hidden", "true"); // decorativo
            canvas = document.createElement("canvas");
            host.appendChild(canvas);
            document.body.prepend(host);
            ctx = canvas.getContext("2d");
            resize();
            started = performance.now();
        }

        function resize() {
            if (!canvas) return;
            const ratio = window.innerHeight / Math.max(1, window.innerWidth);
            canvas.width = RENDER_WIDTH;
            canvas.height = Math.max(80, Math.round(RENDER_WIDTH * ratio));
        }

        function scrollProgress() {
            const max = document.documentElement.scrollHeight - window.innerHeight;
            if (max <= 0) return 0;
            return Math.min(1, Math.max(0, window.scrollY / max));
        }

        function mix(a, b, t) {
            return [
                Math.round(a[0] + (b[0] - a[0]) * t),
                Math.round(a[1] + (b[1] - a[1]) * t),
                Math.round(a[2] + (b[2] - a[2]) * t),
            ];
        }

        function rgba(color, alpha) {
            return `rgba(${color[0]}, ${color[1]}, ${color[2]}, ${alpha})`;
        }

        function blob(x, y, radius, color, alpha) {
            const gradient = ctx.createRadialGradient(x, y, 0, x, y, radius);
            gradient.addColorStop(0, rgba(color, alpha));
            gradient.addColorStop(1, rgba(color, 0));
            ctx.fillStyle = gradient;
            ctx.fillRect(0, 0, canvas.width, canvas.height);
        }

        function paint(time) {
            if (!ctx) return;
            const w = canvas.width;
            const h = canvas.height;

            /* Transicion suave entre la paleta del cartel anterior y la
               del nuevo: cambiar de golpe daria un parpadeo de color en
               toda la pantalla al rotar el escenario. */
            palette = palette.map((color, i) => mix(color, targetPalette[i] || color, 0.04));

            const target = scrollProgress();
            scrollEased += (target - scrollEased) * 0.06; // inercia, como el globo de Conocenos
            const p = scrollEased;

            const t = reducedMotion.matches ? 0 : (time - started) / 1000;

            ctx.clearRect(0, 0, w, h);
            ctx.globalCompositeOperation = "lighter";

            /* Tres focos con periodos distintos (17s, 23s, 29s) para que
               el conjunto no se repita de forma reconocible. */
            blob(
                w * (0.24 + Math.sin(t / 17) * 0.1),
                h * (0.26 + Math.cos(t / 23) * 0.09 + p * 0.5),
                w * 0.62, palette[0], 0.24
            );
            blob(
                w * (0.78 + Math.cos(t / 23) * 0.1),
                h * (0.34 - p * 0.35 + Math.sin(t / 29) * 0.08),
                w * 0.55, palette[1], 0.2
            );
            blob(
                w * (0.5 + Math.sin(t / 29) * 0.16),
                h * (0.9 - p * 0.45),
                w * 0.7, palette[2], 0.16
            );

            ctx.globalCompositeOperation = "source-over";
        }

        function loop(time) {
            paint(time);
            frame = window.requestAnimationFrame(loop);
        }

        function start() {
            if (!finePointer.matches && window.innerWidth < 640) return; // en moviles chicos no vale el gasto
            mount();
            if (reducedMotion.matches) {
                paint(performance.now()); // una sola pasada, sin animacion
            } else {
                frame = window.requestAnimationFrame(loop);
            }
            window.addEventListener("resize", resize, { passive: true, signal: pageSignal });
            onLeave(() => {
                if (frame) window.cancelAnimationFrame(frame);
                if (host) host.remove();
                host = canvas = ctx = null;
            });
        }

        /* Muestrea los colores dominantes de un cartel. La imagen es del
           mismo origen que la pagina, asi que el canvas no queda
           contaminado y getImageData funciona. Si algo falla (imagen aun
           sin decodificar, origen distinto en el futuro), se vuelve a la
           paleta de marca: el fondo nunca es un punto unico de fallo. */
        function sample(img) {
            if (!img || !img.complete || !img.naturalWidth) return BRAND;
            try {
                const size = 12;
                const off = document.createElement("canvas");
                off.width = off.height = size;
                const offCtx = off.getContext("2d", { willReadFrequently: true });
                offCtx.drawImage(img, 0, 0, size, size);
                const data = offCtx.getImageData(0, 0, size, size).data;

                const picks = [];
                for (let i = 0; i < data.length; i += 4) {
                    const r = data[i], g = data[i + 1], b = data[i + 2];
                    const max = Math.max(r, g, b);
                    const min = Math.min(r, g, b);
                    const light = (max + min) / 2 / 255;
                    const sat = max === min ? 0 : (max - min) / (255 - Math.abs(max + min - 255));
                    /* Se descartan los casi negros y los casi blancos: un
                       cartel tiene mucho de ambos (fondo y texto) y no
                       dicen nada del color del evento. */
                    if (light < 0.18 || light > 0.86 || sat < 0.25) continue;
                    picks.push({ color: [r, g, b], score: sat * (1 - Math.abs(light - 0.55)) });
                }
                if (picks.length < 3) return BRAND;
                picks.sort((a, b) => b.score - a.score);
                const dominant = [picks[0].color, picks[Math.floor(picks.length / 2)].color, picks[picks.length - 1].color];
                /* Se mezcla cada color dominante a medio camino con el de
                   marca. Sin esto, un cartel amarillo y rojo pinta la pagina
                   entera de un verde sucio: el fondo deja de ser "luces de
                   escenario del sitio" y pasa a ser un lavado de color ajeno
                   a la identidad. Mezclado, el evento tine la luz pero la
                   luz sigue siendo azul de Radio Doliv. */
                return dominant.map((color, i) => mix(BRAND[i], color, 0.5));
            } catch (error) {
                return BRAND;
            }
        }

        return {
            start,
            /* Lo llama el escenario en cada cambio de cartel. */
            usePoster(img) {
                targetPalette = sample(img);
            },
        };
    })();

    ambient.start();

    /* ============================================================
       2. MODAL DE DETALLE
       ============================================================ */
    const modal = document.getElementById("event-detail-modal");
    let openDetail = () => {};

    if (modal) {
        const fields = {
            image: document.getElementById("event-detail-image"),
            when: document.getElementById("event-detail-when"),
            title: document.getElementById("event-detail-title"),
            artist: document.getElementById("event-detail-artist"),
            location: document.getElementById("event-detail-location"),
            schedule: document.getElementById("event-detail-schedule"),
            description: document.getElementById("event-detail-description"),
            ticket: document.getElementById("event-ticket-link"),
        };
        const copyButton = document.getElementById("event-copy-link");

        let releaseFocusTrap = null;
        let lastTrigger = null;

        openDetail = function (index, trigger) {
            const item = events[index];
            if (!item) return;

            fields.image.src = (window.SITE_BASE || "") + item.image;
            fields.image.alt = "Cartel de " + item.title;
            fields.when.textContent = item.event_date
                ? `${item.weekday} ${item.day} ${item.month} ${item.year}`
                : "Fecha por confirmar";
            fields.title.textContent = item.title;
            fields.artist.textContent = item.artist || "";
            fields.location.textContent = item.location;
            fields.schedule.textContent = item.time;
            fields.description.textContent = item.description;
            fields.ticket.href = ticketLink;

            modal.setAttribute("aria-hidden", "false");
            modal.classList.add("is-open");
            document.body.style.overflow = "hidden";

            /* El foco entra al modal y se queda dentro. trapFocus y
               restoreFocusOn ya existian en core/utils.js (los usa el
               buscador) y esta pagina no los aprovechaba: se podia
               tabular "por detras" del modal hasta la pagina. */
            lastTrigger = trigger || document.activeElement;
            releaseFocusTrap = ns.utils.trapFocus(modal);
            modal.querySelector(".ev-modal-close")?.focus({ preventScroll: true });

            ns.utils.repaintIcons();
        };

        function closeDetail() {
            if (modal.getAttribute("aria-hidden") === "true") return;
            modal.setAttribute("aria-hidden", "true");
            modal.classList.remove("is-open");
            document.body.style.overflow = "";
            if (releaseFocusTrap) {
                releaseFocusTrap();
                releaseFocusTrap = null;
            }
            if (lastTrigger && typeof lastTrigger.focus === "function") {
                lastTrigger.focus({ preventScroll: true });
            }
            lastTrigger = null;
        }

        /* Un solo listener delegado abre el modal desde cualquier
           disparador con [data-event-index] (fila del indice, cartel del
           escenario). Los controles que viven DENTRO de un disparador y
           hacen otra cosa (boletos) se marcan con [data-ev-stop] y se
           descartan aqui, en vez de depender de que cada uno recuerde
           llamar a stopPropagation. */
        document.addEventListener("click", (event) => {
            if (event.target.closest("[data-ev-stop]")) return;
            const trigger = event.target.closest("[data-event-index]");
            if (!trigger) return;
            openDetail(Number(trigger.dataset.eventIndex), trigger);
        }, { signal: pageSignal });

        modal.addEventListener("click", (event) => {
            if (event.target === modal || event.target.closest(".ev-modal-close")) closeDetail();
        }, { signal: pageSignal });

        document.addEventListener("keydown", (event) => {
            if (event.key === "Escape") closeDetail();
        }, { signal: pageSignal });

        if (copyButton) {
            const label = copyButton.querySelector("[data-copy-label]");
            let resetTimer = null;
            copyButton.addEventListener("click", async () => {
                if (!navigator.clipboard) return;
                try {
                    await navigator.clipboard.writeText(window.location.href);
                } catch (error) {
                    return; // permiso denegado: no fingir que se copio
                }
                if (!label) return;
                label.textContent = "Enlace copiado";
                copyButton.classList.add("is-copied");
                window.clearTimeout(resetTimer);
                resetTimer = window.setTimeout(() => {
                    label.textContent = "Copiar enlace";
                    copyButton.classList.remove("is-copied");
                }, 2000);
            }, { signal: pageSignal });
            onLeave(() => window.clearTimeout(resetTimer));
        }
    }

    /* ============================================================
       3. ESCENARIO (capitulo 2)
       ============================================================ */
    const postersWrap = document.getElementById("evPosters");
    if (postersWrap) {
        const posters = Array.from(postersWrap.querySelectorAll(".ev-poster"));
        const slots = Array.from(document.querySelectorAll(".ev-stage-title-slot"));
        const kicker = document.querySelector("[data-stage-kicker]");
        const counter = document.getElementById("evStageCurrent");
        const count = document.getElementById("evCount");
        const AUTOPLAY_MS = 7000;

        let active = 0;
        let paused = false;

        function activeEvent() {
            const poster = posters[active];
            return poster ? events[Number(poster.dataset.eventIndex)] : null;
        }

        function show(index) {
            const target = ((index % posters.length) + posters.length) % posters.length;
            if (target === active) return;
            active = target;

            posters.forEach((poster, i) => poster.classList.toggle("is-active", i === active));
            slots.forEach((slot, i) => {
                const isActive = i === active;
                slot.classList.toggle("is-active", isActive);
                /* inert saca de golpe todo el subarbol del orden de
                   tabulacion y del arbol de accesibilidad, sin la
                   combinacion invalida de aria-hidden sobre un nodo que
                   sigue siendo enfocable. */
                slot.toggleAttribute("inert", !isActive);
            });

            if (counter) counter.textContent = String(active + 1).padStart(2, "0");
            if (kicker) kicker.textContent = active === 0 ? "Próximo evento" : "También en cartelera";

            ambient.usePoster(posters[active].querySelector("img"));
            tick();
        }

        /* --- Cuenta regresiva ------------------------------------- */
        const units = count ? {
            d: count.querySelector('[data-clock="d"]'),
            h: count.querySelector('[data-clock="h"]'),
            m: count.querySelector('[data-clock="m"]'),
            s: count.querySelector('[data-clock="s"]'),
        } : null;

        /* Solo se repinta (y solo late) el digito que cambio: sin esta
           comparacion los cuatro numeros se reescriben y se reaniman cada
           segundo, que es un parpadeo constante imposible de ignorar en
           una tipografia de este tamano. */
        function paintUnit(key, value) {
            const cell = units && units[key];
            if (!cell) return;
            const text = String(value).padStart(2, "0");
            if (cell.textContent === text) return;
            cell.textContent = text;
            if (reducedMotion.matches) return;
            const unit = cell.parentElement;
            unit.classList.remove("is-ticking");
            void unit.offsetWidth; // reinicia la animacion
            unit.classList.add("is-ticking");
        }

        function tick() {
            if (!count) return;
            const item = activeEvent();
            const date = item && item.event_date;
            /* Se cambia el CONTENIDO de la fila, no su existencia:
               ocultar el reloj encogia el capitulo cada vez que el
               escenario pasaba de un evento con fecha a uno sin ella. */
            count.classList.toggle("is-tbd", !date);
            if (!date) return;

            let remaining = Math.max(0, new Date(`${date}T00:00:00`).getTime() - Date.now());
            const days = Math.floor(remaining / 86400000);
            remaining -= days * 86400000;
            const hours = Math.floor(remaining / 3600000);
            remaining -= hours * 3600000;
            const minutes = Math.floor(remaining / 60000);
            remaining -= minutes * 60000;

            paintUnit("d", days);
            paintUnit("h", hours);
            paintUnit("m", minutes);
            paintUnit("s", Math.floor(remaining / 1000));
        }

        tick();
        everyTick(tick, 1000);
        ambient.usePoster(posters[0]?.querySelector("img"));

        /* Si el primer cartel aun no habia decodificado al arrancar, su
           paleta sale de la marca; al cargar se vuelve a muestrear. */
        const firstImage = posters[0]?.querySelector("img");
        if (firstImage && !firstImage.complete) {
            firstImage.addEventListener("load", () => ambient.usePoster(firstImage), { once: true, signal: pageSignal });
        }

        /* --- Controles -------------------------------------------- */
        document.getElementById("evStagePrev")?.addEventListener("click", () => { show(active - 1); restart(); }, { signal: pageSignal });
        document.getElementById("evStageNext")?.addEventListener("click", () => { show(active + 1); restart(); }, { signal: pageSignal });
        document.getElementById("evStageDetail")?.addEventListener("click", (event) => {
            const item = posters[active];
            if (item) openDetail(Number(item.dataset.eventIndex), event.currentTarget);
        }, { signal: pageSignal });

        let autoplay = null;
        function restart() {
            if (autoplay) window.clearInterval(autoplay);
            autoplay = null;
            if (posters.length < 2 || reducedMotion.matches) return;
            autoplay = everyTick(() => {
                /* Ni con la pestana en segundo plano, ni mientras el
                   usuario tiene el cursor o el foco encima leyendo. */
                if (paused || document.hidden) return;
                show(active + 1);
            }, AUTOPLAY_MS);
        }

        const stageSection = postersWrap.closest(".ev-chapter") || postersWrap;
        ["mouseenter", "focusin"].forEach((type) =>
            stageSection.addEventListener(type, () => { paused = true; }, { signal: pageSignal }));
        ["mouseleave", "focusout"].forEach((type) =>
            stageSection.addEventListener(type, () => { paused = false; }, { signal: pageSignal }));

        restart();

        /* --- Parallax del cartel con el cursor --------------------- */
        if (finePointer.matches && !reducedMotion.matches) {
            postersWrap.addEventListener("mousemove", (event) => {
                const rect = postersWrap.getBoundingClientRect();
                postersWrap.style.setProperty("--tilt-x", ((event.clientX - rect.left) / rect.width - 0.5).toFixed(3));
                postersWrap.style.setProperty("--tilt-y", ((event.clientY - rect.top) / rect.height - 0.5).toFixed(3));
            }, { signal: pageSignal });

            postersWrap.addEventListener("mouseleave", () => {
                postersWrap.style.setProperty("--tilt-x", "0");
                postersWrap.style.setProperty("--tilt-y", "0");
            }, { signal: pageSignal });
        }
    }

    /* ============================================================
       4. INDICE: VISOR DEL CARTEL QUE SIGUE AL CURSOR
       Solo con puntero fino y sin prefers-reduced-motion. En tactil no
       hay hover, y para eso cada fila lleva su propia miniatura (ver
       .ev-row-thumb en inc/components/event-row.php).
       ============================================================ */
    const peek = document.getElementById("evPeek");
    const indexList = document.getElementById("evIndex");

    if (peek && indexList && finePointer.matches && !reducedMotion.matches) {
        const peekImage = document.getElementById("evPeekImage");
        const size = peek.getBoundingClientRect();
        let targetX = 0, targetY = 0, x = 0, y = 0;
        let frame = null;
        let visible = false;

        /* El visor persigue al cursor con un lerp en rAF en vez de
           pegarse al pixel exacto en cada mousemove: asi tiene inercia
           (se lee como un objeto que sigue, no como un cursor gigante) y
           ademas el trabajo queda limitado a un frame, pase lo que pase
           con la frecuencia de los eventos del raton. */
        function loop() {
            x += (targetX - x) * 0.14;
            y += (targetY - y) * 0.14;
            peek.style.setProperty("--peek-x", `${x.toFixed(1)}px`);
            peek.style.setProperty("--peek-y", `${y.toFixed(1)}px`);
            frame = window.requestAnimationFrame(loop);
        }

        function place(event) {
            const w = peek.offsetWidth || size.width || 240;
            const h = peek.offsetHeight || size.height || 240;
            /* Arriba y a la derecha del cursor, no centrado en el: centrado
               tapaba justo el titulo de la fila que se esta senalando, que
               es lo que el usuario esta leyendo. Y siempre dentro de la
               ventana, sin salirse por ningun borde. */
            targetX = Math.min(event.clientX + 36, window.innerWidth - w - 16);
            targetY = Math.min(Math.max(event.clientY - h + 24, 16), window.innerHeight - h - 16);
        }

        indexList.addEventListener("mousemove", (event) => {
            const row = event.target.closest(".ev-row");
            if (!row) return;
            place(event);
            const poster = row.dataset.evPoster;
            if (poster && peekImage.getAttribute("src") !== poster) {
                peekImage.src = poster;
                peekImage.alt = "";
            }
            if (!visible) {
                visible = true;
                peek.classList.add("is-visible");
                /* El primer place() ya fijo el destino; se salta la
                   inercia en la aparicion para que no entre volando desde
                   la esquina superior izquierda. */
                x = targetX;
                y = targetY;
                if (!frame) frame = window.requestAnimationFrame(loop);
            }
        }, { signal: pageSignal });

        indexList.addEventListener("mouseleave", () => {
            visible = false;
            peek.classList.remove("is-visible");
            if (frame) {
                window.cancelAnimationFrame(frame);
                frame = null;
            }
        }, { signal: pageSignal });

        onLeave(() => { if (frame) window.cancelAnimationFrame(frame); });
    }

    /* ============================================================
       5. FILTROS
       Cada fila trae su bucket ya calculado desde PHP (data-ev-bucket,
       ver inc/components/event-row.php). "Este mes" incluye "esta
       semana", igual que una vista de calendario mensual incluye la
       semana en curso.
       ============================================================ */
    const filters = Array.from(document.querySelectorAll(".ev-filter"));
    const rows = Array.from(document.querySelectorAll("#evIndex .ev-row"));
    const filterEmpty = document.getElementById("evFilterEmpty");
    const ink = document.getElementById("evFiltersInk");

    if (filters.length && rows.length) {
        function matches(bucket, filter) {
            if (filter === "all") return true;
            if (filter === "month") return bucket === "month" || bucket === "week";
            return bucket === filter;
        }

        /* Un filtro que no puede dar ningun resultado se marca apagado de
           entrada, para no ofrecer una pestana que solo lleva a una lista
           vacia. */
        filters.forEach((tab) => {
            const empty = !rows.some((row) => matches(row.dataset.evBucket, tab.dataset.evFilter));
            tab.classList.toggle("is-empty", empty);
        });

        function moveInk(tab) {
            if (!ink || !tab) return;
            ink.style.width = `${tab.offsetWidth}px`;
            ink.style.transform = `translateX(${tab.offsetLeft}px)`;
        }

        function applyFilter(filter) {
            let visibleRows = 0;
            rows.forEach((row) => {
                const show = matches(row.dataset.evBucket, filter);
                row.classList.toggle("is-filtered-out", !show);
                if (show) {
                    visibleRows++;
                    /* Se renumera lo que queda a la vista: un indice que
                       salta 01, 04, 07 delata el filtro en vez de leerse
                       como una lista. */
                    row.querySelector(".ev-row-index").textContent = String(visibleRows).padStart(2, "0");
                    row.style.setProperty("--row", visibleRows);
                }
            });
            if (filterEmpty) filterEmpty.hidden = visibleRows > 0;
        }

        filters.forEach((tab) => {
            tab.addEventListener("click", () => {
                filters.forEach((other) => {
                    const isCurrent = other === tab;
                    other.classList.toggle("is-active", isCurrent);
                    other.setAttribute("aria-selected", isCurrent ? "true" : "false");
                });
                moveInk(tab);
                applyFilter(tab.dataset.evFilter);
            }, { signal: pageSignal });
        });

        moveInk(document.querySelector(".ev-filter.is-active"));
        /* El subrayado se mide en pixeles, asi que hay que recolocarlo
           cuando cambia el ancho (los filtros se reacomodan en varias
           lineas en pantallas chicas). */
        const remeasure = ns.utils.debounce(() => moveInk(document.querySelector(".ev-filter.is-active")), 150);
        window.addEventListener("resize", remeasure, { passive: true, signal: pageSignal });

        /* Las fuentes llegan despues del primer pintado y cambian el ancho
           de los filtros; sin esto el subrayado queda corrido. */
        if (document.fonts && document.fonts.ready) {
            document.fonts.ready.then(() => moveInk(document.querySelector(".ev-filter.is-active")));
        }
    }

    /* ============================================================
       6. APARICION POR SCROLL
       Reversible (once:false), igual que Conocenos: el gesto se puede
       ver otra vez subiendo y bajando, que es media gracia de una
       pagina de capitulos.
       ============================================================ */
    /* Un solo sistema para toda la pagina: [data-reveal] para los bloques
       que animan a sus hijos y [data-reveal-item] para elementos sueltos.
       Ya no se usan las clases globales .scroll-* de base/animations.css,
       que traen su propio gesto vertical y chocaban con la entrada
       lateral de esta pagina. */
    ns.utils.observeReveal(
        document.querySelectorAll("[data-reveal], [data-reveal-item]"),
        { signal: pageSignal, once: false, threshold: 0, rootMargin: "0px 0px -22% 0px" }
    );

    /* Navbar solida al hacer scroll (mismo comportamiento que inicio). */
    const navbar = document.getElementById("siteNavbar");
    if (navbar) {
        const updateNavbar = () => navbar.classList.toggle("is-scrolled", window.scrollY > 40);
        window.addEventListener("scroll", updateNavbar, { passive: true, signal: pageSignal });
        updateNavbar();
    }

    ns.utils.repaintIcons();
})();
