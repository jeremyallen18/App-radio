/* ============================================
   pages/anuncios-news.js
   Los dos carruseles del diseño portado de news4.html (hero de
   anuncios destacados + galeria "En imagenes"): crossfade simple con
   autoplay, sin jQuery ni MasterSlider -- el resto de la pagina (modal
   de detalle, zoom) sigue viviendo en pages/anuncios.js, sin tocar.

   Envuelto en IIFE + RadioDoliv.pageSignal por la misma razon que el
   resto de los scripts de pagina: el router (core/page-router.js)
   reinyecta este script en cada visita AJAX, y window/document nunca
   se destruyen entre navegaciones.
   ============================================ */
(function () {
    const ns = window.RadioDoliv || {};
    const pageSignal = ns.pageSignal;
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    function makeSlider({ root, slides, dots, prevBtn, nextBtn, autoplayMs }) {
        if (!root || slides.length < 2) return;

        let active = Math.max(0, slides.findIndex((el) => el.classList.contains("is-active")));
        if (active < 0) active = 0;
        let timer = null;
        let paused = false;

        function show(index) {
            active = ((index % slides.length) + slides.length) % slides.length;
            slides.forEach((slide, i) => slide.classList.toggle("is-active", i === active));
            if (dots) dots.forEach((dot, i) => dot.classList.toggle("is-active", i === active));
        }

        function restart() {
            if (timer) window.clearInterval(timer);
            timer = null;
            if (reducedMotion || !autoplayMs) return;
            timer = window.setInterval(() => {
                if (paused || document.hidden) return;
                show(active + 1);
            }, autoplayMs);
        }

        if (dots) {
            dots.forEach((dot, i) => {
                dot.addEventListener("click", () => { show(i); restart(); }, { signal: pageSignal });
            });
        }
        if (prevBtn) prevBtn.addEventListener("click", () => { show(active - 1); restart(); }, { signal: pageSignal });
        if (nextBtn) nextBtn.addEventListener("click", () => { show(active + 1); restart(); }, { signal: pageSignal });

        ["mouseenter", "focusin"].forEach((type) =>
            root.addEventListener(type, () => { paused = true; }, { signal: pageSignal }));
        ["mouseleave", "focusout"].forEach((type) =>
            root.addEventListener(type, () => { paused = false; }, { signal: pageSignal }));

        restart();
        if (pageSignal) {
            pageSignal.addEventListener("abort", () => { if (timer) window.clearInterval(timer); }, { once: true });
        }
    }

    const hero = document.querySelector(".anw-hero");
    if (hero) {
        makeSlider({
            root: hero,
            slides: Array.from(hero.querySelectorAll(".anw-hero-slide")),
            dots: Array.from(hero.querySelectorAll(".anw-dot")),
            prevBtn: document.getElementById("anwHeroPrev"),
            nextBtn: document.getElementById("anwHeroNext"),
            autoplayMs: 7000,
        });
    }

    const gallery = document.getElementById("anwGallerySlider");
    if (gallery) {
        makeSlider({
            root: gallery,
            slides: Array.from(gallery.querySelectorAll(".anw-slide")),
            dots: Array.from(gallery.querySelectorAll(".anw-gallery-thumb")),
            autoplayMs: 5000,
        });
    }

    /* ============================================================
       SCROLL REVEAL — un gesto distinto por seccion (ver el CSS en
       pages/anuncios-news.css: rise en el hero, listas escalonadas en
       los sidebars, "aterrizaje" con zoom en la grilla central, wipe
       de cortina en la galeria, columnas entrando desde direcciones
       opuestas en la fila de categorias, lineas que crecen). Un solo
       observer para todos los [data-reveal] de la pagina -- cada
       seccion ya trae su propia animacion por CSS, aqui solo se
       agrega/quita ".is-visible" segun entra o sale de pantalla.
       ============================================================ */
    if (ns.utils && typeof ns.utils.observeReveal === "function") {
        ns.utils.observeReveal(document.querySelectorAll(".anw [data-reveal]"), {
            signal: pageSignal,
            once: true,
            threshold: 0.1,
            rootMargin: "0px 0px -8% 0px",
        });
    }
})();
