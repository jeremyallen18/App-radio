/* ============================================
   pages/programas.js
   La parrilla como un dia de transmision en vivo:

   - Cabina (#booth): repinta el programa al aire con la hora LOCAL del
     visitante (el servidor no sabe en que zona horaria esta), incluida
     la barra de avance del bloque y el "a continuacion".
   - Dial de 24 h: mueve la aguja al momento actual y salta al programa
     al hacer click en un segmento.
   - Rundown: marca la entrada en vivo, revela cada una por scroll y
     filtra por genero.
   - Modal de detalle de cada programa.

   Todo se recalcula cada 30 s para que la pagina no quede "congelada"
   si alguien la deja abierta cruzando un cambio de programa.
   ============================================ */
(function () {
const pageSignal = window.RadioDoliv.pageSignal;
const { repaintIcons } = window.RadioDoliv.utils;

const items = Array.from(document.querySelectorAll(".rundown-item"));

/* ------------------------------------------------------------------
   Estado "al aire": comparte una sola resolucion de hora local entre
   la cabina, el dial y las entradas del rundown, para que los tres
   no puedan contradecirse entre si.
   ------------------------------------------------------------------ */
function readSlot(item) {
    if (!item.dataset.slotStart) return null;
    const weekdays = (item.dataset.slotWeekdays || "")
        .split(",").map((d) => d.trim()).filter(Boolean);
    return {
        item,
        start: Number(item.dataset.slotStart),
        end: Number(item.dataset.slotEnd),
        weekdays,
    };
}

const slots = items.map(readSlot).filter(Boolean);

function runsToday(slot, weekday) {
    return !slot.weekdays.length || slot.weekdays.includes(String(weekday));
}

function isLive(slot, hour, weekday) {
    if (!runsToday(slot, weekday)) return false;
    const overnight = slot.end <= slot.start;
    return overnight
        ? (hour >= slot.start || hour < slot.end)
        : (hour >= slot.start && hour < slot.end);
}

/* Siguiente programa del dia: el de arranque mas cercano por delante de
   la hora actual; si ya no queda ninguno hoy, el primero de mañana. */
function findNext(hour, weekday) {
    const upcoming = slots
        .filter((slot) => runsToday(slot, weekday) && slot.start > hour)
        .sort((a, b) => a.start - b.start);
    if (upcoming.length) return upcoming[0];
    const tomorrow = slots.slice().sort((a, b) => a.start - b.start);
    return tomorrow.length ? tomorrow[0] : null;
}

/* ------------------------------------------------------------------
   Cabina en vivo
   ------------------------------------------------------------------ */
const booth = document.getElementById("booth");
const boothClock = document.getElementById("booth-clock");
const boothStatusLabel = document.getElementById("booth-status-label");
const boothTitle = document.getElementById("booth-title");
const boothHost = document.getElementById("booth-host");
const boothArtImg = document.getElementById("booth-art-img");
const boothProgress = document.getElementById("booth-progress");
const boothProgressBar = document.getElementById("booth-progress-bar");
const boothProgressFrom = document.getElementById("booth-progress-from");
const boothProgressTo = document.getElementById("booth-progress-to");
const boothNext = document.getElementById("booth-next");
const boothNextName = document.getElementById("booth-next-name");
const boothNextTime = document.getElementById("booth-next-time");

function pad(value) {
    return String(value).padStart(2, "0");
}

function paintBooth(liveSlot, now, nextSlot) {
    if (!booth) return;

    boothClock.textContent = `${pad(now.getHours())}:${pad(now.getMinutes())}`;

    if (liveSlot) {
        const data = liveSlot.item.dataset;
        booth.style.setProperty("--show-accent", data.accent || "var(--brand-cyan)");
        booth.classList.add("is-live");
        boothStatusLabel.textContent = "Al aire ahora";
        boothTitle.textContent = data.title;
        boothHost.textContent = `Con ${data.host}`;
        boothArtImg.src = data.image;
        boothArtImg.alt = data.title;

        /* Avance dentro del bloque: cuantas horas lleva sobre el total,
           contando el cruce de medianoche de los programas nocturnos. */
        const overnight = liveSlot.end <= liveSlot.start;
        const total = overnight ? (24 - liveSlot.start + liveSlot.end) : (liveSlot.end - liveSlot.start);
        const elapsedHours = overnight && now.getHours() < liveSlot.end
            ? (24 - liveSlot.start + now.getHours())
            : (now.getHours() - liveSlot.start);
        const elapsed = elapsedHours + now.getMinutes() / 60;
        const ratio = total > 0 ? Math.min(1, Math.max(0, elapsed / total)) : 0;

        boothProgress.hidden = false;
        boothProgressBar.style.width = `${(ratio * 100).toFixed(1)}%`;
        boothProgressFrom.textContent = `${pad(liveSlot.start)}:00`;
        boothProgressTo.textContent = `${pad(liveSlot.end)}:00`;
    } else {
        booth.style.setProperty("--show-accent", "var(--brand-cyan)");
        booth.classList.remove("is-live");
        boothStatusLabel.textContent = "Sonando ahora";
        boothTitle.textContent = booth.dataset.emptyTitle;
        boothHost.textContent = booth.dataset.emptyHost;
        boothArtImg.removeAttribute("src");
        boothProgress.hidden = true;
    }

    if (nextSlot && nextSlot !== liveSlot) {
        boothNext.hidden = false;
        boothNextName.textContent = nextSlot.item.dataset.title;
        boothNextTime.textContent = nextSlot.item.dataset.time || `${pad(nextSlot.start)}:00`;
    } else {
        boothNext.hidden = true;
    }
}

/* ------------------------------------------------------------------
   Dial de 24 h: la aguja avanza con los minutos, no solo con la hora,
   asi que se mueve visiblemente aunque nadie recargue.
   ------------------------------------------------------------------ */
const dialNeedle = document.getElementById("dial-needle");
const dialSegments = document.querySelectorAll("[data-dial-target]");

dialSegments.forEach((seg) => {
    seg.addEventListener("click", () => {
        document.getElementById(seg.dataset.dialTarget)
            ?.scrollIntoView({ behavior: "smooth", block: "center" });
    });
});

function paintDial(liveSlot, now) {
    if (dialNeedle) {
        const position = ((now.getHours() + now.getMinutes() / 60) / 24) * 100;
        dialNeedle.style.left = `${position.toFixed(2)}%`;
    }
    const liveId = liveSlot ? liveSlot.item.id : null;
    dialSegments.forEach((seg) => {
        seg.classList.toggle("is-live", seg.dataset.dialTarget === liveId);
    });
}

/* ------------------------------------------------------------------
   Recalculo global
   ------------------------------------------------------------------ */
function refreshOnAir() {
    const now = new Date();
    const hour = now.getHours();
    // getDay() es 0=domingo..6=sabado; weekdays en el markup usa 1=lunes..7=domingo.
    const weekday = now.getDay() === 0 ? 7 : now.getDay();

    const liveSlot = slots.find((slot) => isLive(slot, hour, weekday)) || null;
    items.forEach((item) => {
        item.classList.toggle("is-live", Boolean(liveSlot) && item === liveSlot.item);
    });

    paintBooth(liveSlot, now, findNext(hour, weekday));
    paintDial(liveSlot, now);
}

refreshOnAir();
const onAirTimer = window.setInterval(refreshOnAir, 30000);
if (pageSignal) {
    pageSignal.addEventListener("abort", () => window.clearInterval(onAirTimer), { once: true });
}

/* ------------------------------------------------------------------
   Revelado por scroll de cada entrada, escalonando sus partes (hora,
   texto y arte entran por separado) para que el rundown se lea como
   una secuencia y no como un bloque que aparece de golpe.
   ------------------------------------------------------------------ */
if ("IntersectionObserver" in window && items.length) {
    const revealObserver = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
            if (!entry.isIntersecting) return;
            entry.target.classList.add("is-visible");
            revealObserver.unobserve(entry.target);
        });
    }, { threshold: 0.18, rootMargin: "0px 0px -8% 0px" });
    items.forEach((item) => revealObserver.observe(item));

    const blockHeads = document.querySelectorAll(".rundown-block-head");
    const headObserver = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
            if (!entry.isIntersecting) return;
            entry.target.classList.add("is-visible");
            headObserver.unobserve(entry.target);
        });
    }, { threshold: 0.3 });
    blockHeads.forEach((head) => headObserver.observe(head));
} else {
    items.forEach((item) => item.classList.add("is-visible"));
    document.querySelectorAll(".rundown-block-head").forEach((h) => h.classList.add("is-visible"));
}

