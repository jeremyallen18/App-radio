/* ============================================
   core/sticky-player.js
   Barra de reproduccion persistente (estilo Spotify), disponible
   en todas las paginas. Se auto-inyecta en el DOM igual que
   components/chatbot.js y components/search.js, y se apoya en el
   <audio id="radio-audio"> y el toggleRadio() global que ya expone
   core/radio.js -- no modifica ese archivo, solo escucha sus
   eventos, para no romper el contrato existente entre paginas.
   ============================================ */
(function (ns) {
    function initStickyPlayer() {
        if (document.getElementById("sticky-player")) return;

        const bar = document.createElement("div");
        bar.className = "sticky-player";
        bar.id = "sticky-player";
        bar.innerHTML = `
            <div class="sticky-player-info">
                <button type="button" class="sticky-player-play" id="stickyPlayerPlay" aria-label="Reproducir radio">
                    <i data-lucide="play"></i>
                </button>
                <div class="sticky-player-copy">
                    <span class="sticky-player-live"><span class="pulse-dot" aria-hidden="true"></span> En vivo</span>
                    <strong>Radio Doliv</strong>
                </div>
            </div>
            <div class="sticky-player-wave" aria-hidden="true">
                <span></span><span></span><span></span><span></span>
            </div>
            <div class="sticky-player-volume">
                <i data-lucide="volume-2"></i>
                <input type="range" id="stickyPlayerVolume" min="0" max="1" step="0.01" value="0.5" aria-label="Control de volumen">
            </div>
        `;
        document.body.appendChild(bar);

        const playBtn = document.getElementById("stickyPlayerPlay");
        const volumeInput = document.getElementById("stickyPlayerVolume");

        function getAudio() {
            return document.getElementById("radio-audio");
        }

        function syncPlayIcon() {
            const audio = getAudio();
            const isPlaying = Boolean(audio && !audio.paused);
            bar.classList.toggle("is-playing", isPlaying);
            playBtn.innerHTML = isPlaying ? '<i data-lucide="pause"></i>' : '<i data-lucide="play"></i>';
            playBtn.setAttribute("aria-label", isPlaying ? "Pausar radio" : "Reproducir radio");
            ns.utils.repaintIcons();
        }

        playBtn.addEventListener("click", () => {
            if (window.toggleRadio) window.toggleRadio();
        });

        volumeInput.addEventListener("input", (event) => {
            const value = Number(event.target.value);
            const audio = getAudio();
            if (audio) audio.volume = value;
            localStorage.setItem("radioVolume", String(value));
        });

        // El audio ya existe para cuando este script corre (radio.js lo crea
        // de forma sincrona, no dentro de su listener de "load"), pero se
        // reintenta unos milisegundos por si el orden de carga cambiara.
        function attachAudioListeners() {
            const audio = getAudio();
            if (!audio) {
                window.setTimeout(attachAudioListeners, 200);
                return;
            }
            const savedVolume = localStorage.getItem("radioVolume");
            volumeInput.value = savedVolume !== null ? savedVolume : String(audio.volume || 0.5);
            audio.addEventListener("playing", syncPlayIcon);
            audio.addEventListener("pause", syncPlayIcon);
            audio.addEventListener("ended", syncPlayIcon);
            syncPlayIcon();
        }
        attachAudioListeners();

        // Solo aparece despues de bajar un poco, para no competir con el
        // reproductor principal del hero mientras esta a la vista.
        const showThreshold = 260;

        // Expone la altura ocupada por la barra (mas un pequeno margen) como
        // variable CSS global --sticky-player-offset, para que cualquier
        // elemento flotante (ej. el boton del chatbot, ver chatbot.css) se
        // pueda recorrer hacia arriba y nunca quede tapado por la barra,
        // incluso si su alto cambia (breakpoint, contenido) o si la barra
        // aparece/desaparece con el scroll.
        const GAP_ABOVE_PLAYER = 12;
        function updateStickyOffset() {
            const isVisible = bar.classList.contains("is-visible");
            const offset = isVisible ? bar.getBoundingClientRect().height + GAP_ABOVE_PLAYER : 0;
            document.documentElement.style.setProperty("--sticky-player-offset", `${offset}px`);
        }

        function updateVisibility() {
            bar.classList.toggle("is-visible", window.scrollY > showThreshold);
            updateStickyOffset();
        }
        window.addEventListener("scroll", updateVisibility, { passive: true });
        updateVisibility();

        if (window.ResizeObserver) {
            new ResizeObserver(updateStickyOffset).observe(bar);
        } else {
            window.addEventListener("resize", updateStickyOffset);
        }

        // En moviles (Chrome/Samsung Internet), la barra de direcciones se
        // oculta/muestra al hacer scroll y cambia el viewport SIN disparar
        // siempre "resize" en window -- eso podia dejar el boton del
        // chatbot pisando la barra un instante despues del cambio. Escuchar
        // tambien visualViewport (si el navegador lo soporta) recalcula el
        // offset justo cuando cambia ese viewport real.
        if (window.visualViewport) {
            window.visualViewport.addEventListener("resize", updateStickyOffset);
            window.visualViewport.addEventListener("scroll", updateStickyOffset);
        }
        window.addEventListener("orientationchange", updateStickyOffset);

        ns.utils.repaintIcons();
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", initStickyPlayer);
    } else {
        initStickyPlayer();
    }
})(window.RadioDoliv);
