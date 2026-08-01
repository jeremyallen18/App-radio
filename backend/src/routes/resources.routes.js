const express = require('express');
const path = require('path');
const multer = require('multer');
const pool = require('../db');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

const storage = multer.diskStorage({
  destination: path.join(__dirname, '..', '..', 'uploads'),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.jpg';
    cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`);
  },
});
const upload = multer({ storage });

// POST /image/addImage — multipart/form-data: fields imgName, teamId + file "photo"
// (ResourceM/getR.dart)
router.post('/image/addImage', requireAuth, upload.single('photo'), async (req, res) => {
  const { imgName, teamId } = req.body;
  if (!teamId || !req.file) {
    return res.status(400).json({ error: 'teamId y el archivo "photo" son obligatorios' });
  }
  try {
    const publicUrl = `${process.env.PUBLIC_URL || ''}${process.env.BASE_PATH || '/hive-backend'}/uploads/${req.file.filename}`;
    await pool.query(
      'INSERT INTO resource_images (team_id, posted_by, image_name, image_url) VALUES (:teamId, :postedBy, :imageName, :imageUrl)',
      { teamId, postedBy: req.user.id, imageName: imgName || null, imageUrl: publicUrl }
    );
    return res.status(200).json({ message: 'Imagen subida', imgURL: publicUrl });
  } catch (err) {
    return res.status(500).json({ error: 'Error subiendo la imagen' });
  }
});

// GET /image/showImage/:teamId -> array plano [{ imgURL, imgName }, ...]
// (ResourceM/fetchR.dart, imagecc.dart)
router.get('/image/showImage/:teamId', requireAuth, async (req, res) => {
  const { teamId } = req.params;
  try {
    const [rows] = await pool.query(
      'SELECT image_url AS imgURL, image_name AS imgName FROM resource_images WHERE team_id = :teamId ORDER BY created_at DESC',
      { teamId }
    );
    return res.status(200).json(rows);
  } catch (err) {
    return res.status(500).json({ error: 'Error obteniendo las imágenes' });
  }
});

// POST /text/addText/:teamId  { text }  (ResourceM/getR.dart, doc.dart)
router.post('/text/addText/:teamId', requireAuth, async (req, res) => {
  const { teamId } = req.params;
  const { text } = req.body;
  if (!text) return res.status(400).json({ error: 'text es obligatorio' });
  try {
    await pool.query(
      'INSERT INTO resource_texts (team_id, posted_by, content) VALUES (:teamId, :postedBy, :content)',
      { teamId, postedBy: req.user.id, content: text }
    );
    return res.status(200).json({ message: 'Texto agregado' });
  } catch (err) {
    return res.status(500).json({ error: 'Error agregando el texto' });
  }
});

// GET /text/showText/:teamId -> { data: [{ email, texts: [...] }, ...] }
// agrupado por usuario (ver lib/ResourceM/fetchR.dart: messages[i]['email'] /
// messages[i]['texts']).
router.get('/text/showText/:teamId', requireAuth, async (req, res) => {
  const { teamId } = req.params;
  try {
    const [rows] = await pool.query(
      `SELECT u.email, rt.content, rt.created_at
       FROM resource_texts rt JOIN users u ON u.id = rt.posted_by
       WHERE rt.team_id = :teamId ORDER BY rt.created_at ASC`,
      { teamId }
    );
    const byEmail = new Map();
    for (const row of rows) {
      if (!byEmail.has(row.email)) byEmail.set(row.email, []);
      byEmail.get(row.email).push(row.content);
    }
    const data = Array.from(byEmail.entries()).map(([email, texts]) => ({ email, texts }));
    return res.status(200).json({ data });
  } catch (err) {
    return res.status(500).json({ error: 'Error obteniendo los textos' });
  }
});

module.exports = router;
