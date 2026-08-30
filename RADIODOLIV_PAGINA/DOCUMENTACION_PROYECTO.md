# Documentacion del proyecto Radio Doliv

## Rediseno del Home (30 de julio de 2026)

`index.html` se rediseno por completo (hero con reproductor integrado y ondas decorativas, franja de logros con contadores animados, "al aire ahora" con parrilla del dia, programas destacados, seccion "Conoce Radio Doliv", "Por que Radio Doliv", eventos/novedades, testimonios y CTA final, ademas de un footer con redes sociales y boletin). El navbar y el footer se mejoraron de forma compatible con el resto del sitio (solo se agregaron reglas CSS nuevas; nada se elimino de `components/navbar.css` ni `components/footer.css`, y la variante de footer de 4 columnas usa una clase extra `footer-container--extended` que solo aplica en `index.html`, por lo que las demas paginas conservan su footer de 3 columnas sin cambios).

Se agrego `--brand-cyan: #00d4ff` (y `--brand-navy`, `--brand-deep-blue`, `--brand-gray`) en `assets/css/base.css` junto a las variables originales, para no alterar el resto del sitio que sigue usando `--cyan-glow`.

Nuevos archivos CSS (todos importados desde `assets/css/main.css`): `pages/index-highlights.css`, `pages/index-onair.css`, `pages/index-about.css`, `pages/index-why.css`, `pages/index-news.css`, `pages/index-testimonials.css`. `pages/index-hero.css` y `pages/index-programs.css` se reescribieron; `pages/index-community.css` ahora aloja el CTA final (el modal de redes sociales conservo su CSS igual).

La interactividad nueva (contador animado, aparicion progresiva de secciones al hacer scroll, navbar solida al hacer scroll, calculo de "al aire ahora" segun la hora local del visitante, carrusel de testimonios y efecto ripple en botones) vive en un `<script>` propio al final de `index.html`, sin dependencias externas ni frameworks.

Se preservaron todos los enganches que usa el JavaScript compartido: `#theme-toggle`, `.search-container`/`.search-input`, `#playBtnHero`, `#volume-slider`, `#radio-status-label`/`#radio-status-text`, `#radio-audio`, `.nav-container`/`.nav-links` y `#open-social-modal`/`#social-modal`/`#social-modal-close`. La radio, el tema claro/oscuro, el buscador global, el chatbot y el menu movil se probaron despues del rediseno y siguen funcionando igual.

Este documento explica para que sirve cada archivo principal del sitio y como se conectan entre si. La idea es que puedas ubicar rapido que editar sin tener que leer todo el codigo desde cero.

## Refactor de arquitectura (30 de julio de 2026)

El sitio se reorganizo en carpetas por tipo de archivo y el CSS/JS globales se dividieron en modulos. Cambios clave:

- `index.html` sigue siendo la unica pagina en la raiz (para que `/` funcione igual que antes). El resto de paginas se movieron a `pages/`.
- Las URLs viejas de la raiz (`/servicios.html`, `/podcast.html`, etc.) siguen funcionando gracias a redirecciones 301 en el nuevo `.htaccess` de la raiz, que apuntan a la ruta nueva dentro de `/pages/`. Esto evita romper enlaces, codigos QR y posicionamiento ya existentes. Estas redirecciones dependen de Apache/mod_rewrite (Hostinger) y no funcionan con un servidor estatico simple en local.
- Todas las imagenes y audios se movieron dentro de `assets/img/*` y `assets/audio/podcasts/`.
- `styles-v2.css` (5187 lineas) se dividio en modulos dentro de `assets/css/` (`base.css`, `components/`, `pages/`, `themes/`, `responsive.css`), unidos por `assets/css/main.css` mediante `@import`, respetando el orden original para no alterar la cascada. `stilo.css`, que ya no se usaba, fue eliminado.
- `script.js` (971 lineas) se dividio en 6 archivos dentro de `assets/js/` (`core/theme.js`, `core/radio.js`, `data/search-items.js`, `components/search.js`, `components/chatbot.js`, `core/mobile-menu.js`), cargados como scripts clasicos (sin `type="module"`) en ese orden, uno por etiqueta `<script>` en cada pagina. No se usan modulos ES porque los navegadores bloquean `import` entre archivos locales cuando el sitio se abre con doble clic (protocolo `file://`).
- Las rutas internas (paginas, imagenes, CSS, JS) son relativas segun la profundidad de cada pagina: `index.html` usa `assets/...` y `pages/...`; las paginas dentro de `pages/` usan `../assets/...` y nombres sueltos entre si. Como `data/search-items.js` y `components/chatbot.js` se comparten entre paginas de distinta profundidad, cada pagina define `window.SITE_BASE` (`""` en `index.html`, `"../"` en `pages/*`) para que esos dos archivos puedan armar enlaces e imagenes correctos sin importar desde donde se cargaron.
- `config/db.php` no se movio; sigue en `config/`. Como `anuncios.php` ahora vive en `pages/`, su `require_once` se actualizo a `__DIR__ . "/../config/db.php"`.
- Consulta [ESQUEMA_PROYECTO.md](ESQUEMA_PROYECTO.md) para el arbol de carpetas completo y el diagrama de dependencias actualizado.

Las secciones de abajo (anteriores al refactor) siguen describiendo el comportamiento funcional de cada pagina; solo cambiaron las rutas de archivos, no la logica.

## Estructura general

