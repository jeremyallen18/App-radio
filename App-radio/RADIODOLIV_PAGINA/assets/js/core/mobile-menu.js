/* ============================================
   core/mobile-menu.js
   Menú hamburguesa (móvil).
   ============================================ */

/* Referencias del navbar principal para construir toggle móvil. */
const navContainer = document.querySelector(".nav-container");
const navLinksMenu = document.querySelector(".nav-links");

/* Solo crea menú hamburguesa si existen los elementos del navbar. */
if (navContainer && navLinksMenu) {
    /* Creamos el botón hamburguesa dinámicamente para no repetir HTML en cada página. */
    const mobileToggle = document.createElement("button");
    mobileToggle.className = "mobile-menu-toggle";
    mobileToggle.id = "mobile-menu-toggle";
    mobileToggle.setAttribute("aria-label", "Abrir menú");
    mobileToggle.setAttribute("aria-expanded", "false");
    mobileToggle.innerHTML = '<i data-lucide="menu"></i>';

    /* Lo agregamos al final del contenedor del navbar. */
    navContainer.appendChild(mobileToggle);

    /* Función para actualizar icono (menú / x) y estado accesible. */
    function updateMobileToggleUI(isOpen) {
        mobileToggle.innerHTML = isOpen
            ? '<i data-lucide="x"></i>'
            : '<i data-lucide="menu"></i>';
        mobileToggle.setAttribute("aria-expanded", String(isOpen));
        mobileToggle.setAttribute("aria-label", isOpen ? "Cerrar menú" : "Abrir menú");
        if (window.lucide) {
            lucide.createIcons();
        }
    }

    /* Toggle de apertura/cierre del menú en móvil. */
    mobileToggle.addEventListener("click", () => {
        const isOpen = window.RadioDoliv.body.classList.toggle("mobile-menu-open");
        updateMobileToggleUI(isOpen);
    });

    /* Inserta buscador visual dentro del panel móvil (una sola vez). */
    if (!navLinksMenu.querySelector(".mobile-search-row")) {
        const searchLi = document.createElement("li");
        const mobileSearch = document.createElement("div");
        mobileSearch.className = "mobile-search-row";
        mobileSearch.innerHTML = '<i data-lucide="search"></i><input class="mobile-search-input" type="text" placeholder="Buscar...">';
        searchLi.appendChild(mobileSearch);
        navLinksMenu.prepend(searchLi);

        const mobileSearchInput = mobileSearch.querySelector(".mobile-search-input");
        mobileSearchInput.addEventListener("focus", () => {
            const desktopSearch = document.querySelector(".search-input");
            if (desktopSearch) {
                desktopSearch.value = mobileSearchInput.value;
                desktopSearch.dispatchEvent(new Event("input", { bubbles: true }));
            }
        });
    }

    /* Cierra menú al tocar un enlace en móvil. */
    navLinksMenu.querySelectorAll("a").forEach((link) => {
        link.addEventListener("click", () => {
            window.RadioDoliv.body.classList.remove("mobile-menu-open");
            updateMobileToggleUI(false);
        });
    });

    /* Si se expande a desktop, forzamos estado cerrado para evitar inconsistencias.
       Con debounce (antes corria en cada tick de resize sin limitar). */
    window.addEventListener("resize", window.RadioDoliv.utils.debounce(() => {
        if (window.innerWidth > 768 && window.RadioDoliv.body.classList.contains("mobile-menu-open")) {
            window.RadioDoliv.body.classList.remove("mobile-menu-open");
            updateMobileToggleUI(false);
        }
    }, 150));

    /* Estado inicial del icono. */
    updateMobileToggleUI(false);
}
