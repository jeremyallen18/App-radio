const express = require('express');
const pool = require('../db');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// GET /notifications  (bandeja del usuario logueado, más recientes primero)
router.get('/', requireAuth, async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT id, team_id AS teamId, type, message, read_at AS readAt, created_at AS createdAt
       FROM notifications WHERE user_id = :userId ORDER BY created_at DESC LIMIT 100`,
      { userId: req.user.id }
    );
    return res.status(200).json({ notifications: rows });
  } catch (err) {
    return res.status(500).json({ error: 'Error obteniendo las notificaciones' });
  }
});

// POST /notifications/:id/read — marca una notificación propia como leída
router.post('/:id/read', requireAuth, async (req, res) => {
  const { id } = req.params;
  try {
    const [result] = await pool.query(
      'UPDATE notifications SET read_at = NOW() WHERE id = :id AND user_id = :userId AND read_at IS NULL',
      { id, userId: req.user.id }
    );
    if (!result.affectedRows) {
      return res.status(404).json({ error: 'Notificación no encontrada' });
    }
    return res.status(200).json({ message: 'Notificación marcada como leída' });
  } catch (err) {
    return res.status(500).json({ error: 'Error actualizando la notificación' });
  }
});

module.exports = router;
