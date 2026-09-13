<?php
// Validadores para site_content.php: cortan con 400 si inválido,
// o devuelven el valor normalizado listo para bind de PDO.

function site_required_text(string $field, string $label): string {
    $value = trim((string) ($_POST[$field] ?? ''));
    if ($value === '') {
        error_response("$label es requerido", 400);
    }
    return $value;
}

function site_optional_text(string $field): string {
    return trim((string) ($_POST[$field] ?? ''));
}

// Valida formato YYYY-MM-DD. Rechazo de fechas inválidas (p.ej. 2026-02-30);
// cadena vacía => null.
function site_valid_date(string $field, string $label): ?string {
    $raw = trim((string) ($_POST[$field] ?? ''));
    if ($raw === '') return null;
    $parts = explode('-', $raw);
    if (count($parts) !== 3 || !checkdate((int) $parts[1], (int) $parts[2], (int) $parts[0])) {
        error_response("$label debe ser una fecha válida (AAAA-MM-DD)", 400);
    }
    return $raw;
}

function site_valid_int(string $field, string $label, int $default = 0): int {
    $raw = trim((string) ($_POST[$field] ?? ''));
    if ($raw === '') return $default;
    if (filter_var($raw, FILTER_VALIDATE_INT) === false) {
        error_response("$label debe ser un número entero", 400);
    }
    return (int) $raw;
}

// Hora entera 0-23, o null si el campo llegó vacío (usado por slot_start /
// slot_end de radio_programs, que son opcionales en pareja).
function site_valid_hour(string $field, string $label): ?int {
    $raw = trim((string) ($_POST[$field] ?? ''));
    if ($raw === '') return null;
    if (filter_var($raw, FILTER_VALIDATE_INT) === false) {
        error_response("$label debe ser una hora entera entre 0 y 23", 400);
    }
    $hour = (int) $raw;
    if ($hour < 0 || $hour > 23) {
        error_response("$label debe estar entre 0 y 23", 400);
    }
    return $hour;
}

// A diferencia de safe_external_url(), rechaza URLs inválidas con 400
// al ESCRIBIR en vez de guardar '' en silencio.
function site_valid_url(string $rawValue, string $label, bool $required = false): string {
    $raw = trim($rawValue);
    if ($raw === '') {
        if ($required) {
            error_response("$label es requerido", 400);
        }
        return '';
    }
    $safe = safe_external_url($raw);
    if ($safe === '') {
        error_response("$label no es una URL válida (debe empezar con http:// o https://)", 400);
    }
    return $safe;
}

// Decodifica JSON-array. Rechaza con 400 en vez de silenciar
// y borrar datos existentes sin avisar.
function site_decode_json_array(string $raw, string $label): array {
    $raw = trim($raw) !== '' ? $raw : '[]';
    $decoded = json_decode($raw, true);
    if (!is_array($decoded)) {
        error_response("$label debe ser un arreglo JSON válido", 400);
    }
    return $decoded;
}

// Valida ids en tabla, deduplica, mantiene orden. $table fijo
// así que interpolar es seguro (como en site_unique_slug()).
function site_valid_ids_in_table(PDO $pdo, string $raw, string $table, string $label): array {
    $raw = trim($raw);
    if ($raw === '') return [];

    $ids = array_values(array_unique(array_filter(
        array_map('intval', explode(',', $raw)),
        fn($n) => $n > 0
    )));
    if ($ids === []) return [];

    $placeholders = implode(',', array_fill(0, count($ids), '?'));
    $stmt = $pdo->prepare("SELECT id FROM `$table` WHERE id IN ($placeholders)");
    $stmt->execute($ids);
    $found = array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));

    if (count($found) !== count($ids)) {
        error_response("$label contiene un id que ya no existe", 400);
    }
    return $ids;
}
