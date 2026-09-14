<?php
// Harness de chat grupal (empresa + departamento, migración 038).
// Uso: C:\xampp\php\php.exe scratchpad/test_chat_groups.php
require __DIR__ . '/../config.php';
require __DIR__ . '/../helpers.php';
require __DIR__ . '/../org.php';
require __DIR__ . '/../chat_groups.php';
require __DIR__ . '/../chat.php';

$pass = 0; $fail = 0;
function check(string $name, bool $ok): void {
    global $pass, $fail;
    if ($ok) { $pass++; echo "  OK   $name\n"; }
    else     { $fail++; echo "  FAIL $name\n"; }
}

$company = get_the_company($pdo);
check('hay una empresa creada (fixture previo)', $company !== null);
if (!$company) { echo "Sin empresa, no se puede seguir.\n"; exit(1); }

// --- fixtures: un depto temporal + 3 usuarios (2 dentro, 1 fuera) --------
$deptId = generate_id();
$pdo->prepare('INSERT INTO departments (id, company_id, name) VALUES (?, ?, ?)')
    ->execute([$deptId, $company['id'], 'Depto Prueba Chat ' . substr($deptId, 0, 6)]);

function make_user(PDO $pdo, ?string $deptId, string $tag): array {
    $id = generate_id();
    $email = "tmpchat_{$tag}_" . substr($id, 0, 8) . '@test.local';
    $pdo->prepare(
        "INSERT INTO users (id, name, email, password, role, department_id, email_verified_at)
         VALUES (?, ?, ?, 'x', 'employee', ?, NOW())"
    )->execute([$id, "Tmp $tag", $email, $deptId]);
    return ['id' => $id, 'email' => $email, 'department_id' => $deptId];
}

$inA = make_user($pdo, $deptId, 'inA');
$inB = make_user($pdo, $deptId, 'inB');
$outside = make_user($pdo, null, 'outside');

function cleanup(PDO $pdo, string $deptId, array $ids): void {
    $groupIds = $pdo->query("SELECT id FROM chat_groups WHERE ref_id = " . $pdo->quote($deptId))->fetchAll();
    foreach ($groupIds as $g) {
        $pdo->prepare('DELETE FROM chat_group_messages WHERE group_id = ?')->execute([$g['id']]);
        $pdo->prepare('DELETE FROM chat_group_reads WHERE group_id = ?')->execute([$g['id']]);
        $pdo->prepare('DELETE FROM chat_groups WHERE id = ?')->execute([$g['id']]);
    }
    $emails = $pdo->query('SELECT email FROM users WHERE id IN (' . implode(',', array_map([$pdo, 'quote'], $ids)) . ')')
        ->fetchAll(PDO::FETCH_COLUMN);
    foreach ($emails as $email) {
        $pdo->prepare('DELETE FROM notifications WHERE email = ?')->execute([$email]);
    }
    foreach ($ids as $id) {
        $pdo->prepare('DELETE FROM users WHERE id = ?')->execute([$id]);
    }
    $pdo->prepare('DELETE FROM departments WHERE id = ?')->execute([$deptId]);
}
register_shutdown_function('cleanup', $pdo, $deptId, [$inA['id'], $inB['id'], $outside['id']]);

// --- membresía ------------------------------------------------------------
$userA = ['id' => $inA['id'], 'email' => $inA['email'], 'department_id' => $deptId];
$userOutside = ['id' => $outside['id'], 'email' => $outside['email'], 'department_id' => null];

$groups = chat_user_groups($pdo, $userA);
check('empleado de depto ve 2 grupos (empresa + depto)', count($groups) === 2);

$groupsOutside = chat_user_groups($pdo, $userOutside);
check('empleado sin depto ve 1 grupo (solo empresa)', count($groupsOutside) === 1);

$deptGroup = chat_group_get_or_create($pdo, 'department', $deptId);
check('miembro del depto pasa el check de membresía', chat_group_membership_check($pdo, $userA, $deptGroup));
check('quien no es del depto NO pasa el check', !chat_group_membership_check($pdo, $userOutside, $deptGroup));

$companyGroup = chat_group_get_or_create($pdo, 'company', $company['id']);
check('cualquier usuario verificado pasa el check de empresa', chat_group_membership_check($pdo, $userOutside, $companyGroup));

$emails = chat_group_member_emails($pdo, $deptGroup);
sort($emails);
$expected = [$inA['email'], $inB['email']];
sort($expected);
check('member_emails del depto = exactamente los 2 miembros', $emails === $expected);

check('get_or_create es idempotente (mismo id)', chat_group_get_or_create($pdo, 'department', $deptId)['id'] === $deptGroup['id']);

// --- mensajes + no leídos ---------------------------------------------------
$pdo->prepare('INSERT INTO chat_group_messages (group_id, sender_id, body) VALUES (?, ?, ?)')
    ->execute([$deptGroup['id'], $inA['id'], db_encrypt('Hola equipo')]);

$rowsA = chat_group_conversation_rows($pdo, $userA);
$deptRowA = null;
foreach ($rowsA as $r) if ($r['groupId'] === $deptGroup['id']) $deptRowA = $r;
check('bandeja: remitente ve su propio mensaje, unread=0', $deptRowA !== null && $deptRowA['unread'] === 0 && $deptRowA['lastFromMe'] === true);

$userB = ['id' => $inB['id'], 'email' => $inB['email'], 'department_id' => $deptId];
$rowsB = chat_group_conversation_rows($pdo, $userB);
$deptRowB = null;
foreach ($rowsB as $r) if ($r['groupId'] === $deptGroup['id']) $deptRowB = $r;
check('bandeja: el otro miembro ve unread=1', $deptRowB !== null && $deptRowB['unread'] === 1);

// Simula abrir el hilo (lo que hace chatGroupThread): marca como leído.
$pdo->prepare(
    'INSERT INTO chat_group_reads (group_id, user_id, last_read_message_id)
     SELECT ?, ?, COALESCE(MAX(id), 0) FROM chat_group_messages WHERE group_id = ?
     ON DUPLICATE KEY UPDATE last_read_message_id = VALUES(last_read_message_id)'
)->execute([$deptGroup['id'], $inB['id'], $deptGroup['id']]);

$rowsB2 = chat_group_conversation_rows($pdo, $userB);
$deptRowB2 = null;
foreach ($rowsB2 as $r) if ($r['groupId'] === $deptGroup['id']) $deptRowB2 = $r;
check('tras "leer", unread vuelve a 0', $deptRowB2 !== null && $deptRowB2['unread'] === 0);

check('nombre del grupo = nombre del depto', chat_group_display_name($pdo, $deptGroup) === "Depto Prueba Chat " . substr($deptId, 0, 6));

// --- cambio de departamento pierde acceso ----------------------------------
$pdo->prepare('UPDATE users SET department_id = NULL WHERE id = ?')->execute([$inA['id']]);
$userAMoved = ['id' => $inA['id'], 'email' => $inA['email'], 'department_id' => null];
check('tras salir del depto, ya no pasa el check', !chat_group_membership_check($pdo, $userAMoved, $deptGroup));
$pdo->prepare('UPDATE users SET department_id = ? WHERE id = ?')->execute([$deptId, $inA['id']]);

echo "\n$pass OK, $fail FAIL\n";
exit($fail > 0 ? 1 : 0);
