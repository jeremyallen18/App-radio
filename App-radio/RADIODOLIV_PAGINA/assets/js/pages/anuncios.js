/* ============================================
   pages/anuncios.js
   Comportamiento de la pagina de anuncios (modal, zoom, enlaces
   seguros). Los datos ya vienen renderizados por PHP y se pasan
   aqui via la isla JSON #announcements-data (ver pages/anuncios.php).
   ============================================ */
(function () {
    const pageSignal = window.RadioDoliv.pageSignal;
    const announcementsDataEl = document.getElementById("announcements-data");
    const announcements = announcementsDataEl ? JSON.parse(announcementsDataEl.textContent || "[]") : [];
    const modal = document.getElementById("announcement-modal");
    const modalClose = document.getElementById("announcement-modal-close");
    const modalImg = document.getElementById("announcement-modal-img");
    const modalDate = document.getElementById("announcement-modal-date");
    const modalTitle = document.getElementById("announcement-modal-title");
    const modalDesc = document.getElementById("announcement-modal-desc");
    const modalLinks = document.getElementById("announcement-modal-links");
    const zoomInBtn = document.getElementById("announcement-zoom-in");
    const zoomOutBtn = document.getElementById("announcement-zoom-out");
    const zoomResetBtn = document.getElementById("announcement-zoom-reset");
    let currentZoom = 1;

    function imagePath(path) {
        if (!path) return "";
        if (/^https?:\/\//i.test(path)) return path;
        // imagen_url en la BD es relativa a la RAIZ del sitio (ej.
        // "assets/img/anuncios/foo.jpg"), y esta pagina vive un nivel
        // abajo (pages/) -- hace falta SITE_BASE al frente, igual que
        // en eventos.js (fields.image.src) o equipo.js (member.image).
        return (window.SITE_BASE || "") + path.replaceAll(" ", "%20");
    }

    function formatDate(value) {
        if (!value) return "Fecha no disponible";
        const date = new Date(value.replace(" ", "T"));
        if (Number.isNaN(date.getTime())) return value;
        return date.toLocaleDateString("es-MX", { year: "numeric", month: "long", day: "numeric" });
    }

    function setZoom(value) {
        currentZoom = Math.min(2.4, Math.max(0.7, value));
        modalImg.style.transform = `scale(${currentZoom})`;
    }

    // Valida que los enlaces de la base de datos usen protocolos seguros.
    function safeExternalUrl(url) {
        const value = String(url || "").trim();
        if (!value || value.toUpperCase() === "NULL") return "";
        try {
            const parsedUrl = new URL(value, window.location.href);
            return ["http:", "https:", "mailto:", "tel:"].includes(parsedUrl.protocol) ? parsedUrl.href : "";
        } catch (error) {
            return "";
        }
    }

    function addLink(label, url, icon) {
        const safeUrl = safeExternalUrl(url);
        if (!safeUrl) return;
        const link = document.createElement("a");
        link.href = safeUrl;
        link.target = "_blank";
        link.rel = "noopener noreferrer";
        link.innerHTML = `<i data-lucide="${icon}"></i><span>${label}</span>`;
        modalLinks.appendChild(link);
    }

    function openAnnouncement(index) {
        const item = announcements[index];
        if (!item) return;

        const title = item.titulo || "Anuncio";
        const image = imagePath(item.imagen_url || "");

        modalTitle.textContent = title;
        modalDesc.textContent = item.descripcion || "Sin descripción disponible.";
        modalDate.textContent = formatDate(item.fecha_publicacion || "");
        modalImg.src = image;
        modalImg.alt = title;
        modalImg.hidden = image === "";
        modalLinks.innerHTML = "";

        addLink("Página web", item.link_web, "globe");
        addLink("Facebook", item.link_facebook, "external-link");
        addLink("WhatsApp", item.link_whatsapp, "message-circle");

        if (modalLinks.children.length === 0) {
            modalLinks.innerHTML = "<p>No hay enlaces adicionales para este anuncio.</p>";
        }

        setZoom(1);
        modal.classList.add("is-open");
        modal.setAttribute("aria-hidden", "false");
        document.body.style.overflow = "hidden";
        if (window.lucide) lucide.createIcons();
    }

    function closeAnnouncement() {
        modal.classList.remove("is-open");
        modal.setAttribute("aria-hidden", "true");
        document.body.style.overflow = "";
    }

    document.querySelectorAll("[data-announcement-index]").forEach((button) => {
        button.addEventListener("click", () => openAnnouncement(Number(button.dataset.announcementIndex)));
    });

    modalClose.addEventListener("click", closeAnnouncement);
    modal.addEventListener("click", (event) => {
        if (event.target.matches("[data-close-announcement='true']")) {
            closeAnnouncement();
        }
    });
    window.addEventListener("keydown", (event) => {
        if (event.key === "Escape" && modal.classList.contains("is-open")) {
            closeAnnouncement();
        }
    }, { signal: pageSignal });
    zoomInBtn.addEventListener("click", () => setZoom(currentZoom + 0.2));
    zoomOutBtn.addEventListener("click", () => setZoom(currentZoom - 0.2));
    zoomResetBtn.addEventListener("click", () => setZoom(1));
})();
