// Pruebas de integración del directorio de compañeros (GET /user/directory y
// GET /user/profile/{id}) contra el backend PHP real
// (C:\xampp\htdocs\App-radio\hive-backend).
//
// Requisitos: Apache y MySQL de XAMPP corriendo.
// Ejecutar:  node tools/php-backend-test-directory.js
//
// A diferencia de php-backend-test-org.js, este script no crea la empresa por
// HTTP (createCompany falla con 409 si ya existe, cosa habitual en una base de
// desarrollo): los departamentos de prueba y la asignación de usuarios se
// hacen directamente en MySQL, y por HTTP se ejercita solo lo que se está
// probando, que es de lectura. Todo lo creado va marcado con zz_dirit_ y se
// borra al terminar.

const mysql = require('mysql2/promise');

const BASE = process.env.HIVE_BASE_URL || 'http://127.0.0.1/hive-backend';
const DB = { host: '127.0.0.1', user: 'hive_user', password: 'HivePass_2026!', database: 'hive_db' };

const RUN = Date.now().toString(36);
const mk = (n) => `zz_dirit_${RUN}_${n}@test.invalid`;

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

const names = (page) => (page?.colleagues ?? []).map((c) => c.email);

// Ids de 24 hex, igual que generate_id() en el backend.
const newId = () => [...Array(24)].map(() => '0123456789abcdef'[Math.floor(Math.random() * 16)]).join('');

