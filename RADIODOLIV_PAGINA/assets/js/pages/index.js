/* ============================================
   pages/index.js
   Comportamiento de la pagina de inicio: variables CSS por-item
   (--stagger, --show-accent, background-image) aplicadas desde sus
   data-attributes, boton de reproducir radio, volver arriba, navbar
   solida al hacer scroll, boton "imantado", aparicion progresiva de
   secciones, "Suena ahora", modal "Pide tu cancion" y carrusel de
   anuncios de programas.

   Envuelto en IIFE porque el router de navegacion (ver
   core/page-router.js) reinyecta este script en cada visita a esta
   pagina -- sin la IIFE, las declaraciones "const"/"let" de nivel
   superior chocarian ("ya declarado") en la segunda visita. Los
   listeners en window/document usan RadioDoliv.pageSignal para
   limpiarse solos cuando se navega a otra pagina (ver
   page-router.js), evitando que se acumulen en visitas repetidas.
   ============================================ */
(function () {
const pageSignal = window.RadioDoliv.pageSignal;

/* Variables CSS por-item, calculadas por PHP y pasadas via data-*
   (ver index.php) para no mezclar CSS dentro del HTML. */
document.querySelectorAll("[data-stagger]").forEach((el) => {
    el.style.setProperty("--stagger", el.dataset.stagger);
});
document.querySelectorAll("[data-show-accent]").forEach((el) => {
    el.style.setProperty("--show-accent", el.dataset.showAccent);
});
document.querySelectorAll("[data-bg]").forEach((el) => {
    el.style.backgroundImage = `url('${el.dataset.bg}')`;
});

/* Botón de reproducir radio (hero + anuncios + CTA final). */
document.querySelectorAll('[data-action="toggle-radio"]').forEach((btn) => {
    btn.addEventListener("click", () => { if (window.toggleRadio) toggleRadio(); });
});

/* Volver arriba. */
const backToTopBtn = document.getElementById("backToTop");
if (backToTopBtn) {
    window.addEventListener("scroll", () => {
        backToTopBtn.classList.toggle("is-visible", window.scrollY > 500);
    }, { passive: true, signal: pageSignal });
}

/* Navbar solida al hacer scroll. */
const siteNavbar = document.getElementById("siteNavbar");
function updateNavbarScrollState() {
    if (siteNavbar) siteNavbar.classList.toggle("is-scrolled", window.scrollY > 40);
}

/* Los CTA "imantados" ([data-magnetic]) los maneja el modulo global
   core/interactions.js, con eventos delegados. */
window.addEventListener("scroll", updateNavbarScrollState, { passive: true, signal: pageSignal });
updateNavbarScrollState();

/* Aparicion progresiva de secciones y de los elementos puntuales
   marcados con las clases scroll-fade-up, scroll-zoom-in, etc.
   (ver base.css). */
const revealTargets = document.querySelectorAll(
    "[data-reveal], .scroll-fade-up, .scroll-fade-down, .scroll-fade-left, .scroll-fade-right, .scroll-zoom-in, .scroll-bounce-in, .scroll-flip-up, .scroll-blur-in, .scroll-rotate-in"
);
if ("IntersectionObserver" in window && revealTargets.length) {
    const revealObserver = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
            if (entry.isIntersecting) {
                entry.target.classList.add("is-visible");
                revealObserver.unobserve(entry.target);
            }
        });
    }, { threshold: 0, rootMargin: "0px 0px -38% 0px" });
    revealTargets.forEach((target) => revealObserver.observe(target));
} else {
    revealTargets.forEach((target) => target.classList.add("is-visible"));
}

/* "Suena ahora": corrige el programa al aire con la hora LOCAL del
   visitante (el valor inicial venia calculado con la hora del
   servidor, solo como estado por defecto sin JS). */
