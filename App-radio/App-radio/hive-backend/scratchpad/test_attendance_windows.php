<?php
// Harness de ventanas de fichaje + tolerancia + recordatorios.
// Uso: C:\xampp\php\php.exe scratchpad/test_attendance_windows.php
require __DIR__ . '/../config.php';
require __DIR__ . '/../helpers.php';
require __DIR__ . '/../attendance.php';

$pass = 0; $fail = 0;
function check(string $name, bool $ok): void {
    global $pass, $fail;
    if ($ok) { $pass++; echo "  OK   $name\n"; }
    else     { $fail++; echo "  FAIL $name\n"; }
}

// --- fixtures: un trabajador temporal con horario ------------------------
$empId = 'tmpwrk' . substr(bin2hex(random_bytes(9)), 0, 18); // 24 chars
$pdo->prepare(
  "INSERT INTO users (id, name, email, password, role, email_verified_at)
   VALUES (?, 'Tmp Worker', ?, 'x', 'employee', NOW())"
)->execute([$empId, $empId . '@test.local']);

function cleanup(PDO $pdo, string $empId): void {
    $pdo->prepare('DELETE FROM attendance_reminders_sent WHERE employee_id = ?')->execute([$empId]);
    $pdo->prepare('DELETE FROM leave_requests WHERE employee_id = ?')->execute([$empId]);
    $pdo->prepare('DELETE FROM attendance WHERE employee_id = ?')->execute([$empId]);
    $pdo->prepare('DELETE FROM attendance_schedule_snapshots WHERE employee_id = ?')->execute([$empId]);
    $pdo->prepare('DELETE FROM employee_schedules WHERE employee_id = ?')->execute([$empId]);
    $pdo->prepare('DELETE FROM notifications WHERE email = ?')->execute([$empId . '@test.local']);
    $pdo->prepare('DELETE FROM users WHERE id = ?')->execute([$empId]);
}
register_shutdown_function('cleanup', $pdo, $empId);

// --- Task 2: guardar y leer la tolerancia ------------------------------
$pdo->prepare(
  "INSERT INTO employee_schedules
     (employee_id, entry_time, exit_time, meal_time, meal_max_minutes, late_tolerance_minutes)
   VALUES (?, '09:00:00', '17:00:00', '14:00:00', 60, 20)"
)->execute([$empId]);
$s = attendance_schedule_for($pdo, $empId);
$p = attendance_schedule_payload($s);
check('payload incluye lateToleranceMinutes', ($p['lateToleranceMinutes'] ?? null) === 20);

// --- Task 3: tolerancia en el cálculo de retardo ----------------------
$today = date('Y-m-d');
// snapshot congelado con tolerancia 15
$pdo->prepare('DELETE FROM attendance_schedule_snapshots WHERE employee_id = ?')->execute([$empId]);
$pdo->prepare(
  "INSERT INTO attendance_schedule_snapshots
     (employee_id, work_date, entry_time, exit_time, meal_time, meal_max_minutes, late_tolerance_minutes)
   VALUES (?, ?, '09:00:00', '17:00:00', '14:00:00', 60, 15)"
)->execute([$empId, $today]);

function set_entry(PDO $pdo, string $empId, string $today, string $hms): void {
    $pdo->prepare('DELETE FROM attendance WHERE employee_id = ? AND type = "entrada"')->execute([$empId]);
    $pdo->prepare(
      "INSERT INTO attendance (employee_id, type, work_date, event_time, method)
       VALUES (?, 'entrada', ?, ?, 'gps')"
    )->execute([$empId, $today, $today . ' ' . $hms]);
}
$emp = ['id' => $empId, 'name' => 'Tmp', 'email' => $empId . '@test.local'];

set_entry($pdo, $empId, $today, '09:15:00'); // +15 exactos
$sum = attendance_day_summary($pdo, $emp, $today, attendance_events_for($pdo, $empId, $today));
check('entrada +15 con tol 15 NO es tarde', $sum['isLate'] === false);
check('toleranceMinutes en el payload', ($sum['toleranceMinutes'] ?? null) === 15);

set_entry($pdo, $empId, $today, '09:16:00'); // +16
$sum = attendance_day_summary($pdo, $emp, $today, attendance_events_for($pdo, $empId, $today));
check('entrada +16 con tol 15 SÍ es tarde', $sum['isLate'] === true);
check('lateMinutes es el delta real (16)', (int) $sum['lateMinutes'] === 16);

// --- Task 4: helper de hora efectiva + ventana de entrada -------------
$pdo->prepare('DELETE FROM attendance WHERE employee_id = ?')->execute([$empId]);
$pdo->prepare('DELETE FROM attendance_schedule_snapshots WHERE employee_id = ?')->execute([$empId]);

