// Pruebas de integración del workflow jerárquico de tareas (Director ->
// Departamento -> Manager -> Empleado -> completa -> Manager valida ->
// Director ve estadísticas) contra el backend PHP real
// (C:\xampp\htdocs\hive-backend).
//
// Requisitos: Apache y MySQL de XAMPP corriendo, y la migración
// hive-backend/migrations/002_task_workflow.sql ya aplicada.
// Ejecutar:  node tools/php-backend-test-tasks.js
//
// Crea usuarios/empresa/departamento marcados (zz_taskit_...) y los borra
// al terminar, así que no ensucia los datos reales de hive_db.

const mysql = require('mysql2/promise');
const { dbConfig } = require('./load-env');

const BASE = process.env.HIVE_BASE_URL || 'http://127.0.0.1/hive-backend';
const DB = dbConfig();

const RUN = Date.now().toString(36);
const mk = (n) => `zz_taskit_${RUN}_${n}@test.invalid`;

let pass = 0, fail = 0;
const failures = [];
function check(name, cond, detail) {
  if (cond) { pass++; console.log(`  PASS  ${name}`); }
  else { fail++; failures.push(`${name} :: ${detail}`); console.log(`  FAIL  ${name}  -> ${detail}`); }
}

async function req(method, p, { token, json, form } = {}) {
  const headers = {};
  if (token) headers['Authorization'] = token;
  let body;
  if (json !== undefined) { headers['Content-Type'] = 'application/json'; body = JSON.stringify(json); }
  else if (form) { headers['Content-Type'] = 'application/x-www-form-urlencoded'; body = new URLSearchParams(form).toString(); }
  const res = await fetch(`${BASE}${p}`, { method, headers, body, redirect: 'manual' });
  const text = await res.text();
  let parsed = null; try { parsed = JSON.parse(text); } catch (_) {}
  return { status: res.status, body: parsed, text };
}