- `index.html`: pagina de inicio, en la raiz del sitio. Contiene el navbar, el hero principal, reproductor de radio, tarjetas de estadisticas, programas destacados, banner de comunidad y footer.
- `pages/conocenos.html`: pagina institucional. Presenta esencia, mision, vision, valores y datos de contacto.
- `pages/servicios.html`: pagina comercial. Muestra los servicios de Radio Doliv y envia a WhatsApp con mensajes personalizados por servicio.
- `pages/programas.html`: pagina de parrilla. Actualmente muestra Rincon Lunar e Invierno Permanente, con modal para mostrar mas informacion.
- `pages/podcast.html`: biblioteca de podcasts. Muestra filtros por programa, tarjetas de episodios y reproductores de audio.
- `pages/anuncios.php`: pagina dinamica conectada a base de datos. Lee anuncios desde MySQL y los muestra en tarjetas con modal.
- `pages/eventos.html`: pagina de eventos. Muestra una lista tipo boletaje, abre un detalle completo por evento y dirige a Guru Shows para compra de boletos.
- `pages/equipo.html`: pagina del equipo. Muestra integrantes/locutores con tarjetas generadas por JavaScript y modal con foto, biografia, frase y controles de zoom.
- `pages/seccionazul.html`: directorio de patrocinadores y aliados. Genera tarjetas desde JavaScript, permite filtrar por categoria y abre un modal con informacion, redes sociales y mapa.
- Los 6 archivos en `assets/js/core/`, `assets/js/components/` y `assets/js/data/`: JavaScript global, cargado como scripts clasicos en ese orden desde cada pagina. Controla tema claro/oscuro, radio, volumen, menu movil, buscador global y chatbot DoliBot.
- `assets/css/main.css` + modulos en `assets/css/base.css`, `assets/css/components/`, `assets/css/pages/`, `assets/css/themes/` y `assets/css/responsive.css`: hojas de estilo del sitio, unidas mediante `@import` en `main.css`.
- `config/db.php`: configuracion de conexion PDO a MySQL para `pages/anuncios.php`.
- `config/.htaccess`: bloquea acceso directo desde navegador a los archivos de configuracion.
- `.htaccess` (raiz): redirige las URLs antiguas de la raiz hacia sus nuevas ubicaciones en `/pages/`.

## Carpetas de recursos

- `assets/img/logo/`: contiene el logotipo principal del sitio.
- `assets/img/servicios/`: contiene imagenes usadas en las tarjetas de servicios.
- `assets/img/programas/`: contiene portadas o imagenes de programas.
- `assets/img/portadas/`: contiene portadas de podcasts.
- `assets/audio/podcasts/`: contiene archivos MP3 usados en `pages/podcast.html`.
- `assets/img/eventos/`: contiene los flyers usados en `pages/eventos.html` y el QR de WhatsApp de respaldo.
- `assets/img/anuncios/`: contiene imagenes locales que pueden usarse para anuncios.
- `assets/img/locutores/`: contiene fotos de locutoras/equipo.
- `assets/img/patrocinadores/`: contiene imagenes de patrocinadores.

## Flujo visual comun

Todas las paginas principales comparten esta estructura:

1. `<!DOCTYPE html>` declara HTML5.
2. `<html lang="es">` indica que el contenido esta en espanol.
3. `<head>` contiene metadatos, fuentes, iconos y CSS.
4. `<body>` contiene navbar, contenido principal, footer y scripts.
5. `styles-v2.css?v=20260629programas` o `styles-v2.css?v=20260702boletos` carga los estilos con version para evitar cache viejo en Hostinger.
6. `script.js?v=20260714rinconlunar` carga la logica global tambien versionada.

## Navbar

El navbar aparece en casi todas las paginas:

- `.nav-glass`: barra superior fija con fondo tipo vidrio.
- `.nav-container`: organiza logo, enlaces y acciones.
- `.logo`: muestra imagen y texto de Radio Doliv; funciona como enlace a `index.html`.
- `.nav-links`: lista de enlaces principales.
- `.active`: indica la pagina actual.
- `.search-container`: buscador pequeno del navbar.
- `.theme-toggle`: boton para cambiar entre modo oscuro y claro.

## Buscador global

El buscador esta en `script.js` y `styles-v2.css`.

En `script.js`:

- `searchItems`: lista estatica de resultados buscables. Incluye paginas, servicios, programa activo, podcasts, capitulos de podcast, eventos, anuncios y equipo.
- `normalizeSearchText(value)`: convierte texto a minusculas y quita acentos para buscar mejor.
- `initSiteSearch()`: crea el panel de busqueda, conecta eventos y pinta resultados.
- `renderInitialState()`: muestra el mensaje para escribir al menos 2 caracteres.
- `renderNoResults(query)`: muestra el estado visual cuando no hay coincidencias.
- `renderResults(items)`: agrupa resultados y crea enlaces clickeables.
- `runSearch()`: calcula coincidencias y ordena resultados.
- `openSearch(initialValue)`: abre el panel.
- `closeSearch()`: cierra el panel.

En `styles-v2.css`:

- `.site-search-overlay`: capa oscura de fondo.
- `.site-search-panel`: contenedor flotante del buscador.
- `.site-search-box`: input grande.
- `.site-search-results`: zona desplazable de resultados.
- `.site-search-empty`: estado inicial o sin resultados.
- `.site-search-group`: grupo por categoria.
- `.site-search-result`: tarjeta/enlace de resultado.
- `body.light-theme .site-search...`: variantes para modo claro.

## Chatbot DoliBot

El chatbot se crea globalmente desde `script.js`, por eso aparece en todas las paginas que cargan el script principal.

En `script.js`:

- `dolivBotLinks`: guarda enlaces oficiales de Radio Doliv: Facebook, Instagram, TikTok, YouTube, WhatsApp y paginas internas.
- `dolivBotLink(url, label)`: crea enlaces HTML para respuestas del bot. Abre enlaces externos en una pestana nueva y deja enlaces internos en la misma ventana.
- `normalizeDolivBotText(value)`: normaliza lo que escribe el usuario para reconocer palabras con o sin acentos.
- `getDolivServicesReply()`: devuelve la respuesta completa de servicios/paquetes para que el cliente no tenga que buscarlos manualmente.
- `getDolivStartOptions()`: pinta opciones iniciales dentro de la conversacion: Servicios, Podcast, Anuncios, Eventos, Locutores y Seccion Azul.
- `initDolivBot()`: construye el boton flotante, ventana del chat, mensajes, formulario, botones de opcion y eventos.
- `getDolivBotReply(message)`: decide la respuesta segun la intencion del usuario.
- `addBotMessage(content, sender)`: agrega burbujas de conversacion. Los mensajes del usuario se insertan como texto seguro.
- `showTyping()`: muestra indicador de escritura antes de responder.

Comportamiento actual:

- El boton flotante muestra solo el logo/unicornio desde `logo/logo.png`.
- Al abrir, el encabezado muestra DoliBot, estado "En linea", boton `-` para minimizar y boton `x` para cerrar.
- Ya no existe la barra inferior de botones rapidos; las opciones aparecen dentro del mensaje inicial.
- Si el usuario elige o escribe "Servicios", el bot muestra los 10 paquetes disponibles.
- Responde sobre servicios, podcast, anuncios, eventos, locutores/equipo, Seccion Azul, programas, navegacion y redes sociales.

En `styles-v2.css`:

- `.doliv-bot-launcher`: boton flotante del unicornio.
- `.doliv-bot`: ventana principal.
- `.doliv-bot-header`: encabezado azul.
- `.doliv-bot-messages`: zona desplazable de mensajes.
- `.doliv-bot-message`: burbujas de usuario y bot.
- `.doliv-bot-choice-grid` y `.doliv-bot-choice`: opciones iniciales dentro del chat.
- `.doliv-bot-list`: lista de paquetes de servicios dentro de una respuesta.
- `body.light-theme .doliv-bot...`: variantes de contraste para tema claro.

## Tema claro y oscuro

El tema se controla desde `script.js`:

- `setTheme(isLight)`: aplica o quita `body.light-theme`.
- `localStorage.setItem("theme", ...)`: guarda la preferencia del usuario.
- `themeToggle.addEventListener("click", ...)`: alterna el tema al hacer clic.

En CSS:

- `:root` define variables del tema oscuro.
- `body.light-theme` redefine variables para tema claro.
- Muchas secciones tienen ajustes especificos para asegurar contraste.

## Radio en vivo

La radio se controla desde `script.js`:

- `STREAM_URL`: URL del stream.
- `audio`: referencia al elemento de audio o crea uno si la pagina no lo tiene.
- `toggleRadio()`: reproduce o pausa la radio.
- `playRadio(forceReload)`: reproduce la radio y puede recargar la URL del stream para salir de un buffer congelado.
- `playRadio(forceReload)`: reproduce usando el buffer actual y solo reconstruye la conexion cuando recibe `forceReload` por un error real.
- `initRadioHealthChecks()`: sincroniza el boton ante `playing`, `ended` o `error`, pero no reinicia automaticamente la conexion.
- `initRadioHealthChecks()`: conecta escuchas de salud del audio para detectar cortes del streaming.
- `updateUI(isPlaying)`: cambia icono de play/pausa.
- `localStorage.radioPlaying`: recuerda si la radio estaba sonando.
- `localStorage.radioVolume`: recuerda el volumen.

Nota tecnica: el audio no puede ser realmente persistente entre paginas HTML separadas; al navegar, el navegador crea una nueva instancia del audio. El sitio guarda el estado en `localStorage` e intenta reanudar, pero algunos navegadores pueden bloquear autoplay hasta que el usuario toque play. Dentro de una misma pagina, el sitio ahora intenta reconectar automaticamente si el stream se queda congelado o sin datos.

En `index.html`:

- `#playBtnHero`: boton visual de play/pausa.
- `#volume-slider`: control de volumen.
- `#radio-audio`: elemento de audio inicial.

## Modal de redes sociales del inicio

En `index.html`, el boton `¡Síguenos en nuestras redes sociales!` abre una ventana flotante con enlaces oficiales:

- Instagram: `https://www.instagram.com/radio_doliv/`
- Facebook: `https://www.facebook.com/people/RADIO-DOLIV/61574197135745/`
- TikTok: `https://www.tiktok.com/@radio_doliv`
- YouTube: `https://youtube.com/@r_doliv?si=fZA7DtkJsxY3rGpl`

Elementos principales:

- `#open-social-modal`: boton del banner que abre el modal.
- `#social-modal`: contenedor general de la ventana flotante.
- `.social-modal-overlay`: fondo oscuro; permite cerrar al hacer clic fuera.
- `#social-modal-close`: boton para cerrar.
- `.social-modal-links`: lista de enlaces sociales.

El script interno de `index.html` permite cerrar el modal con el boton `x`, haciendo clic fuera o presionando `Escape`.

## Menu movil

El menu movil se crea desde `script.js`:

- `navContainer`: busca el contenedor del navbar.
- `navLinksMenu`: busca la lista de enlaces.
- `mobileToggle`: boton hamburguesa creado dinamicamente.
- `body.mobile-menu-open`: clase que abre/cierra el panel movil.
- `.mobile-search-row`: buscador dentro del menu movil.

## Servicios

`servicios.html` contiene 10 tarjetas:

1. Transmision en Vivo.
2. Gestion de Redes.
3. Produccion de Podcast.
4. Promocion para Musicos.
5. Entrevistas de Impacto.
6. Soluciones para Empresarios.
7. Impulso para Emprendedores.
8. Doliv Media Pack.
9. Promocion para Comerciantes Locales.
10. Activaciones con Botarga.