const scheduleRows = document.querySelectorAll(".home-schedule-row");
const onairName = document.getElementById("onair-program-name");
const onairHost = document.getElementById("onair-program-host");
const onairImage = document.getElementById("onair-program-image");
const onairHostLink = document.getElementById("onair-host-link");
const onairHostCard = document.getElementById("onair-host-card");
const onairHostCardPhoto = document.getElementById("onair-host-card-photo");
const onairHostCardName = document.getElementById("onair-host-card-name");
if (scheduleRows.length) {
    const now = new Date();
    const currentHour = now.getHours();
    // getDay() es 0=domingo..6=sabado; weekdays en el markup usa 1=lunes..7=domingo.
    const currentWeekday = now.getDay() === 0 ? 7 : now.getDay();
    // Primer match gana: la fila de respaldo "Radio Doliv Music" cubre por
    // horas cualquier hueco sin programa (ver index.php), asi que sin este
    // corte pisaria a un programa que si esta al aire ese dia (ej. uno que
    // solo transmite lunes y jueves, ver weekdays).
    let hasCurrent = false;
    scheduleRows.forEach((row) => {
        const weekdaysAttr = row.dataset.slotWeekdays || "";
        const weekdays = weekdaysAttr.split(",").map((d) => d.trim()).filter(Boolean);
        const isTodayScheduled = !weekdays.length || weekdays.includes(String(currentWeekday));
        const startHour = Number(row.dataset.slotStart);
        const endHour = Number(row.dataset.slotEnd);
        const isOvernight = endHour <= startHour;
        const isCurrent = !hasCurrent && isTodayScheduled && (isOvernight
            ? (currentHour >= startHour || currentHour < endHour)
            : (currentHour >= startHour && currentHour < endHour));
        row.classList.toggle("is-current", isCurrent);
        if (isCurrent) hasCurrent = true;
        if (isCurrent && onairName && onairHost) {
            onairName.textContent = row.dataset.slotName;
            onairHost.textContent = row.dataset.slotHost;
            if (onairImage && row.dataset.slotImage) onairImage.src = row.dataset.slotImage;
            if (onairHostCard && onairHostCardPhoto && onairHostCardName) {
                const hostImage = row.dataset.slotHostImage || "";
                const hostSlug = row.dataset.slotHostSlug || "";
                const hostName = row.dataset.slotHost || "el equipo";
                const base = window.SITE_BASE || "";
                if (hostImage) {
                    onairHostCardPhoto.src = hostImage;
                    onairHostCardPhoto.alt = hostName;
                    onairHostCard.classList.remove("is-empty");
                } else {
                    onairHostCardPhoto.src = "";
                    onairHostCardPhoto.alt = "";
                    onairHostCard.classList.add("is-empty");
                }
                onairHostCardName.textContent = hostName;
                onairHostCard.href = hostSlug ? `${base}pages/equipo.php?locutor=${encodeURIComponent(hostSlug)}` : `${base}pages/equipo.php`;
                onairHostCard.setAttribute("aria-label", `Conoce a ${hostName}`);
            }
            if (onairHostLink) {
                const hostSlug = row.dataset.slotHostSlug || "";
                const base = window.SITE_BASE || "";
                onairHostLink.href = hostSlug ? `${base}pages/equipo.php?locutor=${encodeURIComponent(hostSlug)}` : `${base}pages/equipo.php`;
                onairHostLink.setAttribute("aria-label", `Conoce a ${row.dataset.slotHost}`);
            }
        }
    });
}

/* "Pide tu canción": abre el reproductor a modo solicitud (nombre de
   cancion + dedicatoria opcional) y envia el pedido por WhatsApp,
   el mismo canal de contacto directo que ya usa el resto del sitio
   (ver dolivBotLinks.whatsapp en assets/js/components/chatbot.js). */
const SONG_REQUEST_WHATSAPP = "5217131205259";
const songRequestOpenBtn = document.getElementById("songRequestOpen");
const songRequestModal = document.getElementById("song-request-modal");
const songRequestClose = document.getElementById("song-request-close");
const songRequestForm = document.getElementById("song-request-form");
const songRequestSongInput = document.getElementById("song-request-song");
const songRequestError = document.getElementById("song-request-error");

function openSongRequestModal() {
    if (!songRequestModal) return;
    songRequestModal.classList.add("is-open");
    songRequestModal.setAttribute("aria-hidden", "false");
    document.body.style.overflow = "hidden";
    if (songRequestSongInput) songRequestSongInput.focus();
}

function closeSongRequestModal() {
    if (!songRequestModal) return;
    songRequestModal.classList.remove("is-open");
    songRequestModal.setAttribute("aria-hidden", "true");
    document.body.style.overflow = "";
    if (songRequestError) songRequestError.textContent = "";
}

