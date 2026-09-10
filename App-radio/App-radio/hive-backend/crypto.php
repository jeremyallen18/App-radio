<?php
// Cifrado en reposo de columnas sensibles (AES-256-GCM). La clave vive en el
// servidor (DB_ENCRYPTION_KEY en .env): esto NO es cifrado extremo a extremo,
// solo evita que un dump / backup / acceso SQL exponga texto plano.
// Formato: "v1:" . base64( iv(12) . tag(16) . ciphertext ).

require_once __DIR__ . '/config.php';

const DB_DECRYPT_UNAVAILABLE = '[contenido no disponible]';

// 32 bytes crudos o null. Memoiza. Un valor inválido se trata como "sin clave".
// Hook de pruebas: $GLOBALS['__test_db_key'] (base64) tiene prioridad si existe.
function db_encryption_key(): ?string {
    // Hook de pruebas: si $GLOBALS['__test_db_key'] existe, se resuelve SIEMPRE
    // desde él (sin memoizar), para que un test pueda cambiar la clave a media
    // ejecución. En producción (sin el hook) se memoiza tras la 1ª llamada.
    static $cached = false; // false = sin resolver
    $hooked = array_key_exists('__test_db_key', $GLOBALS);
    if (!$hooked && $cached !== false) {
        return $cached;
    }
    $raw = $hooked ? (string) $GLOBALS['__test_db_key'] : (string) DB_ENCRYPTION_KEY;

    $resolve = static function (string $raw): ?string {
        if ($raw === '') {
            return null;
        }
        $decoded = base64_decode($raw, true);
        if ($decoded === false || strlen($decoded) !== 32) {
            static $warned = false;
            if (!$warned) {
                error_log('crypto: DB_ENCRYPTION_KEY inválida (se esperaban 32 bytes base64); cifrado deshabilitado');
                $warned = true;
            }
            return null;
        }
        return $decoded;
    };

    $key = $resolve($raw);
    if (!$hooked) {
        $cached = $key;
    }
    return $key;
}

function db_encryption_enabled(): bool {
    return db_encryption_key() !== null;
}

function db_encrypt(?string $plain): ?string {
    if ($plain === null || $plain === '') {
        return $plain;
    }
    $key = db_encryption_key();
    if ($key === null) {
        return $plain;
    }
    $iv = random_bytes(12);
    $tag = '';
    $ct = openssl_encrypt($plain, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $iv, $tag, '', 16);
    if ($ct === false) {
        error_log('crypto: openssl_encrypt falló; se guarda en plano');
        return $plain;
    }
    return 'v1:' . base64_encode($iv . $tag . $ct);
}

function db_decrypt(?string $stored): ?string {
    if ($stored === null || strncmp($stored, 'v1:', 3) !== 0) {
        return $stored; // NULL o texto plano / formato desconocido
    }
    $key = db_encryption_key();
    if ($key === null) {
        error_log('crypto: valor cifrado pero no hay DB_ENCRYPTION_KEY');
        return DB_DECRYPT_UNAVAILABLE;
    }
    $raw = base64_decode(substr($stored, 3), true);
    if ($raw === false || strlen($raw) < 28) {
        error_log('crypto: envelope v1 malformado');
        return DB_DECRYPT_UNAVAILABLE;
    }
    $iv = substr($raw, 0, 12);
    $tag = substr($raw, 12, 16);
    $ct = substr($raw, 28);
    $plain = openssl_decrypt($ct, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $iv, $tag);
    if ($plain === false) {
        error_log('crypto: openssl_decrypt falló (clave equivocada o valor alterado)');
        return DB_DECRYPT_UNAVAILABLE;
    }
    return $plain;
}
