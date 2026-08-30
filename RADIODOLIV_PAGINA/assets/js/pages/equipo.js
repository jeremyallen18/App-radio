/* ============================================
   pages/equipo.js
   Panel de tarjetas (grilla de 3 columnas, ver equipo-roster.css): cada
   integrante es una tarjeta con foto en blanco y negro, nombre, rol y
   bio corta, que abre su ficha completa al hacer click. Los datos vienen
   de PHP via la isla JSON #team-data (ver pages/equipo.php). El dialogo
   de ficha (#roster-modal) es un unico elemento que vive siempre en el
   DOM -- nunca se destruye entre categorias, solo se repinta su
   contenido (ver showMember).

   Envuelto en IIFE: el router de navegacion (ver core/page-router.js)
   reinyecta este script en cada visita, y sin la IIFE las declaraciones
   de nivel superior chocarian en la segunda visita.
   ============================================ */
(function () {
const pageSignal = window.RadioDoliv.pageSignal;
const teamDataEl = document.getElementById("team-data");
const initialLocutorDataEl = document.getElementById("initial-locutor-data");
const rawTeamMembers = teamDataEl ? JSON.parse(teamDataEl.textContent || "[]") : [];
const { escapeHtml, repaintIcons } = window.RadioDoliv.utils;

const teamMembers = rawTeamMembers.map((member) => ({
    ...member,
    image: window.SITE_BASE + member.image,
}));

const teamReel = document.getElementById("team-reel");
const toggleButtons = document.querySelectorAll(".team-toggle-option");

const rosterModal = document.getElementById("roster-modal");
const rosterModalClose = document.getElementById("roster-modal-close");
const modalImg = document.getElementById("roster-modal-img");
const modalName = document.getElementById("roster-modal-name");
const modalRole = document.getElementById("roster-modal-role");
const modalBio = document.getElementById("roster-modal-bio");
const modalPath = document.getElementById("roster-modal-path");
const modalInterests = document.getElementById("roster-modal-interests");
const zoomOutBtn = document.getElementById("roster-zoom-out");
const zoomResetBtn = document.getElementById("roster-zoom-reset");
const zoomInBtn = document.getElementById("roster-zoom-in");

let modalZoom = 1;
let cardObserver = null;

/* El minimo es 1 (no 0.75) porque el retrato de la ficha ahora va a
   sangre completa con object-fit:cover: por debajo de 1 la foto se
   encogeria dejando ver el degradado del contenedor alrededor, que se
   lee como un error de maquetado en vez de un alejamiento. */
function setModalZoom(value) {
    modalZoom = Math.min(2.4, Math.max(1, value));
    modalImg.style.transform = `scale(${modalZoom})`;
}

function renderReel(members) {
    if (cardObserver) cardObserver.disconnect();

    if (!members.length) {
        teamReel.classList.add("is-empty");
        teamReel.innerHTML = `
            <div class="team-reel-empty" data-reveal>
                <i data-lucide="newspaper"></i>
                <h2>¡Próximamente!</h2>
                <p>La sección de reporteros se revelará más tarde.</p>
            </div>
        `;
        repaintIcons();
        requestAnimationFrame(() => teamReel.querySelector("[data-reveal]")?.classList.add("is-visible"));
        return;
    }

    teamReel.classList.remove("is-empty");

    teamReel.innerHTML = members.map((member) => `
        <article class="team-card" data-slug="${member.slug}"
            style="--member-accent: ${member.accent || "var(--cyan-glow)"};">
            <div class="team-card-media">
                <img src="${member.image}" alt="${escapeHtml(member.name)}" loading="lazy">
            </div>
            <h2 class="team-card-name">${escapeHtml(member.name)}</h2>
            <p class="team-card-role">${escapeHtml(member.role)}</p>
            ${member.short ? `<p class="team-card-desc">${escapeHtml(member.short)}</p>` : ""}
            <button type="button" class="team-card-link" data-slug="${member.slug}">
                Ver ficha completa <i data-lucide="arrow-up-right"></i>
            </button>
        </article>
    `).join("");

    teamReel.querySelectorAll("[data-slug]").forEach((el) => {
        el.addEventListener("click", () => openMemberBySlug(el.dataset.slug));
    });

    repaintIcons();

    /* Cada tarjeta se revela con un fade-up escalonado al entrar en
       pantalla, en vez de aparecer toda la grilla de golpe. */
    const cards = teamReel.querySelectorAll(".team-card");
    if ("IntersectionObserver" in window) {
        cardObserver = new IntersectionObserver((entries) => {
            entries.forEach((entry) => {
                if (entry.isIntersecting) entry.target.classList.add("is-visible");
            });
        }, { threshold: 0.15, rootMargin: "0px 0px -6% 0px" });
        cards.forEach((card, index) => {
            card.style.transitionDelay = `${Math.min(index % 6, 5) * 70}ms`;
            cardObserver.observe(card);
        });
    } else {
        cards.forEach((card) => card.classList.add("is-visible"));
    }
}

function renderCategory(category) {
    renderReel(teamMembers.filter((member) => member.category === category));
}

function showMember(member) {
    if (!member) return;
    rosterModal.style.setProperty("--member-accent", member.accent || "var(--cyan-glow)");
    modalImg.src = member.image;
    modalImg.alt = member.name;
    setModalZoom(1);
    modalName.textContent = member.name;
    modalRole.textContent = member.role;
    modalBio.innerHTML = member.bio.map((paragraph) => `<p>${escapeHtml(paragraph)}</p>`).join("");
    modalPath.innerHTML = member.path.map((item) => `<li>${escapeHtml(item)}</li>`).join("");
    modalInterests.innerHTML = member.interests.map((item) => `<li>${escapeHtml(item)}</li>`).join("");
    rosterModal.classList.add("is-open");
    rosterModal.setAttribute("aria-hidden", "false");
    document.body.style.overflow = "hidden";
    repaintIcons();
}

function openMemberBySlug(slug) {
    showMember(teamMembers.find((member) => member.slug === slug));
}

function closeModal() {
    rosterModal.classList.remove("is-open");
    rosterModal.setAttribute("aria-hidden", "true");
    document.body.style.overflow = "";
}

toggleButtons.forEach((button) => {
    button.addEventListener("click", () => {
        toggleButtons.forEach((btn) => {
            btn.classList.remove("is-active");
            btn.setAttribute("aria-selected", "false");
        });
        button.classList.add("is-active");
        button.setAttribute("aria-selected", "true");
        renderCategory(button.dataset.filter);
        window.scrollTo({ top: teamReel.getBoundingClientRect().top + window.scrollY - 24, behavior: "smooth" });
    });
});

rosterModalClose.addEventListener("click", closeModal);
zoomOutBtn.addEventListener("click", () => setModalZoom(modalZoom - 0.15));
zoomResetBtn.addEventListener("click", () => setModalZoom(1));
zoomInBtn.addEventListener("click", () => setModalZoom(modalZoom + 0.15));
rosterModal.addEventListener("click", (event) => {
    if (event.target.matches("[data-close-roster='true']")) closeModal();
});
window.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && rosterModal.classList.contains("is-open")) closeModal();
}, { signal: pageSignal });

