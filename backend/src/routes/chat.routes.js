const express = require('express');
const pool = require('../db');

const router = express.Router();

// GET /chat/getAllChats — sin auth ni teamId: así lo llama hoy chat.dart y
// chatHistory.dart (mensajería global, ver nota en database/schema.sql).
router.get('/getAllChats', async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT username, message FROM chat_messages ORDER BY created_at ASC LIMIT 200'
    );
    return res.status(200).json({ chats: rows });
  } catch (err) {
    return res.status(500).json({ error: 'Error obteniendo los mensajes' });
  }
});

// POST /chat/sendMessage  { username, message }
router.post('/sendMessage', async (req, res) => {
  const { username, message } = req.body;
  if (!username || !message) {
    return res.status(400).json({ error: 'username y message son obligatorios' });
  }
  try {
    await pool.query('INSERT INTO chat_messages (username, message) VALUES (:username, :message)', {
      username,
      message,
    });
    return res.status(200).json({ message: 'Mensaje enviado' });
  } catch (err) {
    return res.status(500).json({ error: 'Error enviando el mensaje' });
  }
});

module.exports = router;