Cada boton `.service-wa-btn` abre WhatsApp con un mensaje distinto usando el parametro `text=` en la URL.

Estos mismos 10 servicios tambien estan resumidos dentro de DoliBot mediante `getDolivServicesReply()` para que el visitante pueda verlos sin abandonar la conversacion.

## Programas

`programas.html` muestra los programas activos de Radio Doliv.

Cada boton `.show-more-btn` guarda informacion en atributos `data-*`:

- `data-title`: nombre del programa.
- `data-time`: horario.
- `data-categories`: categorias.
- `data-summary`: descripcion larga.

El script interno abre `#show-modal` y coloca esos datos dentro del modal.

Estado actual:

- Programas visibles: Rincon Lunar e Invierno Permanente.
- Programas retirados de la vista y del buscador: Cronologia Digital y DoliSports.
- En `index.html`, la seccion de programas destacados muestra Rincon Lunar e Invierno Permanente.
- Rincon Lunar usa la imagen `programas/rinconlunar.png` y horario de lunes a viernes de 9:00 AM a 11:00 AM.

## Podcast

`podcast.html` usa:

- `.podcast-filter`: botones para filtrar por programa.
- `.podcast-card`: tarjeta de episodio.
- `data-category`: categoria usada por el filtro.
- `<audio controls>`: reproductor nativo de cada episodio.

El script interno:

- Detiene la radio en vivo al entrar a Podcast.
- Evita que dos audios de podcast suenen al mismo tiempo.
- Filtra tarjetas al tocar cada boton.

Estado actual:

- Mood 360 fue retirado de `podcast.html` y de `searchItems` en `script.js`.
- Se eliminaron de `podcasts/audios/` los archivos `moodtressesentapiloto.mp3` y `moodtressesentaadolescenciaenelsigloveintiuno.mp3`.
- Los episodios restantes usan archivos MP3 locales dentro de `podcasts/audios/`.

Para editar podcasts:

- Las tarjetas, categorias, titulos y rutas de audio se editan directamente en `podcast.html`.
- El atributo `data-category` de cada tarjeta debe coincidir con el filtro del programa.
- La ruta de `<source src="podcasts/audios/archivo.mp3">` debe coincidir exactamente con el nombre del MP3, incluyendo mayusculas, minusculas y extension.
- Si se agrega o retira un podcast o episodio, tambien se debe actualizar el arreglo `searchItems` de `script.js` para mantener sincronizado el buscador.
- Para eliminar completamente un episodio, se retira su tarjeta de `podcast.html`, su entrada de `searchItems` y, si ya no se usa, su MP3 de `podcasts/audios/`.

Capitulos agregados al buscador global:

- Voces Jovenes: `Capitulo 1: Ari Diaz`.
- Voces Jovenes: `Capitulo 2: Jazmin`.
- Voces Jovenes: `Capitulo 3: Cami`.
- Envinadas y Divorciadas: `El final de una historia y el inicio de otra`.

Tambien aparecen como resultados los podcasts proximos:

- Mi Ansiedad y Yo.
- Fuera de Guion.
- Mariposa de Crystal.

## Anuncios

`anuncios.php` mezcla PHP, HTML y JavaScript.

Parte PHP:

- `$anuncios`: arreglo donde se guardan registros de la base de datos.
- `$errorConsulta`: mensaje si falla la consulta.
- `h($value)`: escapa texto antes de imprimirlo en HTML.
- `formatearFecha($fecha)`: convierte fechas a formato `d/m/Y`.
- `normalizarImagen($ruta)`: reemplaza espacios en rutas por `%20`.
- `require_once __DIR__ . "/config/db.php"`: carga conexion a base de datos.
- `$pdo->query(...)`: consulta anuncios.
- `$anunciosJson`: convierte anuncios a JSON seguro para JavaScript.

Parte HTML:

- `.announcements-grid`: rejilla de tarjetas.
- `.announcement-card-button`: boton que abre detalle.
- `.announcement-modal`: modal de detalle.
- `.announcement-zoom-controls`: botones de zoom.

Parte JavaScript:

- `announcements`: datos provenientes de PHP.
- `safeExternalUrl(url)`: valida enlaces de la base de datos y solo permite protocolos seguros (`http`, `https`, `mailto`, `tel`).
- `openAnnouncement(index)`: abre modal con datos de un anuncio.
- `closeAnnouncement()`: cierra modal.
- `setZoom(value)`: cambia escala de la imagen.
- `addLink(label, url, icon)`: crea links de web, Facebook o WhatsApp solo si pasan la validacion anterior.

## Eventos

`eventos.html` muestra eventos desde el arreglo local `radioDolivEvents`.

Elementos principales:

- `.events-list`: contenedor donde JavaScript dibuja la lista de eventos.
- `.event-list-card`: tarjeta horizontal tipo boletaje.
- `.event-list-date`: bloque de fecha visible en cada tarjeta.
- `.event-list-image`: miniatura del flyer. Usa `object-fit: contain` para que el flyer no se recorte.
- `.event-more-button`: boton `Mas informacion`, abre el detalle.
- `.event-detail-modal`: modal de detalle del evento.
- `.event-detail-hero`: zona superior con flyer grande.
- `.event-detail-hero img`: imagen principal del flyer. Usa `object-fit: contain` para mostrar el flyer completo.
- `.event-detail-contact`: bloque de compra con boton hacia Guru Shows.
- `.event-ticket-button`: boton principal `Compra tu boleto`.
- `eventTicketLink`: enlace directo a Guru Shows para compra de boletos.
- `renderEvents()`: dibuja las tarjetas de eventos.
- `openEventDetail(index)`: rellena el modal con datos del evento seleccionado.
- `closeEventDetail()`: cierra el modal.
- `eventDate`: fecha interna en formato `AAAA-MM-DD` usada para dar de baja automaticamente un evento.
- `getLocalDateKey()`: obtiene la fecha local del visitante sin depender de UTC.
- `activeRadioDolivEvents`: contiene solamente eventos sin fecha confirmada o cuya fecha aun no ha pasado.

