// Pruebas de integración: levanta el servidor Express real contra la base de
// datos real, recorre todos los endpoints por HTTP y al terminar borra
// únicamente las filas que creó. Ejecutar con: npm test
const { spawn } = require('child_process');
const path = require('path');

const BACKEND = path.join(__dirname, '..');
require('dotenv').config({ path: path.join(BACKEND, '.env') });
const mysql = require('mysql2/promise');

const PORT = 8099;
const BASE = `http://127.0.0.1:${PORT}/hive-backend`;
const RUN = Date.now().toString(36);
const mk = (n) => `zz_itest_${RUN}_${n}@test.invalid`;

let pass = 0, fail = 0;
const failures = [];
function check(name, cond, detail) {
  if (cond) { pass++; console.log(`  PASS  ${name}`); }
  else { fail++; failures.push(`${name} :: ${detail}`); console.log(`  FAIL  ${name}  -> ${detail}`); }
}

async function req(method, urlPath, { token, json, form, raw } = {}) {
  const headers = {};
  if (token) headers['Authorization'] = token;
  let body;
  if (json !== undefined) { headers['Content-Type'] = 'application/json'; body = JSON.stringify(json); }
  else if (form) { headers['Content-Type'] = 'application/x-www-form-urlencoded'; body = new URLSearchParams(form).toString(); }
  else if (raw) { body = raw; }
  const res = await fetch(`${BASE}${urlPath}`, { method, headers, body, redirect: 'manual' });
  const text = await res.text();
  let parsed = null;
  try { parsed = JSON.parse(text); } catch (_) {}
  return { status: res.status, body: parsed, text };
}

