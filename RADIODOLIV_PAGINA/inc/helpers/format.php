<?php
// Convierte una fecha de base de datos a un formato más claro para visitantes.
function formatearFecha($fecha): string {
    if (empty($fecha)) {
        return 'Fecha no disponible';
    }
    $timestamp = strtotime($fecha);
    if ($timestamp === false) {
        return h($fecha);
    }
    return date('d/m/Y', $timestamp);
}

// Asegura que las rutas con espacios funcionen correctamente en el navegador.
function normalizarImagen($ruta): string {
    $ruta = trim((string) $ruta);
    if ($ruta === '') {
        return '';
    }
    if (preg_match('/^https?:\/\//i', $ruta)) {
        return $ruta;
    }
    return str_replace(' ', '%20', $ruta);
}

// Valida que un enlace externo use un protocolo seguro antes de imprimirlo.
function safe_external_url($url): string {
    $value = trim((string) $url);
    if ($value === '' || strtoupper($value) === 'NULL') {
        return '';
    }
    $parts = parse_url($value);
    if (!isset($parts['scheme'])) {
        // Enlace relativo: se acepta tal cual.
        return $value;
    }
    $allowed = ['http', 'https', 'mailto', 'tel'];
    return in_array(strtolower($parts['scheme']), $allowed, true) ? $value : '';
}