(async () => {
  const emails = {
    manager: mk('manager'),
    locutora: mk('locutora'),
    tecnico: mk('tecnico'),
    ventas: mk('ventas'),
    sinArea: mk('sinarea'),
  };
  const tok = {};
  const deptA = newId();   // área del manager, la locutora y el técnico
  const deptB = newId();   // otra área, con una sola persona
  let db, companyId, teamId;

  try {
    console.log('== Directorio de compañeros en ' + BASE + ' ==\n');
    db = await mysql.createConnection(DB);

    console.log('-- SETUP: usuarios --');
    for (const [who, email] of Object.entries(emails)) {
      const r = await req('POST', '/user/signup', { form: { name: `Dir ${who}`, email, password: 'Secreta123' } });
      check(`signup ${who}`, r.status === 200, `status=${r.status} ${r.text.slice(0, 100)}`);
      const l = await req('POST', '/user/login', { form: { email, password: 'Secreta123' } });
      tok[who] = l.body;
    }

    console.log('\n-- SETUP: departamentos (directo en MySQL) --');
    // Se cuelgan de la empresa existente si la hay; si no, de una de prueba.
    const [companies] = await db.query('SELECT id FROM companies ORDER BY created_at ASC LIMIT 1');
    if (companies.length) {
      companyId = companies[0].id;
    } else {
      companyId = newId();
      await db.query('INSERT INTO companies (id, name) VALUES (?, ?)', [companyId, `zz_dirit_${RUN} Radio`]);
    }
    await db.query('INSERT INTO departments (id, company_id, name, manager_email) VALUES (?, ?, ?, ?)',
      [deptA, companyId, `zz_dirit_${RUN} Cabina`, emails.manager]);
    await db.query('INSERT INTO departments (id, company_id, name) VALUES (?, ?, ?)',
      [deptB, companyId, `zz_dirit_${RUN} Ventas`]);

    await db.query("UPDATE users SET role = 'manager', department_id = ?, position = ? WHERE email = ?",
      [deptA, 'Jefa de Cabina', emails.manager]);
    await db.query('UPDATE users SET department_id = ?, position = ? WHERE email = ?',
      [deptA, 'Locutora matutina', emails.locutora]);
    await db.query('UPDATE users SET department_id = ?, position = ? WHERE email = ?',
      [deptA, 'Tecnico de audio', emails.tecnico]);
    await db.query('UPDATE users SET department_id = ?, position = ? WHERE email = ?',
      [deptB, 'Ejecutiva de cuentas', emails.ventas]);
    check('setup de departamentos', true, '');

    console.log('\n-- AUTENTICACION --');
    check('SEGURIDAD: /user/directory sin token -> 401',
      (await req('GET', '/user/directory')).status === 401, 'no dio 401');
    check('SEGURIDAD: /user/profile/{id} sin token -> 401',
      (await req('GET', '/user/profile/cualquiera')).status === 401, 'no dio 401');

    console.log('\n-- SCOPE POR DEFECTO: mi area --');
    const mine = await req('GET', '/user/directory', { token: tok.locutora });
    check('devuelve 200', mine.status === 200, `status=${mine.status} ${mine.text.slice(0, 150)}`);
    const mineEmails = names(mine.body);
    check('incluye a los companeros de mi area',
      mineEmails.includes(emails.manager) && mineEmails.includes(emails.tecnico), `${mineEmails.join(', ')}`);
    check('me incluye a mi mismo', mineEmails.includes(emails.locutora), `${mineEmails.join(', ')}`);
    check('NO incluye a gente de otra area', !mineEmails.includes(emails.ventas), `${mineEmails.join(', ')}`);
    check('myDepartmentId es el mio', mine.body?.myDepartmentId === deptA, `${mine.body?.myDepartmentId}`);
    check('trae la lista de areas para filtrar',
      (mine.body?.departments ?? []).some((d) => d.id === deptB), `${JSON.stringify(mine.body?.departments)?.slice(0, 200)}`);

    console.log('\n-- FORMA DEL PAYLOAD --');
    const me = (mine.body?.colleagues ?? []).find((c) => c.email === emails.locutora);
    check('trae nombre, rol, puesto y departamento',
      me?.name === 'Dir locutora' && me?.role === 'employee' && me?.position === 'Locutora matutina' && me?.department?.id === deptA,
      `${JSON.stringify(me)}`);
    check('el departamento trae employeeCount', me?.department?.employeeCount === 3, `${me?.department?.employeeCount}`);
    check('SEGURIDAD: no expone password, token ni otp',
      me && !('password' in me) && !('token' in me) && !('otp' in me) && !('otp_verified' in me),
      `${Object.keys(me ?? {}).join(', ')}`);

    console.log('\n-- ORDEN --');
    const areaOrder = mineEmails.filter((e) => Object.values(emails).includes(e));
    check('el responsable del area va primero', areaOrder[0] === emails.manager, `${areaOrder.join(', ')}`);

    console.log('\n-- BUSQUEDA --');
    const byName = await req('GET', '/user/directory?q=locutora', { token: tok.locutora });
    check('busca por nombre', names(byName.body).includes(emails.locutora) && !names(byName.body).includes(emails.tecnico),
      `${names(byName.body).join(', ')}`);

    const byPosition = await req('GET', '/user/directory?q=' + encodeURIComponent('Tecnico de audio'), { token: tok.locutora });
    check('busca por puesto', names(byPosition.body).length === 1 && names(byPosition.body)[0] === emails.tecnico,
      `${names(byPosition.body).join(', ')}`);

    const byEmail = await req('GET', '/user/directory?q=' + encodeURIComponent(emails.tecnico), { token: tok.locutora });
    check('busca por correo', names(byEmail.body).includes(emails.tecnico), `${names(byEmail.body).join(', ')}`);

    const noMatch = await req('GET', '/user/directory?q=zzz_nadie_se_llama_asi', { token: tok.locutora });
    check('sin coincidencias devuelve lista vacia', (noMatch.body?.colleagues ?? []).length === 0, `${noMatch.text.slice(0, 150)}`);

    const wildcard = await req('GET', '/user/directory?q=' + encodeURIComponent('%'), { token: tok.locutora });
    check('el comodin % se busca literal, no trae a todos',
      (wildcard.body?.colleagues ?? []).length === 0, `trajo ${(wildcard.body?.colleagues ?? []).length}`);

    console.log('\n-- OTROS AMBITOS --');
    const company = await req('GET', '/user/directory?scope=company', { token: tok.locutora });
    check('scope=company incluye otras areas', names(company.body).includes(emails.ventas), `${names(company.body).length} resultados`);

    const otherArea = await req('GET', `/user/directory?scope=${deptB}`, { token: tok.locutora });
    check('scope=<departamento> filtra por esa area',
      names(otherArea.body).includes(emails.ventas) && !names(otherArea.body).includes(emails.locutora),
      `${names(otherArea.body).join(', ')}`);

    const orphan = await req('GET', '/user/directory', { token: tok.sinArea });
    check('sin departamento asignado, el default cae a toda la empresa',
      names(orphan.body).includes(emails.ventas) && names(orphan.body).includes(emails.locutora),
      `${names(orphan.body).length} resultados`);
    check('sin departamento, myDepartmentId es null', orphan.body?.myDepartmentId === null, `${orphan.body?.myDepartmentId}`);

    console.log('\n-- FICHA DE UN COMPANERO --');
    const ct = await req('POST', '/team/createTeam', {
      token: tok.tecnico,
      json: { teamName: `zz_dirit_${RUN} Produccion`, domains: [{ name: 'Aire', members: [emails.locutora] }] },
    });
    check('setup: equipo de prueba creado', ct.status === 200, `status=${ct.status} ${ct.text.slice(0, 150)}`);
    const [teamRows] = await db.query('SELECT id FROM teams WHERE team_name = ?', [`zz_dirit_${RUN} Produccion`]);
    teamId = teamRows[0]?.id;

    const tecnicoId = (mine.body?.colleagues ?? []).find((c) => c.email === emails.tecnico)?.id;
    const ficha = await req('GET', `/user/profile/${tecnicoId}`, { token: tok.locutora });
    check('devuelve 200', ficha.status === 200, `status=${ficha.status} ${ficha.text.slice(0, 150)}`);
    check('trae el perfil publico',
      ficha.body?.email === emails.tecnico && ficha.body?.department?.id === deptA, `${ficha.text.slice(0, 200)}`);
    check('SEGURIDAD: la ficha no expone password ni token',
      ficha.body && !('password' in ficha.body) && !('token' in ficha.body), `${Object.keys(ficha.body ?? {}).join(', ')}`);
    check('trae los equipos con isLeader',
      (ficha.body?.teams ?? []).some((t) => t.teamName === `zz_dirit_${RUN} Produccion` && t.isLeader === true),
      `${JSON.stringify(ficha.body?.teams)}`);
    check('SEGURIDAD: los equipos no exponen el codigo para unirse',
      (ficha.body?.teams ?? []).every((t) => !('teamCode' in t)), `${JSON.stringify(ficha.body?.teams)}`);
    check('trae joinedAt', typeof ficha.body?.joinedAt === 'string' && ficha.body.joinedAt.length > 0, `${ficha.body?.joinedAt}`);

    const miembro = await req('GET', `/user/profile/${(mine.body?.colleagues ?? []).find((c) => c.email === emails.locutora)?.id}`,
      { token: tok.tecnico });
    check('quien solo es miembro sale con isLeader=false',
      (miembro.body?.teams ?? []).some((t) => t.teamName === `zz_dirit_${RUN} Produccion` && t.isLeader === false),
      `${JSON.stringify(miembro.body?.teams)}`);

    check('ficha de alguien inexistente -> 404',
      (await req('GET', '/user/profile/noexiste', { token: tok.locutora })).status === 404, 'no dio 404');

    console.log('\n-- NO SE ROMPIO /user/me --');
    const meEndpoint = await req('GET', '/user/me', { token: tok.manager });
    check('/user/me sigue devolviendo el perfil con departamento',
      meEndpoint.status === 200 && meEndpoint.body?.role === 'manager' && meEndpoint.body?.department?.id === deptA,
      `${meEndpoint.text.slice(0, 200)}`);

  } catch (e) {
    fail++; failures.push('EXCEPCION: ' + e.stack); console.log('EXCEPCION:', e.stack);
  } finally {
    console.log('\n-- LIMPIEZA --');
    try {
      if (!db) db = await mysql.createConnection(DB);
      const list = Object.values(emails);
      const ph = list.map(() => '?').join(',');
      if (teamId) {
        await db.query('DELETE FROM teams WHERE id = ?', [teamId]);
      }
      await db.query(`UPDATE users SET department_id = NULL WHERE email IN (${ph})`, list);
      await db.query('DELETE FROM departments WHERE id IN (?, ?)', [deptA, deptB]);
      await db.query('DELETE FROM companies WHERE name = ?', [`zz_dirit_${RUN} Radio`]);
      await db.query(`DELETE FROM notifications WHERE email IN (${ph})`, list);
      await db.query(`DELETE FROM users WHERE email IN (${ph})`, list);
      await db.end();
    } catch (e) { console.log('Limpieza fallo:', e.message); }
  }

  console.log(`\n===== RESULTADO: ${pass} PASS / ${fail} FAIL =====`);
  if (failures.length) { console.log('\nFALLOS:'); failures.forEach((f) => console.log(' - ' + f)); }
  process.exit(fail ? 1 : 0);
})();
