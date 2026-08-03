const express = require('express');
const crypto = require('crypto');
const pool = require('../db');
const { requireAuth } = require('../middleware/auth');
const { isTeamMember, requireTeamMember, requireTeamLeader } = require('../middleware/teamAccess');
const { notifyUser } = require('../utils/notify');

const router = express.Router();

function formatDate(d) {
  if (!d) return null;
  const date = new Date(d);
  return date.toISOString().slice(0, 10);
}

function generateTeamCode() {
  return crypto.randomBytes(4).toString('hex').toUpperCase().slice(0, 6);
}

// Arma el mismo shape anidado que el frontend espera (teamDetail.dart,
// create-team-model.dart): team -> domains[] -> members[] (emails) y
// tasks[] (description/assignedTo/deadline/completed).
async function getFullTeam(teamId) {
  const [[team]] = await pool.query(
    `SELECT t.id, t.team_name, t.team_code, t.created_at, t.updated_at, u.email AS leader_email
     FROM teams t JOIN users u ON u.id = t.leader_id
     WHERE t.id = :teamId`,
    { teamId }
  );
  if (!team) return null;

  const [domains] = await pool.query('SELECT id, name FROM domains WHERE team_id = :teamId', { teamId });

  const fullDomains = [];
  for (const domain of domains) {
    const [members] = await pool.query(
      `SELECT u.email FROM domain_members dm JOIN users u ON u.id = dm.user_id WHERE dm.domain_id = :domainId`,
      { domainId: domain.id }
    );
    const [tasks] = await pool.query(
      `SELECT tk.id, tk.description, tk.deadline, tk.completed, u.email AS assigned_to
       FROM tasks tk JOIN users u ON u.id = tk.assigned_to
       WHERE tk.domain_id = :domainId ORDER BY tk.created_at ASC`,
      { domainId: domain.id }
    );
    fullDomains.push({
      _id: String(domain.id),
      name: domain.name,
      members: members.map((m) => m.email),
      tasks: tasks.map((t) => ({
        description: t.description,
        assignedTo: t.assigned_to,
        deadline: formatDate(t.deadline),
        completed: !!t.completed,
      })),
    });
  }

  return {
    _id: String(team.id),
    teamName: team.team_name,
    teamCode: team.team_code,
    leaderEmail: team.leader_email,
    domains: fullDomains,
    createdAt: team.created_at,
    updatedAt: team.updated_at,
  };
}

// POST /team/createTeam  { teamName, domains: [{ name, members: [] }] }
router.post('/createTeam', requireAuth, async (req, res) => {
  const { teamName, domains } = req.body;
  if (!teamName) return res.status(400).json({ error: 'teamName es obligatorio' });
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    let teamCode = generateTeamCode();
    // Evita colisiones de código (poco probable, pero barato de chequear).
    for (let i = 0; i < 5; i++) {
      const [dupe] = await conn.query('SELECT id FROM teams WHERE team_code = :teamCode', { teamCode });
      if (!dupe.length) break;
      teamCode = generateTeamCode();
    }
    const [teamResult] = await conn.query(
      'INSERT INTO teams (team_name, team_code, leader_id) VALUES (:teamName, :teamCode, :leaderId)',
      { teamName, teamCode, leaderId: req.user.id }
    );
    const teamId = teamResult.insertId;
    await conn.query('INSERT INTO team_members (team_id, user_id) VALUES (:teamId, :userId)', {
      teamId,
      userId: req.user.id,
    });

    for (const domain of domains || []) {
      await conn.query('INSERT INTO domains (team_id, name) VALUES (:teamId, :name)', {
        teamId,
        name: domain.name,
      });
    }

    await conn.commit();
    const team = await getFullTeam(teamId);
    return res.status(200).json({ team });
  } catch (err) {
    await conn.rollback();
    return res.status(500).json({ error: 'Error creando el equipo' });
  } finally {
    conn.release();
  }
});

// POST /team/joinTeam  { teamCode }  (join_team.dart)
router.post('/joinTeam', requireAuth, async (req, res) => {
  const { teamCode } = req.body;
  if (!teamCode) return res.status(400).json({ error: 'teamCode es obligatorio' });
  try {
    const [[team]] = await pool.query('SELECT id FROM teams WHERE team_code = :teamCode', { teamCode });
    if (!team) return res.status(404).json({ error: 'Código de equipo inválido' });
    await pool.query(
      'INSERT IGNORE INTO team_members (team_id, user_id) VALUES (:teamId, :userId)',
      { teamId: team.id, userId: req.user.id }
    );
    return res.status(200).json({ message: 'Te uniste al equipo' });
  } catch (err) {
    return res.status(500).json({ error: 'Error al unirse al equipo' });
  }
});

