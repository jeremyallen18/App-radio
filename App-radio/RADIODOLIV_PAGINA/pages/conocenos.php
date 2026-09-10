<?php
define('SITE_BASE_PATH', '../');

$activePage      = 'conocenos';
$pageTitle       = 'Conócenos | Radio Doliv';
$pageDescription = 'Misión, visión, valores e historia de Radio Doliv.';
$pageStylesheet  = 'pages/conocenos';
$canonicalRelative = 'pages/conocenos.php';
?>
<!DOCTYPE html>
<html lang="es" data-page="<?= $activePage ?? '' ?>">
<?php include __DIR__ . '/../inc/partials/head.php'; ?>
<body data-site-base="<?= h(site_root_url()) ?>">
    <?php include __DIR__ . '/../inc/partials/navbar.php'; ?>

    <main class="about-main">

        <!-- ============================================
             1. HERO �?? capitulo a pantalla completa: el
             titulo es el protagonista, sin banda de color,
             solo el fondo continuo del sitio.
             ============================================ -->
        <section class="about-chapter about-chapter--hero" aria-label="Conócenos">
            <div class="about-chapter-inner about-hero-inner">
                <span class="about-badge scroll-fade-down">Nuestra Esencia</span>
                <h1 class="scroll-tilt-up">Conectamos historias, <span class="text-gradient">marcas y comunidad</span></h1>
                <p class="about-hero-subtitle scroll-fade-up">
                    Somos una radio digital enfocada en contenido cercano, creativo y de valor para las personas y negocios de nuestra región.
                </p>
            </div>
        </section>

        <!-- ============================================
             2. QUIENES SOMOS �?? su propio capitulo.
             ============================================ -->
        <section class="about-chapter" aria-label="Quiénes somos">
            <div class="about-chapter-inner about-intro scroll-tilt-up">
                <h2 class="section-title">Quiénes Somos</h2>
                <p>
                    En Radio Doliv conectamos, inspiramos y potenciamos a personas y marcas a través de la creatividad y el sonido.
                    Integramos radio web y agencia de publicidad para crear contenido dinámico, innovador y de calidad.
                </p>
            </div>
        </section>

        <!-- ============================================
             3. MISION / VISION / VALORES �?? su propio
             capitulo, rejilla de 3 tarjetas.
             ============================================ -->
        <section class="about-chapter" aria-label="Misión, visión y valores">
            <div class="about-chapter-inner" data-reveal>
                <div class="purpose-grid">
                    <article class="purpose-card" data-stagger="0" data-tilt>
                        <i data-lucide="target"></i>
                        <h3>Misión</h3>
                        <p>
                            Radio Doliv tiene el propósito de conectar, inspirar y potenciar a personas y marcas a través de la creatividad
                            y el sonido. Como estación de radio web, buscamos ofrecer contenido innovador, dinámico y de calidad que entretenga
                            e informe a nuestra audiencia. Como agencia de publicidad, creamos estrategias originales y efectivas para posicionar
                            negocios y proyectos en el mercado digital y tradicional.
                        </p>
                    </article>

                    <article class="purpose-card" data-stagger="1" data-tilt>
                        <i data-lucide="telescope"></i>
                        <h3>Visión</h3>
                        <p>
                            Nos visualizamos como una referencia en radio digital y publicidad creativa en los próximos años, expandiendo
                            nuestra audiencia y cartera de clientes a nivel nacional e internacional. Queremos ser la plataforma que transforma
                            ideas en experiencias inolvidables, consolidándonos como una marca influyente, versátil y en constante evolución.
                        </p>
                    </article>

                    <article class="purpose-card" data-stagger="2" data-tilt>
                        <i data-lucide="heart-handshake"></i>
                        <h3>Valores</h3>
                        <p>
                            Nuestros valores guían cada programa, campaña y colaboración para mantener calidad, autenticidad y resultados.
                        </p>
                    </article>
                </div>
            </div>
        </section>

        <!-- ============================================
             4. VALORES (detalle) �?? su propio capitulo.
             ============================================ -->
        <section class="about-chapter" aria-label="Nuestros valores">
            <div class="about-chapter-inner" data-reveal>
                <h2 class="section-title">Valores</h2>
                <ul class="values-list">
                    <li data-stagger="0"><strong>Creatividad:</strong> Innovamos con ideas frescas y disruptivas.</li>
                    <li data-stagger="1"><strong>Pasión:</strong> Amamos lo que hacemos y lo transmitimos en cada proyecto.</li>
                    <li data-stagger="2"><strong>Autenticidad:</strong> Nos diferenciamos con contenido y estrategias únicas.</li>
                    <li data-stagger="3"><strong>Compromiso:</strong> Damos el 100% para impulsar el éxito de nuestros clientes y audiencia.</li>
                    <li data-stagger="4"><strong>Evolución:</strong> Nos adaptamos a las tendencias para estar siempre a la vanguardia.</li>
                </ul>
            </div>
        </section>
    </main>

    <?php $footerExtended = false; include __DIR__ . '/../inc/partials/footer.php'; ?>
    <?php include __DIR__ . '/../inc/partials/scripts.php'; ?>
    <script src="<?= asset_url('assets/js/pages/conocenos.js') ?>" data-page-script></script>
</body>
</html>
