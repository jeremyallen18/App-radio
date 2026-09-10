/* ============================================
   core/interactions.js
   Interacciones de mouse compartidas por todo el sitio:

   - [data-magnetic]  boton "imantado" que sigue un poco al cursor
                      (antes vivia duplicado en pages/index.js y
                      pages/eventos.js).
   - [data-tilt]      tarjeta con inclinacion 3D + brillo que sigue
                      al cursor (estilos en components/interactions.css).
   - [data-ripple]    onda de feedback al presionar un boton/CTA.

   Todo va DELEGADO en document, no por pagina: el router AJAX (ver
   core/page-router.js) reemplaza <main> en cada navegacion, asi que
   enlazar elemento por elemento al cargar dejaria sin efecto a las
   tarjetas de las paginas visitadas despues. Los listeners por
   elemento se atan de forma perezosa al primer mouseover (WeakSet
   para no duplicarlos); los nodos descartados por el router se
   olvidan solos.

   Los dos media queries se consultan EN VIVO en cada evento: en
   touch (sin hover real) y con prefers-reduced-motion no se mueve
   nada, aunque el usuario cambie la preferencia sin recargar.
   ============================================ */
(function () {
    const finePointer = window.matchMedia("(hover: hover) and (pointer: fine)");
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

    function allowHoverMotion() {
        return finePointer.matches && !reducedMotion.matches;
    }

    /* --- Boton imantado ------------------------------------------- */
    function bindMagnetic(btn) {
        btn.addEventListener("mousemove", (event) => {
            if (!allowHoverMotion()) return;
            const rect = btn.getBoundingClientRect();
            const x = (event.clientX - rect.left - rect.width / 2) * 0.25;
            const y = (event.clientY - rect.top - rect.height / 2) * 0.35;
            btn.style.transform = `translate(${x}px, ${y}px)`;
        });
        btn.addEventListener("mouseleave", () => {
            btn.style.transform = "";
        });
    }

    /* --- Tarjeta con inclinacion 3D + brillo ----------------------- */
    const TILT_MAX_DEG = 6;

    function bindTilt(card) {
        let frame = null;
        let lastX = 0;
        let lastY = 0;

        card.addEventListener("mousemove", (event) => {
            if (!allowHoverMotion()) return;
            lastX = event.clientX;
            lastY = event.clientY;
            if (frame) return; // maximo una actualizacion por frame
            frame = requestAnimationFrame(() => {
                frame = null;
                const rect = card.getBoundingClientRect();
                if (!rect.width || !rect.height) return;
                const px = (lastX - rect.left) / rect.width;   // 0..1
                const py = (lastY - rect.top) / rect.height;   // 0..1
                const rotY = (px - 0.5) * 2 * TILT_MAX_DEG;
                const rotX = (0.5 - py) * 2 * TILT_MAX_DEG;
                card.classList.add("is-tilted");
                card.style.transform =
                    `perspective(900px) rotateX(${rotX.toFixed(2)}deg) rotateY(${rotY.toFixed(2)}deg) translateY(-4px)`;
                card.style.setProperty("--spot-x", `${(px * 100).toFixed(1)}%`);
                card.style.setProperty("--spot-y", `${(py * 100).toFixed(1)}%`);
            });
        });

        card.addEventListener("mouseleave", () => {
            if (frame) {
                cancelAnimationFrame(frame);
                frame = null;
            }
            card.classList.remove("is-tilted");
            card.style.transform = "";
        });
    }

    /* Vinculacion perezosa al primer mouseover sobre cada elemento. */
    const bound = new WeakSet();
    document.addEventListener("mouseover", (event) => {
        if (!allowHoverMotion() || !event.target.closest) return;
        const target = event.target.closest("[data-magnetic], [data-tilt]");
        if (!target || bound.has(target)) return;
        bound.add(target);
        if (target.hasAttribute("data-magnetic")) bindMagnetic(target);
        if (target.hasAttribute("data-tilt")) bindTilt(target);
    });

    /* --- Onda al presionar ----------------------------------------- */
    document.addEventListener("pointerdown", (event) => {
        if (reducedMotion.matches || !event.target.closest) return;
        if (event.pointerType === "mouse" && event.button !== 0) return;
        const host = event.target.closest("[data-ripple]");
        if (!host) return;

        const rect = host.getBoundingClientRect();
        const size = Math.max(rect.width, rect.height) * 2;
        const ripple = document.createElement("span");
        ripple.className = "fx-ripple";
        ripple.style.width = `${size}px`;
        ripple.style.height = `${size}px`;
        ripple.style.left = `${event.clientX - rect.left - size / 2}px`;
        ripple.style.top = `${event.clientY - rect.top - size / 2}px`;
        host.appendChild(ripple);

        ripple.addEventListener("animationend", () => ripple.remove(), { once: true });
        setTimeout(() => ripple.remove(), 700); // red de seguridad si la animacion no corre
    });
})();
