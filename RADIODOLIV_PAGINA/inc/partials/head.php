<?php
require_once __DIR__ . '/../helpers/html.php';
require_once __DIR__ . '/../helpers/assets.php';
require_once __DIR__ . '/../helpers/seo.php';

// Variables esperadas del controlador (todas opcionales salvo $activePage):
// $pageTitle, $pageDescription, $pageOgImage, $pageStylesheet ('pages/programas', etc.)
$meta = build_meta([
    'title'       => $pageTitle ?? null,
    'description' => $pageDescription ?? null,
    'og_image'    => $pageOgImage ?? null,
]);
// Canonical calculado del host real (no se hardcodea un dominio de produccion
// que podria no coincidir con donde termine desplegado el sitio).
$scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$host = $_SERVER['HTTP_HOST'] ?? 'localhost';
$canonicalUrl = $scheme . '://' . $host . '/' . ltrim($canonicalRelative ?? '', '/');
?>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= h($meta['title']) ?></title>
    <meta name="description" content="<?= h($meta['description']) ?>">

    <meta property="og:type" content="website">
    <meta property="og:title" content="<?= h($meta['title']) ?>">
    <meta property="og:description" content="<?= h($meta['description']) ?>">
    <meta property="og:image" content="<?= h(asset_url($meta['og_image'])) ?>">
    <meta name="twitter:card" content="summary_large_image">

    <link rel="canonical" href="<?= h($canonicalUrl) ?>">
    <link rel="icon" type="image/png" href="<?= h(asset_url('assets/img/logo/logo.png')) ?>">

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&family=Space+Grotesk:wght@500;600;700&display=swap" rel="stylesheet">
    <script src="https://unpkg.com/lucide@latest"></script>

    <?php // Recursos extra de una página específica (ej. Bootstrap CDN o una
          // fuente de Google puntual), cargados ANTES que el CSS del sitio a
          // proposito: asi el reset/reboot de una libreria como Bootstrap no
          // pisa por orden de cascada los estilos compartidos (navbar,
          // footer, tipografia) que ya definen core.css y base.css. ?>
    <?= $pageExtraHead ?? '' ?>

    <link rel="stylesheet" href="<?= h(asset_url('assets/css/core.css')) ?>" data-core-css>
    <?php foreach ((array) ($pageStylesheet ?? []) as $sheet): ?>
    <link rel="stylesheet" href="<?= h(asset_url("assets/css/{$sheet}.css")) ?>" data-page-css>
    <?php endforeach; ?>
</head>
