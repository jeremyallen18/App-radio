const pool = require('../db');

async function isTeamMember(teamId, userId) {
  const [[row]] = await pool.query(
    `SELECT 1 FROM teams t
     LEFT JOIN team_members tm ON tm.team_id = t.id AND tm.user_id = :userId
     WHERE t.id = :teamId AND (t.leader_id = :userId OR tm.user_id = :userId)`,
    { teamId, userId }
  );
  return !!row;
}

async function isTeamLeader(teamId, userId) {
  const [[row]] = await pool.query(
    'SELECT 1 FROM teams WHERE id = :teamId AND leader_id = :userId',
    { teamId, userId }
  );
  return !!row;
}

// Las rutas nombran el parámetro como :teamId o :teamid según la pantalla que
// las estrenó; aceptamos ambas grafías para no depender de esa inconsistencia.
function teamIdOf(req) {
  return req.params.teamId ?? req.params.teamid;
}

// Requiere que req.user pertenezca (como líder o miembro) al equipo :teamId.
function requireTeamMember(req, res, next) {
  const teamId = teamIdOf(req);
  isTeamMember(teamId, req.user.id)
    .then((ok) => {
      if (!ok) return res.status(403).json({ error: 'No perteneces a este equipo' });
      next();
    })
    .catch(() => res.status(500).json({ error: 'Error verificando membresía del equipo' }));
}

// Requiere que req.user sea el líder del equipo :teamId.
function requireTeamLeader(req, res, next) {
  const teamId = teamIdOf(req);
  isTeamLeader(teamId, req.user.id)
    .then((ok) => {
      if (!ok) return res.status(403).json({ error: 'Solo el líder del equipo puede realizar esta acción' });
      next();
    })
    .catch(() => res.status(500).json({ error: 'Error verificando el liderazgo del equipo' }));
}

module.exports = { isTeamMember, isTeamLeader, requireTeamMember, requireTeamLeader };
