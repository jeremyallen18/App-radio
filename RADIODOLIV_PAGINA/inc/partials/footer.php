<?php
require_once __DIR__ . '/../helpers/html.php';
// $footerExtended (bool, opcional): variante de 4 columnas + newsletter que
// solo usa index.php. El resto de páginas usa la variante simple de 3 columnas.
// OJO: usa site_root_url() (absoluta), NO SITE_BASE_PATH (relativa al
// directorio del script) -- el footer, igual que el navbar, no se vuelve a
// pintar en cada navegacion AJAX (ver core/page-router.js), asi que sus
// enlaces deben seguir siendo validos sin importar la URL actual.
$base = site_root_url();
$extended = !empty($footerExtended);
?>
<footer class="main-footer">
    <div class="footer-container<?= $extended ? ' footer-container--extended' : '' ?>">
        <div class="footer-brand">
            <div class="logo-footer">
                <i data-lucide="radio" class="icon-cyan"></i>
                <span>Radio <b>Doliv</b></span>
            </div>
            <?php if ($extended): ?>
            <p>Tu radio digital, en vivo las 24 horas. Publicidad que se escucha y se siente.</p>
            <div class="footer-social">
                <a href="https://www.instagram.com/radio_doliv/" target="_blank" rel="noopener noreferrer" aria-label="Instagram de Radio Doliv">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="2" y="2" width="20" height="20" rx="5"></rect><circle cx="12" cy="12" r="4"></circle><circle cx="17.5" cy="6.5" r="1" fill="currentColor" stroke="none"></circle></svg>
                </a>
                <a href="https://www.facebook.com/people/RADIO-DOLIV/61574197135745/" target="_blank" rel="noopener noreferrer" aria-label="Facebook de Radio Doliv">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z"></path></svg>
                </a>
                <a href="https://www.tiktok.com/@radio_doliv" target="_blank" rel="noopener noreferrer" aria-label="TikTok de Radio Doliv">
                    <i data-lucide="music-2"></i>
                </a>
                <a href="https://youtube.com/@r_doliv?si=fZA7DtkJsxY3rGpl" target="_blank" rel="noopener noreferrer" aria-label="YouTube de Radio Doliv">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M22.5 6.5s-.2-1.6-.9-2.3c-.9-.9-1.8-.9-2.3-1C15.9 3 12 3 12 3h0s-3.9 0-7.3.2c-.5.1-1.4.1-2.3 1-.7.7-.9 2.3-.9 2.3S1.3 8.4 1.3 10.3v1.4c0 1.9.2 3.8.2 3.8s.2 1.6.9 2.3c.9.9 2 .9 2.5 1 1.8.2 7.6.2 7.6.2s3.9 0 7.3-.2c.5-.1 1.4-.1 2.3-1 .7-.7.9-2.3.9-2.3s.2-1.9.2-3.8v-1.4c0-1.9-.2-3.8-.2-3.8z"></path><polygon points="10 9 15 12 10 15" fill="currentColor" stroke="none"></polygon></svg>
                </a>
            </div>
            <?php else: ?>
            <p>Publicidad que se escucha y se siente.</p>
            <?php endif; ?>
        </div>

        <div class="footer-links">
            <h4>Enlaces rápidos</h4>
            <ul>
                <li><a href="<?= h($base) ?>index.php">Inicio</a></li>
                <?php if ($extended): ?>
                <li><a href="<?= h($base) ?>pages/programas.php">Programas</a></li>
                <li><a href="<?= h($base) ?>pages/podcast.php">Podcast</a></li>
                <li><a href="<?= h($base) ?>pages/eventos.php">Eventos</a></li>
                <li><a href="<?= h($base) ?>pages/servicios.php">Servicios</a></li>
                <?php else: ?>
                <li><a href="<?= h($base) ?>pages/servicios.php">Servicios</a></li>
                <li><a href="<?= h($base) ?>pages/podcast.php">Podcast</a></li>
                <?php endif; ?>
            </ul>
        </div>

        <div class="footer-contact">
            <h4>Contacto</h4>
            <p>Email: grupodoliv@gmail.com</p>
            <p>Teléfono: +52 1 713 120 5259</p>
            <p><?= $extended ? '' : 'Dirección: ' ?>Cda. Ejército del Trabajo, Rojastitlan, 52650 Santiago Tilapa, Méx.</p>
        </div>
    </div>

    <div class="footer-bottom<?= $extended ? ' footer-bottom--split' : '' ?>">
        <p>&copy; <?= $extended ? '2026' : '2025' ?> Radio Doliv. Todos los derechos reservados.</p>
        <?php if ($extended): ?>
        <p>Transmisión en vivo las 24 horas, los 7 días de la semana.</p>
        <?php endif; ?>
        <p class="footer-legal">
            <button type="button" class="footer-legal-link" data-privacy-open>Política de privacidad</button>
        </p>
    </div>

    <?php /* Aviso de privacidad. Va dentro del <footer> (fuera de <main>) a
             proposito: el footer no se re-pinta en la navegacion AJAX (ver
             core/page-router.js), asi que este <dialog> y su script quedan
             disponibles en todas las paginas con una sola carga. Se usa el
             <dialog> nativo por su cierre con Esc, backdrop y foco ya
             resueltos, sin depender del JS de modales del sitio. */ ?>
    <dialog class="privacy-dialog" id="privacy-dialog" aria-labelledby="privacy-dialog-title">
        <div class="privacy-dialog-inner">
            <button type="button" class="privacy-dialog-close" data-privacy-close aria-label="Cerrar aviso de privacidad">
                <i data-lucide="x" aria-hidden="true"></i>
            </button>
            <h2 id="privacy-dialog-title">Política de privacidad</h2>
            <p class="privacy-dialog-updated">Última actualización: 2026</p>

            <p>En Radio Doliv cuidamos tu información. Este aviso resume qué datos
               tratamos cuando visitas <b>radiodoliv</b> y para qué.</p>

            <h3>Qué información recopilamos</h3>
            <ul>
                <li><b>Datos que tú envías.</b> Si dejas un comentario en vivo,
                    pides una canción, usas el asistente DoliBot o nos escribes por
                    correo o WhatsApp, guardamos el texto y los datos de contacto que
                    decidas compartir para poder responderte y moderar el contenido.</li>
                <li><b>Datos técnicos básicos.</b> Nuestro servidor registra de forma
                    estándar la dirección IP, el navegador y la fecha de cada visita
                    para seguridad y para evitar abuso o spam.</li>
                <li><b>Preferencias en tu dispositivo.</b> Guardamos localmente en tu
                    navegador ajustes como el tema claro/oscuro o el estado del
                    reproductor. Esta información no sale de tu equipo.</li>
            </ul>

            <h3>Para qué la usamos</h3>
            <ul>
                <li>Mostrar y moderar los comentarios en vivo de cada transmisión.</li>
                <li>Atender solicitudes de canciones, publicidad, eventos y dudas.</li>
                <li>Responder tus mensajes al asistente DoliBot (las consultas se
                    procesan mediante un proveedor de inteligencia artificial para
                    generar la respuesta; no se usan para identificarte).</li>
                <li>Mantener el sitio seguro y funcionando correctamente.</li>
            </ul>

            <h3>Con quién se comparte</h3>
            <p>No vendemos ni intercambiamos tu información. Solo se comparte con los
               servicios necesarios para operar el sitio: el proveedor de hosting, el
               proveedor de inteligencia artificial que responde a DoliBot y los
               servicios de redes sociales o video (TikTok, YouTube, Facebook,
               Instagram) cuando abres un enlace o un contenido incrustado, momento en
               el que aplican también sus propias políticas.</p>

            <h3>Contenido incrustado y de terceros</h3>
            <p>Algunas páginas cargan tipografías y librerías desde redes de
               distribución (Google Fonts, CDNJS/unpkg) y videos de TikTok. Estos
               terceros pueden recibir tu dirección IP por el simple hecho de cargar
               ese recurso.</p>

            <h3>Menores de edad</h3>
            <p>El sitio es de contenido general. Si eres menor de edad, participa con
               el acompañamiento de tu madre, padre o tutor.</p>

            <h3>Tus opciones</h3>
            <p>Puedes navegar sin dejar comentarios ni usar el chat. Puedes borrar en
               cualquier momento las preferencias guardadas limpiando los datos del
               sitio en tu navegador. Para solicitar la eliminación de un comentario o
               de datos que nos hayas enviado, escríbenos a
               <a href="mailto:grupodoliv@gmail.com">grupodoliv@gmail.com</a>.</p>

            <h3>Cambios</h3>
            <p>Podemos actualizar este aviso; la fecha de arriba indica la última
               versión. El uso continuado del sitio implica la aceptación de los
               cambios.</p>

            <p class="privacy-dialog-contact">Dudas sobre privacidad:
               <a href="mailto:grupodoliv@gmail.com">grupodoliv@gmail.com</a> ·
               +52 1 713 120 5259</p>
        </div>
    </dialog>

    <script>
    (function () {
        var dlg = document.getElementById('privacy-dialog');
        if (!dlg || dlg.dataset.wired) return;
        dlg.dataset.wired = '1';
        function open() {
            if (typeof dlg.showModal === 'function') dlg.showModal();
            else dlg.setAttribute('open', '');
            if (window.lucide) window.lucide.createIcons();
        }
        function close() {
            if (typeof dlg.close === 'function') dlg.close();
            else dlg.removeAttribute('open');
        }
        // Delegado en document: el boton disparador vive dentro del footer, que
        // no se re-pinta en la navegacion AJAX, pero el delegado tampoco depende
        // de eso y es robusto si algo cambia.
        document.addEventListener('click', function (e) {
            if (e.target.closest('[data-privacy-open]')) { e.preventDefault(); open(); }
            else if (e.target.closest('[data-privacy-close]')) { e.preventDefault(); close(); }
        });
        // Clic fuera de la tarjeta (sobre el ::backdrop) cierra.
        dlg.addEventListener('click', function (e) {
            if (e.target === dlg) close();
        });
    })();
    </script>
</footer>

<?php // Dock persistente SOLO para movil (<=768px): mini-reproductor +
      // barra inferior de 5 pestanas. Fuera de <main> a proposito, para
      // sobrevivir a la navegacion AJAX (ver core/page-router.js). En
      // escritorio queda display:none (ver components/mobile-dock.css). ?>
<?php include __DIR__ . '/mobile-dock.php'; ?>
