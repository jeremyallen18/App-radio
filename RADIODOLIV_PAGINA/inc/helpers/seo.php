<?php
// Combina los valores SEO propios de cada página con los valores por defecto
// del sitio, para que head.php pueda emitir meta description/OG/canonical
// consistentemente sin que cada página los repita a mano.
function build_meta(array $overrides = []): array {
    $defaults = [
        'title'       => 'Radio Doliv',
        'description' => 'Radio Doliv: radio digital en vivo las 24 horas, programas, podcasts originales y una comunidad que crece cada día desde el Estado de México.',
        'og_image'    => 'assets/img/logo/logo.png',
    ];
    $merged = $defaults;
    foreach ($overrides as $key => $value) {
        if ($value !== null && $value !== '') {
            $merged[$key] = $value;
        }
    }
    return $merged;
}
