<?php
// Recordatorios de asistencia: avisos push de entrada, hora de comida y salida.
// Se disparan por tiempo desde cron_attendance_reminders.php (cada 5 min) y, como
// respaldo, de forma perezosa por GET /attendance/today (solo el usuario actual).
//
// Esquema "doble aviso":
//   entry_pre  = entry - 10 min   entry_late = entry + 10 min
//   meal_pre   = meal  - 15 min
//   exit_pre   = exit  - 15 min   exit_due   = exit   exit_late = exit + 15 min
//
// Cada (trabajador, día, kind) se emite UNA vez (attendance_reminders_sent, PK).
// La ventana de gracia evita disparar avisos rancios si el cron se retrasa.

const ATT_REMINDER_GRACE_MIN = 20;

// Idempotente; se puede llamar en cada request. $onlyUserId != null => solo esa
// persona (uso perezoso). Devuelve el nº de avisos emitidos.
function attendance_dispatch_due_reminders(PDO $pdo, ?string $onlyUserId = null): int {
    $workDate = date('Y-m-d');
    if (!is_working_day($workDate)) {
        return 0;
    }
    $now = time();
    $graceSec = ATT_REMINDER_GRACE_MIN * 60;

    $sql = "SELECT u.id AS emp_id, u.email
            FROM employee_schedules es
            JOIN users u ON u.id = es.employee_id
            WHERE u.role IN ('employee','manager') AND " . SQL_USER_VERIFIED;
    $params = [];
    if ($onlyUserId !== null) {
        $sql .= ' AND u.id = ?';
        $params[] = $onlyUserId;
    }
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll();
    if (!$rows) {
        return 0;
    }

    // Prepara UNA sola vez el INSERT de deduplicación y reutiliza el handle.
    $ins = $pdo->prepare(
        'INSERT INTO attendance_reminders_sent (employee_id, work_date, kind, sent_at)
         VALUES (?, ?, ?, NOW())'
    );

    $sent = 0;
    foreach ($rows as $r) {
        $empId = $r['emp_id'];
        $email = $r['email'];

        // Horas efectivas: snapshot del día si ya existe (congelado), si no el horario.
        $entryEff = attendance_effective_time($pdo, $empId, $workDate, 'entry_time');
        $mealEff  = attendance_effective_time($pdo, $empId, $workDate, 'meal_time');
        $exitEff  = attendance_effective_time($pdo, $empId, $workDate, 'exit_time');
        if ($entryEff === null) {
            continue;
        }

        if (leave_absence_for_day($pdo, $empId, $workDate)) {
            continue; // ausencia aprobada: ningún aviso
        }

        $events    = attendance_events_for($pdo, $empId, $workDate);
        $hasEntry  = attendance_pick($events, 'entrada') !== null;
        $hasMeal   = attendance_pick($events, 'inicio_comida') !== null;
        $mealSkip  = attendance_meal_skipped($events);
        $inMeal    = attendance_state($events) === 'en_comida';
        $hasExit   = attendance_pick($events, 'salida') !== null;

        $entryTs = strtotime($workDate . ' ' . $entryEff);
        $mealTs  = $mealEff !== null ? strtotime($workDate . ' ' . $mealEff) : null;
        $exitTs  = $exitEff !== null ? strtotime($workDate . ' ' . $exitEff) : null;

        $due = [];
        if (!$hasEntry) {
            $due['entry_pre']  = ['target' => $entryTs - 10 * 60, 'grace' => ATT_REMINDER_GRACE_MIN * 60,
                'msg' => 'Tu entrada es a las ' . substr($entryEff, 0, 5) . '. No olvides registrarla.'];
            $due['entry_late'] = ['target' => $entryTs + 10 * 60, 'grace' => ATT_REMINDER_GRACE_MIN * 60,
                'msg' => 'Aún no registras tu entrada de hoy (hora asignada ' . substr($entryEff, 0, 5) . ').'];
        }
        if ($hasEntry && !$hasMeal && !$mealSkip && !$inMeal && $mealTs !== null) {
            $due['meal_pre'] = ['target' => $mealTs - 15 * 60, 'grace' => 15 * 60,
                'msg' => 'Tu hora de comida está por empezar (a las ' . substr($mealEff, 0, 5) . ').'];
        }
        if ($hasEntry && !$hasExit && $exitTs !== null) {
            $due['exit_pre']  = ['target' => $exitTs - 15 * 60, 'grace' => 15 * 60,
                'msg' => 'Tu salida es a las ' . substr($exitEff, 0, 5) . '. Prepárate para registrarla.'];
            $due['exit_due']  = ['target' => $exitTs, 'grace' => 15 * 60,
                'msg' => 'Ya son las ' . substr($exitEff, 0, 5) . '. No olvides registrar tu salida.'];
            $due['exit_late'] = ['target' => $exitTs + 15 * 60, 'grace' => ATT_REMINDER_GRACE_MIN * 60,
                'msg' => 'Aún no registras tu salida de hoy.'];
        }

        foreach ($due as $kind => $d) {
            if ($now < $d['target'] || $now > $d['target'] + ($d['grace'] ?? $graceSec)) {
                continue; // aún no vence, o ya se pasó la ventana de gracia
            }
            try {
                $ins->execute([$empId, $workDate, $kind]);
            } catch (PDOException $e) {
                if ($e->getCode() === '23000') {
                    continue; // ya enviado (PK) — carrera con otro pase/cron
                }
                throw $e;
            }
            if ($ins->rowCount() === 0) {
                continue;
            }
            notify_user($pdo, $email, null, 'attendance_reminder', $d['msg'], 'attendance', null);
            $sent++;
        }
    }
    return $sent;
}