/* ------------------------------------------------------------------
   Filtro por genero. Ademas de ocultar entradas, esconde la cabecera de
   una franja que se quedo sin ninguna -- antes podia quedar un titulo
   de bloque flotando sobre el vacio.
   ------------------------------------------------------------------ */
const filterButtons = document.querySelectorAll(".rundown-filter");
if (filterButtons.length) {
    const blocks = document.querySelectorAll(".rundown-block");
    const emptyMessage = document.getElementById("rundown-empty");

    filterButtons.forEach((button) => {
        button.addEventListener("click", () => {
            filterButtons.forEach((btn) => btn.classList.remove("is-active"));
            button.classList.add("is-active");

            const filter = button.dataset.filter.toLowerCase();
            let visibleCount = 0;

            items.forEach((item) => {
                const tags = (item.dataset.categories || "").toLowerCase()
                    .split(",").map((t) => t.trim());
                const matches = filter === "todos" || tags.includes(filter);
                item.classList.toggle("is-filtered-out", !matches);
                if (matches) visibleCount += 1;
            });

            blocks.forEach((block) => {
                const stillVisible = block.querySelectorAll(".rundown-item:not(.is-filtered-out)").length;
                block.classList.toggle("is-filtered-out", stillVisible === 0);
            });

            if (emptyMessage) emptyMessage.hidden = visibleCount > 0;
        });
    });
}