Baja automatica de eventos:

- Los eventos con `eventDate` permanecen visibles durante todo el dia indicado.
- A partir del dia siguiente dejan de mostrarse automaticamente en `eventos.html`.
- El filtro solo los oculta; no borra sus datos ni sus flyers del servidor.
- Los eventos con fecha pendiente no llevan `eventDate`, por lo que permanecen visibles como `Proximamente`.
- Las entradas de Eventos en `searchItems` usan el mismo campo `eventDate`. `runSearch()` compara esa fecha y evita mostrar eventos vencidos en el buscador general.
- La fecha debe escribirse siempre con ceros, por ejemplo `2026-08-09`, para que la comparacion funcione correctamente.

Eventos actuales:

- 31 Minutos: Teatro Morelos. Fecha: proximamente.
- 31 Minutos: Malinalco. Fecha: domingo 9 de agosto de 2026, 4:00 PM.
- 31 Minutos: Tlalnepantla. Fecha: viernes 25 de septiembre de 2026, 4:00 PM y 6:00 PM.
- 31 Minutos: Villa Victoria. Fecha: sabado 25 de julio de 2026, 3:45 PM.
- 31 Minutos: Valle de Bravo. Fecha: domingo 26 de julio de 2026, 3:30 PM.

Archivos recientes agregados a `eventos/`:

- `eventos/31minutosteatromorelos.jpeg`: flyer de 31 Minutos en Teatro Morelos Toluca.
- `eventos/31minutosmalinalco.jpeg`: flyer de 31 Minutos en Malinalco.
- `eventos/31minutostlanepantla.jpeg`: flyer de 31 Minutos en Tlalnepantla.
- `eventos/31minutosvillavictoria.jpeg`: flyer de 31 Minutos en Villa Victoria.
- `eventos/31minutosvalledebravo.jpeg`: flyer de 31 Minutos en Valle de Bravo.
- `eventos/whatsapp-qr.png`: QR de WhatsApp conservado como recurso de respaldo, aunque el CTA principal de Eventos ahora compra boletos en Guru Shows.

Eventos retirados recientemente:

- Las Guerreras K-Pop: Villa Guerrero, segunda apertura en Malinalco, San Mateo Atenco y Acambay.
- 31 Minutos: Tributo Oficial en Santiago Tianguistenco.
- Se retiraron sus objetos de `radioDolivEvents`, sus entradas de `searchItems` y sus referencias de esta documentacion.
- Tambien se eliminaron sus flyers: `guerreraskpopvillaguerrero.jpeg`, `segundaapertura.jpeg`, `sanmateoatenco.jpeg`, `guerreras-kpop-acambay.png` y `31minutos-tianguistenco.png`.

Para editar eventos:

- Las tarjetas se administran dentro del arreglo `radioDolivEvents` de `eventos.html`.
- Para agregar uno, se copia un objeto existente y se actualizan `title`, `artist`, `location`, `image`, `weekday`, `day`, `month`, `year`, `eventDate`, `time` y `description`.
- El flyer se coloca en `eventos/` y la propiedad `image` debe usar la ruta `eventos/nombre-del-archivo.ext`.
- Tambien debe agregarse una entrada equivalente en `searchItems` de `script.js`, usando el mismo `eventDate` si la fecha esta confirmada.
- Para un evento sin fecha, se usan los textos visuales de `Proximamente` y se omite `eventDate` tanto en `eventos.html` como en `script.js`.
- Para retirar manualmente un evento, se elimina su objeto de `radioDolivEvents`, su entrada de `searchItems` y su flyer solamente si ninguna otra parte del sitio lo utiliza.

## Equipo

`equipo.html` muestra integrantes del equipo desde un arreglo local de JavaScript.

- `teamMembers`: arreglo con datos de integrantes.
- `teamGrid`: contenedor donde se dibujan las tarjetas.
- `openTeamModal(index)`: abre el modal con foto, rol, frase y biografia.
- `closeTeamModal()`: cierra el modal.
- `setTeamPhotoZoom(value)`: permite acercar o alejar la foto dentro del modal.
- `.team-card`, `.team-modal`, `.team-photo-zoom-controls`: clases principales usadas por CSS.

Estado actual:

- Categorias visibles: Locutores y Reporteros.
- Reporteros muestra `Proximamente`.
- Integrantes activos en Locutores: Adilene Bernal, Amanda Regina, Isis Axeneth, July Morelos, Fernanda y Lizbeth Cedillo Garcia.
- Naye Vega, Abi/Abigail y Abdeel fueron retirados de la vista y del buscador.
- El modal permite acercar, alejar y reiniciar zoom en las fotos.

Fernanda:

- Se agrego como `Locutora de Rincon Lunar` dentro de `teamMembers`.
- Su fotografia usa la ruta `locutores/fernanda.png`.
- Su ficha incluye biografia, resumen, frase e intereses.
- Tambien se agrego una entrada de Fernanda en `searchItems` de `script.js` para que aparezca en el buscador global.

Para editar el equipo:

- Los datos de cada integrante se editan en el arreglo `teamMembers` de `equipo.html`.
- Los campos principales son `name`, `role`, `category`, `image`, `bio`, `short`, `quote`, `path` e `interests`.
- Las fotografias se guardan en `locutores/` y la propiedad `image` debe coincidir exactamente con el nombre y extension del archivo.
- Para agregar o retirar un integrante, tambien se actualiza su entrada dentro de `searchItems` en `script.js`.
- La categoria debe coincidir con un filtro existente, por ejemplo `locutores` o `reporteros`.

