const jwt = require('jsonwebtoken');

// El frontend Flutter guarda literalmente el body de /user/login como el
// valor de Authorization en las siguientes llamadas (sin prefijo "Bearer ").
// Por eso login.dart hace: jsonDecode(response.body) -> String plano.
// El body de la respuesta debe ser el token codificado como JSON string,
// es decir `res.json(token)`, no `res.json({ token })`.

function signToken(user) {
  return jwt.sign(
    { sub: user.id, email: user.email },
    process.env.JWT_SECRET || 'change-me-please',
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
}

function verifyToken(rawToken) {
  return jwt.verify(rawToken, process.env.JWT_SECRET || 'change-me-please');
}

module.exports = { signToken, verifyToken };
