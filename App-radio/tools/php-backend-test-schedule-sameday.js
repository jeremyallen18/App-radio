// Smoke test: un cambio de horario del director aplica al día en curso.
// Requiere XAMPP (Apache + MySQL). Crea filas zz_sched_* y las borra.
const mysql = require('mysql2/promise');
const crypto = require('crypto');
const BASE = 'http://127.0.0.1/hive-backend';
const DB = { host: '127.0.0.1', user: 'hive_user', password: 'HivePass_2026!', database: 'hive_db' };
const RUN = Date.now().toString(36);
const id = () => crypto.randomBytes(12).toString('hex');
let pass = 0, fail = 0; const fails = [];
const check = (n, c, d) => { if (c) { pass++; console.log('  PASS ' + n); } else { fail++; fails.push(n + ' :: ' + d); console.log('  FAIL ' + n + ' -> ' + d); } };

async function req(method, p, { token, json } = {}) {
  const headers = {}; let body;
  if (token) headers['Authorization'] = token;
  if (json) { headers['Content-Type'] = 'application/json'; body = JSON.stringify(json); }
  const res = await fetch(BASE + p, { method, headers, body, redirect: 'manual' });
  const text = await res.text(); let j = null; try { j = JSON.parse(text); } catch (_) {}
  return { status: res.status, body: j, text };
}

(async () => {
  const db = await mysql.createConnection(DB);
  const companyId = id(), deptId = id(), dirId = id(), empId = id();
  const dirTok = 'zzTs_' + RUN + '_dir', dirEmail = `zz_sched_${RUN}_dir@test.invalid`;
  const empEmail = `zz_sched_${RUN}_emp@test.invalid`;
  const today = new Date().toISOString().slice(0, 10);
  const yesterday = new Date(Date.now() - 864e5).toISOString().slice(0, 10);
  try {
    await db.execute('INSERT INTO companies (id, name) VALUES (?, ?)', [companyId, 'zz_sched_co_' + RUN]);
    await db.execute('INSERT INTO departments (id, company_id, name, manager_email) VALUES (?,?,?,?)', [deptId, companyId, 'zz_D_' + RUN, null]);
    const mkUser = (uid, email, role, dept, token) => db.execute(
      'INSERT INTO users (id, name, email, password, token, role, department_id, email_verified_at) VALUES (?,?,?,?,?,?,?, NOW())',
      [uid, email.split('@')[0], email, 'x', token, role, dept]);
    await mkUser(dirId, dirEmail, 'director', null, dirTok);
    await mkUser(empId, empEmail, 'employee', deptId, 'zzTs_' + RUN + '_emp');

    // Horario vigente + snapshot de HOY ya congelado con los valores viejos.
    await db.execute(
      'INSERT INTO employee_schedules (employee_id, entry_time, exit_time, meal_time, meal_max_minutes, late_tolerance_minutes) VALUES (?, "08:00:00","17:00:00","14:00:00",60,15)',
      [empId]);
    await db.execute(
      'INSERT INTO attendance_schedule_snapshots (employee_id, work_date, entry_time, exit_time, meal_time, meal_max_minutes, late_tolerance_minutes) VALUES (?, ?, "08:00:00","17:00:00","14:00:00",60,15)',
      [empId, today]);
    // Snapshot de AYER: debe quedar intacto (histórico inmutable).
    await db.execute(
      'INSERT INTO attendance_schedule_snapshots (employee_id, work_date, entry_time, exit_time, meal_time, meal_max_minutes, late_tolerance_minutes) VALUES (?, ?, "08:00:00","17:00:00","14:00:00",60,15)',
      [empId, yesterday]);

    // El director autoriza salida temprana: cambia el horario a las 09:00
    // (y también entrada/comida/límite/tolerancia, para verificar qué se
    // propaga al snapshot de hoy y qué no).
    const r = await req('POST', '/admin/schedules/' + empId, {
      token: dirTok,
      json: { entryTime: '08:30', exitTime: '09:00', mealTime: '13:00', mealMaxMinutes: 45, lateToleranceMinutes: 10 },
    });
    check('guardar horario -> 200', r.status === 200, r.status + ' ' + r.text);

    const [[sched]] = await db.execute('SELECT * FROM employee_schedules WHERE employee_id = ?', [empId]);
    check('employee_schedules.exit_time = 09:00:00', sched.exit_time === '09:00:00', sched.exit_time);

    const [[snapToday]] = await db.execute(
      'SELECT * FROM attendance_schedule_snapshots WHERE employee_id = ? AND work_date = ?', [empId, today]);
    check('snapshot HOY exit_time sincronizado a 09:00:00', snapToday.exit_time === '09:00:00', snapToday.exit_time);
    check('snapshot HOY meal_time -> 13:00:00', snapToday.meal_time === '13:00:00', snapToday.meal_time);
    check('snapshot HOY meal_max_minutes -> 45', snapToday.meal_max_minutes === 45, String(snapToday.meal_max_minutes));
    check('snapshot HOY late_tolerance_minutes -> 10', snapToday.late_tolerance_minutes === 10, String(snapToday.late_tolerance_minutes));
    check('snapshot HOY entry_time NO cambia (queda 08:00:00)', snapToday.entry_time === '08:00:00', snapToday.entry_time);

    const [[snapYest]] = await db.execute(
      'SELECT * FROM attendance_schedule_snapshots WHERE employee_id = ? AND work_date = ?', [empId, yesterday]);
    check('snapshot AYER intacto (exit_time sigue 17:00:00)', snapYest.exit_time === '17:00:00', snapYest.exit_time);
    check('snapshot AYER intacto (meal_max sigue 60)', snapYest.meal_max_minutes === 60, String(snapYest.meal_max_minutes));
  } finally {
    await db.execute('DELETE FROM attendance_schedule_snapshots WHERE employee_id = ?', [empId]);
    await db.execute('DELETE FROM employee_schedules WHERE employee_id = ?', [empId]);
    await db.execute('DELETE FROM users WHERE email LIKE ?', ['zz_sched_' + RUN + '_%']);
    await db.execute('DELETE FROM departments WHERE id = ?', [deptId]);
    await db.execute('DELETE FROM companies WHERE id = ?', [companyId]);
    await db.end();
  }
  console.log('\n' + pass + ' pass, ' + fail + ' fail');
  if (fail) { console.log(fails.join('\n')); process.exit(1); }
})().catch(e => { console.error(e); process.exit(1); });
