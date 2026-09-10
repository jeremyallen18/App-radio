/* ============================================
   core/theme.js
   Controla el modo claro/oscuro del sitio.
   ============================================ */

/* Referencia compartida al <body> (definida por core/namespace.js, que
   siempre se carga primero). Ya no se declara un "body" global propio:
   radio.js y mobile-menu.js leen RadioDoliv.body en vez de depender de
   un identificador implícito sostenido solo por el orden de <script>. */
const body = window.RadioDoliv.body;

/* Botón del tema (si existe en la página actual). */
const themeToggle = document.getElementById("theme-toggle");

/* Función que aplica tema y guarda preferencia en localStorage. */
function setTheme(isLight) {
    /* Agrega o quita la clase según valor booleano. */
    body.classList.toggle("light-theme", isLight);

    /* Guarda preferencia de tema para próximas páginas. */
    localStorage.setItem("theme", isLight ? "light" : "dark");

    /* Si existe el botón de tema, actualizamos su icono y su estado accesible. */
    if (themeToggle) {
        /* Elegimos luna cuando está en claro, y sol cuando está en oscuro. */
        const iconName = isLight ? "moon" : "sun";

        /* Renderizamos el icono dinámico. */
        themeToggle.innerHTML = `<i data-lucide="${iconName}" id="theme-icon"></i>`;

        /* Refleja el estado del tema para lectores de pantalla (antes el
           botón no anunciaba si el tema claro estaba activo o no). */
        themeToggle.setAttribute("aria-pressed", String(isLight));
        themeToggle.setAttribute("aria-label", isLight ? "Cambiar a tema oscuro" : "Cambiar a tema claro");

        /* Pedimos a Lucide que pinte el icono nuevo. */
        if (window.lucide) {
            lucide.createIcons();
        }
    }
}

/* Recupera tema guardado previamente. */
const savedTheme = localStorage.getItem("theme");

/* Aplica tema al cargar script. */
setTheme(savedTheme === "light");

/* Si existe botón tema, registramos clic para alternar tema. */
if (themeToggle) {
    themeToggle.addEventListener("click", () => {
        /* Calcula el siguiente estado. */
        const isLight = !body.classList.contains("light-theme");

        /* Aplica el nuevo estado. */
        setTheme(isLight);
    });
}
