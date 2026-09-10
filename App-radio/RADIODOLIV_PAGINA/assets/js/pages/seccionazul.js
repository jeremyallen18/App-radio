/* ============================================
   pages/seccionazul.js
   Directorio de aliados. Las entradas se pintan en el servidor (ver
   pages/seccionazul.php) para que el directorio sea indexable y no
   parpadee vacio al cargar; aqui solo vive lo que necesita el
   navegador: filtrar por giro, revelar las entradas al hacer scroll y
   abrir la ficha completa con los datos de la isla JSON #sponsors-data.

   Envuelto en IIFE: el router de navegacion (ver core/page-router.js)
   reinyecta este script en cada visita, y sin la IIFE las
   declaraciones de nivel superior chocarian en la segunda visita.
   ============================================ */
(function () {
const pageSignal = window.RadioDoliv.pageSignal;
const { escapeHtml, repaintIcons } = window.RadioDoliv.utils;

const sponsorsDataEl = document.getElementById("sponsors-data");
const sponsors = sponsorsDataEl ? JSON.parse(sponsorsDataEl.textContent || "[]") : [];

const dirBody = document.getElementById("dir-body");
const dirEmpty = document.getElementById("dir-empty");
const sections = Array.from(document.querySelectorAll(".dir-section"));
const entries = Array.from(document.querySelectorAll(".dir-entry"));
const indexTabs = document.querySelectorAll(".dir-index-tab");

const dossier = document.getElementById("sz-dossier");
const dossierClose = document.getElementById("sz-dossier-close");
const dossierImg = document.getElementById("sz-dossier-img");
const dossierCategory = document.getElementById("sz-dossier-category");
const dossierTitle = document.getElementById("sz-dossier-title");
const dossierSubtitle = document.getElementById("sz-dossier-subtitle");
const dossierDescription = document.getElementById("sz-dossier-description");
const dossierSocials = document.getElementById("sz-dossier-socials");
const dossierMap = document.getElementById("sz-dossier-map");

/* ------------------------------------------------------------------
   Revelado por scroll: cada entrada entra con un desfase corto dentro
   de su propio giro (--stagger lo pone el PHP por posicion en la
   seccion), de modo que la lista se lee de arriba abajo en vez de
   aparecer entera de golpe.
   ------------------------------------------------------------------ */
const dirJoin = document.querySelector(".dir-join");
const revealTargets = [
    ...entries,
    ...document.querySelectorAll(".dir-section-head"),
    ...(dirJoin ? [dirJoin] : []),
];

if ("IntersectionObserver" in window && revealTargets.length) {
    const revealObserver = new IntersectionObserver((observed) => {
        observed.forEach((entry) => {
            if (!entry.isIntersecting) return;
            entry.target.classList.add("is-visible");
            revealObserver.unobserve(entry.target);
        });
    }, { threshold: 0.12, rootMargin: "0px 0px -6% 0px" });

    revealTargets.forEach((target) => revealObserver.observe(target));
} else {
    revealTargets.forEach((target) => target.classList.add("is-visible"));
}

/* ------------------------------------------------------------------
   Cifras del pie de imprenta: cuentan hacia arriba desde 0 al cargar,
   el mismo gesto de "cifra viva" que usan los paneles de patrocinio.
   No depende de scroll (el masthead siempre esta a la vista al
   entrar), solo espera a que termine la animacion de entrada del
   bloque para no competir con ella.
   ------------------------------------------------------------------ */
const countEls = document.querySelectorAll(".dir-colophon dd[data-count]");
if (countEls.length && !window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    countEls.forEach((el, index) => {
        const target = parseInt(el.dataset.count, 10);
        if (!Number.isFinite(target)) return;
        const duration = 900;
        const delay = 750 + index * 70;
        window.setTimeout(() => {
            const start = performance.now();
            function tick(now) {
                const progress = Math.min(1, (now - start) / duration);
                const eased = 1 - Math.pow(1 - progress, 3);
                el.textContent = String(Math.round(target * eased));
                if (progress < 1) window.requestAnimationFrame(tick);
                else el.textContent = String(target);
            }
            window.requestAnimationFrame(tick);
        }, delay);
    });
} else {
    countEls.forEach((el) => { el.textContent = el.dataset.count; });
}

/* ------------------------------------------------------------------
   Filtro por giro: oculta secciones completas en vez de re-pintar el
   HTML, asi que las entradas ya reveladas conservan su estado y no
   vuelven a animarse al ir y venir entre giros.
   ------------------------------------------------------------------ */
indexTabs.forEach((tab) => {
    tab.addEventListener("click", () => {
        indexTabs.forEach((other) => other.classList.remove("is-active"));
        tab.classList.add("is-active");

        const filter = tab.dataset.filter;
        let visible = 0;
        sections.forEach((section) => {
            const matches = filter === "todos" || section.dataset.category === filter;
            section.classList.toggle("is-filtered-out", !matches);
            if (matches) visible += 1;
        });

        if (dirEmpty) dirEmpty.hidden = visible > 0;

        /* Al elegir un giro concreto se sube al inicio del listado: de
           otro modo, filtrar desde el pie de la pagina dejaba al lector
           mirando el espacio vacio que quedaba debajo. */
        if (filter !== "todos") {
            const top = dirBody.getBoundingClientRect().top + window.scrollY - 120;
            window.scrollTo({ top, behavior: "smooth" });
        }
    });
});

/* ------------------------------------------------------------------
   Ficha completa
   ------------------------------------------------------------------ */
function openDossier(index) {
    const sponsor = sponsors[index];
    if (!sponsor) return;

    dossierImg.src = window.SITE_BASE + sponsor.image;
    dossierImg.alt = sponsor.name;
    dossierCategory.textContent = sponsor.category_label ?? sponsor.categoryLabel ?? "";
    dossierTitle.textContent = sponsor.name;
    dossierSubtitle.textContent = sponsor.subtitle;

    dossierDescription.innerHTML = (sponsor.description || [])
        .map((paragraph) => `<p>${escapeHtml(paragraph)}</p>`)
        .join("");

    dossierSocials.innerHTML = sponsor.socials.length
        ? sponsor.socials.map((social) => `
            <a href="${social.url}" target="_blank" rel="noopener noreferrer">
                <i data-lucide="${escapeHtml(social.icon)}"></i>
                <span>${escapeHtml(social.label)}</span>
            </a>`).join("")
        : '<p class="sz-dossier-empty">Sin redes registradas.</p>';

    dossierMap.innerHTML = sponsor.map
        ? `<iframe src="${sponsor.map}" title="Ubicación de ${escapeHtml(sponsor.name)}" allowfullscreen="" loading="lazy" referrerpolicy="no-referrer-when-downgrade"></iframe>`
        : '<p class="sz-dossier-empty">Sin ubicación registrada.</p>';

    dossier.classList.add("is-open");
    dossier.setAttribute("aria-hidden", "false");
    document.body.style.overflow = "hidden";
    repaintIcons();
}

function closeDossier() {
    dossier.classList.remove("is-open");
    dossier.setAttribute("aria-hidden", "true");
    document.body.style.overflow = "";
    // Descarga el iframe del mapa: si se queda montado, cada ficha abierta
    // deja corriendo un embed de Google Maps de fondo.
    dossierMap.innerHTML = "";
}

document.querySelectorAll("[data-sponsor-index]").forEach((button) => {
    button.addEventListener("click", () => openDossier(Number(button.dataset.sponsorIndex)));
});

dossierClose.addEventListener("click", closeDossier);
dossier.addEventListener("click", (event) => {
    if (event.target.matches("[data-close-sz='true']")) closeDossier();
});
window.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && dossier.classList.contains("is-open")) closeDossier();
}, { signal: pageSignal });
})();
