<?php
// Reporte mensual de actividades (tareas de departamento completadas). Comparte
// los guards y el rango de mes de attendance_reports.php.
//
// Endpoints (registrados en index.php):
//   GET /admin/activities/summary?month=&departmentId=            (director/manager)
//   GET /admin/activities/report?month=&departmentId=&format=csv|pdf

// Tareas 'completada' con completed_at dentro de [from, to], atribuidas a la
// persona responsable (assigned_to, o completed_by si no hubo asignado) y
// limitadas a los empleados visibles para este admin.
function activities_completed_rows(PDO $pdo, array $admin, string $from, string $to, string $deptFilter): array {
    $byId = [];
    foreach (attendance_admin_employees($pdo, $admin) as $emp) {
        if ($deptFilter !== '' && $emp['department_id'] !== $deptFilter) continue;
        $byId[$emp['id']] = $emp;
    }
    if (!$byId) return [];

    $in = implode(',', array_fill(0, count($byId), '?'));
    $params = array_merge(array_keys($byId), [$from, $to]);
    $stmt = $pdo->prepare(
        "SELECT t.id, t.title, t.due_date, t.completed_at, t.completed_late, t.department_id,
                COALESCE(t.assigned_to, t.completed_by) AS person_id,
                d.name AS dept_name
           FROM dept_tasks t
           LEFT JOIN departments d ON d.id = t.department_id
          WHERE t.status = 'completada'
            AND COALESCE(t.assigned_to, t.completed_by) IN ($in)
            AND DATE(t.completed_at) BETWEEN ? AND ?
          ORDER BY t.completed_at ASC"
    );
    $stmt->execute($params);

    $rows = [];
    foreach ($stmt->fetchAll() as $r) {
        $emp = $byId[$r['person_id']] ?? null;
        if ($emp === null) continue;
        $rows[] = [
            'taskId'       => $r['id'],
            'title'        => $r['title'],
            'employeeId'   => $emp['id'],
            'employeeName' => $emp['name'],
            'position'     => $emp['position'] ?: '',
            'departmentId' => $r['department_id'],
            'departmentName' => $r['dept_name'] ?? '',
            'dueDate'      => $r['due_date'],
            'completedAt'  => $r['completed_at'],
            'late'         => (bool) ($r['completed_late'] ?? 0),
        ];
    }
    return $rows;
}

// GET /admin/activities/summary — conteos por empleado + totales (vista previa).
function adminActivitiesSummary(PDO $pdo) {
    $admin = attendance_admin_guard($pdo);
    [$from, $to, $m] = attendance_month_bounds($_GET['month'] ?? null);
    $deptFilter = trim((string) ($_GET['departmentId'] ?? ''));

    $rows = activities_completed_rows($pdo, $admin, $from, $to, $deptFilter);

    $byEmp = [];
    foreach ($rows as $r) {
        $e = $r['employeeId'];
        $byEmp[$e] ??= [
            'employeeId'   => $e,
            'name'         => $r['employeeName'],
            'position'     => $r['position'],
            'departmentId' => $r['departmentId'],
            'completed'    => 0,
            'onTime'       => 0,
            'late'         => 0,
        ];
        $byEmp[$e]['completed']++;
        $byEmp[$e][$r['late'] ? 'late' : 'onTime']++;
    }

    $list = array_values($byEmp);
    usort($list, fn($a, $b) => strcasecmp($a['name'], $b['name']));

    $tot = ['completed' => 0, 'onTime' => 0, 'late' => 0, 'people' => count($list)];
    foreach ($list as $e) {
        $tot['completed'] += $e['completed'];
        $tot['onTime']    += $e['onTime'];
        $tot['late']      += $e['late'];
    }

    json_response([
        'success'   => true,
        'month'     => $m,
        'from'      => $from,
        'to'        => $to,
        'employees' => $list,
        'totals'    => $tot,
    ]);
}