async function waitForServer(proc) {
  for (let i = 0; i < 60; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${PORT}/`);
      if (r.ok) return true;
    } catch (_) {}
    if (proc.exitCode !== null) return false;
    await new Promise((r) => setTimeout(r, 500));
  }
  return false;
}

(async () => {
  console.log('== Arrancando backend en puerto', PORT, '==');
  const proc = spawn(process.execPath, ['src/index.js'], {
    cwd: BACKEND,
    env: { ...process.env, PORT: String(PORT), BASE_PATH: '/hive-backend' },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let serverLog = '';
  proc.stdout.on('data', (d) => { serverLog += d; });
  proc.stderr.on('data', (d) => { serverLog += d; });

  const up = await waitForServer(proc);
  if (!up) {
    console.log('EL SERVIDOR NO ARRANCO. Log:\n' + serverLog);
    proc.kill();
    process.exit(1);
  }
  console.log('Servidor arriba.\n');

  const emails = { leader: mk('leader'), member: mk('member'), outsider: mk('outsider') };
  const tok = {};
  let teamId, teamCode, leaveId, notifId;

  try {
    // ---------------- AUTH ----------------
    console.log('-- AUTH --');
    for (const [role, email] of Object.entries(emails)) {
      const r = await req('POST', '/user/signup', { form: { name: `IT ${role}`, email, password: 'Secreta123' } });
      check(`signup ${role}`, r.status === 200, `status=${r.status} body=${r.text.slice(0, 120)}`);
    }
    const dupe = await req('POST', '/user/signup', { form: { name: 'dup', email: emails.leader, password: 'Secreta123' } });
    check('signup duplicado rechazado (409)', dupe.status === 409, `status=${dupe.status}`);

    const badSignup = await req('POST', '/user/signup', { form: { email: 'x@y.z' } });
    check('signup sin campos rechazado (400)', badSignup.status === 400, `status=${badSignup.status}`);

    for (const [role, email] of Object.entries(emails)) {
      const r = await req('POST', '/user/login', { form: { email, password: 'Secreta123' } });
      check(`login ${role}`, r.status === 200 && typeof r.body === 'string' && r.body.length > 20,
        `status=${r.status} body=${r.text.slice(0, 120)}`);
      tok[role] = r.body;
    }

    const badLogin = await req('POST', '/user/login', { form: { email: emails.leader, password: 'malaPass' } });
    check('login con password incorrecta rechazado', badLogin.status === 401, `status=${badLogin.status}`);

    const noAuth = await req('GET', '/user/sendName');
    check('endpoint protegido sin token -> 401', noAuth.status === 401, `status=${noAuth.status}`);

    const badTok = await req('GET', '/user/sendName', { token: 'no.es.un.jwt' });
    check('endpoint protegido con token invalido -> 401', badTok.status === 401, `status=${badTok.status}`);

    const name = await req('GET', '/user/sendName', { token: tok.leader });
    check('sendName devuelve el nombre', name.status === 200 && name.body === 'IT leader',
      `status=${name.status} body=${name.text.slice(0, 80)}`);

    // ---------------- TEAMS ----------------
    console.log('\n-- EQUIPOS --');
    const created = await req('POST', '/team/createTeam', {
      token: tok.leader,
      json: { teamName: 'Equipo IT', domains: [{ name: 'Backend', members: [] }, { name: 'Machine Learning', members: [] }] },
    });
    check('createTeam', created.status === 200 && created.body?.team?._id,
      `status=${created.status} body=${created.text.slice(0, 200)}`);
    teamId = created.body?.team?._id;
    teamCode = created.body?.team?.teamCode;
    check('createTeam devuelve teamCode', !!teamCode, `teamCode=${teamCode}`);
    check('createTeam devuelve las areas', created.body?.team?.domains?.length === 2,
      `domains=${JSON.stringify(created.body?.team?.domains?.map((d) => d.name))}`);

    const noName = await req('POST', '/team/createTeam', { token: tok.leader, json: { domains: [] } });
    check('createTeam sin teamName -> 400', noName.status === 400, `status=${noName.status}`);

    const joined = await req('POST', '/team/joinTeam', { token: tok.member, json: { teamCode } });
    check('joinTeam con codigo valido', joined.status === 200, `status=${joined.status} body=${joined.text.slice(0, 120)}`);

    const badJoin = await req('POST', '/team/joinTeam', { token: tok.member, json: { teamCode: 'NOEXISTE' } });
    check('joinTeam con codigo invalido -> 404', badJoin.status === 404, `status=${badJoin.status}`);

    const show = await req('GET', '/team/showTeams', { token: tok.leader });
    check('showTeams para el lider', show.status === 200 && show.body?.teams?.some((t) => t._id === teamId),
      `status=${show.status}`);
    check('showTeams incluye el email propio', show.body?.email === emails.leader, `email=${show.body?.email}`);

    const showMember = await req('GET', '/team/showTeams', { token: tok.member });
    check('showTeams para el miembro que se unio', showMember.body?.teams?.some((t) => t._id === teamId),
      `teams=${JSON.stringify(showMember.body?.teams?.map((t) => t._id))}`);

    const showOutsider = await req('GET', '/team/showTeams', { token: tok.outsider });
    check('showTeams NO filtra equipos ajenos', !showOutsider.body?.teams?.some((t) => t._id === teamId),
      `outsider ve=${JSON.stringify(showOutsider.body?.teams?.map((t) => t._id))}`);

    // -- invitar por area (nombre con espacio: "Machine Learning") --
    const invite = await req('POST', `/team/sendTeamcode/${teamId}/${encodeURIComponent('Machine Learning')}`, {
      token: tok.leader, json: { recipients: [emails.member] },
    });
    check('sendTeamcode a area con espacio en el nombre', invite.status === 200 && invite.body?.added?.includes(emails.member),
      `status=${invite.status} body=${invite.text.slice(0, 160)}`);

    const inviteUnknown = await req('POST', `/team/sendTeamcode/${teamId}/Backend`, {
      token: tok.leader, json: { recipients: ['nadie@test.invalid'] },
    });
    check('sendTeamcode reporta correos inexistentes', inviteUnknown.body?.notFound?.includes('nadie@test.invalid'),
      `body=${inviteUnknown.text.slice(0, 160)}`);

    const inviteOutsider = await req('POST', `/team/sendTeamcode/${teamId}/Backend`, {
      token: tok.outsider, json: { recipients: [emails.member] },
    });
    check('SEGURIDAD: outsider no puede invitar (403)', inviteOutsider.status === 403, `status=${inviteOutsider.status}`);

    // ---------------- TAREAS ----------------
    console.log('\n-- TAREAS --');
    const task = await req('POST', `/team/task/${teamCode}`, {
      token: tok.leader,
      form: { domainName: 'Machine Learning', email: emails.member, task: 'Tarea de prueba', deadline: '2026-12-31' },
    });
    check('crear tarea', task.status === 200, `status=${task.status} body=${task.text.slice(0, 160)}`);

    const taskOutsider = await req('POST', `/team/task/${teamCode}`, {
      token: tok.outsider,
      form: { domainName: 'Backend', email: emails.member, task: 'hack', deadline: '2026-12-31' },
    });
    check('SEGURIDAD: outsider no puede crear tareas (403)', taskOutsider.status === 403, `status=${taskOutsider.status}`);

    const inc = await req('GET', '/team/incompleteTasks', { token: tok.member });
    check('incompleteTasks lista la tarea asignada',
      inc.status === 200 && inc.body?.incompleteTasks?.some((t) => t.description === 'Tarea de prueba'),
      `status=${inc.status} body=${inc.text.slice(0, 200)}`);
    check('incompleteTasks formatea deadline como YYYY-MM-DD',
      inc.body?.incompleteTasks?.[0]?.deadline === '2026-12-31',
      `deadline=${inc.body?.incompleteTasks?.[0]?.deadline}`);

    const done = await req('POST', '/team/taskDone', {
      token: tok.member,
      form: { teamCode, domainName: 'Machine Learning', email: emails.member, task: 'Tarea de prueba' },
    });
    check('taskDone marca la tarea', done.status === 200, `status=${done.status} body=${done.text.slice(0, 160)}`);

    const doneAgain = await req('POST', '/team/taskDone', {
      token: tok.member,
      form: { teamCode, domainName: 'Machine Learning', email: emails.member, task: 'Tarea de prueba' },
    });
    check('taskDone repetido -> 404', doneAgain.status === 404, `status=${doneAgain.status}`);

    const comp = await req('GET', '/team/completedTasks', { token: tok.member });
    check('completedTasks lista la tarea hecha',
      comp.body?.completedTasks?.some((t) => t.description === 'Tarea de prueba'),
      `body=${comp.text.slice(0, 200)}`);

    const doneOutsider = await req('POST', '/team/taskDone', {
      token: tok.outsider, form: { teamCode, domainName: 'Backend', email: emails.member, task: 'x' },
    });
    check('SEGURIDAD: outsider no puede cerrar tareas (403)', doneOutsider.status === 403, `status=${doneOutsider.status}`);

    // ---------------- RECURSOS ----------------
    console.log('\n-- RECURSOS --');
    const addText = await req('POST', `/text/addText/${teamId}`, { token: tok.member, json: { text: 'Nota de prueba' } });
    check('addText', addText.status === 200, `status=${addText.status} body=${addText.text.slice(0, 160)}`);

    const showText = await req('GET', `/text/showText/${teamId}`, { token: tok.member });
    check('showText devuelve el texto agrupado por email',
      showText.status === 200 && showText.body?.data?.some((d) => d.email === emails.member && d.texts.includes('Nota de prueba')),
      `status=${showText.status} body=${showText.text.slice(0, 200)}`);

    const textOutsider = await req('GET', `/text/showText/${teamId}`, { token: tok.outsider });
    check('SEGURIDAD: outsider no lee textos del equipo (403)', textOutsider.status === 403, `status=${textOutsider.status}`);

    const addTextOutsider = await req('POST', `/text/addText/${teamId}`, { token: tok.outsider, json: { text: 'hack' } });
    check('SEGURIDAD: outsider no escribe textos (403)', addTextOutsider.status === 403, `status=${addTextOutsider.status}`);

    // imagen (multipart)
    const fd = new FormData();
    fd.append('imgName', 'prueba');
    fd.append('teamId', String(teamId));
    fd.append('photo', new Blob([Buffer.from('fake-jpeg-bytes')], { type: 'image/jpeg' }), 'prueba.jpg');
    const upRes = await fetch(`${BASE}/image/addImage`, { method: 'POST', headers: { Authorization: tok.member }, body: fd });
    const upBody = await upRes.text();
    check('addImage (multipart)', upRes.status === 200, `status=${upRes.status} body=${upBody.slice(0, 200)}`);

    const showImg = await req('GET', `/image/showImage/${teamId}`, { token: tok.member });
    check('showImage devuelve array con imgURL/imgName',
      showImg.status === 200 && Array.isArray(showImg.body) && showImg.body.some((i) => i.imgName === 'prueba'),
      `status=${showImg.status} body=${showImg.text.slice(0, 200)}`);

    const fd2 = new FormData();
    fd2.append('imgName', 'hack');
    fd2.append('teamId', String(teamId));
    fd2.append('photo', new Blob([Buffer.from('x')], { type: 'image/jpeg' }), 'h.jpg');
    const upOut = await fetch(`${BASE}/image/addImage`, { method: 'POST', headers: { Authorization: tok.outsider }, body: fd2 });
    check('SEGURIDAD: outsider no sube imagenes (403)', upOut.status === 403, `status=${upOut.status}`);

    // ---------------- CHAT ----------------
    console.log('\n-- CHAT --');
    const chatNoAuth = await req('GET', '/chat/getAllChats');
    check('SEGURIDAD: chat requiere auth (401)', chatNoAuth.status === 401, `status=${chatNoAuth.status}`);

    const send = await req('POST', '/chat/sendMessage', { token: tok.member, form: { message: 'hola itest' } });
    check('sendMessage', send.status === 200, `status=${send.status} body=${send.text.slice(0, 160)}`);

    const chats = await req('GET', '/chat/getAllChats', { token: tok.member });
    const mine = chats.body?.chats?.filter((c) => c.message === 'hola itest');
    check('getAllChats incluye el mensaje', mine?.length >= 1, `body=${chats.text.slice(0, 200)}`);
    check('SEGURIDAD: username viene del token, no del body', mine?.[0]?.username === emails.member,
      `username=${mine?.[0]?.username} esperado=${emails.member}`);

    const spoof = await req('POST', '/chat/sendMessage', {
      token: tok.member, form: { username: 'admin@suplantado.com', message: 'intento de suplantacion' },
    });
    const chats2 = await req('GET', '/chat/getAllChats', { token: tok.member });
    const spoofed = chats2.body?.chats?.find((c) => c.message === 'intento de suplantacion');
    check('SEGURIDAD: username del body es ignorado', spoof.status === 200 && spoofed?.username === emails.member,
      `username guardado=${spoofed?.username}`);

    // ---------------- PERMISOS (leave) ----------------
    console.log('\n-- PERMISOS --');
    const leave = await req('POST', `/leave/applyLeave/${teamId}`, {
      token: tok.member,
      json: { leaves: [{ startDate: '2026-09-01', endDate: '2026-09-05', reason: 'Vacaciones' }] },
    });
    check('applyLeave', leave.status === 200 && leave.body?._id, `status=${leave.status} body=${leave.text.slice(0, 160)}`);
    leaveId = leave.body?._id;

    const leaveRes = await req('POST', `/leave/leaveResult/${leaveId}`, { token: tok.member });
    check('leaveResult devuelve el estado', leaveRes.status === 200 && leaveRes.body?.status === 'pending',
      `status=${leaveRes.status} body=${leaveRes.text.slice(0, 160)}`);

    const leaveResOutsider = await req('POST', `/leave/leaveResult/${leaveId}`, { token: tok.outsider });
    check('SEGURIDAD: outsider no consulta permisos ajenos (403)', leaveResOutsider.status === 403,
      `status=${leaveResOutsider.status}`);

    const leaveResLeader = await req('POST', `/leave/leaveResult/${leaveId}`, { token: tok.leader });
    check('el lider si puede consultar el permiso de su equipo', leaveResLeader.status === 200,
      `status=${leaveResLeader.status}`);

    const leaveOutsider = await req('POST', `/leave/applyLeave/${teamId}`, {
      token: tok.outsider,
      json: { leaves: [{ startDate: '2026-09-01', endDate: '2026-09-05', reason: 'ajeno' }] },
    });
    check('SEGURIDAD: outsider no pide permiso en equipo ajeno (403)', leaveOutsider.status === 403,
      `status=${leaveOutsider.status}`);

    // ---------------- MENSAJE AL LIDER ----------------
    console.log('\n-- MENSAJE AL LIDER --');
    const toLeader = await req('POST', `/user/sendMessage/${teamId}`, {
      token: tok.member, json: { Correo: emails.member, message: 'Necesito ayuda' },
    });
    check('sendMessage al lider', toLeader.status === 200, `status=${toLeader.status} body=${toLeader.text.slice(0, 160)}`);

    const toLeaderOutsider = await req('POST', `/user/sendMessage/${teamId}`, {
      token: tok.outsider, json: { Correo: 'x', message: 'ajeno' },
    });
    check('SEGURIDAD: outsider no manda mensajes al lider ajeno (403)', toLeaderOutsider.status === 403,
      `status=${toLeaderOutsider.status}`);

    // ---------------- RESET PASSWORD ----------------
    console.log('\n-- RESET DE CONTRASENA --');
    const rp = await req('POST', '/user/resetPassword', { form: { email: emails.outsider } });
    check('resetPassword genera OTP', rp.status === 200, `status=${rp.status} body=${rp.text.slice(0, 160)}`);

    const rpUnknown = await req('POST', '/user/resetPassword', { form: { email: 'nadie@test.invalid' } });
    check('resetPassword con correo inexistente -> 404', rpUnknown.status === 404, `status=${rpUnknown.status}`);

    const conn = await mysql.createConnection({
      host: process.env.DB_HOST, port: +process.env.DB_PORT, user: process.env.DB_USER,
      password: process.env.DB_PASSWORD, database: process.env.DB_NAME,
    });
    const [[otpRow]] = await conn.query(
      `SELECT o.otp_code FROM password_reset_otps o JOIN users u ON u.id=o.user_id
       WHERE u.email=? ORDER BY o.id DESC LIMIT 1`, [emails.outsider]);

    const badOtp = await req('POST', `/user/verifyOTP/${encodeURIComponent(emails.outsider)}`, { json: { OTP: '000000' } });
    check('verifyOTP con codigo incorrecto -> 400', badOtp.status === 400, `status=${badOtp.status}`);

    const okOtp = await req('POST', `/user/verifyOTP/${encodeURIComponent(emails.outsider)}`, { json: { OTP: otpRow.otp_code } });
    check('verifyOTP con codigo correcto', okOtp.status === 200, `status=${okOtp.status} body=${okOtp.text.slice(0, 160)}`);

    const reuseOtp = await req('POST', `/user/verifyOTP/${encodeURIComponent(emails.outsider)}`, { json: { OTP: otpRow.otp_code } });
    check('OTP de un solo uso (reuso -> 400)', reuseOtp.status === 400, `status=${reuseOtp.status}`);

    const mismatch = await req('POST', `/user/newPassword/${encodeURIComponent(emails.outsider)}`, {
      json: { newPassword: 'Nueva123', confirmPassword: 'Distinta123' },
    });
    check('newPassword con contrasenas distintas -> 400', mismatch.status === 400, `status=${mismatch.status}`);

    const newPass = await req('POST', `/user/newPassword/${encodeURIComponent(emails.outsider)}`, {
      json: { newPassword: 'Nueva123', confirmPassword: 'Nueva123' },
    });
    check('newPassword actualiza', newPass.status === 200, `status=${newPass.status} body=${newPass.text.slice(0, 160)}`);

    const loginNew = await req('POST', '/user/login', { form: { email: emails.outsider, password: 'Nueva123' } });
    check('login con la contrasena nueva funciona', loginNew.status === 200, `status=${loginNew.status}`);
    if (loginNew.status === 200) tok.outsider = loginNew.body;

    const loginOld = await req('POST', '/user/login', { form: { email: emails.outsider, password: 'Secreta123' } });
    check('la contrasena vieja ya no sirve', loginOld.status === 401, `status=${loginOld.status}`);
    await conn.end();

    // ---------------- NOTIFICACIONES ----------------
    console.log('\n-- NOTIFICACIONES --');
    const notifEmpty = await req('GET', '/notifications', { token: tok.leader });
    check('GET /notifications responde', notifEmpty.status === 200 && Array.isArray(notifEmpty.body?.notifications),
      `status=${notifEmpty.status} body=${notifEmpty.text.slice(0, 160)}`);

    const delOutsider = await req('POST', `/team/deleteMember/${teamId}`, {
      token: tok.outsider, form: { memberEmail: emails.member },
    });
    check('SEGURIDAD: outsider no elimina miembros (403)', delOutsider.status === 403, `status=${delOutsider.status}`);

    const delByMember = await req('POST', `/team/deleteMember/${teamId}`, {
      token: tok.member, form: { memberEmail: emails.member },
    });
    check('SEGURIDAD: un miembro normal no elimina miembros (403)', delByMember.status === 403, `status=${delByMember.status}`);

    const del = await req('POST', `/team/deleteMember/${teamId}`, {
      token: tok.leader, form: { memberEmail: emails.member },
    });
    check('lider elimina miembro', del.status === 200, `status=${del.status} body=${del.text.slice(0, 160)}`);

    const notifs = await req('GET', '/notifications', { token: tok.member });
    const removedNotif = notifs.body?.notifications?.find((n) => n.type === 'member_removed');
    check('el miembro eliminado recibe notificacion in-app', !!removedNotif,
      `body=${notifs.text.slice(0, 250)}`);
    notifId = removedNotif?.id;
    check('la notificacion arranca como no leida', removedNotif && removedNotif.readAt === null,
      `readAt=${removedNotif?.readAt}`);

    if (notifId) {
      const readOther = await req('POST', `/notifications/${notifId}/read`, { token: tok.leader });
      check('SEGURIDAD: no puedo marcar leida una notificacion ajena (404)', readOther.status === 404,
        `status=${readOther.status}`);

      const read = await req('POST', `/notifications/${notifId}/read`, { token: tok.member });
      check('marcar notificacion como leida', read.status === 200, `status=${read.status}`);

      const after = await req('GET', '/notifications', { token: tok.member });
      check('la notificacion queda marcada como leida',
        after.body?.notifications?.find((n) => n.id === notifId)?.readAt !== null, 'readAt sigue null');
    }

    // leaderResign
    const resignOutsider = await req('POST', `/team/leaderResign/${teamId}`, {
      token: tok.outsider, form: { Correo: emails.outsider },
    });
    check('SEGURIDAD: outsider no reasigna el liderazgo (403)', resignOutsider.status === 403, `status=${resignOutsider.status}`);

    const resign = await req('POST', `/team/leaderResign/${teamId}`, {
      token: tok.leader, form: { Correo: emails.member },
    });
    check('lider asigna nuevo lider', resign.status === 200, `status=${resign.status} body=${resign.text.slice(0, 160)}`);

    const notifs2 = await req('GET', '/notifications', { token: tok.member });
    check('el nuevo lider recibe notificacion',
      notifs2.body?.notifications?.some((n) => n.type === 'leader_assigned'),
      `body=${notifs2.text.slice(0, 250)}`);

    const showAfter = await req('GET', '/team/showTeams', { token: tok.member });
    const t = showAfter.body?.teams?.find((x) => x._id === teamId);
    check('el equipo refleja el nuevo lider', t?.leaderEmail === emails.member, `leaderEmail=${t?.leaderEmail}`);

  } catch (e) {
    fail++;
    failures.push('EXCEPCION: ' + e.stack);
    console.log('EXCEPCION:', e.stack);
  } finally {
    // ---------------- LIMPIEZA ----------------
    console.log('\n-- LIMPIEZA --');
    try {
      const c = await mysql.createConnection({
        host: process.env.DB_HOST, port: +process.env.DB_PORT, user: process.env.DB_USER,
        password: process.env.DB_PASSWORD, database: process.env.DB_NAME, multipleStatements: false,
      });
      const list = Object.values(emails);
      const ph = list.map(() => '?').join(',');
      const [users] = await c.query(`SELECT id FROM users WHERE email IN (${ph})`, list);
      const ids = users.map((u) => u.id);
      if (ids.length) {
        const ip = ids.map(() => '?').join(',');
        const [teams] = await c.query(`SELECT id FROM teams WHERE leader_id IN (${ip})`, ids);
        const tids = teams.map((t) => t.id);
        if (tids.length) {
          const tp = tids.map(() => '?').join(',');
          await c.query(`DELETE FROM notifications WHERE team_id IN (${tp})`, tids);
          await c.query(`DELETE FROM leader_messages WHERE team_id IN (${tp})`, tids);
          await c.query(`DELETE FROM leave_requests WHERE team_id IN (${tp})`, tids);
          await c.query(`DELETE FROM tasks WHERE team_id IN (${tp})`, tids);
          await c.query(`DELETE FROM resource_texts WHERE team_id IN (${tp})`, tids);
          await c.query(`DELETE FROM resource_images WHERE team_id IN (${tp})`, tids);
          await c.query(`DELETE dm FROM domain_members dm JOIN domains d ON d.id=dm.domain_id WHERE d.team_id IN (${tp})`, tids);
          await c.query(`DELETE FROM team_members WHERE team_id IN (${tp})`, tids);
          await c.query(`DELETE FROM domains WHERE team_id IN (${tp})`, tids);
          await c.query(`DELETE FROM teams WHERE id IN (${tp})`, tids);
        }
        await c.query(`DELETE FROM notifications WHERE user_id IN (${ip})`, ids);
        await c.query(`DELETE FROM password_reset_otps WHERE user_id IN (${ip})`, ids);
        await c.query(`DELETE FROM users WHERE id IN (${ip})`, ids);
      }
      await c.query(`DELETE FROM chat_messages WHERE username IN (${ph})`, list);
      const [left] = await c.query(`SELECT COUNT(*) n FROM users WHERE email IN (${ph})`, list);
      console.log('Usuarios de prueba restantes:', left[0].n);
      await c.end();
    } catch (e) {
      console.log('Limpieza fallo:', e.message);
    }
    proc.kill();
  }

  console.log(`\n===== RESULTADO: ${pass} PASS / ${fail} FAIL =====`);
  if (failures.length) {
    console.log('\nFALLOS:');
    failures.forEach((f) => console.log(' - ' + f));
  }
  if (serverLog.trim()) console.log('\n[log servidor]\n' + serverLog.trim().slice(0, 1500));
  process.exit(fail ? 1 : 0);
})();
