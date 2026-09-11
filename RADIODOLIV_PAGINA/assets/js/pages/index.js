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

/* "Suena ahora": resuelve la parrilla con la hora de Ciudad de México,
   igual que la página de programas. Nunca usa la zona horaria local del
   visitante, que podría mostrar una transmisión distinta. */
const scheduleRows = document.querySelectorAll(".home-schedule-row");
const onairName = document.getElementById("onair-program-name");
const onairHost = document.getElementById("onair-program-host");
const onairImage = document.getElementById("onair-program-image");
const onairHostLink = document.getElementById("onair-host-link");
const onairHostCards = document.getElementById("onair-host-cards");
const mexicoTimeFormatter = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/Mexico_City",
    hourCycle: "h23",
    weekday: "short",
    hour: "2-digit",
});
const mexicoWeekdays = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };

function mexicoScheduleNow() {
    const parts = {};
    mexicoTimeFormatter.formatToParts(new Date()).forEach(({ type, value }) => {
        parts[type] = value;
    });
    return { hour: Number(parts.hour), weekday: mexicoWeekdays[parts.weekday] };
}

function previousWeekday(weekday) {
    return weekday === 1 ? 7 : weekday - 1;
}

function updateOnAirProgram() {
    if (!scheduleRows.length) return;
    const now = mexicoScheduleNow();
    let currentRow = null;
    let fallbackRow = null;

    scheduleRows.forEach((row) => {
        if (row.dataset.slotFallback === "true") {
            fallbackRow = row;
            row.classList.remove("is-current");
            return;
        }
        if (!row.dataset.slotStart || !row.dataset.slotEnd) {
            row.classList.remove("is-current");
            return;
        }
        const weekdaysAttr = row.dataset.slotWeekdays || "";
        const weekdays = weekdaysAttr.split(",").map((d) => d.trim()).filter(Boolean);
        const startHour = Number(row.dataset.slotStart);
        const endHour = Number(row.dataset.slotEnd);
        const isOvernight = endHour <= startHour;
        const scheduleWeekday = isOvernight && now.hour < endHour
            ? previousWeekday(now.weekday)
            : now.weekday;
        const isScheduled = !weekdays.length || weekdays.includes(String(scheduleWeekday));
        const isCurrent = currentRow === null && isScheduled && (isOvernight
            ? (now.hour >= startHour || now.hour < endHour)
            : (now.hour >= startHour && now.hour < endHour));
        row.classList.toggle("is-current", isCurrent);
        if (isCurrent) currentRow = row;
    });

    const selectedRow = currentRow || fallbackRow;
    if (!selectedRow) return;
    selectedRow.classList.add("is-current");
    if (onairName && onairHost) {
        onairName.textContent = selectedRow.dataset.slotName;
        onairHost.textContent = selectedRow.dataset.slotHost;
        if (onairImage && selectedRow.dataset.slotImage) {
            onairImage.src = selectedRow.dataset.slotImage;
        }
        let hosts = [];
        try {
            hosts = JSON.parse(selectedRow.dataset.slotHosts || "[]");
        } catch (e) {
            hosts = [];
        }
        const base = window.SITE_BASE || "";
        if (onairHostCards) {
            onairHostCards.innerHTML = "";
            if (!hosts.length) {
                const emptyCard = document.createElement("a");
                emptyCard.href = `${base}pages/equipo.php`;
                emptyCard.className = "home-player-host-card is-empty";
                emptyCard.setAttribute("aria-label", "Conoce al equipo");
                emptyCard.innerHTML = '<img loading="lazy"><span class="home-player-host-name">el equipo</span>';
                onairHostCards.appendChild(emptyCard);
            } else {
                hosts.forEach((host) => {
                    const card = document.createElement("a");
                    card.href = `${base}pages/equipo.php?locutor=${encodeURIComponent(host.slug)}`;
                    card.className = "home-player-host-card";
                    card.setAttribute("aria-label", `Conoce a ${host.name}`);
                    const img = document.createElement("img");
                    img.loading = "lazy";
                    img.src = host.image || "";
                    img.alt = host.name || "";
                    const name = document.createElement("span");
                    name.className = "home-player-host-name";
                    name.textContent = host.name || "";
                    card.append(img, name);
                    onairHostCards.appendChild(card);
                });
            }
        }
        if (onairHostLink) {
            const firstSlug = hosts.length ? hosts[0].slug : "";
            onairHostLink.href = firstSlug ? `${base}pages/equipo.php?locutor=${encodeURIComponent(firstSlug)}` : `${base}pages/equipo.php`;
            onairHostLink.setAttribute("aria-label", `Conoce a ${selectedRow.dataset.slotHost}`);
        }
    }
}

