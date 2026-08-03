const jwt = require('jsonwebtoken');

// El frontend Flutter guarda literalmente el body de /user/login como el
// valor de Authorization en las siguientes llamadas (sin prefijo "Bearer ").
// Por eso login.dart hace: jsonDecode(response.body) -> String plano.
// El body de la respuesta debe ser el token codificado como JSON string,
// es decir `res.json(token)`, no `res.json({ token })`.

// Sin fallback: si falta JWT_SECRET el proceso no debe arrancar, para que
// nunca se firmen/verifiquen tokens con un secreto público y predecible.
if (!process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET no está definido. Configúralo en el entorno antes de iniciar el servidor.');
}
const JWT_SECRET = process.env.JWT_SECRET;

function signToken(user) {
  return jwt.sign(
    { sub: user.id, email: user.email },
    JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
}

function verifyToken(rawToken) {
  return jwt.verify(rawToken, JWT_SECRET);
}

module.exports = { signToken, verifyToken };