if (songRequestOpenBtn) songRequestOpenBtn.addEventListener("click", openSongRequestModal);
if (songRequestClose) songRequestClose.addEventListener("click", closeSongRequestModal);
if (songRequestModal) {
    songRequestModal.addEventListener("click", (event) => {
        if (event.target.matches("[data-close-song-request='true']")) closeSongRequestModal();
    });
}
window.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && songRequestModal && songRequestModal.classList.contains("is-open")) {
        closeSongRequestModal();
    }
}, { signal: pageSignal });

if (songRequestForm) {
    songRequestForm.addEventListener("submit", (event) => {
        event.preventDefault();
        const song = songRequestSongInput ? songRequestSongInput.value.trim() : "";
        if (!song) {
            if (songRequestError) songRequestError.textContent = "Escribe el nombre de la canción para continuar.";
            if (songRequestSongInput) songRequestSongInput.focus();
            return;
        }
        const dedicationInput = document.getElementById("song-request-dedication");
        const dedication = dedicationInput ? dedicationInput.value.trim() : "";
        const currentProgram = onairName ? onairName.textContent : "Radio Doliv";

        // Sin emoji "pictograficos" (fuera del plano basico de Unicode):
        // el redireccionador de wa.me los corrompe en algunos casos.
        const lines = [
            "¡Hola Radio Doliv! Quiero pedir mi canción.",
            `Canción: ${song}`,
            `Programa: ${currentProgram}`,
        ];
        if (dedication) lines.push(`Dedicatoria: ${dedication}`);

        const whatsappUrl = `https://wa.me/${SONG_REQUEST_WHATSAPP}?text=${encodeURIComponent(lines.join("\n"))}`;
        window.open(whatsappUrl, "_blank", "noopener");

        songRequestForm.reset();
        closeSongRequestModal();
    });
}

/* Carrusel de anuncios de programas: una diapositiva visible a la
   vez, con puntos, flechas y autoplay. */
const announceTrack = document.querySelector(".home-announce-track");
const announceDots = document.getElementById("announceDots");
const announcePrev = document.getElementById("announcePrev");
const announceNext = document.getElementById("announceNext");
if (announceTrack && announceDots) {
    const slides = Array.from(announceTrack.querySelectorAll(".home-announce-slide"));
    let activeSlide = 0;
    let announceTimer = null;

    slides.forEach((_, index) => {
        const dot = document.createElement("button");
        dot.type = "button";
        dot.className = "home-announce-dot" + (index === 0 ? " is-active" : "");
        dot.setAttribute("aria-label", `Ver anuncio ${index + 1}`);
        dot.addEventListener("click", () => { showAnnounceSlide(index); restartAnnounceAutoplay(); });
        announceDots.appendChild(dot);
    });
    const dotEls = announceDots.querySelectorAll(".home-announce-dot");

    function showAnnounceSlide(index) {
        const outgoing = slides[activeSlide];
        activeSlide = (index + slides.length) % slides.length;
        const incoming = slides[activeSlide];
        if (outgoing === incoming) return;

        incoming.classList.add("is-active");
        incoming.setAttribute("aria-hidden", "false");
        incoming.querySelectorAll("a, button").forEach((el) => { el.tabIndex = 0; });
        dotEls.forEach((dot, i) => dot.classList.toggle("is-active", i === activeSlide));

        setTimeout(() => {
            outgoing.classList.remove("is-active");
            outgoing.setAttribute("aria-hidden", "true");
            outgoing.querySelectorAll("a, button").forEach((el) => { el.tabIndex = -1; });
        }, 320);
    }

    function restartAnnounceAutoplay() {
        if (announceTimer) clearInterval(announceTimer);
        if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
        announceTimer = setInterval(() => showAnnounceSlide(activeSlide + 1), 6000);
    }

    if (announcePrev) announcePrev.addEventListener("click", () => { showAnnounceSlide(activeSlide - 1); restartAnnounceAutoplay(); });
    if (announceNext) announceNext.addEventListener("click", () => { showAnnounceSlide(activeSlide + 1); restartAnnounceAutoplay(); });
    restartAnnounceAutoplay();
    pageSignal.addEventListener("abort", () => { if (announceTimer) clearInterval(announceTimer); }, { once: true });
}

/* Comentarios en vivo: sin backend todavia, asi que el formulario solo
   antepone el mensaje del propio oyente a la lista (con su hora local)
   y sube el contador de "en linea" para que se sienta como una
   conversacion activa. Se pierde al recargar -- ver index.php para el
   markup y los comentarios de muestra. */
