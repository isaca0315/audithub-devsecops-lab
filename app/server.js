'use strict';

const path = require('path');
const express = require('express');
const { Pool } = require('pg');
const { version } = require('./package.json');

const PORT = Number(process.env.APP_PORT || 3000);
const MASTER_KEY = process.env.MASTER_KEY;
const BOOTSTRAP_FLAG = 'FLAG{arranque_con_secreto}';
const db = new Pool();

const app = express();
app.disable('x-powered-by');

app.use((req, res, next) => {
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    const ms = Number(process.hrtime.bigint() - start) / 1e6;
    console.log(`[http] ${req.method} ${req.originalUrl} ${res.statusCode} ${ms.toFixed(0)}ms`);
  });
  next();
});

app.use(express.static(path.join(__dirname, 'public'), { maxAge: '1h' }));

app.get('/health', async (_req, res) => {
  try {
    await db.query('SELECT 1');
    res.json({ status: 'ok', version });
  } catch (err) {
    console.error(`[health] fallo consultando la base: ${err.message}`);
    res.status(503).json({ status: 'db_unreachable' });
  }
});

app.get('/events', async (_req, res) => {
  try {
    const { rows } = await db.query(
      'SELECT id, actor, action, created_at FROM events ORDER BY id DESC LIMIT 50'
    );
    res.json(rows);
  } catch (err) {
    console.error(`[events] fallo consultando eventos: ${err.message}`);
    res.status(500).json({ error: 'No se pudieron leer los eventos' });
  }
});

app.get('/debug/config', (_req, res) => {
  res.json({ version, env: process.env });
});

app.use((err, _req, res, _next) => {
  console.error(`[unhandled] ${err.stack || err}`);
  res.status(500).json({ error: 'Error interno' });
});

app.listen(PORT, () => {
  console.log(`[api] AuditHub ${version} escuchando en :${PORT}`);
  console.log(`[bootstrap] master key cargada: ${MASTER_KEY} flag=${BOOTSTRAP_FLAG}`);
});
