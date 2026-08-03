// Pruebas de integración del backend PHP (C:\xampp\htdocs\hive-backend),
// que es el que sirve Apache y el que consume la app Flutter.
//
// Requisitos: Apache y MySQL de XAMPP corriendo.
// Ejecutar:  node tools/php-backend-test.js
//
// Crea usuarios/equipos con correos marcados (zz_phpit_...@test.invalid) y los
// borra al terminar, así que no ensucia los datos reales de hive_db.

const path = require('path');
const fs = require('fs');
const mysql = require(path.join(__dirname, '..', 'backend', 'node_modules', 'mysql2', 'promise'));

const UPLOAD_DIR = 'C:\\xampp\\htdocs\\hive-backend\\uploads';

const BASE = process.env.HIVE_BASE_URL || 'http://127.0.0.1/hive-backend';
const DB = { host: '127.0.0.1', user: 'hive_user', password: 'HivePass_2026!', database: 'hive_db' };

const RUN = Date.now().toString(36);
const mk = (n) => `zz_phpit_${RUN}_${n}@test.invalid`;

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
  const emails = { leader: mk('leader'), member: mk('member'), outsider: mk('outsider') };
  const tok = {};
  let teamId, teamCode, leaveId, notifId;

  const ping = await req('GET', '/');
  if (ping.status !== 200) {
    console.log(`No hay respuesta en ${BASE} (status=${ping.status}). ¿Está Apache de XAMPP corriendo?`);
    process.exit(1);
  }
  console.log(`== Backend PHP en ${BASE} ==\n`);

  try {
    console.log('-- AUTH --');
    for (const [role, email] of Object.entries(emails)) {
      const r = await req('POST', '/user/signup', { form: { name: `IT ${role}`, email, password: 'Secreta123' } });
      check(`signup ${role}`, r.status === 200, `status=${r.status} ${r.text.slice(0, 100)}`);
    }
    const dupe = await req('POST', '/user/signup', { form: { name: 'x', email: emails.leader, password: 'Secreta123' } });
    check('signup duplicado -> 409', dupe.status === 409, `status=${dupe.status}`);

    const incomplete = await req('POST', '/user/signup', { form: { email: 'x@y.z' } });
    check('signup incompleto -> 400', incomplete.status === 400, `status=${incomplete.status}`);

    for (const [role, email] of Object.entries(emails)) {
      const r = await req('POST', '/user/login', { form: { email, password: 'Secreta123' } });
      check(`login ${role}`, r.status === 200 && typeof r.body === 'string' && r.body.length >= 32,
        `status=${r.status} ${r.text.slice(0, 100)}`);
      tok[role] = r.body;
    }

    const badLogin = await req('POST', '/user/login', { form: { email: emails.leader, password: 'incorrecta' } });
    check('login con password incorrecta -> 401', badLogin.status === 401, `status=${badLogin.status}`);

    check('endpoint protegido sin token -> 401', (await req('GET', '/user/sendName')).status === 401, 'no dio 401');
    check('endpoint protegido con token basura -> 401',
      (await req('GET', '/user/sendName', { token: 'tokenfalso' })).status === 401, 'no dio 401');

    const nm = await req('GET', '/user/sendName', { token: tok.leader });
    check('sendName devuelve el nombre', nm.status === 200 && nm.body === 'IT leader', `body=${nm.text.slice(0, 60)}`);

    console.log('\n-- EQUIPOS --');
    const ct = await req('POST', '/team/createTeam', {
      token: tok.leader, json: { teamName: 'Equipo IT PHP', domains: [{ name: 'Backend', members: [] }, { name: 'Machine Learning', members: [] }] },
    });
    teamId = ct.body?.team?._id; teamCode = ct.body?.team?.teamCode;
    check('createTeam', ct.status === 200 && !!teamId && !!teamCode, `status=${ct.status} ${ct.text.slice(0, 150)}`);

    check('createTeam sin teamName -> 400',
      (await req('POST', '/team/createTeam', { token: tok.leader, json: { domains: [] } })).status === 400, 'no dio 400');

    check('joinTeam con codigo valido',
      (await req('POST', '/team/joinTeam', { token: tok.member, json: { teamCode } })).status === 200, 'no dio 200');
    check('joinTeam con codigo invalido -> 404',
      (await req('POST', '/team/joinTeam', { token: tok.member, json: { teamCode: 'NOEXISTE' } })).status === 404, 'no dio 404');

    const shL = await req('GET', '/team/showTeams', { token: tok.leader });
    check('showTeams para el lider', shL.status === 200 && shL.body?.teams?.some((t) => t._id === teamId), `${shL.text.slice(0, 150)}`);
    check('showTeams incluye el email propio', shL.body?.email === emails.leader, `email=${shL.body?.email}`);

    const tL = shL.body?.teams?.find((t) => t._id === teamId);
    check('showTeams devuelve las areas anidadas (teamDetail.dart las necesita)',
      Array.isArray(tL?.domains) && tL.domains.length === 2 && tL.domains.some((d) => d.name === 'Machine Learning'),
      `domains=${JSON.stringify(tL?.domains?.map((d) => d.name))}`);
    check('cada area trae members[] y tasks[]',
      tL?.domains?.every((d) => Array.isArray(d.members) && Array.isArray(d.tasks)), `${JSON.stringify(tL?.domains?.[0])}`);
    check('createTeam tambien devuelve las areas', Array.isArray(ct.body?.team?.domains) && ct.body.team.domains.length === 2,
      `domains=${JSON.stringify(ct.body?.team?.domains)}`);

    const shM = await req('GET', '/team/showTeams', { token: tok.member });
    check('showTeams para el miembro', shM.body?.teams?.some((t) => t._id === teamId), 'el miembro no ve el equipo');

    const shO = await req('GET', '/team/showTeams', { token: tok.outsider });
    check('showTeams no expone equipos ajenos', !shO.body?.teams?.some((t) => t._id === teamId), 'el extraño ve el equipo');

    const inv = await req('POST', `/team/sendTeamcode/${teamId}/${encodeURIComponent('Machine Learning')}`, {
      token: tok.leader, json: { recipients: [emails.member] },
    });
    check('sendTeamcode (area con espacio)', inv.status === 200 && inv.body?.success === true, `status=${inv.status} ${inv.text.slice(0, 120)}`);

    // el nombre del area viaja url-encoded; no debe guardarse como "Machine%20Learning"
    const cDom = await mysql.createConnection(DB);
    const [doms] = await cDom.query('SELECT name FROM domains WHERE team_id = ?', [teamId]);
    await cDom.end();
    const names = doms.map((d) => d.name);
    check('el area con espacio no se duplica url-encoded',
      names.filter((n) => n === 'Machine Learning').length === 1 && !names.some((n) => n.includes('%20')),
      `areas en la BD = ${JSON.stringify(names)}`);

    check('SEGURIDAD: extraño no puede invitar -> 403',
      (await req('POST', `/team/sendTeamcode/${teamId}/Backend`, { token: tok.outsider, json: { recipients: [emails.member] } })).status === 403,
      'no dio 403');

    console.log('\n-- TAREAS --');
    const tk = await req('POST', `/team/task/${teamCode}`, {
      token: tok.leader, form: { domainName: 'Machine Learning', email: emails.member, task: 'Tarea PHP', deadline: '2026-12-31' },
    });
    check('crear tarea', tk.status === 200, `status=${tk.status} ${tk.text.slice(0, 120)}`);

    check('SEGURIDAD: extraño no crea tareas -> 403',
      (await req('POST', `/team/task/${teamCode}`, { token: tok.outsider, form: { domainName: 'Backend', email: emails.member, task: 'hack', deadline: '2026-12-31' } })).status === 403,
      'no dio 403');

    const inc = await req('GET', '/team/incompleteTasks', { token: tok.member });
    check('incompleteTasks lista la tarea', inc.status === 200 && inc.body?.incompleteTasks?.some((t) => t.description === 'Tarea PHP'),
      `${inc.text.slice(0, 180)}`);

    // la lista de tareas necesita teamCode + domainName para poder completarlas
    const pend = inc.body?.incompleteTasks?.find((t) => t.description === 'Tarea PHP');
    check('incompleteTasks trae teamCode/domainName/teamName',
      pend?.teamCode === teamCode && pend?.domainName === 'Machine Learning' && pend?.teamName === 'Equipo IT PHP',
      `tarea=${JSON.stringify(pend)}`);

    check('taskDone marca la tarea',
      (await req('POST', '/team/taskDone', { token: tok.member, form: { teamCode, domainName: 'Machine Learning', email: emails.member, task: 'Tarea PHP' } })).status === 200,
      'no dio 200');
    check('taskDone repetido -> 404',
      (await req('POST', '/team/taskDone', { token: tok.member, form: { teamCode, domainName: 'Machine Learning', email: emails.member, task: 'Tarea PHP' } })).status === 404,
      'no dio 404');

    const comp = await req('GET', '/team/completedTasks', { token: tok.member });
    check('completedTasks lista la tarea hecha', comp.body?.completedTasks?.some((t) => t.description === 'Tarea PHP'), `${comp.text.slice(0, 180)}`);

    // teamDetail.dart cuenta pendientes con `t['completed'] == false`, así que
    // completed tiene que llegar como booleano, no como 0/1.
    const shT = await req('GET', '/team/showTeams', { token: tok.member });
    const dom = shT.body?.teams?.find((t) => t._id === teamId)?.domains?.find((d) => d.name === 'Machine Learning');
    const tsk = dom?.tasks?.find((t) => t.description === 'Tarea PHP');
    check('la tarea aparece anidada en su area', !!tsk, `tasks=${JSON.stringify(dom?.tasks)}`);
    check('completed llega como booleano (no 0/1)', typeof tsk?.completed === 'boolean' && tsk.completed === true,
      `completed=${JSON.stringify(tsk?.completed)} (tipo ${typeof tsk?.completed})`);
    check('la tarea trae assignedTo y deadline', tsk?.assignedTo === emails.member && tsk?.deadline === '2026-12-31',
      `assignedTo=${tsk?.assignedTo} deadline=${tsk?.deadline}`);

    check('SEGURIDAD: extraño no cierra tareas -> 403',
      (await req('POST', '/team/taskDone', { token: tok.outsider, form: { teamCode, domainName: 'Backend', email: emails.member, task: 'x' } })).status === 403,
      'no dio 403');

    console.log('\n-- RECURSOS --');
    const at = await req('POST', `/text/addText/${teamId}`, { token: tok.member, json: { text: 'Nota PHP' } });
    check('addText (201)', at.status === 201, `status=${at.status} ${at.text.slice(0, 120)}`);

    const st = await req('GET', `/text/showText/${teamId}`, { token: tok.member });
    check('showText agrupa por email y usa {text:...}',
      st.status === 200 && st.body?.data?.some((d) => d.email === emails.member && d.texts?.some((x) => x.text === 'Nota PHP')),
      `${st.text.slice(0, 200)}`);

    check('SEGURIDAD: showText sin token -> 401', (await req('GET', `/text/showText/${teamId}`)).status === 401, 'no dio 401');
    check('SEGURIDAD: extraño no lee textos -> 403',
      (await req('GET', `/text/showText/${teamId}`, { token: tok.outsider })).status === 403, 'no dio 403');
    check('SEGURIDAD: extraño no escribe textos -> 403',
      (await req('POST', `/text/addText/${teamId}`, { token: tok.outsider, json: { text: 'hack' } })).status === 403, 'no dio 403');

    // imagen real (1x1 PNG) porque el backend valida con getimagesize()
    const png = Buffer.from('89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000a49444154789c6300010000050001' +
      '0d0a2db40000000049454e44ae426082', 'hex');
    const fd = new FormData();
    fd.append('imgName', 'prueba'); fd.append('teamId', String(teamId));
    fd.append('photo', new Blob([png], { type: 'image/png' }), 'prueba.png');
    const up = await fetch(`${BASE}/image/addImage`, { method: 'POST', headers: { Authorization: tok.member }, body: fd });
    check('addImage (multipart)', up.status === 200, `status=${up.status} ${(await up.text()).slice(0, 150)}`);

    const si = await req('GET', `/image/showImage/${teamId}`, { token: tok.member });
    check('showImage devuelve array plano', si.status === 200 && Array.isArray(si.body) && si.body.some((i) => i.imgName === 'prueba'),
      `${si.text.slice(0, 180)}`);
    check('SEGURIDAD: extraño no ve imagenes -> 403',
      (await req('GET', `/image/showImage/${teamId}`, { token: tok.outsider })).status === 403, 'no dio 403');

    const fd2 = new FormData();
    fd2.append('imgName', 'hack'); fd2.append('teamId', String(teamId));
    fd2.append('photo', new Blob([png], { type: 'image/png' }), 'h.png');
    const up2 = await fetch(`${BASE}/image/addImage`, { method: 'POST', headers: { Authorization: tok.outsider }, body: fd2 });
    check('SEGURIDAD: extraño no sube imagenes -> 403', up2.status === 403, `status=${up2.status}`);

    console.log('\n-- CHAT --');
    check('SEGURIDAD: chat sin token -> 401', (await req('GET', '/chat/getAllChats')).status === 401, 'no dio 401');
    check('sendMessage', (await req('POST', '/chat/sendMessage', { token: tok.member, form: { message: 'hola phpit' } })).status === 200, 'no dio 200');

    const ch = await req('GET', '/chat/getAllChats', { token: tok.member });
    const mine = ch.body?.chats?.filter((c) => c.message === 'hola phpit');
    check('getAllChats incluye el mensaje', mine?.length >= 1, `${ch.text.slice(0, 150)}`);
    check('SEGURIDAD: el username sale del token', mine?.[0]?.username === emails.member, `username=${mine?.[0]?.username}`);

    await req('POST', '/chat/sendMessage', { token: tok.member, form: { username: 'jefe@suplantado.com', message: 'phpit-suplantacion' } });
    const ch2 = await req('GET', '/chat/getAllChats', { token: tok.member });
    const sp = ch2.body?.chats?.find((c) => c.message === 'phpit-suplantacion');
    check('SEGURIDAD: el username del body se ignora', sp?.username === emails.member, `username guardado=${sp?.username}`);

    console.log('\n-- PERMISOS --');
    const lv = await req('POST', `/leave/applyLeave/${teamId}`, {
      token: tok.member, json: { leaves: [{ startDate: '2026-09-01', endDate: '2026-09-05', reason: 'Vacaciones' }] },
    });
    leaveId = lv.body?._id;
    check('applyLeave', lv.status === 200 && !!leaveId, `status=${lv.status} ${lv.text.slice(0, 150)}`);
    check('leaveResult (dueño)', (await req('POST', `/leave/leaveResult/${leaveId}`, { token: tok.member })).status === 200, 'no dio 200');
    check('leaveResult (lider del equipo)', (await req('POST', `/leave/leaveResult/${leaveId}`, { token: tok.leader })).status === 200, 'no dio 200');
    check('SEGURIDAD: extraño no consulta permisos ajenos -> 403',
      (await req('POST', `/leave/leaveResult/${leaveId}`, { token: tok.outsider })).status === 403, 'no dio 403');
    check('SEGURIDAD: extraño no pide permiso en equipo ajeno -> 403',
      (await req('POST', `/leave/applyLeave/${teamId}`, { token: tok.outsider, json: { leaves: [{ startDate: '2026-09-01', endDate: '2026-09-05', reason: 'x' }] } })).status === 403,
      'no dio 403');

    console.log('\n-- MENSAJE AL LIDER --');
    check('sendMessage al lider (campo "Correo")',
      (await req('POST', `/user/sendMessage/${teamId}`, { token: tok.member, json: { Correo: emails.member, message: 'Necesito ayuda' } })).status === 200,
      'no dio 200');
    check('SEGURIDAD: extraño no escribe al lider ajeno -> 403',
      (await req('POST', `/user/sendMessage/${teamId}`, { token: tok.outsider, json: { Correo: 'x', message: 'ajeno' } })).status === 403, 'no dio 403');

    console.log('\n-- RESET DE CONTRASENA --');
    check('resetPassword genera OTP', (await req('POST', '/user/resetPassword', { form: { email: emails.outsider } })).status === 200, 'no dio 200');
    check('resetPassword con correo inexistente -> 404',
      (await req('POST', '/user/resetPassword', { form: { email: 'nadie@test.invalid' } })).status === 404, 'no dio 404');

    const c1 = await mysql.createConnection(DB);
    const [[otpRow]] = await c1.query('SELECT otp FROM users WHERE email = ?', [emails.outsider]);
    await c1.end();

    check('verifyOTP con codigo incorrecto -> 400',
      (await req('POST', `/user/verifyOTP/${encodeURIComponent(emails.outsider)}`, { json: { OTP: '000000' } })).status === 400, 'no dio 400');
    check('verifyOTP con codigo correcto',
      (await req('POST', `/user/verifyOTP/${encodeURIComponent(emails.outsider)}`, { json: { OTP: otpRow.otp } })).status === 200, 'no dio 200');
    check('newPassword con contrasenas distintas -> 400',
      (await req('POST', `/user/newPassword/${encodeURIComponent(emails.outsider)}`, { json: { newPassword: 'Nueva123', confirmPassword: 'Otra123' } })).status === 400,
      'no dio 400');
    check('newPassword actualiza',
      (await req('POST', `/user/newPassword/${encodeURIComponent(emails.outsider)}`, { json: { newPassword: 'Nueva123', confirmPassword: 'Nueva123' } })).status === 200,
      'no dio 200');
    check('el OTP queda invalidado tras usarlo',
      (await req('POST', `/user/verifyOTP/${encodeURIComponent(emails.outsider)}`, { json: { OTP: otpRow.otp } })).status === 400, 'el OTP sigue sirviendo');

    const ln = await req('POST', '/user/login', { form: { email: emails.outsider, password: 'Nueva123' } });
    check('login con la contrasena nueva', ln.status === 200, `status=${ln.status}`);
    if (ln.status === 200) tok.outsider = ln.body;
    check('la contrasena vieja ya no sirve',
      (await req('POST', '/user/login', { form: { email: emails.outsider, password: 'Secreta123' } })).status === 401, 'la vieja sigue sirviendo');

    console.log('\n-- NOTIFICACIONES --');
    const nf0 = await req('GET', '/notifications', { token: tok.leader });
    check('GET /notifications responde', nf0.status === 200 && Array.isArray(nf0.body?.notifications), `${nf0.text.slice(0, 150)}`);
    check('SEGURIDAD: /notifications sin token -> 401', (await req('GET', '/notifications')).status === 401, 'no dio 401');

    check('SEGURIDAD: extraño no elimina miembros -> 403',
      (await req('POST', `/team/deleteMember/${teamId}`, { token: tok.outsider, form: { memberEmail: emails.member } })).status === 403, 'no dio 403');
    check('SEGURIDAD: un miembro normal no elimina miembros -> 403',
      (await req('POST', `/team/deleteMember/${teamId}`, { token: tok.member, form: { memberEmail: emails.member } })).status === 403, 'no dio 403');

    check('el lider elimina a un miembro',
      (await req('POST', `/team/deleteMember/${teamId}`, { token: tok.leader, form: { memberEmail: emails.member } })).status === 200, 'no dio 200');

    const nf = await req('GET', '/notifications', { token: tok.member });
    const removed = nf.body?.notifications?.find((n) => n.type === 'member_removed');
    check('el miembro eliminado recibe notificacion in-app', !!removed, `${nf.text.slice(0, 250)}`);
    check('la notificacion arranca sin leer', removed && removed.readAt === null, `readAt=${removed?.readAt}`);
    notifId = removed?.id;

    if (notifId) {
      check('SEGURIDAD: no puedo marcar leida una notificacion ajena -> 404',
        (await req('POST', `/notifications/${notifId}/read`, { token: tok.leader })).status === 404, 'no dio 404');
      check('marcar notificacion como leida',
        (await req('POST', `/notifications/${notifId}/read`, { token: tok.member })).status === 200, 'no dio 200');
      const nf2 = await req('GET', '/notifications', { token: tok.member });
      check('la notificacion queda marcada como leida',
        nf2.body?.notifications?.find((n) => n.id === notifId)?.readAt !== null, 'readAt sigue null');
    }

    // el miembro tiene que volver al equipo para poder ser lider
    await req('POST', '/team/joinTeam', { token: tok.member, json: { teamCode } });

    check('SEGURIDAD: extraño no reasigna el liderazgo -> 403',
      (await req('POST', `/team/leaderResign/${teamId}`, { token: tok.outsider, form: { Correo: emails.outsider } })).status === 403, 'no dio 403');

    const rs = await req('POST', `/team/leaderResign/${teamId}`, { token: tok.leader, form: { Correo: emails.member } });
    check('leaderResign con "Correo" (lo que manda LResign.dart)', rs.status === 200, `status=${rs.status} "${rs.text.slice(0, 90)}"`);

    const nf3 = await req('GET', '/notifications', { token: tok.member });
    check('el nuevo lider recibe notificacion', nf3.body?.notifications?.some((n) => n.type === 'leader_assigned'), `${nf3.text.slice(0, 250)}`);

    const sh2 = await req('GET', '/team/showTeams', { token: tok.member });
    check('el equipo refleja el nuevo lider',
      sh2.body?.teams?.find((t) => t._id === teamId)?.leaderEmail === emails.member,
      `leaderEmail=${sh2.body?.teams?.find((t) => t._id === teamId)?.leaderEmail}`);

    console.log('\n-- ELIMINAR EQUIPO --');
    // tras el leaderResign el líder es "member"; "leader" quedó como miembro normal
    check('SEGURIDAD: extraño no puede eliminar el equipo -> 403',
      (await req('POST', `/team/deleteTeam/${teamId}`, { token: tok.outsider })).status === 403, 'no dio 403');
    check('SEGURIDAD: un miembro normal no puede eliminar el equipo -> 403',
      (await req('POST', `/team/deleteTeam/${teamId}`, { token: tok.leader })).status === 403, 'no dio 403');

    const cBefore = await mysql.createConnection(DB);
    const [[{ n: domsBefore }]] = await cBefore.query('SELECT COUNT(*) n FROM domains WHERE team_id = ?', [teamId]);
    await cBefore.end();
    check('el equipo tiene areas antes de borrarlo', domsBefore > 0, `domains=${domsBefore}`);

    const dt = await req('POST', `/team/deleteTeam/${teamId}`, { token: tok.member });
    check('el lider elimina el equipo', dt.status === 200, `status=${dt.status} "${dt.text.slice(0, 80)}"`);

    const shDel = await req('GET', '/team/showTeams', { token: tok.member });
    check('el equipo desaparece de showTeams', !shDel.body?.teams?.some((t) => t._id === teamId),
      `sigue apareciendo`);

    const cAfter = await mysql.createConnection(DB);
    const [[{ n: teamRows }]] = await cAfter.query('SELECT COUNT(*) n FROM teams WHERE id = ?', [teamId]);
    const [[{ n: domRows }]] = await cAfter.query('SELECT COUNT(*) n FROM domains WHERE team_id = ?', [teamId]);
    const [[{ n: memRows }]] = await cAfter.query('SELECT COUNT(*) n FROM team_members WHERE team_id = ?', [teamId]);
    const [[{ n: txtRows }]] = await cAfter.query('SELECT COUNT(*) n FROM texts WHERE team_id = ?', [teamId]);
    const [[{ n: imgRows }]] = await cAfter.query('SELECT COUNT(*) n FROM images WHERE team_id = ?', [teamId]);
    const [[{ n: taskRows }]] = await cAfter.query('SELECT COUNT(*) n FROM tasks WHERE team_code = ?', [teamCode]);
    await cAfter.end();
    check('se borran equipo, areas, miembros, textos, imagenes y tareas',
      teamRows === 0 && domRows === 0 && memRows === 0 && txtRows === 0 && imgRows === 0 && taskRows === 0,
      `teams=${teamRows} domains=${domRows} members=${memRows} texts=${txtRows} images=${imgRows} tasks=${taskRows}`);

    const nfDel = await req('GET', '/notifications', { token: tok.leader });
    check('los miembros reciben aviso de que el equipo fue eliminado',
      nfDel.body?.notifications?.some((n) => n.type === 'team_deleted'), `${nfDel.text.slice(0, 250)}`);

    check('eliminar un equipo inexistente -> 403',
      (await req('POST', `/team/deleteTeam/${teamId}`, { token: tok.member })).status === 403, 'no dio 403');

  } catch (e) {
    fail++; failures.push('EXCEPCION: ' + e.stack); console.log('EXCEPCION:', e.stack);
  } finally {
    console.log('\n-- LIMPIEZA --');
    try {
      const c = await mysql.createConnection(DB);
      const list = Object.values(emails);
      const ph = list.map(() => '?').join(',');
      const [teams] = await c.query(`SELECT id FROM teams WHERE leader_email IN (${ph})`, list);
      const tids = teams.map((t) => t.id);
      if (tids.length) {
        const tp = tids.map(() => '?').join(',');
        // los archivos subidos hay que borrarlos del disco además de la tabla
        const [imgs] = await c.query(`SELECT img_path FROM images WHERE team_id IN (${tp})`, tids);
        for (const { img_path: p } of imgs) {
          const f = path.join(UPLOAD_DIR, path.basename(p));
          if (fs.existsSync(f)) { try { fs.unlinkSync(f); } catch (_) {} }
        }
        await c.query(`DELETE dm FROM domain_members dm JOIN domains d ON d.id=dm.domain_id WHERE d.team_id IN (${tp})`, tids);
        await c.query(`DELETE FROM domains WHERE team_id IN (${tp})`, tids);
        await c.query(`DELETE FROM team_members WHERE team_id IN (${tp})`, tids);
        await c.query(`DELETE FROM texts WHERE team_id IN (${tp})`, tids);
        await c.query(`DELETE FROM images WHERE team_id IN (${tp})`, tids);
        await c.query(`DELETE FROM leaves WHERE team_id IN (${tp})`, tids);
        await c.query(`DELETE FROM leader_messages WHERE team_id IN (${tp})`, tids);
        await c.query(`DELETE FROM notifications WHERE team_id IN (${tp})`, tids);
        await c.query(`DELETE FROM tasks WHERE team_code IN (SELECT team_code FROM teams WHERE id IN (${tp}))`, tids);
        await c.query(`DELETE FROM teams WHERE id IN (${tp})`, tids);
      }
      await c.query(`DELETE FROM team_members WHERE email IN (${ph})`, list);
      await c.query(`DELETE FROM texts WHERE email IN (${ph})`, list);
      await c.query(`DELETE FROM leaves WHERE email IN (${ph})`, list);
      await c.query(`DELETE FROM notifications WHERE email IN (${ph})`, list);
      await c.query(`DELETE FROM tasks WHERE email IN (${ph})`, list);
      await c.query(`DELETE FROM chat_messages WHERE username IN (${ph})`, list);
      await c.query(`DELETE FROM users WHERE email IN (${ph})`, list);
      const [[left]] = await c.query(`SELECT COUNT(*) n FROM users WHERE email IN (${ph})`, list);
      console.log('Usuarios de prueba restantes:', left.n);
      await c.end();
    } catch (e) { console.log('Limpieza fallo:', e.message); }
  }

  console.log(`\n===== RESULTADO: ${pass} PASS / ${fail} FAIL =====`);
  if (failures.length) { console.log('\nFALLOS:'); failures.forEach((f) => console.log(' - ' + f)); }
  process.exit(fail ? 1 : 0);
})();