// GET /admin/activities/report?format=csv|pdf — descarga, una fila por tarea.
function adminActivitiesReport(PDO $pdo) {
    $admin = attendance_admin_guard($pdo);
    [$from, $to, $m] = attendance_month_bounds($_GET['month'] ?? null);
    $deptFilter = trim((string) ($_GET['departmentId'] ?? ''));
    $format = strtolower(trim((string) ($_GET['format'] ?? 'csv')));
    if (!in_array($format, ['csv', 'pdf'], true)) $format = 'csv';

    $rows = activities_completed_rows($pdo, $admin, $from, $to, $deptFilter);

    if ($format === 'pdf') {
        activities_report_pdf($m, $rows);
    } else {
        activities_report_csv($m, $rows);
    }
    exit;
}

function activities_fmt_date(?string $s): string {
    if (!$s) return '';
    $t = strtotime($s);
    return $t ? date('Y-m-d', $t) : $s;
}

function activities_report_csv(string $month, array $rows): void {
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="actividades_' . $month . '.csv"');
    header('Cache-Control: private, no-store');
    echo "\xEF\xBB\xBF"; // BOM para Excel
    $out = fopen('php://output', 'w');
    fputcsv($out, [
        'Empleado', 'Puesto', 'Departamento', 'Actividad',
        'Fecha limite', 'Fecha de entrega', 'Entrega',
    ]);
    foreach ($rows as $r) {
        fputcsv($out, [
            $r['employeeName'], $r['position'], $r['departmentName'], $r['title'],
            activities_fmt_date($r['dueDate']), activities_fmt_date($r['completedAt']),
            $r['late'] ? 'Con retardo' : 'A tiempo',
        ]);
    }
    fclose($out);
}

function activities_report_pdf(string $month, array $rows): void {
    require_once __DIR__ . '/lib/fpdf/fpdf.php';
    $pdf = new FPDF('L', 'mm', 'A4');
    $pdf->SetTitle('Reporte de actividades ' . $month);
    $pdf->SetAutoPageBreak(true, 15);
    $pdf->AddPage();

    $pdf->SetFont('Helvetica', 'B', 14);
    $pdf->Cell(0, 8, attendance_pdf_txt('Reporte de actividades - ' . $month), 0, 1);
    $pdf->SetFont('Helvetica', '', 9);
    $pdf->Cell(0, 6, attendance_pdf_txt('Generado el ' . date('Y-m-d H:i') . '  -  ' . count($rows) . ' actividad(es)'), 0, 1);
    $pdf->Ln(2);

    $headers = ['Empleado', 'Departamento', 'Actividad', 'Fecha limite', 'Entrega', 'Estado'];
    $w = [50, 40, 95, 28, 28, 26];

    $pdf->SetFont('Helvetica', 'B', 8);
    $pdf->SetFillColor(230, 230, 230);
    foreach ($headers as $i => $h) {
        $pdf->Cell($w[$i], 7, attendance_pdf_txt($h), 1, 0, 'C', true);
    }
    $pdf->Ln();

    $pdf->SetFont('Helvetica', '', 8);
    if (!$rows) {
        $pdf->Cell(array_sum($w), 7, attendance_pdf_txt('Sin actividades completadas en el mes.'), 1, 1, 'C');
    }
    foreach ($rows as $r) {
        $cells = [
            $r['employeeName'], $r['departmentName'],
            mb_strimwidth($r['title'], 0, 70, '...', 'UTF-8'),
            activities_fmt_date($r['dueDate']), activities_fmt_date($r['completedAt']),
            $r['late'] ? 'Retardo' : 'A tiempo',
        ];
        foreach ($cells as $i => $c) {
            $pdf->Cell($w[$i], 6, attendance_pdf_txt((string) $c), 1, 0, $i < 3 ? 'L' : 'C');
        }
        $pdf->Ln();
    }

    $body = $pdf->Output('S');
    header('Content-Type: application/pdf');
    header('Content-Disposition: attachment; filename="actividades_' . $month . '.pdf"');
    header('Content-Length: ' . strlen($body));
    header('Cache-Control: private, no-store');
    echo $body;
}
