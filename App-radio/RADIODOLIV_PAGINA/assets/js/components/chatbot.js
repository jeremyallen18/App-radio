/* ============================================
   components/chatbot.js
   Chatbot flotante DoliBot, disponible en
   todas las paginas que cargan main.js.
   ============================================ */

/* Enlaces oficiales que el chatbot puede compartir con visitantes. Los
   internos llevan window.SITE_BASE al frente (igual que data/search-items.js)
   para que funcionen tanto en index.php como dentro de /pages/. */
const dolivBotLinks = {
    facebook: "https://www.facebook.com/people/RADIO-DOLIV/61574197135745/",
    instagram: "https://www.instagram.com/radio_doliv/",
    tiktok: "https://www.tiktok.com/@radio_doliv",
    youtube: "https://youtube.com/@r_doliv?si=fZA7DtkJsxY3rGpl",
    whatsapp: "https://wa.me/5217131205259",
    inicio: `${window.SITE_BASE || ""}index.php`,
    servicios: `${window.SITE_BASE || ""}pages/servicios.php`,
    anuncios: `${window.SITE_BASE || ""}pages/anuncios.php`,
    eventos: `${window.SITE_BASE || ""}pages/eventos.php`,
    equipo: `${window.SITE_BASE || ""}pages/equipo.php`,
    podcast: `${window.SITE_BASE || ""}pages/podcast.php`,
    programas: `${window.SITE_BASE || ""}pages/programas.php`,
    seccionAzul: `${window.SITE_BASE || ""}pages/seccionazul.php`,
    conocenos: `${window.SITE_BASE || ""}pages/conocenos.php`,
};

/* Crea enlaces HTML seguros para mensajes del bot. */
function dolivBotLink(url, label) {
    const isExternal = /^(https?:|mailto:|tel:)/i.test(url);
    const target = isExternal ? ' target="_blank" rel="noopener noreferrer"' : "";
    return `<a href="${url}"${target}>${label}</a>`;
}

/* Etiqueta visible para cada clave de dolivBotLinks cuando DoliBot IA la
   inserta en su respuesta (ver formato [[clave]] en inc/api/dolibot-chat.php). */
const dolivBotLinkLabels = {
    facebook: "Facebook",
    instagram: "Instagram",
    tiktok: "TikTok",
    youtube: "YouTube",
    whatsapp: "WhatsApp",
    inicio: "Inicio",
    servicios: "Servicios",
    anuncios: "Anuncios",
    eventos: "Eventos",
    equipo: "Equipo",
    podcast: "Podcast",
    programas: "Programas",
    seccionAzul: "Sección Azul",
    conocenos: "Conócenos",
};

/* Normaliza mensajes del usuario para reconocer intenciones con o sin acentos.
   Delega en RadioDoliv.utils.normalizeText (antes era una copia identica de
   normalizeSearchText en components/search.js). */
const normalizeDolivBotText = window.RadioDoliv.utils.normalizeText;

/* Respuesta completa de paquetes para que el usuario no tenga que buscarlos uno por uno. */
function getDolivServicesReply() {
    return `
        Estos son los servicios que Radio Doliv puede cotizar para tu marca o proyecto:
        <ul class="doliv-bot-list">
            <li><strong>Transmisión en Vivo:</strong> cobertura para eventos, lanzamientos o programas en tiempo real.</li>
            <li><strong>Gestión de Redes:</strong> diseño y planeación de contenido para mejorar visibilidad y engagement.</li>
            <li><strong>Producción de Podcast:</strong> apoyo desde la idea hasta grabación, edición, publicación y distribución.</li>
            <li><strong>Promoción para Músicos:</strong> difusión y contenido estratégico para proyectos musicales.</li>
            <li><strong>Entrevistas de Impacto:</strong> formatos para contar historias, presentar proyectos o conectar con público nuevo.</li>
            <li><strong>Soluciones para Empresarios:</strong> campañas y presencia de marca enfocadas en posicionamiento comercial.</li>
            <li><strong>Impulso para Emprendedores:</strong> estrategia publicitaria para lanzar o hacer crecer una marca.</li>
            <li><strong>Doliv Media Pack:</strong> difusión integral combinando radio, contenido digital y presencia de marca.</li>
            <li><strong>Promoción para Comerciantes Locales:</strong> campañas pensadas para negocios de la comunidad.</li>
            <li><strong>Activaciones con Botarga:</strong> acciones presenciales para atraer clientes y generar recordación.</li>
        </ul>
        Para costos y disponibilidad, lo mejor es escribir por ${dolivBotLink(dolivBotLinks.whatsapp, "WhatsApp")} o revisar ${dolivBotLink(dolivBotLinks.servicios, "Servicios")}.
    `;
}

