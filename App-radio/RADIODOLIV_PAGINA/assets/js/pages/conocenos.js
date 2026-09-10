/* ============================================
   pages/conocenos.js
   Aparicion (y desaparicion) progresiva de las secciones y de los
   elementos puntuales marcados con las clases scroll-fade-up,
   scroll-zoom-in, etc. (ver assets/css/base/animations.css). A diferencia de
   index.php, aqui NO se deja de observar tras la primera aparicion:
   el reveal se revierte si el elemento vuelve a salir del area de
   disparo al subir el scroll, para que la animacion se pueda ver
   de nuevo entrando y saliendo. El --stagger de cada tarjeta llega
   via data-stagger (ver pages/conocenos.php) y se aplica aqui.

   Envuelto en IIFE: el router de navegacion (ver core/page-router.js)
   reinyecta este script en cada visita, y sin la IIFE las
   declaraciones de nivel superior chocarian en la segunda visita.
   ============================================ */
(function () {
document.querySelectorAll("[data-stagger]").forEach((el) => {
    el.style.setProperty("--stagger", el.dataset.stagger);
});

const revealTargets = document.querySelectorAll(
    "[data-reveal], .scroll-fade-up, .scroll-fade-down, .scroll-fade-left, .scroll-fade-right, .scroll-zoom-in, .scroll-bounce-in, .scroll-flip-up, .scroll-blur-in, .scroll-rotate-in, .scroll-tilt-up"
);
if ("IntersectionObserver" in window && revealTargets.length) {
    const revealObserver = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
            entry.target.classList.toggle("is-visible", entry.isIntersecting);
        });
    }, { threshold: 0, rootMargin: "0px 0px -38% 0px" });
    revealTargets.forEach((target) => revealObserver.observe(target));
} else {
    revealTargets.forEach((target) => target.classList.add("is-visible"));
}
})();

/* ============================================
   FONDO ANIMADO: VANTA.GLOBE
   Monta un canvas WebGL a pantalla completa DETRAS del contenido
   (#about-vanta, z-index -1, pointer-events none -- ver
   assets/css/pages/conocenos.css). No toca el HTML de la pagina: el
   contenedor se crea y se destruye aqui.

   Tres cosas que este bloque tiene que respetar si o si:
   1. El router AJAX (core/page-router.js) reinyecta este script en
      cada visita, asi que hay que destruir el efecto -- y su contexto
      WebGL -- al salir, escuchando el abort de RadioDoliv.pageSignal.
   2. El tema claro/oscuro se alterna sin recargar (core/theme.js solo
      cambia la clase de <body>), asi que se observa esa clase y se
      reinicia el globo con la paleta correspondiente.
   3. Si no hay WebGL, o el usuario pidio menos movimiento, no se monta
      nada: queda el fondo degradado global del sitio.
   ============================================ */
