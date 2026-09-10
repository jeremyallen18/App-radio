<?php
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
// Cifra (o con --decrypt, descifra) las columnas sensibles existentes.
// Idempotente: solo toca filas cuyo valor NO empieza por "v1:" (o, con
// --decrypt, las que sí). Requiere DB_ENCRYPTION_KEY.
//
// Uso:
//   C:\xampp\php\php.exe hive-backend/migrate_encrypt_027.php
//   C:\xampp\php\php.exe hive-backend/migrate_encrypt_027.php --decrypt   (rollback)
//
// En local puede hacer falta:  set OPENSSL_CONF=C:\xampp\php\extras\ssl\openssl.cnf
//
// Trabaja por lotes de 200 filas, una transacción por lote: un fallo a media
// ejecución deja un estado parcial consistente que una nueva ejecución completa.

require __DIR__ . '/config.php';
require __DIR__ . '/crypto.php';

if (!db_encryption_enabled()) {
    fwrite(STDERR, "ABORT: DB_ENCRYPTION_KEY no configurada.\n");
    exit(1);
}
$decrypt = in_array('--decrypt', $argv, true);

$assumeYes = in_array('--yes', $argv, true);
$mode = $decrypt ? 'DESCIFRAR' : 'CIFRAR';
fwrite(STDERR, "migrate_encrypt_027: va a $mode columnas sensibles de hive_db IN SITU.\n");
fwrite(STDERR, "Haz un mysqldump ANTES. Guarda DB_ENCRYPTION_KEY por separado del dump.\n");
if (!$assumeYes) {
    fwrite(STDERR, "Aborta: vuelve a ejecutar con --yes para confirmar.\n");
    exit(1);
}

/** @var array<array{table:string,col:string}> */
$targets = [
    ['table' => 'chat_messages',         'col' => 'body'],
    ['table' => 'notifications',         'col' => 'message'],
    ['table' => 'leave_requests',        'col' => 'reason'],
    ['table' => 'leave_requests',        'col' => 'rejection_reason'],
    ['table' => 'leave_requests',        'col' => 'cancellation_reason'],
    ['table' => 'absence_justifications','col' => 'reason'],
    ['table' => 'absence_justifications','col' => 'review_note'],
];

$grand = 0;
foreach ($targets as $t) {
    [$table, $col] = [$t['table'], $t['col']];
    $like = $decrypt ? "$col LIKE 'v1:%'" : "$col IS NOT NULL AND $col NOT LIKE 'v1:%'";
    $rows = $pdo->query("SELECT id, $col AS v FROM $table WHERE $like")->fetchAll(PDO::FETCH_ASSOC);
    if (!$rows) { echo str_pad("$table.$col", 40) . "0\n"; continue; }
    $upd = $pdo->prepare("UPDATE $table SET $col = ? WHERE id = ?");
    $n = 0;
    $pdo->beginTransaction();
    foreach ($rows as $i => $r) {
        $new = $decrypt ? db_decrypt($r['v']) : db_encrypt($r['v']);
        if ($decrypt && $new === DB_DECRYPT_UNAVAILABLE) {
            fwrite(STDERR, "ABORT: $table.$col id={$r['id']} no se pudo descifrar (¿clave equivocada?). Sin cambios en este lote.\n");
            if ($pdo->inTransaction()) { $pdo->rollBack(); }
            exit(1);
        }
        if (!$decrypt && strncmp((string) $new, 'v1:', 3) !== 0) {
            fwrite(STDERR, "ABORT: $table.$col id={$r['id']} no se pudo cifrar (openssl). Sin cambios en este lote.\n");
            if ($pdo->inTransaction()) { $pdo->rollBack(); }
            exit(1);
        }
        $upd->execute([$new, $r['id']]);
        $n++;
        if ($n % 200 === 0) { $pdo->commit(); $pdo->beginTransaction(); }
    }
    $pdo->commit();
    $grand += $n;
    echo str_pad("$table.$col", 40) . "$n\n";
}
echo str_repeat('-', 45) . "\n" . str_pad(($decrypt ? 'descifradas' : 'cifradas') . ':', 40) . "$grand\n";