// GET /team/showTeams  (dashboard.dart)
// Devuelve los equipos donde el usuario es líder, miembro del equipo, o
// miembro de alguna de sus áreas — más su propio email (dashboard.dart lo
// usa para saber "quién soy yo" al comparar contra leaderEmail).
router.get('/showTeams', requireAuth, async (req, res) => {
  try {
    const [teamRows] = await pool.query(
      `SELECT DISTINCT t.id FROM teams t
       LEFT JOIN team_members tm ON tm.team_id = t.id
       LEFT JOIN domains d ON d.team_id = t.id
       LEFT JOIN domain_members dmem ON dmem.domain_id = d.id
       WHERE t.leader_id = :userId OR tm.user_id = :userId OR dmem.user_id = :userId`,
      { userId: req.user.id }
    );
    const teams = [];
    for (const row of teamRows) {
      const team = await getFullTeam(row.id);
      if (team) teams.push(team);
    }
    return res.status(200).json({ teams, email: req.user.email });
  } catch (err) {
    return res.status(500).json({ error: 'Error obteniendo los equipos' });
  }
});

// POST /team/sendTeamcode/:teamId/:domainName  { recipients: [email, ...] }
// Invita (agrega) usuarios ya registrados a un área del equipo.
router.post('/sendTeamcode/:teamId/:domainName', requireAuth, requireTeamMember, async (req, res) => {
  const { teamId, domainName } = req.params;
  const { recipients } = req.body;
  if (!Array.isArray(recipients) || !recipients.length) {
    return res.status(400).json({ error: 'recipients es obligatorio' });
  }
  try {
    const [[domain]] = await pool.query(
      'SELECT id FROM domains WHERE team_id = :teamId AND name = :domainName',
      { teamId, domainName }
    );
    if (!domain) return res.status(404).json({ error: 'Área no encontrada en este equipo' });

    const added = [];
    const notFound = [];
    for (const email of recipients) {
      const [[user]] = await pool.query('SELECT id FROM users WHERE email = :email', { email });
      if (!user) {
        notFound.push(email);
        continue;
      }
      await pool.query('INSERT IGNORE INTO team_members (team_id, user_id) VALUES (:teamId, :userId)', {
        teamId,
        userId: user.id,
      });
      await pool.query(
        'INSERT IGNORE INTO domain_members (domain_id, user_id) VALUES (:domainId, :userId)',
        { domainId: domain.id, userId: user.id }
      );
      added.push(email);
    }
    return res.status(200).json({ added, notFound });
  } catch (err) {
    return res.status(500).json({ error: 'Error invitando miembros' });
  }
});

// POST /team/task/:teamcode  { domainName, email, task, deadline }  (addTask.dart)
router.post('/task/:teamcode', requireAuth, async (req, res) => {
  const { teamcode } = req.params;
  const { domainName, email, task, deadline } = req.body;
  if (!domainName || !email || !task || !deadline) {
    return res.status(400).json({ error: 'domainName, email, task y deadline son obligatorios' });
  }
  try {
    const [[team]] = await pool.query('SELECT id FROM teams WHERE team_code = :teamcode', { teamcode });
    if (!team) return res.status(404).json({ error: 'Equipo no encontrado' });
    if (!(await isTeamMember(team.id, req.user.id))) {
      return res.status(403).json({ error: 'No perteneces a este equipo' });
    }
    const [[domain]] = await pool.query(
      'SELECT id FROM domains WHERE team_id = :teamId AND name = :domainName',
      { teamId: team.id, domainName }
    );
    if (!domain) return res.status(404).json({ error: 'Área no encontrada en este equipo' });
    const [[assignee]] = await pool.query('SELECT id FROM users WHERE email = :email', { email });
    if (!assignee) return res.status(404).json({ error: 'No existe un usuario con ese correo' });

    await pool.query(
      `INSERT INTO tasks (team_id, domain_id, assigned_to, description, deadline)
       VALUES (:teamId, :domainId, :assignedTo, :description, :deadline)`,
      { teamId: team.id, domainId: domain.id, assignedTo: assignee.id, description: task, deadline }
    );
    return res.status(200).json({ message: 'Tarea creada' });
  } catch (err) {
    return res.status(500).json({ error: 'Error creando la tarea' });
  }
});

// POST /team/taskDone  { teamCode, domainName, email, task }
// (teamDetail.dart y MarkTaskDone.dart)
router.post('/taskDone', requireAuth, async (req, res) => {
  const { teamCode, domainName, email, task } = req.body;
  if (!teamCode || !domainName || !email || !task) {
    return res.status(400).json({ error: 'teamCode, domainName, email y task son obligatorios' });
  }
  try {
    const [[team]] = await pool.query('SELECT id FROM teams WHERE team_code = :teamCode', { teamCode });
    if (!team) return res.status(404).json({ error: 'Equipo no encontrado' });
    if (!(await isTeamMember(team.id, req.user.id))) {
      return res.status(403).json({ error: 'No perteneces a este equipo' });
    }
    const [result] = await pool.query(
      `UPDATE tasks tk
       JOIN domains d ON d.id = tk.domain_id
       JOIN teams t ON t.id = tk.team_id
       JOIN users u ON u.id = tk.assigned_to
       SET tk.completed = 1, tk.completed_at = NOW()
       WHERE t.team_code = :teamCode AND d.name = :domainName
         AND u.email = :email AND tk.description = :task AND tk.completed = 0`,
      { teamCode, domainName, email, task }
    );
    if (!result.affectedRows) {
      return res.status(404).json({ error: 'No se encontró la tarea pendiente indicada' });
    }
    return res.status(200).json({ message: 'Tarea marcada como hecha' });
  } catch (err) {
    return res.status(500).json({ error: 'Error marcando la tarea como hecha' });
  }
});

