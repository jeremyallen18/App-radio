/* ============================================
   core/radio.js
   Reproductor de radio persistente: reconexion,
   volumen y estado entre secciones.

   Con la navegacion AJAX (ver core/page-router.js) este script ya
   NO se vuelve a ejecutar al cambiar de pagina -- solo corre una vez,
   al cargar la primera pagina de la sesion -- asi que el <audio> y su
   estado de reproduccion ahora sobreviven de verdad entre paginas (ya
   no hay una reconexion de stream en cada click de navegacion). Pero
   el boton play/pause del hero y el slider de volumen SI viven dentro
   de <main> (solo existen en index.php) y se destruyen/recrean en
   cada visita a esa pagina, asi que las referencias de arriba deben
   poder re-consultarse: bindHeroControls() hace eso y queda expuesta
   en RadioDoliv.radio.onNavigate() para que el router la llame
   despues de cada swap de <main>.
   ============================================ */

/* Botón play/pause del reproductor (si existe). */
let playBtn = document.getElementById("playBtnHero");

/* Slider de volumen (si existe). */
let volumeSlider = document.getElementById("volume-slider");

/* Textos de estado visibles dentro de la tarjeta del reproductor. */
let radioStatusLabel = document.getElementById("radio-status-label");
let radioStatusText = document.getElementById("radio-status-text");

/* URL del stream de radio. */
const STREAM_URL = "https://stream.zeno.fm/vrfurwfubkhtv";

/* Controla una sola reconexion y aumenta la espera si el servidor sigue caido. */
let radioReconnectTimer = null;
let radioReconnectAttempt = 0;

/* Indica si la pagina actual es Podcast, donde la radio debe permanecer pausada. */
function isPodcastPage() {
    return window.location.pathname.split("/").pop().toLowerCase() === "podcast.php";
}

/* Cancela cualquier reconexion pendiente. */
function clearRadioReconnect() {
    if (!radioReconnectTimer) return;
    clearTimeout(radioReconnectTimer);
    radioReconnectTimer = null;
}

/* Buscamos el audio en el HTML actual. */
let audio = document.getElementById("radio-audio");

/* Si no existe audio en esta página, lo creamos para mantener continuidad. */
if (!audio) {
    /* Creamos el objeto de audio con la URL del stream. */
    audio = new Audio(STREAM_URL);

    /* Asignamos un id para futuras referencias. */
    audio.id = "radio-audio";

    /* No forzamos descarga inmediata para cuidar datos. */
    audio.preload = "none";

    /* Se mantiene oculto, porque no es un control visual. */
    audio.style.display = "none";

    /* Lo agregamos al DOM para que viva durante la página. */
    document.body.appendChild(audio);
}

/* Si por alguna razón no tiene src, se lo asignamos. */
if (!audio.src) {
    audio.src = STREAM_URL;
}

/* Actualiza icono play/pause del botón del reproductor. */
function updateUI(isPlaying) {
    /* Si no hay botón en esta página, no hacemos nada. */
    if (!playBtn) return;

    /* Muestra pausa cuando reproduce, play cuando está detenido. */
    playBtn.innerHTML = isPlaying
        ? '<i data-lucide="pause"></i>'
        : '<i data-lucide="play"></i>';

    /* Repinta icono con Lucide. */
    if (window.lucide) {
        lucide.createIcons();
    }
}

/* Informa si la radio esta conectando, sonando o encontro un error. */
function updateRadioStatus(state) {
    if (!radioStatusLabel || !radioStatusText) return;

    const messages = {
        connecting: ["Conectando", "Preparando transmisión en vivo..."],
        playing: ["En vivo ahora", "Transmisión en directo"],
        paused: ["Radio en vivo", "Presiona Play para escuchar"],
        reconnecting: ["Reconectando", "Restableciendo transmisión en vivo..."],
        error: ["Reconectando", "Restableciendo transmisión en vivo..."]
    };
    const message = messages[state] || messages.paused;
    radioStatusLabel.textContent = message[0];
    radioStatusText.textContent = message[1];
}

/* Reconecta solo si no hay una pausa manual ni estamos dentro de Podcast. */
function scheduleRadioReconnect(delay = 15000) {
    if (radioReconnectTimer || isPodcastPage()) return;
    if (localStorage.getItem("radioUserPaused") === "true") return;

    updateRadioStatus("reconnecting");
    radioReconnectTimer = setTimeout(() => {
        radioReconnectTimer = null;
        if (isPodcastPage() || localStorage.getItem("radioUserPaused") === "true") return;

        radioReconnectAttempt += 1;
        playRadio(true).catch((error) => {
            /* No insiste cuando el propio navegador bloquea el autoplay. */
            if (error && error.name === "NotAllowedError") return;
            const nextDelay = Math.min(5000 * (2 ** radioReconnectAttempt), 30000);
            scheduleRadioReconnect(nextDelay);
        });
    }, delay);
}

