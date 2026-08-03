// Vacía las bases de datos de la app y reinicia los contadores AUTO_INCREMENT
// en 1, dejando el esquema intacto y listo para datos nuevos.
//
// DESTRUCTIVO: borra todas las filas. Exige --yes para ejecutarse.
//
//   node tools/reset-database.js --yes              (solo hive_db)
//   node tools/reset-database.js --yes --all        (hive_db + team_management)
//
// Nota: users, teams y leaves de hive_db usan ids CHAR(24) generados por PHP
// (generate_id()), no AUTO_INCREMENT — ahí no hay contador que reiniciar; las
// tablas simplemente quedan vacías.

const path = require('path');
const fs = require('fs');
const mysql = require(path.join(__dirname, '..', 'backend', 'node_modules', 'mysql2', 'promise'));
require(path.join(__dirname, '..', 'backend', 'node_modules', 'dotenv'))
  .config({ path: path.join(__dirname, '..', 'backend', '.env') });

const args = process.argv.slice(2);
if (!args.includes('--yes')) {
  console.log('Esto BORRA todas las filas de la base de datos.');
  console.log('Si estás seguro, vuelve a ejecutarlo con --yes (añade --all para incluir team_management).');
  process.exit(1);
}

const UPLOADS = 'C:\\xampp\\htdocs\\hive-backend\\uploads';

const targets = [
  { label: 'hive_db (backend PHP, el que usa la app)', config: { host: '127.0.0.1', user: 'hive_user', password: 'HivePass_2026!', database: 'hive_db' } },
];
if (args.includes('--all')) {
  targets.push({
    label: 'team_management (backend Node, sin uso)',
    config: {
      host: process.env.DB_HOST || '127.0.0.1',
      port: Number(process.env.DB_PORT) || 3306,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME || 'team_management',
    },
  });
}

async function wipe(target) {
  console.log(`\n== ${target.label} ==`);
  let conn;
  try {
    conn = await mysql.createConnection(target.config);
  } catch (e) {
    console.log(`  no se pudo conectar (${e.code}); se omite`);
    return;
  }

  const db = target.config.database;
  const [rows] = await conn.query(
    'SELECT table_name AS t FROM information_schema.tables WHERE table_schema = ? AND table_type = ? ORDER BY table_name',
    [db, 'BASE TABLE']
  );
  const tables = rows.map((r) => r.t);
  if (!tables.length) {
    console.log('  no hay tablas');
    await conn.end();
    return;
  }

  await conn.query('SET FOREIGN_KEY_CHECKS = 0');
  for (const t of tables) {
    try {
      // TRUNCATE deja el AUTO_INCREMENT en 1 por sí solo.
      await conn.query(`TRUNCATE TABLE \`${t}\``);
    } catch (e) {
      // Sin privilegio DROP, TRUNCATE falla: se borra y se reinicia a mano.
      await conn.query(`DELETE FROM \`${t}\``);
      try { await conn.query(`ALTER TABLE \`${t}\` AUTO_INCREMENT = 1`); } catch (_) {}
    }
  }
  await conn.query('SET FOREIGN_KEY_CHECKS = 1');

  let totalRows = 0;
  const pending = [];
  for (const t of tables) {
    const [[c]] = await conn.query(`SELECT COUNT(*) n FROM \`${t}\``);
    totalRows += c.n;
    const [[meta]] = await conn.query(
      'SELECT AUTO_INCREMENT a FROM information_schema.tables WHERE table_schema = ? AND table_name = ?',
      [db, t]
    );
    const next = meta.a; // null en tablas sin AUTO_INCREMENT
    if (next !== null && next !== 1) pending.push(`${t}=${next}`);
    console.log(`  ${t.padEnd(20)} filas=${c.n}  proximo_id=${next === null ? '(id no numerico)' : next}`);
  }

  console.log(`  -> ${totalRows} filas restantes, ${pending.length ? 'contadores sin reiniciar: ' + pending.join(', ') : 'todos los contadores en 1'}`);
  await conn.end();
}

(async () => {
  for (const t of targets) await wipe(t);

  // Los archivos subidos quedarían huérfanos al vaciar la tabla images.
  if (fs.existsSync(UPLOADS)) {
    const files = fs.readdirSync(UPLOADS).filter((f) => !f.startsWith('.'));
    for (const f of files) {
      try { fs.unlinkSync(path.join(UPLOADS, f)); } catch (_) {}
    }
    console.log(`\n== uploads ==\n  ${files.length} archivo(s) eliminado(s), quedan ${fs.readdirSync(UPLOADS).filter((f) => !f.startsWith('.')).length}`);
  }

  console.log('\nListo. Las bases quedan vacías y con el esquema intacto.');
})();
