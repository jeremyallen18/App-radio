// Pruebas de integración de la estructura organizacional (companies,
// departments, roles) contra el backend PHP real (C:\xampp\htdocs\hive-backend).
//
// Requisitos: Apache y MySQL de XAMPP corriendo.
// Ejecutar:  node tools/php-backend-test-org.js
//
// Crea usuarios/empresa/departamentos marcados (zz_orgit_...) y los borra al
// terminar, así que no ensucia los datos reales de hive_db.

const path = require('path');
const mysql = require(path.join(__dirname, '..', 'backend', 'node_modules', 'mysql2', 'promise'));

const BASE = process.env.HIVE_BASE_URL || 'http://127.0.0.1/hive-backend';
const DB = { host: '127.0.0.1', user: 'hive_user', password: 'HivePass_2026!', database: 'hive_db' };

const RUN = Date.now().toString(36);
const mk = (n) => `zz_orgit_${RUN}_${n}@test.invalid`;

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
  const emails = { director: mk('director'), manager: mk('manager'), employee: mk('employee'), outsider: mk('outsider') };
  const tok = {};
  let companyName, deptId;

  try {
    console.log('== Estructura organizacional en ' + BASE + ' ==\n');

    console.log('-- SETUP: usuarios --');
    for (const [role, email] of Object.entries(emails)) {
      const r = await req('POST', '/user/signup', { form: { name: `Org ${role}`, email, password: 'Secreta123' } });
      check(`signup ${role}`, r.status === 200, `status=${r.status} ${r.text.slice(0, 100)}`);
      const l = await req('POST', '/user/login', { form: { email, password: 'Secreta123' } });
      tok[role] = l.body;
    }

    console.log('\n-- /user/me antes de tener rol --');
    const meDefault = await req('GET', '/user/me', { token: tok.employee });
    check('rol por defecto es employee', meDefault.body?.role === 'employee', `${meDefault.text}`);
    check('department es null antes de asignar', meDefault.body?.department === null, `${meDefault.text}`);

    console.log('\n-- COMPANY --');
    companyName = `Radio Doliv IT ${RUN}`;
    const cc = await req('POST', '/company/create', { token: tok.director, json: { name: companyName } });
    check('createCompany', cc.status === 200 && cc.body?.company?.name === companyName, `status=${cc.status} ${cc.text.slice(0, 150)}`);

    const meAfterCompany = await req('GET', '/user/me', { token: tok.director });
    check('el creador de la empresa queda como director', meAfterCompany.body?.role === 'director', `${meAfterCompany.text}`);

    const dupCompany = await req('POST', '/company/create', { token: tok.manager, json: { name: 'Otra' } });
    check('createCompany duplicada -> 409', dupCompany.status === 409, `status=${dupCompany.status}`);

    const info = await req('GET', '/company/info', { token: tok.employee });
    check('getCompany visible para cualquier autenticado', info.status === 200 && info.body?.company?.name === companyName, `${info.text.slice(0, 150)}`);

    const upd = await req('POST', '/company/update', { token: tok.director, json: { description: 'Radio local' } });
    check('updateCompany (director)', upd.status === 200 && upd.body?.company?.description === 'Radio local', `${upd.text.slice(0, 150)}`);

    check('SEGURIDAD: updateCompany sin ser director -> 403',
      (await req('POST', '/company/update', { token: tok.employee, json: { description: 'hack' } })).status === 403, 'no dio 403');

    console.log('\n-- DEPARTMENTS --');
    const cd = await req('POST', '/department/create', { token: tok.director, json: { name: 'Sistemas', description: 'IT' } });
    deptId = cd.body?.department?.id;
    check('createDepartment (director)', cd.status === 200 && !!deptId, `status=${cd.status} ${cd.text.slice(0, 150)}`);

    check('SEGURIDAD: createDepartment sin ser director -> 403',
      (await req('POST', '/department/create', { token: tok.employee, json: { name: 'Hackers' } })).status === 403, 'no dio 403');

    const dupDept = await req('POST', '/department/create', { token: tok.director, json: { name: 'Sistemas' } });
    check('createDepartment duplicado -> 409', dupDept.status === 409, `status=${dupDept.status}`);

    const list = await req('GET', '/department/list', { token: tok.employee });
    check('listDepartments incluye el nuevo departamento', list.body?.departments?.some((d) => d.id === deptId), `${list.text.slice(0, 200)}`);

    console.log('\n-- ASSIGN MANAGER --');
    const am = await req('POST', `/department/assignManager/${deptId}`, { token: tok.director, json: { email: emails.manager } });
    check('assignDepartmentManager (director)', am.status === 200 && am.body?.department?.managerEmail === emails.manager, `${am.text.slice(0, 200)}`);

    const meManager = await req('GET', '/user/me', { token: tok.manager });
    check('el manager queda con role=manager y su departamento', meManager.body?.role === 'manager' && meManager.body?.department?.id === deptId, `${meManager.text}`);

    check('SEGURIDAD: assignDepartmentManager sin ser director -> 403',
      (await req('POST', `/department/assignManager/${deptId}`, { token: tok.manager, json: { email: emails.employee } })).status === 403, 'no dio 403');

    check('assignDepartmentManager departamento inexistente -> 404',
      (await req('POST', '/department/assignManager/noexiste', { token: tok.director, json: { email: emails.employee } })).status === 404, 'no dio 404');

    console.log('\n-- ASSIGN EMPLOYEE --');
    const ae = await req('POST', `/department/assignEmployee/${deptId}`, { token: tok.manager, json: { email: emails.employee, position: 'Ingeniero de Software' } });
    check('assignDepartmentEmployee (manager del propio depto)', ae.status === 200 && ae.body?.department?.employeeCount >= 1, `${ae.text.slice(0, 200)}`);

    const meEmployee = await req('GET', '/user/me', { token: tok.employee });
    check('el empleado queda con su departamento y position',
      meEmployee.body?.department?.id === deptId && meEmployee.body?.position === 'Ingeniero de Software', `${meEmployee.text}`);
    check('el empleado sigue con role=employee (no se le sube el rol)', meEmployee.body?.role === 'employee', `${meEmployee.text}`);

    check('SEGURIDAD: assignDepartmentEmployee por un extraño a otro depto -> 403',
      (await req('POST', `/department/assignEmployee/${deptId}`, { token: tok.outsider, json: { email: emails.outsider } })).status === 403, 'no dio 403');

    check('SEGURIDAD: no se puede reasignar a un manager con assignEmployee -> 400',
      (await req('POST', `/department/assignEmployee/${deptId}`, { token: tok.director, json: { email: emails.manager } })).status === 400, 'no dio 400');

    check('SEGURIDAD: no se puede reasignar al director -> 400',
      (await req('POST', `/department/assignManager/${deptId}`, { token: tok.director, json: { email: emails.director } })).status === 400, 'no dio 400');

    console.log('\n-- NOTIFICACIONES --');
    const nfManager = await req('GET', '/notifications', { token: tok.manager });
    check('el nuevo manager recibe notificación', nfManager.body?.notifications?.some((n) => n.type === 'department_manager_assigned'), `${nfManager.text.slice(0, 200)}`);
    const nfEmployee = await req('GET', '/notifications', { token: tok.employee });
    check('el nuevo empleado recibe notificación', nfEmployee.body?.notifications?.some((n) => n.type === 'department_assigned'), `${nfEmployee.text.slice(0, 200)}`);

  } catch (e) {
    fail++; failures.push('EXCEPCION: ' + e.stack); console.log('EXCEPCION:', e.stack);
  } finally {
    console.log('\n-- LIMPIEZA --');
    try {
      const c = await mysql.createConnection(DB);
      const list = Object.values(emails);
      const ph = list.map(() => '?').join(',');
      await c.query(`UPDATE users SET department_id = NULL WHERE email IN (${ph})`, list);
      if (deptId) await c.query('DELETE FROM departments WHERE id = ?', [deptId]);
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