/* Reproduce la radio con opcion de recargar la URL del stream. */
function playRadio(forceReload = false) {
    /* Si no existe audio, devolvemos una promesa rechazada controlada. */
    if (!audio) return Promise.reject(new Error("Audio no disponible"));

    /* Asegura que el audio no quede silenciado accidentalmente. */
    audio.muted = false;

    /* Confirma inmediatamente que el clic fue recibido. */
    updateRadioStatus("connecting");

    /* Si se pide recarga, reconstruimos la conexion usando la URL estable. */
    if (forceReload) {
        /* Pausa el audio actual antes de reemplazar la fuente. */
        audio.pause();

        /* Reutiliza la URL oficial sin parametros que puedan fragmentar el stream. */
        audio.src = STREAM_URL;

        /* Pide al navegador cargar la nueva fuente. */
        audio.load();
    } else if (audio.readyState === 0) {
        /* Con preload desactivado, inicia la carga dentro del clic del usuario. */
        audio.load();
    }

    /* Intenta reproducir y sincroniza estado visual cuando lo logra. */
    return audio.play().then(() => {
        /* Guarda que el usuario quiere mantener la radio sonando. */
        localStorage.setItem("radioPlaying", "true");
        localStorage.setItem("radioUserPaused", "false");

        /* Muestra icono de pausa. */
        updateUI(true);

        updateRadioStatus("playing");
    }).catch((error) => {
        /* Si el navegador bloquea o falla el stream, marca estado detenido. */
        localStorage.setItem("radioPlaying", "false");

        /* Muestra icono de play para no prometer audio que no suena. */
        updateUI(false);

        updateRadioStatus("error");

        /* Reenvia el error por si otra funcion quiere reaccionar. */
        throw error;
    });
}

/* Mantiene la interfaz sincronizada y recupera bloqueos prolongados. */
function initRadioHealthChecks() {
    /* Si no hay audio, no hay nada que monitorear. */
    if (!audio) return;

    /* Cuando vuelve a sonar, sincronizamos el boton. */
    audio.addEventListener("playing", () => {
        /* Sincroniza icono de pausa. */
        updateUI(true);
        updateRadioStatus("playing");
        clearRadioReconnect();
        radioReconnectAttempt = 0;
    });

    /* Da tiempo al buffer para recuperarse antes de abrir otra conexion. */
    audio.addEventListener("waiting", () => scheduleRadioReconnect(15000));
    audio.addEventListener("stalled", () => scheduleRadioReconnect(15000));

    /* Un final o error real inicia una recuperacion mas rapida. */
    const recoverStoppedRadio = () => {
        updateRadioStatus("reconnecting");
        scheduleRadioReconnect(5000);
    };
    audio.addEventListener("ended", recoverStoppedRadio);
    audio.addEventListener("error", recoverStoppedRadio);
}

/* Alterna reproducción de radio. */
function toggleRadio() {
    /* Si por algo no existe audio, salimos. */
    if (!audio) return;

    /* Si está pausado, continuamos el buffer existente siempre que sea valido. */
    if (audio.paused) {
        const needsReload = Boolean(audio.error) || audio.ended;
        playRadio(needsReload).catch(() => {
            /* Si el navegador bloquea autoplay, dejamos UI en pausa. */
            updateUI(false);
        });
    } else {
        /* Si estaba reproduciendo, pausamos. */
        audio.pause();
        clearRadioReconnect();

        /* Guardamos estado detenido. */
        localStorage.setItem("radioPlaying", "false");
        localStorage.setItem("radioUserPaused", "true");

        /* Actualizamos botón visual. */
        updateUI(false);
        updateRadioStatus("paused");
    }
}

/* Re-consulta playBtn/volumeSlider/status labels (solo existen dentro
   del hero de index.php) y les conecta listeners frescos. Se llama al
   cargar la pagina Y despues de cada navegacion AJAX, porque el swap
   de <main> destruye esos elementos y crea unos nuevos -- las
   referencias/listeners de la visita anterior quedan apuntando a
   nodos ya desconectados. Adjuntar el listener de click/input a un
   elemento recien creado nunca duplica nada (no hay uno viejo que
   limpiar: el nodo viejo, con su listener, ya no existe). */
