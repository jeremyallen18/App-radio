const { verifyToken } = require('../utils/token');

// Todas las pantallas autenticadas del frontend mandan el token crudo en el
// header 'Authorization' (sin "Bearer "). Ver p.ej. lib/screens/login.dart,
// lib/screens/dashboard.dart, lib/screens/teamDetail.dart.
function requireAuth(req, res, next) {
  const raw = req.headers.authorization;
  if (!raw) {
    return res.status(401).json({ error: 'Falta el header Authorization' });
  }
  try {
    const payload = verifyToken(raw);
    req.user = { id: payload.sub, email: payload.email };
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Token inválido o expirado' });
  }
}

module.exports = { requireAuth };