(async () => {
  const emails = {
    director: mk('director'), manager: mk('manager'),
    employeeA: mk('employeeA'), employeeB: mk('employeeB'), outsider: mk('outsider'),
  };
  const tok = {};
  let companyName, deptId, otherDeptId, deptTaskId;

  try {
    console.log('== Workflow jerárquico de tareas en ' + BASE + ' ==\n');

    console.log('-- SETUP: usuarios, empresa, departamento --');
    for (const [role, email] of Object.entries(emails)) {
      const r = await req('POST', '/user/signup', { form: { name: `Task ${role}`, email, password: 'Secreta123' } });
      check(`signup ${role}`, r.status === 200, `status=${r.status} ${r.text.slice(0, 100)}`);
      const l = await req('POST', '/user/login', { form: { email, password: 'Secreta123' } });
      tok[role] = l.body;
    }

    companyName = `Radio Doliv Tasks ${RUN}`;
    const cc = await req('POST', '/company/create', { token: tok.director, json: { name: companyName } });
    check('createCompany', cc.status === 200, `status=${cc.status} ${cc.text.slice(0, 150)}`);

    const cd = await req('POST', '/department/create', { token: tok.director, json: { name: `Sistemas ${RUN}` } });
    deptId = cd.body?.department?.id;
    check('createDepartment', cd.status === 200 && !!deptId, `${cd.text.slice(0, 150)}`);

    const cd2 = await req('POST', '/department/create', { token: tok.director, json: { name: `Marketing ${RUN}` } });
    otherDeptId = cd2.body?.department?.id;
    check('createDepartment (segundo depto, para pruebas cruzadas)', cd2.status === 200 && !!otherDeptId, `${cd2.text.slice(0, 150)}`);

    const am = await req('POST', `/department/assignManager/${deptId}`, { token: tok.director, json: { email: emails.manager } });
    check('assignDepartmentManager', am.status === 200, `${am.text.slice(0, 150)}`);

    for (const e of [emails.employeeA, emails.employeeB]) {
      const ae = await req('POST', `/department/assignEmployee/${deptId}`, { token: tok.manager, json: { email: e } });
      check(`assignDepartmentEmployee ${e}`, ae.status === 200, `${ae.text.slice(0, 150)}`);
    }
    const aeOut = await req('POST', `/department/assignEmployee/${otherDeptId}`, { token: tok.director, json: { email: emails.outsider } });
    check('assignDepartmentEmployee (outsider en el otro depto)', aeOut.status === 200, `${aeOut.text.slice(0, 150)}`);

    console.log('\n-- CREATE DEPARTMENT TASK (Director) --');
    const ct = await req('POST', `/department/task/${deptId}`, {
      token: tok.director, json: { task: 'Migrar servidores', deadline: '2026-12-31', priority: 'alta' },
    });
    deptTaskId = ct.body?.task?.id;
    check('createDepartmentTask (director)', ct.status === 200 && !!deptTaskId, `${ct.text.slice(0, 200)}`);
    check('la tarea nace sin asignar (assignedTo=null) y status=pending',
      ct.body?.task?.assignedTo === null && ct.body?.task?.status === 'pending', `${ct.text.slice(0, 200)}`);
    check('la tarea trae priority=alta y progress=0',
      ct.body?.task?.priority === 'alta' && ct.body?.task?.progress === 0, `${ct.text.slice(0, 200)}`);

    check('SEGURIDAD: createDepartmentTask sin ser director -> 403',
      (await req('POST', `/department/task/${deptId}`, { token: tok.manager, json: { task: 'hack', deadline: '2026-12-31' } })).status === 403, 'no dio 403');

    check('createDepartmentTask sin descripción -> 400',
      (await req('POST', `/department/task/${deptId}`, { token: tok.director, json: { deadline: '2026-12-31' } })).status === 400, 'no dio 400');

    console.log('\n-- LIST DEPARTMENT TASKS --');
    const lt = await req('GET', `/department/task/${deptId}/list`, { token: tok.manager });
    check('listDepartmentTasks (manager del propio depto)', lt.status === 200 && lt.body?.tasks?.some((t) => t.id === deptTaskId), `${lt.text.slice(0, 200)}`);

    check('SEGURIDAD: listDepartmentTasks de otro depto -> 403',
      (await req('GET', `/department/task/${otherDeptId}/list`, { token: tok.manager })).status === 403, 'no dio 403');

    console.log('\n-- ASSIGN (Manager reparte entre empleados) --');
    check('SEGURIDAD: assignDepartmentTask con un empleado ajeno al depto -> 400',
      (await req('POST', `/department/task/${deptTaskId}/assign`, { token: tok.manager, json: { emails: [emails.outsider] } })).status === 400, 'no dio 400');

    const asg = await req('POST', `/department/task/${deptTaskId}/assign`, {
      token: tok.manager, json: { emails: [emails.employeeA, emails.employeeB] },
    });
    check('assignDepartmentTask (manager, dos empleados)', asg.status === 200 && asg.body?.tasks?.length === 2, `${asg.text.slice(0, 300)}`);
    const [taskA, taskB] = asg.body?.tasks?.sort((a, b) => (a.assignedTo === emails.employeeA ? -1 : 1)) ?? [];
    check('la primera fila se reutiliza (mismo id que la tarea original)',
      asg.body?.tasks?.some((t) => t.id === deptTaskId), `${asg.text.slice(0, 300)}`);
    check('se clona una fila nueva para el segundo empleado (ids distintos)',
      taskA?.id !== taskB?.id, `${asg.text.slice(0, 300)}`);
    check('ambas filas quedan con assignedTo correcto',
      asg.body?.tasks?.some((t) => t.assignedTo === emails.employeeA) && asg.body?.tasks?.some((t) => t.assignedTo === emails.employeeB),
      `${asg.text.slice(0, 300)}`);

    console.log('\n-- NOTIFICACIONES: task_assigned --');
    const nfA = await req('GET', '/notifications', { token: tok.employeeA });
    check('employeeA recibe notificación task_assigned', nfA.body?.notifications?.some((n) => n.type === 'task_assigned'), `${nfA.text.slice(0, 200)}`);

    console.log('\n-- COMPLETE (Empleado) --');
    check('SEGURIDAD: completeDepartmentTask por alguien que no es el dueño -> 403',
      (await req('POST', `/department/task/${taskA.id}/complete`, { token: tok.employeeB })).status === 403, 'no dio 403');

    const comp = await req('POST', `/department/task/${taskA.id}/complete`, { token: tok.employeeA });
    check('completeDepartmentTask (employeeA)', comp.status === 200 && comp.body?.task?.status === 'done' && comp.body?.task?.completed === true,
      `${comp.text.slice(0, 200)}`);
    check('completeDepartmentTask deja progress=100', comp.body?.task?.progress === 100, `${comp.text.slice(0, 200)}`);

    console.log('\n-- NOTIFICACIONES: task_completed --');
    const nfManager = await req('GET', '/notifications', { token: tok.manager });
    check('el manager recibe notificación task_completed', nfManager.body?.notifications?.some((n) => n.type === 'task_completed'), `${nfManager.text.slice(0, 200)}`);

    console.log('\n-- APPROVE (Manager valida) --');
    check('SEGURIDAD: approveDepartmentTask antes de status=done -> 400',
      (await req('POST', `/department/task/${taskB.id}/approve`, { token: tok.manager })).status === 400, 'no dio 400');

    check('SEGURIDAD: approveDepartmentTask por alguien fuera del depto -> 403',
      (await req('POST', `/department/task/${taskA.id}/approve`, { token: tok.outsider })).status === 403, 'no dio 403');

    const apr = await req('POST', `/department/task/${taskA.id}/approve`, { token: tok.manager });
    check('approveDepartmentTask (manager)', apr.status === 200 && apr.body?.task?.status === 'approved', `${apr.text.slice(0, 200)}`);

    console.log('\n-- NOTIFICACIONES: task_approved --');
    const nfEmpA = await req('GET', '/notifications', { token: tok.employeeA });
    check('employeeA recibe notificación task_approved', nfEmpA.body?.notifications?.some((n) => n.type === 'task_approved'), `${nfEmpA.text.slice(0, 200)}`);

    console.log('\n-- STATS (Director / Manager) --');
    const statsDirector = await req('GET', '/department/stats', { token: tok.director });
    const rowDirector = statsDirector.body?.stats?.find((s) => s.departmentId === deptId);
    check('departmentTaskStats (director) incluye el departamento con total=2', statsDirector.status === 200 && rowDirector?.total === 2, `${statsDirector.text.slice(0, 300)}`);
    // taskA: completada y luego aprobada -> approved=1. taskB: nunca se
    // completó en este test -> se queda pending=1 (done=0).
    check('departmentTaskStats: 1 approved, 1 pending', rowDirector?.approved === 1 && rowDirector?.pending === 1 && rowDirector?.done === 0, `${JSON.stringify(rowDirector)}`);

    const statsManager = await req('GET', '/department/stats', { token: tok.manager });
    check('departmentTaskStats (manager) solo ve su propio departamento',
      statsManager.body?.stats?.length === 1 && statsManager.body?.stats?.[0]?.departmentId === deptId, `${statsManager.text.slice(0, 300)}`);

    check('SEGURIDAD: departmentTaskStats sin ser director/manager -> 403',
      (await req('GET', '/department/stats', { token: tok.employeeA })).status === 403, 'no dio 403');

    console.log('\n-- AISLAMIENTO: no rompe el flujo de tareas de equipo --');
    check('las tareas de departamento no traen team_code/domain_name en el payload',
      taskA.teamCode === undefined && taskA.domainName === undefined, `${JSON.stringify(taskA)}`);

  } catch (e) {
    fail++; failures.push('EXCEPCION: ' + e.stack); console.log('EXCEPCION:', e.stack);
  } finally {
    console.log('\n-- LIMPIEZA --');
    try {
      const c = await mysql.createConnection(DB);
      const list = Object.values(emails);
      const ph = list.map(() => '?').join(',');
      await c.query(`DELETE FROM tasks WHERE email IN (${ph})`, list);
      if (deptId) await c.query('DELETE FROM tasks WHERE department_id = ?', [deptId]);
      await c.query(`UPDATE users SET department_id = NULL WHERE email IN (${ph})`, list);
      if (deptId) await c.query('DELETE FROM departments WHERE id = ?', [deptId]);
      if (otherDeptId) await c.query('DELETE FROM departments WHERE id = ?', [otherDeptId]);
      if (companyName) await c.query('DELETE FROM companies WHERE name = ?', [companyName]);
      await c.query(`DELETE FROM notifications WHERE email IN (${ph})`, list);
      await c.query(`DELETE FROM users WHERE email IN (${ph})`, list);
      await c.end();
    } catch (e) { console.log('Limpieza fallo:', e.message); }
  }

  console.log(`\n===== RESULTADO: ${pass} PASS / ${fail} FAIL =====`);
  if (failures.length) { console.log('\nFALLOS:'); failures.forEach((f) => console.log(' - ' + f)); }
  process.exit(fail ? 1 : 0);
})();
