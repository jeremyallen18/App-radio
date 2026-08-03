const express = require('express');
const pool = require('../db');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// GET /chat/getAllChats — mensajería global (ver nota en database/schema.sql),
// pero requiere estar autenticado para leerla.
router.get('/getAllChats', requireAuth, async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT username, message FROM chat_messages ORDER BY created_at ASC LIMIT 200'
    );
    return res.status(200).json({ chats: rows });
  } catch (err) {
    return res.status(500).json({ error: 'Error obteniendo los mensajes' });
  }
});

// POST /chat/sendMessage  { message }
// El username se deriva del token (req.user.email), nunca del body, para
// evitar que un usuario autenticado suplante a otro en el chat.
router.post('/sendMessage', requireAuth, async (req, res) => {
  const { message } = req.body;
  if (!message) {
    return res.status(400).json({ error: 'message es obligatorio' });
  }
  try {
    await pool.query('INSERT INTO chat_messages (username, message) VALUES (:username, :message)', {
      username: req.user.email,
      message,
    });
    return res.status(200).json({ message: 'Mensaje enviado' });
  } catch (err) {
    return res.status(500).json({ error: 'Error enviando el mensaje' });
  }
});

module.exports = router;
