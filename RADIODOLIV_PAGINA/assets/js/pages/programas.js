/* ============================================
   pages/programas.js
   La parrilla como un dia de transmision en vivo:

   - Cabina (#booth): repinta el programa al aire con la hora de Ciudad de
     México (zona de la parrilla, ver getMexicoNow), sin importar en que
     zona horaria este el visitante, incluida la barra de avance del
     bloque y el "a continuacion".
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

const MEXICO_TZ = "America/Mexico_City";
const mexicoPartsFormatter = new Intl.DateTimeFormat("en-US", {
    timeZone: MEXICO_TZ,
    hourCycle: "h23",
    weekday: "short",
    hour: "2-digit",
    minute: "2-digit",
});
const WEEKDAY_ISO = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };
const WEEKDAY_LABEL = { 1: "lun", 2: "mar", 3: "mié", 4: "jue", 5: "vie", 6: "sáb", 7: "dom" };

/* La parrilla esta definida en hora de Ciudad de Mexico, no en la del
   visitante -- por eso "ahora" se resuelve siempre en esa zona horaria,
   sin importar desde donde se abra la pagina. */
function getMexicoNow() {
    const parts = {};
    mexicoPartsFormatter.formatToParts(new Date()).forEach(({ type, value }) => {
        parts[type] = value;
    });
    return {
        hours: Number(parts.hour),
        minutes: Number(parts.minute),
        weekday: WEEKDAY_ISO[parts.weekday],
    };
}

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

function previousWeekday(weekday) {
    return weekday === 1 ? 7 : weekday - 1;
}

function isLive(slot, hour, weekday) {
    const overnight = slot.end <= slot.start;
    const scheduleWeekday = overnight && hour < slot.end
        ? previousWeekday(weekday)
        : weekday;
    if (!runsToday(slot, scheduleWeekday)) return false;
    return overnight
        ? (hour >= slot.start || hour < slot.end)
        : (hour >= slot.start && hour < slot.end);
}

/* Siguiente programa: el de arranque mas cercano por delante de la hora
   actual que se emita HOY; si ya no queda ninguno, se avanza dia a dia
   buscando el primero que de verdad salga al aire ese dia. Antes se
   cogia el de arranque mas temprano sin mirar los weekdays, asi que el
   fin de semana la cabina anunciaba programas que solo van entre semana.
   Devuelve { slot, day } para que la cabina pueda rotular el dia cuando
   no es hoy. */
