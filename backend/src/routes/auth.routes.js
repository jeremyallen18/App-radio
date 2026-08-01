const express = require('express');
const bcrypt = require('bcryptjs');
const pool = require('../db');
const { signToken } = require('../utils/token');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// POST /user/signup  { name, email, password }  (screens/signup.dart)
router.post('/signup', async (req, res) => {
  const { name, email, password } = req.body;
  if (!name || !email || !password) {
    return res.status(400).json({ error: 'name, email y password son obligatorios' });
  }
  try {
    const [existing] = await pool.query('SELECT id FROM users WHERE email = :email', { email });
    if (existing.length) {
      return res.status(409).json({ error: 'Ese correo ya está registrado' });
    }
    const passwordHash = await bcrypt.hash(password, 10);
    await pool.query(
      'INSERT INTO users (name, email, password_hash) VALUES (:name, :email, :passwordHash)',
      { name, email, passwordHash }
    );
    return res.status(200).json({ message: 'Usuario creado correctamente' });
  } catch (err) {
    return res.status(500).json({ error: 'Error creando el usuario' });
  }
});

// POST /user/login  { email, password }  (screens/login.dart)
// OJO: el body de la respuesta debe ser el token como JSON *string*, no un
// objeto, porque el frontend hace jsonDecode(response.body) directo.
router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'email y password son obligatorios' });
  }
  try {
    const [rows] = await pool.query('SELECT * FROM users WHERE email = :email', { email });
    if (!rows.length) {
      return res.status(401).json({ error: 'Correo o contraseña incorrectos' });
    }
    const user = rows[0];
    const match = await bcrypt.compare(password, user.password_hash);
    if (!match) {
      return res.status(401).json({ error: 'Correo o contraseña incorrectos' });
    }
    const token = signToken(user);
    return res.status(200).json(token);
  } catch (err) {
    return res.status(500).json({ error: 'Error al iniciar sesión' });
  }
});

// GET /user/sendName  (lib/models/appbar.dart, lib/home_page/profile.dart)
// El frontend hace `json.decode(response.body)` y lo trata como un String
// plano -> hay que responder con el nombre como JSON string, no un objeto.
router.get('/sendName', requireAuth, async (req, res) => {
  const [rows] = await pool.query('SELECT name FROM users WHERE id = :id', { id: req.user.id });
  if (!rows.length) return res.status(404).json({ error: 'Usuario no encontrado' });
  return res.status(200).json(rows[0].name);
});

// POST /user/resetPassword  { email }  (forgot_pass.dart)
router.post('/resetPassword', async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'email es obligatorio' });
  try {
    const [rows] = await pool.query('SELECT id FROM users WHERE email = :email', { email });
    if (!rows.length) {
      return res.status(404).json({ error: 'No existe una cuenta con ese correo' });
    }
    const otp = String(Math.floor(100000 + Math.random() * 900000));
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutos
    await pool.query(
      'INSERT INTO password_reset_otps (user_id, otp_code, expires_at) VALUES (:userId, :otp, :expiresAt)',
      { userId: rows[0].id, otp, expiresAt }
    );
    // TODO: integrar un proveedor real de correo/SMS. Por ahora se deja en
    // el log del servidor para poder probar el flujo completo sin esa pieza.
    console.log(`[OTP] ${email} -> ${otp} (expira ${expiresAt.toISOString()})`);
    return res.status(200).json({ message: 'OTP enviado' });
  } catch (err) {
    return res.status(500).json({ error: 'Error generando el OTP' });
  }
});

// POST /user/verifyOTP/:email  { OTP }  (otp_verify.dart)
router.post('/verifyOTP/:email', async (req, res) => {
  const { email } = req.params;
  const otp = req.body.OTP;
  if (!otp) return res.status(400).json({ error: 'OTP es obligatorio' });
  try {
    const [rows] = await pool.query(
      `SELECT o.id FROM password_reset_otps o
       JOIN users u ON u.id = o.user_id
       WHERE u.email = :email AND o.otp_code = :otp
         AND o.used_at IS NULL AND o.expires_at > NOW()
       ORDER BY o.id DESC LIMIT 1`,
      { email, otp }
    );
    if (!rows.length) {
      return res.status(400).json({ error: 'OTP inválido o expirado' });
    }
    await pool.query('UPDATE password_reset_otps SET used_at = NOW() WHERE id = :id', { id: rows[0].id });
    return res.status(200).json({ message: 'OTP verificado' });
  } catch (err) {
    return res.status(500).json({ error: 'Error verificando el OTP' });
  }
});

// POST /user/newPassword/:email  { newPassword, confirmPassword }  (new_password.dart)
router.post('/newPassword/:email', async (req, res) => {
  const { email } = req.params;
  const { newPassword, confirmPassword } = req.body;
  if (!newPassword || !confirmPassword) {
    return res.status(400).json({ error: 'newPassword y confirmPassword son obligatorios' });
  }
  if (newPassword !== confirmPassword) {
    return res.status(400).json({ error: 'Las contraseñas no coinciden' });
  }
  try {
    const passwordHash = await bcrypt.hash(newPassword, 10);
    const [result] = await pool.query(
      'UPDATE users SET password_hash = :passwordHash WHERE email = :email',
      { passwordHash, email }
    );
    if (!result.affectedRows) {
      return res.status(404).json({ error: 'No existe una cuenta con ese correo' });
    }
    return res.status(200).json({ message: 'Contraseña actualizada' });
  } catch (err) {
    return res.status(500).json({ error: 'Error actualizando la contraseña' });
  }
});

// POST /user/sendMessage/:teamId  { Correo, message }
// Reutilizado por ResourceM/Leaderassist.dart (pedir ayuda al líder) y
// screens/MResign.dart (avisar intención de renunciar).
router.post('/sendMessage/:teamId', requireAuth, async (req, res) => {
  const { teamId } = req.params;
  const correo = req.body.Correo;
  const { message } = req.body;
  if (!message) return res.status(400).json({ error: 'message es obligatorio' });
  try {
    await pool.query(
      'INSERT INTO leader_messages (team_id, from_user, correo, message) VALUES (:teamId, :fromUser, :correo, :message)',
      { teamId, fromUser: req.user.id, correo: correo || '', message }
    );
    return res.status(200).json({ message: 'Mensaje enviado' });
  } catch (err) {
    return res.status(500).json({ error: 'Error enviando el mensaje' });
  }
});

module.exports = router;
