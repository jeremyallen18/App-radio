require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');

const pool = require('./db');
const authRoutes = require('./routes/auth.routes');
const teamsRoutes = require('./routes/teams.routes');
const leaveRoutes = require('./routes/leave.routes');
const chatRoutes = require('./routes/chat.routes');
const resourcesRoutes = require('./routes/resources.routes');
const notificationsRoutes = require('./routes/notifications.routes');

const app = express();
const basePath = process.env.BASE_PATH || '/hive-backend';

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true })); // varias pantallas mandan body sin Content-Type -> form-urlencoded

const api = express.Router();

// GET /googleOAuth — sin prefijo /user (así lo llama signup.dart). El botón
// de Google en el frontend no completa ningún flujo OAuth real todavía, así
// que esto es un stub honesto en vez de simular un login que no existe.
api.get('/googleOAuth', (req, res) => {
  res.status(501).json({ error: 'Google OAuth no está implementado todavía' });
});

api.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

api.use('/user', authRoutes);
api.use('/team', teamsRoutes);
api.use('/leave', leaveRoutes);
api.use('/chat', chatRoutes);
api.use('/notifications', notificationsRoutes);
api.use('/', resourcesRoutes); // resources.routes.js ya declara /image/... y /text/...

app.use(basePath, api);

app.get('/', (req, res) => {
  res.json({ status: 'ok', basePath });
});

const port = Number(process.env.PORT) || 80;
pool.ensureSchema()
  .then(() => {
    app.listen(port, () => {
      console.log(`hive-backend (MySQL) escuchando en http://localhost:${port}${basePath}`);
    });
  })
  .catch((err) => {
    console.error('Error preparando el esquema de la base de datos:', err);
    process.exit(1);
  });