function findNext(hour, weekday) {
    const laterToday = slots
        .filter((slot) => runsToday(slot, weekday) && slot.start > hour)
        .sort((a, b) => a.start - b.start);
    if (laterToday.length) return { slot: laterToday[0], day: weekday };

    for (let ahead = 1; ahead <= 7; ahead += 1) {
        const day = ((weekday - 1 + ahead) % 7) + 1;
        const onThatDay = slots
            .filter((slot) => runsToday(slot, day))
            .sort((a, b) => a.start - b.start);
        if (onThatDay.length) return { slot: onThatDay[0], day };
    }
    return null;
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

function paintBooth(liveSlot, now, next) {
    if (!booth) return;

    boothClock.textContent = `${pad(now.hours)}:${pad(now.minutes)}`;

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
        const elapsedHours = overnight && now.hours < liveSlot.end
            ? (24 - liveSlot.start + now.hours)
            : (now.hours - liveSlot.start);
        const elapsed = elapsedHours + now.minutes / 60;
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

    if (next && next.slot !== liveSlot) {
        boothNext.hidden = false;
        boothNextName.textContent = next.slot.item.dataset.title;
        const time = next.slot.item.dataset.time || `${pad(next.slot.start)}:00`;
        // Si el siguiente programa no es de hoy, se antepone el dia para
        // que no parezca que empieza en unas horas.
        boothNextTime.textContent = next.day === now.weekday
            ? time
            : `${WEEKDAY_LABEL[next.day]} · ${time}`;
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
        const position = ((now.hours + now.minutes / 60) / 24) * 100;
        dialNeedle.style.left = `${position.toFixed(2)}%`;
    }
    const liveId = liveSlot ? liveSlot.item.id : null;
    dialSegments.forEach((seg) => {
        // El dial es la foto de HOY: los segmentos de programas que no
        // salen al aire hoy se ocultan (se recalcula cada ciclo para que
        // siga bien si la pagina cruza la medianoche).
        const days = (seg.dataset.dialWeekdays || "")
            .split(",").map((d) => d.trim()).filter(Boolean);
        const runsToday = !days.length || days.includes(String(now.weekday));
        // Una franja nocturna puede haber iniciado ayer y seguir al aire
        // después de medianoche; debe permanecer visible mientras es la
        // transmisión actual aunque su día de inicio ya no sea "hoy".
        seg.classList.toggle(
            "is-hidden-day",
            !runsToday && seg.dataset.dialTarget !== liveId
        );
        seg.classList.toggle("is-live", seg.dataset.dialTarget === liveId);
    });
}

/* ------------------------------------------------------------------
   Recalculo global
   ------------------------------------------------------------------ */
function refreshOnAir() {
    const now = getMexicoNow();
    const hour = now.hours;
    const weekday = now.weekday;

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
   Filtros de la parrilla: DIA (que se emite ese dia) + GENERO. Son
   independientes -- cada uno marca su propia clase en la entrada
   (is-hidden-day / is-filtered-out) -- y una sola funcion recalcula
   que franjas quedan vacias y si hay que mostrar el mensaje de "nada
   coincide", combinando ambos.

   Al entrar, PHP ya renderizo la parrilla con el dia de HOY en hora de
   Ciudad de México; aqui se reaplica por si la carga cruzo la
   medianoche, y luego los botones cambian el dia sin recargar.
   ------------------------------------------------------------------ */
const rundownBlocks = document.querySelectorAll(".rundown-block");
const rundownEmpty = document.getElementById("rundown-empty");
const genreButtons = document.querySelectorAll(".rundown-filter");
const dayButtons = document.querySelectorAll(".rundown-day");

let activeGenre = "todos";
let activeDay = getMexicoNow().weekday;

function itemRunsOnDay(item, day) {
    /* Sin lista de dias = suena todos los dias (incluye la musica 24/7,
       que ni siquiera trae el atributo). */
    const days = (item.dataset.slotWeekdays || "")
        .split(",").map((d) => d.trim()).filter(Boolean);
    return !days.length || days.includes(String(day));
}

function itemMatchesGenre(item, genre) {
    if (genre === "todos") return true;
    const tags = (item.dataset.categories || "").toLowerCase()
        .split(",").map((t) => t.trim());
    return tags.includes(genre);
}

/* revealAll: al cambiar de dia/genero, las entradas que reaparecen
   pueden no haber pasado nunca por el IntersectionObserver de revelado
   y quedarian invisibles -- se fuerzan a su estado final. En la primera
   carga se pasa false para conservar la animacion de entrada por scroll. */
function refreshRundown(revealAll) {
    let visibleCount = 0;
    items.forEach((item) => {
        const onDay = itemRunsOnDay(item, activeDay);
        const onGenre = itemMatchesGenre(item, activeGenre);
        item.classList.toggle("is-hidden-day", !onDay);
        item.classList.toggle("is-filtered-out", !onGenre);
        if (onDay && onGenre) {
            visibleCount += 1;
            if (revealAll) item.classList.add("is-visible");
        }
    });

    rundownBlocks.forEach((block) => {
        const shown = block.querySelectorAll(
            ".rundown-item:not(.is-hidden-day):not(.is-filtered-out)"
        ).length;
        block.classList.toggle("is-hidden-day", shown === 0);
        block.classList.remove("is-filtered-out");
        if (revealAll && shown > 0) {
            block.querySelector(".rundown-block-head")?.classList.add("is-visible");
        }
    });

    if (rundownEmpty) rundownEmpty.hidden = visibleCount > 0;
}

genreButtons.forEach((button) => {
    button.addEventListener("click", () => {
        genreButtons.forEach((btn) => btn.classList.remove("is-active"));
        button.classList.add("is-active");
        activeGenre = button.dataset.filter.toLowerCase();
        refreshRundown(true);
    });
});

dayButtons.forEach((button) => {
    button.addEventListener("click", () => {
        dayButtons.forEach((btn) => btn.classList.remove("is-active"));
        button.classList.add("is-active");
        activeDay = Number(button.dataset.day);
        refreshRundown(true);
    });
});

/* Sincroniza el dia real al cargar (por si PHP renderizo con el dia
   anterior al cruzar la medianoche) sin romper el revelado por scroll. */
(function syncDayOnLoad() {
    activeDay = getMexicoNow().weekday;
    dayButtons.forEach((btn) => {
        btn.classList.toggle("is-active", Number(btn.dataset.day) === activeDay);
    });
    refreshRundown(false);
})();

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
