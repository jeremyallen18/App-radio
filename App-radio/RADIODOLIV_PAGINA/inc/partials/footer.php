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
    </div>
</footer>