function bindHeroControls() {
    playBtn = document.getElementById("playBtnHero");
    volumeSlider = document.getElementById("volume-slider");
    radioStatusLabel = document.getElementById("radio-status-label");
    radioStatusText = document.getElementById("radio-status-text");

    if (playBtn) {
        playBtn.addEventListener("click", toggleRadio);
    }

    if (volumeSlider && audio) {
        const savedVolume = localStorage.getItem("radioVolume");
        volumeSlider.value = savedVolume !== null ? savedVolume : String(audio.volume || 0.5);
        const value = Number(volumeSlider.value);
        volumeSlider.style.background = `linear-gradient(to right, var(--cyan-glow) ${value * 100}%, rgba(255, 255, 255, 0.15) ${value * 100}%)`;

        volumeSlider.addEventListener("input", (e) => {
            /* Valor del slider entre 0 y 1. */
            const inputValue = Number(e.target.value);

            /* Aplica volumen real al audio. */
            audio.volume = inputValue;

            /* Persiste volumen para las demás secciones. */
            localStorage.setItem("radioVolume", String(inputValue));

            /* Pinta barra visual del slider según porcentaje actual. */
            e.target.style.background = `linear-gradient(to right, var(--cyan-glow) ${inputValue * 100}%, rgba(255, 255, 255, 0.15) ${inputValue * 100}%)`;
        });
    }

    /* Sincroniza icono/estado visibles con lo que el audio ya esta
       haciendo en realidad (persiste entre paginas, ver arriba). */
    updateUI(Boolean(audio && !audio.paused));
    updateRadioStatus(audio && !audio.paused ? "playing" : "paused");
    if (window.lucide) lucide.createIcons();
}

/* Aplica la regla de "Podcast pausa, el resto reanuda" para la pagina
   actual. Antes vivia solo dentro del listener de "load" porque cada
   navegacion recargaba la pagina entera (y con ella este script); con
   navegacion AJAX este script ya no se re-ejecuta, asi que el router
   llama esta funcion despues de cada swap de <main> (ver
   RadioDoliv.radio.onNavigate mas abajo) para reproducir el mismo
   efecto. */
function syncPodcastPageState() {
    if (!audio) return;
    const userPausedRadio = localStorage.getItem("radioUserPaused") === "true";

    if (isPodcastPage()) {
        if (!audio.paused) {
            audio.pause();
            clearRadioReconnect();
            localStorage.setItem("radioPlaying", "false");
        }
        updateUI(false);
        updateRadioStatus("paused");
    } else if (!userPausedRadio && audio.paused) {
        /* Solo intenta reconectar si de verdad esta pausado -- evita
           un "Conectando..." de mentira en cada navegacion cuando ya
           estaba sonando. */
        playRadio(false).catch(() => updateUI(false));
    }
}

/* Punto de entrada del router de navegacion (ver core/page-router.js):
   se llama una vez despues de cada swap de <main>. */
window.RadioDoliv.radio = {
    onNavigate: function () {
        bindHeroControls();
        syncPodcastPageState();
    },
};

/* Al cargar página, restauramos estado de reproducción y volumen. */
window.addEventListener("load", () => {
    /* Lee volumen guardado previamente y lo aplica al audio. */
    const savedVolume = localStorage.getItem("radioVolume");
    if (audio && savedVolume !== null) {
        audio.volume = Number(savedVolume);
    }

    bindHeroControls();
    syncPodcastPageState();
});

/* Activa monitoreo contra cortes y buffers trabados del streaming. */
initRadioHealthChecks();

/* Capturamos enlaces del menú para aplicar regla especial en "Podcast".
   Los enlaces del navbar viven fuera de <main> y nunca se destruyen
   entre navegaciones, asi que este listener no necesita reconectarse. */
const navLinks = document.querySelectorAll(".nav-links a");

/* Recorremos cada link del menú. */
navLinks.forEach((link) => {
    link.addEventListener("click", (e) => {
        /* Si no hay audio, no hay nada que pausar. */
        if (!audio) return;

        /* Si se navega a Podcast, detenemos la radio para no mezclar audio. */
        if (e.target.textContent.trim().toLowerCase() === "podcast") {
            /* Pausa reproductor global. */
            audio.pause();
            clearRadioReconnect();

            /* Guarda estado detenido. */
            localStorage.setItem("radioPlaying", "false");

            /* No marca pausa manual: al salir de Podcast se intentara reanudar. */

            /* Actualiza botón visual a play. */
            updateUI(false);
        }
    });
});

/* Asegura render inicial de iconos, incluso si el usuario no hace clic. */
if (window.lucide) {
    lucide.createIcons();
}
