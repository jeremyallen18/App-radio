const pool = require('../db');

async function notifyUser(userId, teamId, type, message) {
  await pool.query(
    'INSERT INTO notifications (user_id, team_id, type, message) VALUES (:userId, :teamId, :type, :message)',
    { userId, teamId, type, message }
  );
}

module.exports = { notifyUser };