updateOnAirProgram();
const onAirTimer = window.setInterval(updateOnAirProgram, 30000);
if (pageSignal) {
    pageSignal.addEventListener("abort", () => window.clearInterval(onAirTimer), { once: true });
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

/* Comentarios en vivo: respaldados por inc/api/live-comments.php
   (tabla radio_live_comments). El servidor pinta el estado inicial en
   index.php; aqui se hace polling incremental (GET ?since=<ultimo id>) y
   se publican comentarios nuevos por POST. La caja "se reinicia cada
   hora": la respuesta trae "bucket" (la hora en punto vigente) y cuando
   cambia se vacia la lista. Si el endpoint no responde (BD sin migrar en
   el server, red caida) el polling se detiene solo y el envio muestra el
   error -- la portada nunca se rompe por esto. */
const liveCommentsForm = document.getElementById("liveCommentsForm");
const liveCommentsInput = document.getElementById("liveCommentsInput");
const liveCommentsName = document.getElementById("liveCommentsName");
const liveCommentsList = document.getElementById("liveCommentsList");
const liveCommentsCount = document.getElementById("liveCommentsCount");
const liveCommentsError = document.getElementById("liveCommentsError");

if (liveCommentsForm && liveCommentsInput && liveCommentsList) {
    const API = (window.SITE_BASE || "") + "inc/api/live-comments.php";
    const POLL_MS = 8000;
    const NAME_KEY = "radiodoliv_live_name";
    const CLIENT_KEY = "radiodoliv_live_client";

    let clientId = "";
    try {
        clientId = localStorage.getItem(CLIENT_KEY) || "";
        if (!clientId) {
            clientId = (crypto.randomUUID && crypto.randomUUID()) ||
                (Date.now().toString(36) + Math.random().toString(36).slice(2));
            localStorage.setItem(CLIENT_KEY, clientId);
        }
    } catch (_) { /* modo privado: seguimos sin persistir */ }

    try {
        const savedName = localStorage.getItem(NAME_KEY);
        if (savedName && liveCommentsName && !liveCommentsName.value) {
            liveCommentsName.value = savedName;
        }
    } catch (_) { /* ignore */ }

    let bucket = liveCommentsList.dataset.bucket || "";
    let lastId = 0;
    liveCommentsList.querySelectorAll("[data-comment-id]").forEach((li) => {
        lastId = Math.max(lastId, parseInt(li.dataset.commentId, 10) || 0);
    });
    let pollFailures = 0;
    let sending = false;
    let pollTimer = null;

    const initials = (name) => {
        const parts = String(name).trim().split(/\s+/).filter(Boolean);
        if (!parts.length) return "?";
        const first = parts[0][0] || "";
        const last = parts.length > 1 ? (parts[parts.length - 1][0] || "") : "";
        return (first + last).toUpperCase();
    };

    const showError = (msg) => {
        if (!liveCommentsError) return;
        liveCommentsError.textContent = msg;
        liveCommentsError.hidden = !msg;
    };

    const renderComment = (c) => {
        if (!c || !c.id || liveCommentsList.querySelector(`[data-comment-id="${c.id}"]`)) {
            return;
        }
        const item = document.createElement("li");
        item.className = "home-comment";
        item.dataset.commentId = String(c.id);
        item.innerHTML = `
            <span class="home-comment-avatar"></span>
            <span class="home-comment-body">
                <span class="home-comment-top">
                    <strong class="home-comment-name"></strong>
                    <span class="home-comment-time"></span>
                </span>
                <span class="home-comment-text"></span>
            </span>
        `;
        item.querySelector(".home-comment-avatar").textContent = initials(c.name);
        item.querySelector(".home-comment-name").textContent = c.name;
        item.querySelector(".home-comment-time").textContent = c.time || "";
        item.querySelector(".home-comment-text").textContent = c.body;
        liveCommentsList.appendChild(item);
        lastId = Math.max(lastId, c.id);
    };

    const syncCount = (n) => {
        if (liveCommentsCount && Number.isFinite(n)) {
            liveCommentsCount.textContent = String(n);
        }
    };

    const applyBucket = (serverBucket) => {
        if (serverBucket && serverBucket !== bucket) {
            bucket = serverBucket;
            liveCommentsList.dataset.bucket = serverBucket;
            liveCommentsList.innerHTML = "";
            lastId = 0;
        }
    };

    const poll = async () => {
        try {
            const res = await fetch(`${API}?since=${lastId}`, { headers: { Accept: "application/json" } });
            if (!res.ok) throw new Error("http " + res.status);
            const data = await res.json();
            if (!data || data.success !== true) throw new Error("bad payload");
            pollFailures = 0;
            applyBucket(data.bucket);
            const atBottom = liveCommentsList.scrollTop + liveCommentsList.clientHeight >= liveCommentsList.scrollHeight - 24;
            (data.comments || []).forEach(renderComment);
            syncCount(data.count);
            if (atBottom) liveCommentsList.scrollTop = liveCommentsList.scrollHeight;
        } catch (_) {
            pollFailures += 1;
            if (pollFailures >= 3) stopPolling();
        }
    };

    // El router SPA reinyecta este script; guardamos el timer en window para
    // que nunca queden dos pollers vivos a la vez sobre la misma pagina.
    const stopPolling = () => {
        if (window.__radioLiveCommentsPoll) {
            clearInterval(window.__radioLiveCommentsPoll);
            window.__radioLiveCommentsPoll = null;
        }
        pollTimer = null;
    };
    const startPolling = () => {
        stopPolling();
        pollFailures = 0;
        pollTimer = window.__radioLiveCommentsPoll = setInterval(poll, POLL_MS);
    };

    liveCommentsForm.addEventListener("submit", async (event) => {
        event.preventDefault();
        if (sending) return;
        const body = liveCommentsInput.value.trim();
        const name = (liveCommentsName && liveCommentsName.value.trim()) || "";
        if (!body) return;
        showError("");

        sending = true;
        const sendBtn = liveCommentsForm.querySelector(".home-comments-send");
        if (sendBtn) sendBtn.disabled = true;

        try {
            const res = await fetch(API, {
                method: "POST",
                headers: { "Content-Type": "application/json", Accept: "application/json" },
                body: JSON.stringify({ name, body, client_id: clientId }),
            });
            const data = await res.json().catch(() => null);
            if (!res.ok || !data || data.success !== true) {
                showError((data && data.error) || "No se pudo enviar tu comentario. Intenta de nuevo.");
            } else {
                applyBucket(data.bucket);
                renderComment(data.comment);
                liveCommentsList.scrollTop = liveCommentsList.scrollHeight;
                syncCount((parseInt(liveCommentsCount && liveCommentsCount.textContent, 10) || 0) + 1);
                liveCommentsInput.value = "";
                try { if (name) localStorage.setItem(NAME_KEY, name); } catch (_) { /* ignore */ }
                liveCommentsInput.focus();
                if (!window.__radioLiveCommentsPoll) startPolling();
            }
        } catch (_) {
            showError("Sin conexión. Revisa tu internet e intenta de nuevo.");
        } finally {
            sending = false;
            if (sendBtn) sendBtn.disabled = false;
        }
    });

    poll();
    startPolling();
    pageSignal.addEventListener("abort", stopPolling, { once: true });
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