/* --- Barra de progreso de scroll: porcentaje de avance en toda la
   pagina, actualizada en cada frame de scroll (throttle via rAF). --- */
const scrollProgressBar = document.getElementById("team-scroll-progress-bar");
if (scrollProgressBar) {
    let progressFrame = null;
    function updateScrollProgress() {
        progressFrame = null;
        const scrollable = document.documentElement.scrollHeight - window.innerHeight;
        const ratio = scrollable > 0 ? window.scrollY / scrollable : 0;
        scrollProgressBar.style.width = `${Math.min(100, Math.max(0, ratio * 100))}%`;
    }
    updateScrollProgress();
    window.addEventListener("scroll", () => {
        if (progressFrame) return;
        progressFrame = requestAnimationFrame(updateScrollProgress);
    }, { passive: true, signal: pageSignal });
    window.addEventListener("resize", updateScrollProgress, { signal: pageSignal });
}

/* Revela el encabezado por scroll (mismo mecanismo [data-reveal] que
   servicios.php/conocenos.php). */
const topReveals = document.querySelectorAll(".team-hero-band[data-reveal]");
if ("IntersectionObserver" in window && topReveals.length) {
    const topObserver = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
            if (!entry.isIntersecting) return;
            entry.target.classList.add("is-visible");
            topObserver.unobserve(entry.target);
        });
    }, { threshold: 0.2, rootMargin: "0px 0px -10% 0px" });
    topReveals.forEach((target) => topObserver.observe(target));
} else {
    topReveals.forEach((target) => target.classList.add("is-visible"));
}

renderCategory("locutores");

/* Si llegamos con ?locutor=slug (desde el reproductor de inicio), abrimos
   directo su ficha -- el equivalente a su seccion "Conoceme" sin obligar
   al oyente a buscarlo en el carrete. */
const initialLocutorSlug = initialLocutorDataEl ? JSON.parse(initialLocutorDataEl.textContent || '""') : "";
if (initialLocutorSlug) {
    const initialMember = teamMembers.find((member) => member.slug === initialLocutorSlug);
    if (initialMember && initialMember.category === "locutores") {
        showMember(initialMember);
    }
}
})();