// GET /team/incompleteTasks  (home_page/tasks.dart)
router.get('/incompleteTasks', requireAuth, async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT tk.description, tk.deadline, u.email AS assignedTo
       FROM tasks tk JOIN users u ON u.id = tk.assigned_to
       WHERE tk.assigned_to = :userId AND tk.completed = 0
       ORDER BY tk.deadline ASC`,
      { userId: req.user.id }
    );
    const incompleteTasks = rows.map((r) => ({
      description: r.description,
      assignedTo: r.assignedTo,
      deadline: formatDate(r.deadline),
    }));
    return res.status(200).json({ incompleteTasks });
  } catch (err) {
    return res.status(500).json({ error: 'Error obteniendo las tareas pendientes' });
  }
});

// GET /team/completedTasks  (home_page/tasks.dart)
router.get('/completedTasks', requireAuth, async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT tk.description, tk.deadline, u.email AS assignedTo
       FROM tasks tk JOIN users u ON u.id = tk.assigned_to
       WHERE tk.assigned_to = :userId AND tk.completed = 1
       ORDER BY tk.completed_at DESC`,
      { userId: req.user.id }
    );
    const completedTasks = rows.map((r) => ({
      description: r.description,
      assignedTo: r.assignedTo,
      deadline: formatDate(r.deadline),
    }));
    return res.status(200).json({ completedTasks });
  } catch (err) {
    return res.status(500).json({ error: 'Error obteniendo las tareas completadas' });
  }
});

// POST /team/deleteMember/:teamId  { memberEmail }  (LResign.dart -> Resign, "Eliminar miembro")
router.post('/deleteMember/:teamId', requireAuth, requireTeamLeader, async (req, res) => {
  const { teamId } = req.params;
  const { memberEmail } = req.body;
  if (!memberEmail) return res.status(400).json({ error: 'memberEmail es obligatorio' });
  try {
    const [[member]] = await pool.query('SELECT id FROM users WHERE email = :memberEmail', { memberEmail });
    if (!member) return res.status(404).json({ error: 'No existe un usuario con ese correo' });
    await pool.query('DELETE FROM team_members WHERE team_id = :teamId AND user_id = :userId', {
      teamId,
      userId: member.id,
    });
    await pool.query(
      `DELETE dm FROM domain_members dm
       JOIN domains d ON d.id = dm.domain_id
       WHERE d.team_id = :teamId AND dm.user_id = :userId`,
      { teamId, userId: member.id }
    );
    const [[team]] = await pool.query('SELECT team_name FROM teams WHERE id = :teamId', { teamId });
    if (team) {
      await notifyUser(
        member.id,
        teamId,
        'member_removed',
        `Fuiste eliminado del equipo "${team.team_name}"`
      );
    }
    return res.status(200).json({ message: 'Miembro eliminado' });
  } catch (err) {
    return res.status(500).json({ error: 'Error eliminando al miembro' });
  }
});

// POST /team/leaderResign/:teamId  { Correo }  (LResign.dart -> Resign, "Asignar nuevo líder")
router.post('/leaderResign/:teamId', requireAuth, requireTeamLeader, async (req, res) => {
  const { teamId } = req.params;
  const correo = req.body.Correo;
  if (!correo) return res.status(400).json({ error: 'Correo es obligatorio' });
  try {
    const [[newLeader]] = await pool.query('SELECT id FROM users WHERE email = :correo', { correo });
    if (!newLeader) return res.status(404).json({ error: 'No existe un usuario con ese correo' });
    const [[team]] = await pool.query('SELECT team_name FROM teams WHERE id = :teamId', { teamId });
    if (!team) return res.status(404).json({ error: 'Equipo no encontrado' });
    await pool.query('UPDATE teams SET leader_id = :leaderId WHERE id = :teamId', {
      leaderId: newLeader.id,
      teamId,
    });
    await pool.query('INSERT IGNORE INTO team_members (team_id, user_id) VALUES (:teamId, :userId)', {
      teamId,
      userId: newLeader.id,
    });
    await notifyUser(
      newLeader.id,
      teamId,
      'leader_assigned',
      `Ahora eres el líder del equipo "${team.team_name}"`
    );
    return res.status(200).json({ message: 'Nuevo líder asignado' });
  } catch (err) {
    return res.status(500).json({ error: 'Error asignando el nuevo líder' });
  }
});

module.exports = router;
