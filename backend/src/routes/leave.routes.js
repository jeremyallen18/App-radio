const express = require('express');
const pool = require('../db');
const { requireAuth } = require('../middleware/auth');
const { requireTeamMember } = require('../middleware/teamAccess');

const router = express.Router();

// POST /leave/applyLeave/:teamid  { leaves: [{ startDate, endDate, reason }] }
// (leave approval/leave.dart)
router.post('/applyLeave/:teamid', requireAuth, requireTeamMember, async (req, res) => {
  const { teamid } = req.params;
  const leaves = req.body.leaves;
  if (!Array.isArray(leaves) || !leaves.length) {
    return res.status(400).json({ error: 'leaves es obligatorio' });
  }
  const { startDate, endDate, reason } = leaves[0];
  if (!startDate || !endDate || !reason) {
    return res.status(400).json({ error: 'startDate, endDate y reason son obligatorios' });
  }
  try {
    const [result] = await pool.query(
      `INSERT INTO leave_requests (team_id, user_id, start_date, end_date, reason)
       VALUES (:teamId, :userId, :startDate, :endDate, :reason)`,
      { teamId: teamid, userId: req.user.id, startDate, endDate, reason }
    );
    return res.status(200).json({ _id: String(result.insertId) });
  } catch (err) {
    return res.status(500).json({ error: 'Error solicitando el permiso' });
  }
});

// POST /leave/leaveResult/:leaveId  (leave approval/leave.dart)
// El frontend dispara esta llamada justo después de crear la solicitud y no
// lee la respuesta (fire-and-forget), así que solo devolvemos el estado
// actual sin modificar nada — no hay ninguna pantalla en la app donde el
// líder apruebe/rechace, esa pieza queda pendiente de diseñar si se necesita.
router.post('/leaveResult/:leaveId', requireAuth, async (req, res) => {
  const { leaveId } = req.params;
  try {
    const [[leave]] = await pool.query(
      `SELECT lr.status, lr.user_id, t.leader_id
       FROM leave_requests lr JOIN teams t ON t.id = lr.team_id
       WHERE lr.id = :leaveId`,
      { leaveId }
    );
    if (!leave) return res.status(404).json({ error: 'Solicitud de permiso no encontrada' });
    if (leave.user_id !== req.user.id && leave.leader_id !== req.user.id) {
      return res.status(403).json({ error: 'No puedes consultar esta solicitud' });
    }
    return res.status(200).json({ status: leave.status });
  } catch (err) {
    return res.status(500).json({ error: 'Error consultando la solicitud' });
  }
});

module.exports = router;