## Seccion Azul

`seccionazul.html` funciona como directorio de patrocinadores y aliados.

- `blueSponsors`: arreglo local con patrocinadores, categoria, resumen, descripcion, redes y mapa.
- `.blue-filter`: botones para filtrar por categoria.
- `renderBlueCards(category)`: dibuja tarjetas segun el filtro elegido.
- `openBlueModal(index)`: abre modal con informacion completa, redes sociales y mapa.
- `closeBlueModal()`: cierra modal y limpia el iframe del mapa.
- Categorias actuales: Escuelas, Mascotas, Comida y dulces, Bienestar, Servicios, Social y Tecnologia.
- Aliado escolar agregado recientemente: Colegio Brusel, con imagen `patrocinadores/Colegiobrusel.jpg`, Facebook y mapa de Google Maps.

Actualizacion de Colegio Brusel:

- La imagen nueva conserva el nombre `patrocinadores/Colegiobrusel.jpg`.
- En `seccionazul.html` la ruta incluye el parametro de version `?v=20260714`, que obliga al navegador y a Hostinger a solicitar la imagen actualizada en lugar de reutilizar una copia antigua de cache.
- Si la imagen vuelve a reemplazarse conservando el mismo nombre, se debe cambiar el valor despues de `?v=`, por ejemplo `Colegiobrusel.jpg?v=20260720`.

Para editar patrocinadores:

- Los datos se administran en el arreglo `blueSponsors` de `seccionazul.html`.
- Las imagenes se guardan en `patrocinadores/` y se referencian desde la propiedad `image`.
- Al reemplazar una imagen con el mismo nombre en Hostinger, se recomienda actualizar su parametro `?v=` para evitar que se siga mostrando la version almacenada en cache.
- Si se agrega o retira un patrocinador que aparece en las busquedas, tambien debe actualizarse `searchItems` en `script.js`.

## Base de datos

`config/db.php` crea la conexion PDO:

- `$host`: servidor MySQL.
- `$db`: nombre de base de datos.
- `$user`: usuario.
- `$pass`: contrasena.
- `new PDO(...)`: crea conexion.
- `PDO::ATTR_ERRMODE`: activa errores como excepciones.
- `PDO::ATTR_DEFAULT_FETCH_MODE`: devuelve resultados asociativos.

Importante: este archivo contiene credenciales reales. En produccion debe protegerse y no compartirse publicamente.

`config/.htaccess` contiene:

- `Require all denied`: impide abrir directamente archivos dentro de `config/` desde el navegador cuando el servidor usa Apache, como ocurre normalmente en Hostinger.

PHP puede seguir leyendo `config/db.php` mediante `require_once`, porque esta proteccion solo bloquea acceso HTTP directo.

## Estilos principales

`styles-v2.css` organiza el diseno por secciones:

- Variables globales.
- Reset base.
- Navbar.
- Buscador global.
- Chatbot DoliBot.
- Modal de redes sociales del inicio.
- Hero de inicio.
- Reproductor.
- Estadisticas.
- Programas destacados.
- Footer.
- Conocenos.
- Servicios.
- Programas.
- Anuncios.
- Podcast.
- Responsive.
- Eventos.

## Correcciones recientes

### Correccion del reproductor del 21 de julio de 2026

