/* ============================================
   core/mobile-dock.js
   Logica minima del "Dock" movil (inc/partials/mobile-dock.php):
   conecta el boton play/pausa al toggleRadio() global que ya
   expone core/radio.js y sincroniza el icono + el texto de estado
   con los eventos del <audio id="radio-audio">. No modifica
   radio.js: solo escucha, igual que core/sticky-player.js.

   El estado "activo" de las pestanas NO se toca aqui: lo resuelve
   CSS contra <html data-page="..."> (mantenido al dia por el router
   AJAX, ver core/page-router.js). El dock vive fuera de <main>, asi
   que este script corre una sola vez y sus listeners persisten
   entre navegaciones.
   ============================================ */
(function (ns) {
    function initMobileDock() {
        var dock = document.getElementById("mobileDock");
        if (!dock || dock.dataset.bound === "1") return;
        dock.dataset.bound = "1";

        var playBtn = document.getElementById("mobileDockPlay");
        var statusEl = document.getElementById("mobileDockStatus");

        var TEXT_PLAYING = "En vivo ahora";
        var TEXT_PAUSED = "Toca para escuchar en vivo";

        function getAudio() {
            return document.getElementById("radio-audio");
        }

        function sync() {
            var audio = getAudio();
            var isPlaying = Boolean(audio && !audio.paused && !audio.ended);
            dock.classList.toggle("is-playing", isPlaying);
            if (playBtn) {
                playBtn.setAttribute("aria-label", isPlaying ? "Pausar radio en vivo" : "Reproducir radio en vivo");
            }
            if (statusEl) {
                statusEl.textContent = isPlaying ? TEXT_PLAYING : TEXT_PAUSED;
            }
        }

        if (playBtn) {
            playBtn.addEventListener("click", function () {
                if (typeof window.toggleRadio === "function") {
                    window.toggleRadio();
                }
                // Reflejo optimista; los eventos del audio corrigen si hace falta.
                window.setTimeout(sync, 0);
            });
        }

        // radio.js crea el <audio> de forma sincrona, pero por si el
        // orden de carga cambiara se reintenta unos ms (igual que
        // sticky-player.js).
        (function attach() {
            var audio = getAudio();
            if (!audio) {
                window.setTimeout(attach, 200);
                return;
            }
            ["playing", "pause", "ended", "waiting", "stalled"].forEach(function (evt) {
                audio.addEventListener(evt, sync);
            });
            sync();
        })();
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", initMobileDock);
    } else {
        initMobileDock();
    }
})(window.RadioDoliv);
