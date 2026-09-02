// Lee hive-backend/.env y devuelve { DB_HOST, DB_NAME, DB_USER, DB_PASS, ... }.
// Centraliza esto para que los scripts de tools/ nunca se desincronicen de
// las credenciales reales del proyecto (antes cada script tenía
// 'hive_user' / 'HivePass_2026!' hardcodeado, que son solo los valores de
// ejemplo de .env.example, no los reales).

const fs = require('fs');
const path = require('path');

function loadEnv() {
  const envPath = path.join(__dirname, '..', 'hive-backend', '.env');
  const out = {};
  if (fs.existsSync(envPath)) {
    for (const rawLine of fs.readFileSync(envPath, 'utf8').split('\n')) {
      const line = rawLine.trim();
      if (!line || line.startsWith('#')) continue;
      const idx = line.indexOf('=');
      if (idx === -1) continue;
      out[line.slice(0, idx).trim()] = line.slice(idx + 1).trim();
    }
  } else {
    console.log(`Aviso: no se encontró ${envPath}; usando valores por defecto.`);
  }
  return {
    DB_HOST: out.DB_HOST || '127.0.0.1',
    DB_NAME: out.DB_NAME || 'hive_db',
    DB_USER: out.DB_USER || 'root',
    DB_PASS: out.DB_PASS || '',
    APP_BASE_PATH: out.APP_BASE_PATH || '/hive-backend',
    envPath,
  };
}

function dbConfig() {
  const env = loadEnv();
  return { host: env.DB_HOST, user: env.DB_USER, password: env.DB_PASS, database: env.DB_NAME };
}

// Ruta real de uploads del proyecto (hive-backend/uploads, relativa a este
// repo), en vez de una ruta de XAMPP hardcodeada que se rompe si el
// proyecto se mueve o el usuario no se llama igual.
const UPLOAD_DIR = path.join(__dirname, '..', 'hive-backend', 'uploads');

module.exports = { loadEnv, dbConfig, UPLOAD_DIR };
