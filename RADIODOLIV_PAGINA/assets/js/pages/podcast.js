/* ============================================
   pages/podcast.js
   Filtro que cambia que tarjetas de programa se ven, y dentro de cada
   tarjeta: reproduccion de capitulos con SU PROPIO <audio>, barra de
   reproduccion (play/pausa, +-10s, progreso, volumen) y duracion de
   cada capitulo obtenida de sus metadatos. Reproducir un programa
   pausa el audio de los demas (un solo programa suena a la vez).

   Envuelto en IIFE: el router de navegacion (ver core/page-router.js)
   reinyecta este script en cada visita, y sin la IIFE las
   declaraciones de nivel superior chocarian en la segunda visita.
   ============================================ */
(function () {
// Pausa la radio en vivo dentro de la página Podcast (no se debe mezclar con episodios).
localStorage.setItem("radioPlaying", "false");
const liveRadio = document.getElementById("radio-audio");
if (liveRadio) liveRadio.pause();

const filterButtons = document.querySelectorAll(".podcast-filter, .podcast-discover-item");
const programs = document.querySelectorAll(".podcast-program");
const allAudios = document.querySelectorAll(".podcast-audio");

const formatTime = (seconds) => {
    if (!Number.isFinite(seconds) || seconds < 0) return "00:00";
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${String(mins).padStart(2, "0")}:${String(secs).padStart(2, "0")}`;
};

/* --- Filtros (pills de arriba + miniaturas de "Descubre más
   programas"): ambos comparten data-filter y muestran/ocultan
   tarjetas .podcast-program. "todos" muestra el catalogo completo
   (todas las tarjetas); un slug de programa deja visible solo esa. --- */
const setActiveProgram = (slug) => {
    const showAll = slug === "todos";

    programs.forEach((program) => {
        program.classList.toggle("is-active", showAll || program.dataset.category === slug);
    });

    document.querySelectorAll(".podcast-filter").forEach((button) => {
        button.classList.toggle("is-active", button.dataset.filter === slug);
    });

    // La grilla de "Descubre más programas" solo tiene sentido para
    // sugerir otros programas cuando se esta viendo uno en concreto;
    // con "todos" ya estan todos a la vista, asi que no se oculta ninguno.
    document.querySelectorAll(".podcast-discover-item").forEach((item) => {
        item.classList.toggle("is-hidden", !showAll && item.dataset.filter === slug);
    });
};

filterButtons.forEach((button) => {
    button.addEventListener("click", () => setActiveProgram(button.dataset.filter));
});

/* --- Cada tarjeta de programa (.podcast-program) trae su propia
   lista de capitulos, barra de reproduccion y <audio>: todo lo de
   abajo trabaja dentro de una sola tarjeta a la vez. --- */
programs.forEach((program) => {
    const audio = program.querySelector("[data-player-audio]");
    if (!audio) return; // Programa sin episodios: solo el placeholder, sin reproductor.

    const episodes = program.querySelectorAll(".podcast-episode");
    const barCover = program.querySelector("[data-player-cover]");
    const barTitle = program.querySelector("[data-player-title]");
    const barToggle = program.querySelector(".podcast-player-toggle");
    const barCurrent = program.querySelector("[data-player-current]");
    const barDuration = program.querySelector("[data-player-duration]");
    const barSeek = program.querySelector("[data-player-seek]");
    const barVolume = program.querySelector("[data-player-volume]");

    const loadEpisode = (episode, autoplay) => {
        episodes.forEach((other) => other.classList.remove("is-active"));
        episode.classList.add("is-active");

        audio.src = episode.dataset.src;
        barTitle.textContent = episode.dataset.title || "—";
        barCover.style.backgroundImage = episode.dataset.cover ? `url("${episode.dataset.cover}")` : "none";
        barCurrent.textContent = "00:00";
        barDuration.textContent = "00:00";
        barSeek.value = 0;
        barSeek.style.setProperty("--podcast-progress", "0%");

        if (autoplay) {
            // Un solo programa suena a la vez: pausa el audio de los demas.
            allAudios.forEach((otherAudio) => {
                if (otherAudio !== audio) otherAudio.pause();
            });
            audio.play();
        }
    };

    episodes.forEach((episode) => {
        episode.addEventListener("click", () => {
            if (episode.classList.contains("is-active") && audio.src) {
                if (audio.paused) {
                    allAudios.forEach((otherAudio) => {
                        if (otherAudio !== audio) otherAudio.pause();
                    });
                    audio.play();
                } else {
                    audio.pause();
                }
                return;
            }
            loadEpisode(episode, true);
        });
    });

    barToggle?.addEventListener("click", () => {
        if (!audio.src) return;
        if (audio.paused) {
            allAudios.forEach((otherAudio) => {
                if (otherAudio !== audio) otherAudio.pause();
            });
            audio.play();
        } else {
            audio.pause();
        }
    });

    program.querySelector('[data-player-action="rewind"]')?.addEventListener("click", () => {
        if (!audio.src) return;
        audio.currentTime = Math.max(0, audio.currentTime - 10);
    });

    program.querySelector('[data-player-action="forward"]')?.addEventListener("click", () => {
        if (!audio.src) return;
        audio.currentTime = Math.min(audio.duration || audio.currentTime + 10, audio.currentTime + 10);
    });

    audio.addEventListener("play", () => {
        episodes.forEach((episode) => episode.classList.remove("is-playing"));
        program.querySelector(".podcast-episode.is-active")?.classList.add("is-playing");
        barToggle?.classList.add("is-playing");
    });

    audio.addEventListener("pause", () => {
        program.querySelector(".podcast-episode.is-active")?.classList.remove("is-playing");
        barToggle?.classList.remove("is-playing");
    });

    audio.addEventListener("ended", () => {
        episodes.forEach((episode) => episode.classList.remove("is-active", "is-playing"));
        barToggle?.classList.remove("is-playing");
    });

    audio.addEventListener("loadedmetadata", () => {
        barDuration.textContent = formatTime(audio.duration);
    });

    audio.addEventListener("timeupdate", () => {
        barCurrent.textContent = formatTime(audio.currentTime);
        if (audio.duration) {
            const percent = (audio.currentTime / audio.duration) * 100;
            barSeek.value = String(percent);
            barSeek.style.setProperty("--podcast-progress", `${percent}%`);
        }
    });

    barSeek?.addEventListener("input", () => {
        if (!audio.duration) return;
        audio.currentTime = (Number(barSeek.value) / 100) * audio.duration;
        barSeek.style.setProperty("--podcast-progress", `${barSeek.value}%`);
    });

    if (barVolume) {
        audio.volume = Number(barVolume.value) / 100;
        barVolume.addEventListener("input", () => {
            audio.volume = Number(barVolume.value) / 100;
        });
    }

    /* --- Duracion de cada capitulo: se obtiene por separado (solo
       metadatos, sin descargar el audio completo) para poder
       mostrarla en la lista antes de reproducir nada. --- */
    episodes.forEach((episode) => {
        const durationEl = episode.querySelector("[data-duration]");
        if (!durationEl || !episode.dataset.src) return;

        const probe = new Audio();
        probe.preload = "metadata";
        probe.src = episode.dataset.src;
        probe.addEventListener("loadedmetadata", () => {
            durationEl.textContent = formatTime(probe.duration);
        });
        probe.addEventListener("error", () => {
            durationEl.textContent = "--:--";
        });
    });

    /* --- Estado inicial: el primer capitulo aparece cargado (pero en
       pausa) en la barra de esta tarjeta, igual que un reproductor de
       podcasts real antes de darle play. --- */
    const firstEpisode = episodes[0];
    if (firstEpisode) loadEpisode(firstEpisode, false);
});

/* --- Estado inicial de filtros: arranca en "todos" (catalogo completo). --- */
setActiveProgram("todos");

if (window.lucide) lucide.createIcons();

/* --- Animación de entrada con GSAP: las tarjetas de programa y la
   barra lateral aparecen con un pequeño desplazamiento y fade; al
   cambiar de filtro, los capitulos que quedan a la vista entran con
   un stagger sutil. Respeta prefers-reduced-motion dejando todo
   visible sin mover. --- */
if (window.gsap) {
    const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const revealTargets = [...programs, ...document.querySelectorAll(".podcast-sidebar > *")].filter(Boolean);

    if (prefersReducedMotion) {
        gsap.set(revealTargets, { opacity: 1, y: 0 });
    } else {
        gsap.set(revealTargets, { opacity: 0, y: 24 });
        gsap.to(revealTargets, { opacity: 1, y: 0, duration: 0.5, stagger: 0.08, ease: "power2.out" });

        filterButtons.forEach((button) => {
            button.addEventListener("click", () => {
                const rows = document.querySelectorAll(".podcast-program.is-active .podcast-episode");
                if (!rows.length) return;
                gsap.fromTo(rows, { opacity: 0, y: 10 }, { opacity: 1, y: 0, duration: 0.35, stagger: 0.03, ease: "power2.out" });
            });
        });
    }
}
})();