check('hora efectiva usa el horario cuando no hay snapshot',
    attendance_effective_time($pdo, $empId, $today, 'entry_time') === '09:00:00');

$pdo->prepare(
  "INSERT INTO attendance_schedule_snapshots
     (employee_id, work_date, entry_time, exit_time, meal_time, meal_max_minutes, late_tolerance_minutes)
   VALUES (?, ?, '08:30:00', '16:30:00', '13:30:00', 60, 15)"
)->execute([$empId, $today]);
check('hora efectiva prefiere el snapshot',
    attendance_effective_time($pdo, $empId, $today, 'meal_time') === '13:30:00');
$pdo->prepare('DELETE FROM attendance_schedule_snapshots WHERE employee_id = ?')->execute([$empId]);

// sin horario -> null
$pdo->prepare('DELETE FROM employee_schedules WHERE employee_id = ?')->execute([$empId]);
check('sin horario, hora efectiva es null',
    attendance_effective_time($pdo, $empId, $today, 'entry_time') === null);

// restaurar horario para el resto de la suite
$pdo->prepare(
  "INSERT INTO employee_schedules
     (employee_id, entry_time, exit_time, meal_time, meal_max_minutes, late_tolerance_minutes)
   VALUES (?, '09:00:00', '17:00:00', '14:00:00', 60, 15)"
)->execute([$empId]);

// --- Task 5: ventanas de comida y salida (lógica de frontera) --------
// meal_time efectiva y exit_time efectiva desde el horario restaurado
check('meal_time efectiva = 14:00:00',
    attendance_effective_time($pdo, $empId, $today, 'meal_time') === '14:00:00');
check('exit_time efectiva = 17:00:00',
    attendance_effective_time($pdo, $empId, $today, 'exit_time') === '17:00:00');

// simulación de la comparación que hará el endpoint
$mealTs = strtotime($today . ' 14:00:00');
check('12:00 < meal_time  => bloqueado', strtotime($today . ' 12:00:00') < $mealTs);
check('14:00 >= meal_time => permitido', !(strtotime($today . ' 14:00:00') < $mealTs));

// --- Task 6: despachador de recordatorios ----------------------------
require_once __DIR__ . '/../leave_requests.php';
require_once __DIR__ . '/../attendance_reminders.php';

// horario con entrada = ahora - 10 min  => entry_late vencido y dentro de gracia
$nowT = new DateTimeImmutable();
$entryH = $nowT->modify('-10 minutes')->format('H:i:s');
$pdo->prepare('UPDATE employee_schedules SET entry_time = ?, meal_time = "23:30:00", exit_time = "23:59:00" WHERE employee_id = ?')
    ->execute([$entryH, $empId]);
$pdo->prepare('DELETE FROM attendance WHERE employee_id = ?')->execute([$empId]);
$pdo->prepare('DELETE FROM attendance_reminders_sent WHERE employee_id = ?')->execute([$empId]);
$pdo->prepare('DELETE FROM notifications WHERE email = ?')->execute([$empId . '@test.local']);

if (is_working_day($today)) {
    $n1 = attendance_dispatch_due_reminders($pdo, $empId);
    check('primer pase emite entry_pre + entry_late (2)', $n1 === 2);
    $n2 = attendance_dispatch_due_reminders($pdo, $empId);
    check('segundo pase no repite (dedup)', $n2 === 0);
    $cnt = (int) $pdo->query(
        "SELECT COUNT(*) FROM notifications WHERE email = '" . $empId . "@test.local'
         AND type = 'attendance_reminder'"
    )->fetchColumn();
    check('2 filas notifications attendance_reminder', $cnt === 2);

    // con ausencia aprobada: no dispara
    $pdo->prepare('DELETE FROM attendance_reminders_sent WHERE employee_id = ?')->execute([$empId]);
    $lid = substr(bin2hex(random_bytes(12)), 0, 24);
    $pdo->prepare(
      "INSERT INTO leave_requests
         (id, employee_id, type, requested_start_date, requested_end_date, requested_days,
          approved_start_date, approved_end_date, approved_days, status)
       VALUES (?, ?, 'permiso', ?, ?, 1, ?, ?, 1, 'aprobado')"
    )->execute([$lid, $empId, $today, $today, $today, $today]);
    $n3 = attendance_dispatch_due_reminders($pdo, $empId);
    check('con ausencia aprobada no dispara', $n3 === 0);
    $pdo->prepare('DELETE FROM leave_requests WHERE id = ?')->execute([$lid]);
} else {
    check('(domingo: despachador se salta — no evaluado)', true);
}

echo "\n$pass OK / $fail FAIL\n";
exit($fail === 0 ? 0 : 1);