- Se reviso el control de audio compartido por todas las paginas y los reproductores locales de `podcast.html`.
- La causa principal de cortes, desincronizacion y efecto de repeticion estaba en `script.js`: cada clic en Play ejecutaba `playRadio(true)`, pausaba el audio, reemplazaba la fuente, vaciaba el buffer con `load()` y abria una conexion nueva.
- Los eventos normales `waiting` y `stalled` tambien programaban una recarga forzada despues de siete segundos. En conexiones variables esto podia reiniciar un stream que todavia estaba intentando recuperar su buffer.
- `toggleRadio()` ahora conserva la conexion y ejecuta `playRadio(false)` durante una reproduccion normal. Solo solicita recarga cuando el elemento tiene un error real o termino inesperadamente.
- Se retiraron las reconexiones asociadas a `waiting` y `stalled`; el navegador puede resolver esos buffers breves sin perder el punto actual del stream.
- En una segunda revision se retiro tambien la reconexion automatica de `error` y `ended`. Ante esos eventos la interfaz vuelve a Play y espera una accion del usuario, evitando cualquier reinicio o bucle generado por JavaScript.
- Las recargas de emergencia vuelven a utilizar la URL estable `STREAM_URL`. Ya no agregan parametros diferentes con la hora, porque cada URL nueva obligaba a crear otra sesion y otro buffer.
- El elemento `#radio-audio` de `index.html` ahora usa `preload="none"` para no abrir una descarga antes de que el usuario solicite reproducir.
- Se comprobo que `https://stream.zeno.fm/vrfurwfubkhtv` redirige correctamente y entrega contenido `audio/mpeg` con el nombre `RADIO DOLIV`.
- Los cuatro MP3 disponibles en `podcasts/audios/` existen, pero pesan aproximadamente entre 87 MB y 118 MB. En conexiones lentas pueden tardar en iniciar; `podcast.html` ya utiliza `preload="none"` y evita reproducir dos episodios a la vez.
- Todas las paginas cambiaron la version de carga a `script.js?v=20260721audiofix2`, obligando a Hostinger y a los navegadores a descargar la segunda correccion en lugar del JavaScript anterior almacenado en cache.
- Para editar la fuente se modifica `STREAM_URL` al inicio de `script.js` y la ruta del elemento `#radio-audio` en `index.html`; ambas deben mantenerse iguales.
- Para cambiar el manejo de estados se edita `initRadioHealthChecks()` en `script.js`. No se recomienda agregar reconexiones automaticas por `waiting`, `stalled`, `ended` o `error`, porque pueden provocar reinicios perceptibles y repeticiones.
- Como prueba externa se capturaron 33 segundos directamente desde Zeno, sin pasar por la pagina. El archivo contenia 1,375 tramas MP3 validas, sin bytes fuera de trama ni bloques exactos duplicados.
- Durante la descarga directa el servidor entrego datos en bloques con pausas variables. Si el audio sigue cortandose con `audiofix3`, se debe revisar la estabilidad de subida del programa codificador hacia Zeno, el equipo de transmision y el estado de la estacion en el panel de Zeno.
- Se corrigio el primer clic del reproductor: como `#radio-audio` usa `preload="none"`, `playRadio()` ahora llama `load()` explicitamente cuando `readyState` es `0` y despues ejecuta `play()` dentro de la misma accion del usuario.
- La tarjeta de Inicio ahora muestra estados visibles mediante `#radio-status-label` y `#radio-status-text`: `Conectando`, `En vivo ahora`, `Radio en vivo` o `No se pudo conectar`.
- La correccion anterior del primer clic se publico inicialmente como `script.js?v=20260721audiofix3`.
- Se agrego reproduccion automatica en las paginas que no sean `podcast.html`. Al cargar, `script.js` intenta ejecutar `playRadio(false)` si el usuario no habia pausado la radio manualmente.
- La preferencia `radioUserPaused` distingue una pausa hecha con el boton de una pausa temporal al entrar a Podcast. La pausa manual se respeta; la pausa de Podcast permite intentar reanudar la radio al visitar otra seccion.
- `podcast.html` continua pausando la radio en vivo para evitar que se mezcle con los episodios.
- La reproduccion automatica con sonido puede ser bloqueada por las politicas del navegador durante una primera visita sin interaccion. El sitio realiza el intento, pero no puede saltarse esa restriccion; despues de que el usuario haya usado Play, la reanudacion tiene mayor probabilidad de ser autorizada.
- La version vigente despues de este cambio es `script.js?v=20260721autoplay` en las nueve paginas.
- Se reemplazo el mensaje `No se pudo conectar / Presiona Play para volver a intentar` por `Reconectando / Restableciendo transmision en vivo`.
- Se agrego una reconexion automatica controlada: espera 15 segundos ante `waiting` o `stalled`, y 5 segundos ante `error` o `ended`.
- Si Zeno continua sin responder, la espera aumenta progresivamente hasta un maximo de 30 segundos para evitar ciclos rapidos con efecto de repeticion.
- Los eventos `playing`, la pausa manual y la entrada a `podcast.html` cancelan cualquier reconexion pendiente.
- Un bloqueo de autoplay identificado como `NotAllowedError` no genera intentos repetidos.
- La version vigente despues de esta mejora es `script.js?v=20260721reconnect` en las nueve paginas.

### Actualizacion del 20 de julio de 2026

- Se completo la documentacion de los cambios recientes realizados en Equipo, Podcast, Eventos y Seccion Azul.
- En `equipo.html` se documento el alta de Fernanda dentro de `teamMembers`, su fotografia `locutores/fernanda.png` y su registro correspondiente en `searchItems` de `script.js`.
- En `podcast.html` se documento la baja de Mood 360. Tambien quedaron registradas la eliminacion de sus entradas del buscador y de sus dos audios en `podcasts/audios/`.
- En `eventos.html` se documento la eliminacion manual de cinco eventos fuera de uso y de sus flyers asociados.
- Se documento la baja automatica de eventos: cada objeto con fecha confirmada utiliza `eventDate` en formato `AAAA-MM-DD`; `getLocalDateKey()` obtiene el dia local y `activeRadioDolivEvents` excluye los eventos cuya fecha ya paso.
- En `script.js`, las entradas de eventos de `searchItems` utilizan el mismo `eventDate`, y `runSearch()` filtra los eventos vencidos para que tampoco aparezcan en el buscador global.
- Los eventos permanecen visibles durante todo el dia de su presentacion y se ocultan a partir del dia siguiente. El proceso no elimina automaticamente el codigo ni las imagenes.
- Los eventos con fecha pendiente deben omitir `eventDate` para continuar visibles como `Proximamente`.
- En `seccionazul.html` se documento la actualizacion de `patrocinadores/Colegiobrusel.jpg` y el uso del parametro `?v=20260714` para evitar que Hostinger o el navegador carguen una version anterior desde cache.
- Para mantener la automatizacion, cualquier fecha de evento debe actualizarse tanto en `radioDolivEvents` de `eventos.html` como en su entrada de `searchItems` en `script.js`.
- Las instrucciones completas para editar cada apartado se encuentran en las secciones `Podcast`, `Eventos`, `Equipo`, `Seccion Azul` y `Recomendaciones para editar` de este documento.