(function () {
    const ns = window.RadioDoliv || {};
    const signal = ns.pageSignal;
    const body = document.body;

    /* Respeta la preferencia del sistema: un globo girando es
       justamente el tipo de movimiento continuo que esto desactiva. */
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    /* Paletas por tema. Vanta recibe enteros, no strings CSS, por eso
       los colores viven aqui y no en la hoja de estilos.
         - color:  puntos y lineas del globo (acento de marca)
         - color2: segundo tono de la malla, da profundidad
         - backgroundColor: mismo fondo base del sitio en cada tema
           (--bg-dark: #050a14 oscuro / #f0f2f5 claro), para que el
           canvas se funda con navbar y footer en vez de recortarse.
         - backgroundAlpha: 0 -> el canvas es transparente y deja ver el
           degradado propio del sitio, asi el globo se lee como una capa
           tenue y no como un bloque encima. backgroundColor SIGUE
           importando aunque no se pinte: vanta interpola el color de
           las lineas contra el, asi que tiene que seguir siendo el
           fondo real de cada tema.
       Los tonos son deliberadamente apagados (azules medios en vez del
       cian saturado): el globo tiene que insinuarse, no competir con
       los titulares. */
    const PALETTES = {
        dark:  { color: 0x1b6fb8, color2: 0x0e4f8a, backgroundColor: 0x050a14, backgroundAlpha: 0 },
        light: { color: 0x5b86b8, color2: 0x8aa6c8, backgroundColor: 0xf0f2f5, backgroundAlpha: 0 }
    };

    const BASE = body.dataset.siteBase || "/";
    const VENDOR = [
        BASE + "assets/js/vendor/three.r134.min.js",
        BASE + "assets/js/vendor/vanta.globe.min.js"
    ];

    let effect = null;
    let host = null;
    let destroyed = false;


    /* --------------------------------------------------------------
       Animacion de scroll: el globo gira y se desplaza segun cuanto se
       ha recorrido la pagina, asi el fondo acompana la lectura de los
       capitulos en vez de quedarse en un bucle ajeno al contenido.

       No usa un listener de "scroll": se engancha al onUpdate del
       propio efecto, que ya corre una vez por frame dentro del rAF de
       vanta. Sale mas barato (nada que throttlear, ni un rAF paralelo),
       queda sincronizado con el render, y se limpia solo cuando se
       destruye el efecto -- no hay listener que pueda sobrevivir a la
       navegacion AJAX.

       El efecto tiene DOS grupos y hay que conducir los dos, o el
       conjunto se parte visualmente:
         - `cont`  -> la base (rejilla de puntos y sus lineas).
         - `cont2` -> el globo (esfera de aristas + lineas orbitales).
       El onUpdate original no toca la rotacion ni la posicion de
       ninguno de los dos grupos: a `cont2` solo le aplica un giro
       interno minimo a la esfera y a sus lineas (milesimas de radian
       por frame), asi que el giro de aqui se SUMA a ese, no lo pisa.

       De la camara solo se fijan los objetivos `tx`/`ty`: el onUpdate
       original interpola su posicion HACIA ellos.

       El valor de scroll se sigue con un lerp propio, asi el globo
       arranca y frena con inercia en vez de pegarse al pixel exacto
       del scroll (y de paso amortigua el scroll brusco de rueda).
       -------------------------------------------------------------- */
    /* Valores que fija vanta en su onInit, de los que parten todos los
       desplazamientos de abajo. */
    const CONT_BASE  = { x: -50, y: -20 };
    const CONT2_BASE = { x: 0, y: 15, rotX: -0.25 };

    function scrollProgress() {
        const max = document.documentElement.scrollHeight - window.innerHeight;
        if (max <= 0) return 0;
        return Math.min(1, Math.max(0, window.scrollY / max));
    }

    /* Giro propio del globo, independiente del scroll: una vuelta
       completa cada ~70 s. Vanta.GLOBE por si solo NO rota la malla
       (su onUpdate solo anima puntos y lineas), asi que si no se
       agrega esto el globo se queda quieto cuando nadie scrollea. */
    const IDLE_TURN_MS = 70000;

    function driveWithScroll(fx) {
        const baseUpdate = typeof fx.onUpdate === "function" ? fx.onUpdate.bind(fx) : null;

        /* Arranca ya en el punto que toca: si se entra a media pagina
           (o se remonta por cambio de tema) el globo no debe saltar. */
        let eased = scrollProgress();

        /* El giro se acumula por tiempo transcurrido, no por numero de
           frames: asi va a la misma velocidad en una pantalla de 60 Hz
           que en una de 144 Hz, y no pega un tiron al volver de una
           pestana en segundo plano (donde el rAF se congela). */
        let idleAngle = 0;
        let lastTime = performance.now();

        fx.onUpdate = function () {
            const now = performance.now();
            const delta = Math.min(now - lastTime, 100); /* tope: evita el salto al volver de background */
            lastTime = now;
            idleAngle += (delta / IDLE_TURN_MS) * Math.PI * 2;

            const target = scrollProgress();
            eased += (target - eased) * 0.08; /* inercia suave */
            const p = eased;

            /* Giro = rotacion continua + aporte del scroll. El scroll
               no manda sobre el giro, lo acelera: bajando la pagina se
               suma algo menos de una vuelta extra. Es el MISMO angulo
               para base y globo, para que giren como una sola pieza. */
            const spin = idleAngle + p * Math.PI * 1.7;

            /* Curva horizontal de ida y vuelta (seno) en vez de un
               arrastre lineal: vuelve al centro al final de la pagina. */
            const sway = Math.sin(p * Math.PI);

            if (this.cont) {
                this.cont.rotation.y = spin;

                /* Inclinacion leve: evita que el giro se lea plano. */
                this.cont.rotation.z = p * 0.18;

                /* La base sube mientras gira y acompana el vaiven. */
                this.cont.position.y = CONT_BASE.y + p * 34;
                this.cont.position.x = CONT_BASE.x + sway * 20;
            }

            if (this.cont2) {
                /* El globo gira con la base -- sobre el giro propio, mas
                   lento, que vanta ya aplica a la esfera y a sus lineas --
                   y se inclina un poco mas conforme se baja. */
                this.cont2.rotation.y = spin;
                this.cont2.rotation.x = CONT2_BASE.rotX + p * 0.12;

                /* Se desplaza junto con la base, con amplitudes algo
                   menores: viajan como un conjunto y aun asi queda
                   parallax entre ambos, que es lo que da profundidad. */
                this.cont2.position.y = CONT2_BASE.y + p * 24;
                this.cont2.position.x = CONT2_BASE.x + sway * 14;
            }

            /* La camara se abre un poco al bajar: sensacion de alejarse
               del globo conforme avanza el relato. */
            if (this.camera) {
                this.camera.tx = 50 + p * 18;
                this.camera.ty = 100 - p * 26;
            }

            if (baseUpdate) baseUpdate();
        };
    }

    /* Carga un <script> una sola vez por sesion: el router reinyecta
       este archivo en cada visita, pero three.js y vanta ya quedaron
       en window, asi que no se vuelven a descargar ni a evaluar. */
    function loadScript(src) {
        return new Promise((resolve, reject) => {
            const existing = document.querySelector(`script[data-vendor-src="${src}"]`);
            if (existing) {
                if (existing.dataset.loaded === "true") return resolve();
                existing.addEventListener("load", resolve, { once: true });
                existing.addEventListener("error", reject, { once: true });
                return;
            }
            const tag = document.createElement("script");
            tag.src = src;
            tag.dataset.vendorSrc = src;
            tag.addEventListener("load", () => { tag.dataset.loaded = "true"; resolve(); }, { once: true });
            tag.addEventListener("error", reject, { once: true });
            document.head.appendChild(tag);
        });
    }

    function currentPalette() {
        return body.classList.contains("light-theme") ? PALETTES.light : PALETTES.dark;
    }

    function mount() {
        if (destroyed || !window.VANTA || !window.VANTA.GLOBE) return;

        if (!host) {
            host = document.createElement("div");
            host.id = "about-vanta";
            host.setAttribute("aria-hidden", "true"); /* decorativo: invisible para lectores de pantalla */
            body.prepend(host);
        }

        effect = window.VANTA.GLOBE(Object.assign({
            el: host,
            THREE: window.THREE, /* explicito: no depender de como vanta resuelva el global */
            /* Sin control por mouse/touch/giroscopio: el globo es fondo,
               no un juguete -- asi el scroll y el arrastre en movil
               siguen comportandose exactamente como en el resto del sitio. */
            mouseControls: false,
            touchControls: false,
            gyroControls: false,
            minHeight: 200.0,
            minWidth: 200.0,
            scale: 1.0,
            scaleMobile: 1.0,
            size: 0.9,
            points: 9.0,
            maxDistance: 21.0
        }, currentPalette()));

        /* Engancha la animacion de scroll al frame del efecto. */
        driveWithScroll(effect);
    }

    function unmount() {
        if (effect) {
            effect.destroy(); /* libera el contexto WebGL, no solo el DOM */
            effect = null;
        }
        if (host) {
            host.remove();
            host = null;
        }
    }

    /* Cambio de tema: Vanta no permite repintar colores en caliente,
       asi que se remonta el efecto con la paleta nueva. */
    const themeObserver = new MutationObserver(() => {
        if (!effect) return;
        unmount();
        mount();
    });
    themeObserver.observe(body, { attributes: true, attributeFilter: ["class"] });

    /* Salida de la pagina (navegacion AJAX): apagar todo. */
    if (signal) {
        signal.addEventListener("abort", () => {
            destroyed = true;
            themeObserver.disconnect();
            unmount();
        }, { once: true });
    }

    /* En serie, no en paralelo: vanta.globe resuelve THREE al evaluarse,
       asi que si three.js todavia no esta en window el efecto arranca
       roto ("Cannot read properties of undefined"). */
    VENDOR.reduce((chain, src) => chain.then(() => loadScript(src)), Promise.resolve())
        .then(mount)
        .catch(() => { /* sin libreria no hay globo: queda el fondo del sitio */ });
})();