/* Opciones iniciales dentro de la conversación. */
function getDolivStartOptions() {
    return `
        ¿Qué te gustaría consultar?
        <div class="doliv-bot-choice-grid">
            <button type="button" class="doliv-bot-choice" data-bot-prompt="Servicios">Servicios</button>
            <button type="button" class="doliv-bot-choice" data-bot-prompt="Podcast">Podcast</button>
            <button type="button" class="doliv-bot-choice" data-bot-prompt="Anuncios">Anuncios</button>
            <button type="button" class="doliv-bot-choice" data-bot-prompt="Eventos">Eventos</button>
            <button type="button" class="doliv-bot-choice" data-bot-prompt="Locutores">Locutores</button>
            <button type="button" class="doliv-bot-choice" data-bot-prompt="Sección Azul">Sección Azul</button>
        </div>
    `;
}

/* Construye el chatbot flotante en todas las páginas que cargan este script. */
function initDolivBot() {
    /* Evita duplicar el bot si el script se carga más de una vez. */
    if (document.getElementById("doliv-bot")) return;

    /* Crea el botón flotante que abre el chat. */
    const launcher = document.createElement("button");
    launcher.className = "doliv-bot-launcher";
    launcher.type = "button";
    launcher.setAttribute("aria-label", "Abrir chat de Radio Doliv");
    launcher.innerHTML = `<img src="${window.SITE_BASE || ""}assets/img/logo/logo.png" alt="">`;

    /* Crea la ventana principal del chatbot. */
    const bot = document.createElement("section");
    bot.className = "doliv-bot";
    bot.id = "doliv-bot";
    bot.setAttribute("aria-hidden", "true");
    bot.innerHTML = `
        <header class="doliv-bot-header">
            <div class="doliv-bot-brand">
                <span class="doliv-bot-avatar"><img src="${window.SITE_BASE || ""}assets/img/logo/logo.png" alt="Radio Doliv"></span>
                <span>
                    <strong>DoliBot</strong>
                    <small>Asistente Virtual - En línea</small>
                </span>
            </div>
            <div class="doliv-bot-actions">
                <button class="doliv-bot-icon-btn" type="button" data-bot-minimize aria-label="Minimizar chat">
                    <i data-lucide="minus"></i>
                </button>
                <button class="doliv-bot-icon-btn" type="button" data-bot-close aria-label="Cerrar chat">
                    <i data-lucide="x"></i>
                </button>
            </div>
        </header>
        <div class="doliv-bot-messages" aria-live="polite"></div>
        <form class="doliv-bot-form">
            <input type="text" class="doliv-bot-input" placeholder="Escribe tu mensaje..." autocomplete="off">
            <button type="submit" aria-label="Enviar mensaje"><i data-lucide="send"></i></button>
        </form>
    `;

    /* Agrega los elementos al documento para que floten sobre cualquier página. */
    document.body.appendChild(launcher);
    document.body.appendChild(bot);

    /* Referencias internas del chatbot. */
    const messages = bot.querySelector(".doliv-bot-messages");
    const form = bot.querySelector(".doliv-bot-form");
    const input = bot.querySelector(".doliv-bot-input");
    const closeButton = bot.querySelector("[data-bot-close]");
    const minimizeButton = bot.querySelector("[data-bot-minimize]");

    /* Historial reciente para darle contexto a la IA (OpenRouter). Se manda
       al backend en cada mensaje y se recorta para no crecer sin límite. */
    const dolivBotHistory = [];

    /* Escapa texto antes de insertarlo como HTML: la respuesta de la IA es
       texto libre generado por un modelo externo (y puede incluir texto
       escrito por el propio usuario reflejado de vuelta), asi que nunca se
       trata como HTML de confianza, a diferencia de las respuestas locales
       fijas de getDolivBotReply. */
    function escapeBotHtml(text) {
        const div = document.createElement("div");
        div.textContent = text;
        return div.innerHTML;
    }

    /* Convierte saltos de línea de la respuesta de la IA en <br> despues de
       escapar el texto, para que se lea igual de bien que las respuestas
       locales sin arriesgar XSS. */
    function formatAiReply(text) {
        const withLineBreaks = escapeBotHtml(text).replace(/\n+/g, "<br>");
        /* Resuelve tokens [[clave]] que la IA inserta para enlazar secciones
           del sitio (ver system prompt en inc/api/dolibot-chat.php). Solo se
           convierten en <a> si la clave existe en dolivBotLinks: el modelo
           nunca controla directamente una URL, solo elige entre esta lista
           blanca, así que no hay riesgo de que "recomiende" un enlace externo
           arbitrario. Cualquier token con una clave desconocida se deja como
           texto plano. */
        return withLineBreaks.replace(/\[\[([a-zA-Z]+)\]\]/g, (match, rawKey) => {
            const key = Object.keys(dolivBotLinks).find((k) => k.toLowerCase() === rawKey.toLowerCase());
            if (!key) return match;
            return dolivBotLink(dolivBotLinks[key], dolivBotLinkLabels[key] || key);
        });
    }

    /* Devuelve la hora local para cada burbuja del chat. */
    function currentBotTime() {
        return new Date().toLocaleTimeString("es-MX", { hour: "2-digit", minute: "2-digit" });
    }

    /* Inserta un mensaje en la conversación. */
    function addBotMessage(content, sender = "bot") {
        const bubble = document.createElement("article");
        const messageBody = document.createElement("div");
        const messageTime = document.createElement("time");
        bubble.className = `doliv-bot-message is-${sender}`;
        if (sender === "user") {
            messageBody.textContent = content;
        } else {
            messageBody.innerHTML = content;
        }
        messageTime.textContent = currentBotTime();
        bubble.appendChild(messageBody);
        bubble.appendChild(messageTime);
        messages.appendChild(bubble);
        messages.scrollTop = messages.scrollHeight;
    }

    /* Muestra un pequeño indicador mientras el bot prepara respuesta. */
    function showTyping() {
        const typing = document.createElement("article");
        typing.className = "doliv-bot-message is-bot is-typing";
        typing.innerHTML = "<div><span></span><span></span><span></span></div>";
        messages.appendChild(typing);
        messages.scrollTop = messages.scrollHeight;
        return typing;
    }

    /* Genera respuestas naturales según palabras clave del usuario. */
    function getDolivBotReply(message) {
        const text = normalizeDolivBotText(message);

        if (!text) {
            return "Te leo. Puedes preguntarme por servicios, anuncios, eventos, podcasts, locutores, redes o Sección Azul.";
        }

        if (/(hola|buenas|hey|que tal|saludos)/.test(text)) {
            return "¡Hola! Qué gusto tenerte por aquí. Soy DoliBot y puedo ayudarte a moverte por Radio Doliv, encontrar secciones o contactar al equipo.";
        }

        if (/(gracias|muchas gracias|perfecto|excelente)/.test(text)) {
            return "¡Con gusto! Me alegra ayudarte. Si necesitas otra sección o contacto, aquí sigo.";
        }

        if (/(servicio|cotizar|publicidad|contratar|precio|paquete|anunciarme|marca|negocio)/.test(text)) {
            return getDolivServicesReply();
        }

        if (/(whatsapp|contacto|telefono|llamar|mensaje)/.test(text)) {
            return `Claro. Puedes contactarnos por ${dolivBotLink(dolivBotLinks.whatsapp, "WhatsApp")} o revisar nuestras redes: ${dolivBotLink(dolivBotLinks.facebook, "Facebook")}, ${dolivBotLink(dolivBotLinks.instagram, "Instagram")}, ${dolivBotLink(dolivBotLinks.tiktok, "TikTok")} y ${dolivBotLink(dolivBotLinks.youtube, "YouTube")}.`;
        }

        if (/(facebook|instagram|tiktok|youtube|redes|red social|redes sociales)/.test(text)) {
            return `Estas son nuestras redes oficiales: ${dolivBotLink(dolivBotLinks.facebook, "Facebook")}, ${dolivBotLink(dolivBotLinks.instagram, "Instagram")}, ${dolivBotLink(dolivBotLinks.tiktok, "TikTok")} y ${dolivBotLink(dolivBotLinks.youtube, "YouTube")}.`;
        }

        if (/(anuncio|anuncios|promocion|promociones|informacion)/.test(text)) {
            return `Los anuncios activos están en ${dolivBotLink(dolivBotLinks.anuncios, "Anuncios")}. Si quieres publicar uno o pedir información sobre un anuncio, lo más rápido es escribir por ${dolivBotLink(dolivBotLinks.whatsapp, "WhatsApp")}.`;
        }

        if (/(evento|eventos|kpop|festival|actividad|31 minutos)/.test(text)) {
            return `Puedes ver actividades y experiencias en ${dolivBotLink(dolivBotLinks.eventos, "Eventos")}. Si necesitas detalles de un evento específico, también puedes contactar al equipo por ${dolivBotLink(dolivBotLinks.whatsapp, "WhatsApp")}.`;
        }

        if (/(locutor|locutora|equipo|conductores|integrantes|quien conduce)/.test(text)) {
            return `Para conocer locutores, conductoras y equipo de Radio Doliv entra a ${dolivBotLink(dolivBotLinks.equipo, "Equipo")}. Si buscas a alguien en particular, dime su nombre y te ayudo a ubicar la sección.`;
        }

        if (/(seccion azul|seccionazul|patrocinador|patrocinadores|aliado|aliados|directorio|negocio)/.test(text)) {
            return `La ${dolivBotLink(dolivBotLinks.seccionAzul, "Sección Azul")} reúne patrocinadores, aliados, escuelas, negocios, redes y ubicaciones. Es la mejor ruta si buscas información de un aliado de Radio Doliv.`;
        }

        if (/(podcast|episodio|audio|escuchar|capitulo)/.test(text)) {
            return `En ${dolivBotLink(dolivBotLinks.podcast, "Podcast")} puedes escuchar episodios disponibles y filtrar por programa. Hay contenido de Voces Jóvenes, Envinadas y Divorciadas, Mi Ansiedad y Yo, Fuera de Guion y Mariposa de Crystal. Si quieres producir un podcast para tu marca, también entra en el paquete de Producción de Podcast dentro de Servicios.`;
        }

        if (/(programa|programas|horario|parrilla|radio en vivo|en vivo)/.test(text)) {
            return `Para horarios y espacios al aire visita ${dolivBotLink(dolivBotLinks.programas, "Programas")}. Si quieres escuchar la radio en vivo, vuelve a ${dolivBotLink(dolivBotLinks.inicio, "Inicio")} y usa el reproductor principal.`;
        }

        if (/(conocenos|quienes son|historia|mision|vision|valores)/.test(text)) {
            return `Si quieres saber más sobre Radio Doliv, entra a ${dolivBotLink(dolivBotLinks.conocenos, "Conócenos")}. Ahí encuentras nuestra esencia, historia y valores.`;
        }

        if (/(navegar|pagina|menu|donde|ir a|llevar|ayuda)/.test(text)) {
            return `Te puedo llevar a: ${dolivBotLink(dolivBotLinks.inicio, "Inicio")}, ${dolivBotLink(dolivBotLinks.servicios, "Servicios")}, ${dolivBotLink(dolivBotLinks.programas, "Programas")}, ${dolivBotLink(dolivBotLinks.podcast, "Podcast")}, ${dolivBotLink(dolivBotLinks.anuncios, "Anuncios")}, ${dolivBotLink(dolivBotLinks.eventos, "Eventos")}, ${dolivBotLink(dolivBotLinks.equipo, "Equipo")} o ${dolivBotLink(dolivBotLinks.seccionAzul, "Sección Azul")}.`;
        }

        return `Puedo ayudarte con navegación del sitio, servicios, anuncios, eventos, locutores, podcasts, programas, Sección Azul o redes sociales. También puedes escribirnos directo por ${dolivBotLink(dolivBotLinks.whatsapp, "WhatsApp")}.`;
    }

    /* Deshace el atrapado de foco activo (si el chat esta abierto). */
    let releaseFocusTrap = null;

    /* Abre el chatbot y enfoca el campo de texto. Atrapa el foco de teclado
       dentro del panel mientras esta abierto (antes el foco podia salirse
       al fondo de la pagina con Tab). */
    function openBot() {
        bot.classList.add("is-open");
        bot.setAttribute("aria-hidden", "false");
        launcher.classList.add("is-hidden");
        window.setTimeout(() => input.focus(), 120);
        releaseFocusTrap = window.RadioDoliv.utils.trapFocus(bot);
    }

    /* Cierra el chatbot, devuelve el botón flotante y regresa el foco al
       lanzador (antes el foco se perdia al cerrar). */
    function closeBot() {
        bot.classList.remove("is-open", "is-expanded");
        bot.setAttribute("aria-hidden", "true");
        launcher.classList.remove("is-hidden");
        if (releaseFocusTrap) {
            releaseFocusTrap();
            releaseFocusTrap = null;
        }
        launcher.focus();
    }

    /* Pide una respuesta a DoliBot IA (OpenRouter, vía el backend en
       inc/api/dolibot-chat.php). Devuelve null si no se pudo usar la IA,
       para que el llamador caiga a las respuestas locales por palabras
       clave y el chat nunca se quede sin responder. */
    async function fetchAiReply(message) {
        try {
            const response = await fetch(`${window.SITE_BASE || ""}inc/api/dolibot-chat.php`, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ message, history: dolivBotHistory }),
            });
            const data = await response.json();
            if (!response.ok || !data.success || !data.reply) return null;
            return data.reply;
        } catch (error) {
            return null;
        }
    }

    /* Procesa el texto escrito por el usuario: intenta responder con la IA
       de DoliBot y, si no está disponible, usa las respuestas locales por
       palabras clave (getDolivBotReply) como respaldo. */
    async function handleUserMessage(message) {
        addBotMessage(message, "user");
        const typing = showTyping();

        const aiReply = await fetchAiReply(message);
        typing.remove();

        if (aiReply) {
            dolivBotHistory.push({ role: "user", content: message });
            dolivBotHistory.push({ role: "assistant", content: aiReply });
            /* Conserva solo los últimos turnos para no mandar un historial
               cada vez más largo (y más caro) en cada petición. */
            if (dolivBotHistory.length > 12) dolivBotHistory.splice(0, dolivBotHistory.length - 12);
            addBotMessage(formatAiReply(aiReply), "bot");
        } else {
            addBotMessage(getDolivBotReply(message), "bot");
        }
    }

    /* Mensajes iniciales con tono cercano. */
    addBotMessage("¡Hola! Soy DoliBot, tu asistente virtual de Radio Doliv.");
    addBotMessage("Puedo ayudarte a navegar la página, encontrar servicios, anuncios, eventos, locutores, podcasts, Sección Azul y redes sociales.");
    addBotMessage(getDolivStartOptions());

    /* Eventos principales del chatbot. */
    launcher.addEventListener("click", openBot);
    closeButton.addEventListener("click", closeBot);
    minimizeButton.addEventListener("click", closeBot);
    messages.addEventListener("click", (event) => {
        const choice = event.target.closest("[data-bot-prompt]");
        if (choice) {
            handleUserMessage(choice.dataset.botPrompt);
        }
    });
    form.addEventListener("submit", (event) => {
        event.preventDefault();
        const message = input.value.trim();
        if (!message) return;
        input.value = "";
        handleUserMessage(message);
    });
    /* Cierra con Escape (antes solo el buscador tenia este atajo). */
    window.addEventListener("keydown", (event) => {
        if (event.key === "Escape" && bot.classList.contains("is-open")) {
            closeBot();
        }
    });

    /* Dibuja iconos después de insertar HTML dinámico. */
    if (window.lucide) lucide.createIcons();
}

/* Activa el asistente virtual global. */
initDolivBot();
