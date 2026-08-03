const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT) || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'team_management',
  waitForConnections: true,
  connectionLimit: 10,
  namedPlaceholders: true,
});

// No hay sistema de migraciones en este proyecto; las tablas nuevas se crean
// de forma idempotente al arrancar el servidor.
async function ensureSchema() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS notifications (
      id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
      user_id INT UNSIGNED NOT NULL,
      team_id INT UNSIGNED NULL,
      type VARCHAR(50) NOT NULL,
      message VARCHAR(255) NOT NULL,
      read_at DATETIME NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      CONSTRAINT fk_notifications_team FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE SET NULL,
      KEY idx_notifications_user_read (user_id, read_at)
    ) ENGINE=InnoDB
  `);
}

module.exports = pool;
module.exports.ensureSchema = ensureSchema;