/* ------------------------------------------------------------------
   Modal de detalle
   ------------------------------------------------------------------ */
const modal = document.getElementById("show-modal");
const closeBtn = document.getElementById("show-modal-close");
const modalTitle = document.getElementById("show-modal-title");
const modalTime = document.getElementById("show-modal-time");
const modalCats = document.getElementById("show-modal-cats");
const modalSummary = document.getElementById("show-modal-summary");

function openModal(data) {
    modalTitle.textContent = data.title || "Programa";
    modalTime.textContent = (data.time || "").replace("|", "·");
    modalSummary.textContent = data.summary || "";
    modalCats.innerHTML = (data.categories || "")
        .split(",")
        .map((tag) => tag.trim())
        .filter(Boolean)
        .map((tag) => `<li>${tag}</li>`)
        .join("");
    modal.style.setProperty("--show-accent", data.accent || "var(--brand-cyan)");
    modal.classList.add("is-open");
    modal.setAttribute("aria-hidden", "false");
    document.body.style.overflow = "hidden";
    repaintIcons();
}

function closeModal() {
    modal.classList.remove("is-open");
    modal.setAttribute("aria-hidden", "true");
    document.body.style.overflow = "";
}

document.querySelectorAll(".show-more-btn").forEach((btn) => {
    btn.addEventListener("click", () => openModal(btn.dataset));
});

closeBtn.addEventListener("click", closeModal);
modal.addEventListener("click", (event) => {
    if (event.target.matches("[data-close-modal='true']")) closeModal();
});
window.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && modal.classList.contains("is-open")) closeModal();
}, { signal: pageSignal });
})();