const liveCommentsForm = document.getElementById("liveCommentsForm");
const liveCommentsInput = document.getElementById("liveCommentsInput");
const liveCommentsList = document.getElementById("liveCommentsList");
const liveCommentsCount = document.getElementById("liveCommentsCount");

if (liveCommentsForm && liveCommentsInput && liveCommentsList) {
    liveCommentsForm.addEventListener("submit", (event) => {
        event.preventDefault();
        const text = liveCommentsInput.value.trim();
        if (!text) return;

        const item = document.createElement("li");
        item.className = "home-comment";
        item.innerHTML = `
            <span class="home-comment-avatar">TÚ</span>
            <span class="home-comment-body">
                <span class="home-comment-top">
                    <strong class="home-comment-name">Tú</strong>
                    <span class="home-comment-time">${new Date().toLocaleTimeString("es-MX", { hour: "2-digit", minute: "2-digit" })}</span>
                </span>
                <span class="home-comment-text"></span>
            </span>
        `;
        item.querySelector(".home-comment-text").textContent = text;
        liveCommentsList.appendChild(item);
        liveCommentsList.scrollTop = liveCommentsList.scrollHeight;

        if (liveCommentsCount) {
            liveCommentsCount.textContent = String(parseInt(liveCommentsCount.textContent, 10) + 1);
        }

        liveCommentsInput.value = "";
        liveCommentsInput.focus();
    });
}

/* Sugerencia de scroll: tarjeta fija sobre el boton del chatbot que
   propone una seccion al azar (parrilla, voces, podcasts, eventos).
   Aparece al pasar el hero (reproductor incluido) y su barra se llena
   con el scroll acumulado del visitante -- al completarse, cambia a
   otra sugerencia al azar (nunca repite la actual seguida). El
   visitante puede cerrarla; vuelve a subir al hero la resetea. */
const scrollTip = document.getElementById("scrollTip");
const scrollTipLink = document.getElementById("scrollTipLink");
const scrollTipText = document.getElementById("scrollTipText");
const scrollTipBar = document.getElementById("scrollTipBar");
const scrollTipClose = document.getElementById("scrollTipClose");
const scrollTipHero = document.querySelector(".ps-band--hero");

if (scrollTip && scrollTipLink && scrollTipText && scrollTipBar && scrollTipHero) {
    const SCROLL_TIPS = [
        { href: "#parrilla-del-dia", label: "Mira la parrilla de hoy" },
        { href: "#nuestras-voces", label: "Conoce a nuestras voces" },
        { href: "#podcasts-originales", label: "Escucha los podcasts" },
        { href: "#proximos-eventos", label: "Próximos eventos" },
    ];
    const SCROLL_BUDGET = 450; // px de scroll para llenar la barra
    let dismissed = false;
    let currentTipIndex = -1;
    let progressStartY = 0;

    function pickNextTipIndex() {
        if (SCROLL_TIPS.length < 2) return 0;
        let next;
        do { next = Math.floor(Math.random() * SCROLL_TIPS.length); } while (next === currentTipIndex);
        return next;
    }

    function showTip(index) {
        currentTipIndex = index;
        const tip = SCROLL_TIPS[index];
        scrollTipLink.href = tip.href;
        scrollTipText.textContent = tip.label;
    }

    showTip(pickNextTipIndex());

    function updateScrollTip() {
        if (dismissed) return;
        const triggerY = scrollTipHero.getBoundingClientRect().bottom + window.scrollY - 160;
        const isPastHero = window.scrollY > triggerY;

        scrollTip.classList.toggle("is-visible", isPastHero);

        if (!isPastHero) {
            progressStartY = window.scrollY;
            scrollTipBar.style.width = "0%";
            return;
        }

        const progress = Math.min(100, Math.max(0, ((window.scrollY - progressStartY) / SCROLL_BUDGET) * 100));
        scrollTipBar.style.width = progress + "%";

        if (progress >= 100) {
            progressStartY = window.scrollY;
            showTip(pickNextTipIndex());
        }
    }

    window.addEventListener("scroll", updateScrollTip, { passive: true, signal: pageSignal });
    updateScrollTip();

    if (scrollTipClose) {
        scrollTipClose.addEventListener("click", () => {
            dismissed = true;
            scrollTip.classList.remove("is-visible");
        });
    }
}
})();
