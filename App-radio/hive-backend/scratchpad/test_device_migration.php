<?php
// Verifica que la migración 033 dejó el esquema esperado.
// Uso: C:\xampp\php\php.exe scratchpad/test_device_migration.php
require __DIR__ . '/../config.php';

$pass = 0; $fail = 0;
function check(string $name, bool $ok): void {
    global $pass, $fail;
    echo ($ok ? "  OK   " : "  FAIL ") . $name . "\n";
    $ok ? $pass++ : $fail++;
}

function column(PDO $pdo, string $table, string $col): ?array {
    $st = $pdo->prepare(
        'SELECT DATA_TYPE, COLUMN_TYPE, IS_NULLABLE
         FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?'
    );
    $st->execute([$table, $col]);
    return $st->fetch() ?: null;
}
function tableExists(PDO $pdo, string $table): bool {
    $st = $pdo->prepare(
        'SELECT 1 FROM information_schema.TABLES
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?'
    );
    $st->execute([$table]);
    return (bool) $st->fetch();
}

check('tabla attendance_trusted_devices existe', tableExists($pdo, 'attendance_trusted_devices'));
check('tabla attendance_device_requests existe', tableExists($pdo, 'attendance_device_requests'));

check('attendance.device_key es varchar(64) nullable',
    (function () use ($pdo) {
        $c = column($pdo, 'attendance', 'device_key');
        return $c && $c['COLUMN_TYPE'] === 'varchar(64)' && $c['IS_NULLABLE'] === 'YES';
    })());
check('attendance.device_status es el enum esperado',
    (function () use ($pdo) {
        $c = column($pdo, 'attendance', 'device_status');
        return $c && $c['COLUMN_TYPE'] === "enum('trusted','first_use','director_approved')";
    })());
check('attendance.biometric_result es el enum esperado',
    (function () use ($pdo) {
        $c = column($pdo, 'attendance', 'biometric_result');
        return $c && $c['COLUMN_TYPE'] === "enum('ok','skipped','failed')";
    })());
check('attendance.biometric_type existe', column($pdo, 'attendance', 'biometric_type') !== null);
check('attendance.location_accuracy_m existe', column($pdo, 'attendance', 'location_accuracy_m') !== null);

check('trusted_devices.employee_id es PRIMARY KEY',
    (function () use ($pdo) {
        $st = $pdo->query(
            "SELECT COLUMN_KEY FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'attendance_trusted_devices'
               AND COLUMN_NAME = 'employee_id'"
        );
        $r = $st->fetch();
        return $r && $r['COLUMN_KEY'] === 'PRI';
    })());
check('device_requests tiene índice único (employee_id, device_key)',
    (function () use ($pdo) {
        $st = $pdo->query(
            "SHOW INDEX FROM attendance_device_requests WHERE Key_name = 'uq_att_dev_req'"
        );
        return count($st->fetchAll()) === 2;
    })());

echo "\n$pass passed, $fail failed\n";
exit($fail === 0 ? 0 : 1);