- Se corrigio una referencia CSS a `programas/latidocultural.jpeg`, que no existia, por `programas/cronologiadigital.jpeg`.
- Se agrego validacion de enlaces externos en `anuncios.php` con `safeExternalUrl()`.
- Se agrego `config/.htaccess` para proteger archivos de configuracion.
- Se agrego DoliBot como chatbot global en `script.js` y `styles-v2.css`.
- El logo del navbar ahora funciona como enlace directo a `index.html`.
- El boton de comunidad en `index.html` ahora abre un modal con enlaces a Instagram, Facebook, TikTok y YouTube.
- Se actualizo `servicios.html` para que cada boton de WhatsApp use un mensaje personalizado por servicio.
- Se corrigio contraste en secciones que se perdian en modo claro.
- Se actualizo `seccionazul.html` como directorio de patrocinadores con categorias, detalles, redes sociales y mapas.
- Se agrego Colegio Brusel a Seccion Azul y al buscador global.
- Se actualizo la imagen de Colegio Brusel y se agrego `?v=20260714` a su ruta para evitar que Hostinger o el navegador sigan mostrando la imagen anterior desde cache.
- Se reconstruyo `equipo.html` con categorias Locutores/Reporteros, biografias y zoom en fotos.
- Se agrego a Fernanda como locutora de Rincon Lunar, usando `locutores/fernanda.png`, su biografia completa y una entrada en el buscador global.
- Se retiro del sitio y del buscador a Naye Vega, Abi/Abigail y Abdeel.
- Se dejo `programas.html` con Rincon Lunar e Invierno Permanente como programas activos y se retiraron Cronologia Digital y DoliSports.
- Se agrego Rincon Lunar al buscador global.
- Se actualizo el buscador con anuncios solicitados como Reporterito Doliv y Lufesca Evento.
- Se actualizo el buscador con capitulos individuales del podcast.
- Se retiro Mood 360 de `podcast.html` y del buscador, y se eliminaron sus dos archivos MP3 de `podcasts/audios/`.
- Se reconstruyo `eventos.html` con lista de eventos, detalle, imagen completa del flyer y enlace directo para compra de boletos en Guru Shows.
- Se cambio el CTA de Eventos de `Contacto al WhatsApp` a `Compra tu boleto`.
- Se reemplazo el flyer de 31 Minutos, se agrego temporalmente el evento Guerreras K-Pop Acambay y se agregaron nuevas sedes de 31 Minutos.
- Posteriormente se retiraron cinco eventos vencidos o fuera de uso: Guerreras K-Pop Villa Guerrero, segunda apertura, San Mateo Atenco y Acambay, ademas de 31 Minutos Tianguistenco. Sus entradas del buscador y flyers tambien fueron eliminados.
- Se agrego la baja automatica por fecha en Eventos mediante `eventDate`, `getLocalDateKey()` y `activeRadioDolivEvents`.
- Se agrego el mismo control de `eventDate` al buscador global para que los eventos vencidos tampoco aparezcan como resultados.
- Se retiro Doliv Fest de Eventos y del buscador por ser contenido anterior.
- Se actualizaron versiones de cache: estilos recientes con `20260629programas` / `20260702boletos` y script global con `20260702eventos31`.
- Se retiro la reconexion automatica del streaming; el navegador administra el buffer y cualquier reconexion posterior requiere un nuevo clic del usuario.

## Recomendaciones para editar

Nota post-refactor: donde el texto de abajo dice `script.js` o `styles-v2.css` a secas (nombres heredados de antes del refactor de arquitectura), la logica real ahora vive dividida en `assets/js/` y `assets/css/` — ver la tabla de equivalencias justo arriba, en "Refactor de arquitectura", y el arbol completo en [ESQUEMA_PROYECTO.md](ESQUEMA_PROYECTO.md).

- Para cambiar textos visibles: editar el HTML correspondiente dentro de `pages/` (o `index.html` para inicio).
- Para cambiar colores, espacios o tamanos: editar el modulo correspondiente dentro de `assets/css/` (por seccion/pagina) en vez de un solo archivo gigante.
- Para cambiar comportamiento: editar el modulo correspondiente dentro de `assets/js/core/` o `assets/js/components/`.
- Para agregar resultados al buscador: editar `searchItems` en `assets/js/data/search-items.js`. Las rutas de `url` deben ser absolutas desde la raiz, por ejemplo `/pages/servicios.html`.
- Para agregar servicios: editar `pages/servicios.html` y agregar entrada en `searchItems`.
- Para agregar programas: editar `pages/programas.html` y agregar entrada en `searchItems`.
- Para agregar podcasts: editar `pages/podcast.html` (los audios van en `assets/audio/podcasts/`) y agregar entrada en `searchItems`.
- Para agregar eventos: editar `radioDolivEvents` en `pages/eventos.html`, colocar el flyer en `assets/img/eventos/` y agregar una entrada en `searchItems` con el mismo `eventDate`.
- Para cambiar la fecha de un evento: actualizar `eventDate` en `pages/eventos.html` y en su entrada de `searchItems` en `assets/js/data/search-items.js`; tambien actualizar los textos `weekday`, `day`, `month`, `year`, `time` y `subtitle` visibles.
- Para agregar integrantes: editar `teamMembers` en `pages/equipo.html`, guardar la foto en `assets/img/locutores/` y agregar la entrada correspondiente en `searchItems`.
- Para agregar patrocinadores: editar `blueSponsors` en `pages/seccionazul.html`, guardar la imagen en `assets/img/patrocinadores/` y actualizar `searchItems` si debe aparecer en el buscador.
- Para forzar la actualizacion de una imagen reemplazada: cambiar o agregar un parametro de version al final de la ruta, por ejemplo `imagen.jpg?v=20260720`.
- Para cambiar respuestas del chatbot: editar `getDolivBotReply()` en `assets/js/components/chatbot.js`.
- Para cambiar paquetes que muestra el chatbot: editar `getDolivServicesReply()` en `assets/js/components/chatbot.js`.
- Para cambiar redes/contacto del chatbot: editar `dolivBotLinks` en `assets/js/components/chatbot.js`.
- Para agregar o quitar una pagina nueva en la raiz: si es una pagina de contenido, va en `pages/`; si necesitas conservar una URL vieja de la raiz, agrega su redireccion en el `.htaccess` de la raiz.
