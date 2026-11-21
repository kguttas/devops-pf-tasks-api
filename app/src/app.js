'use strict';

const express = require('express');
const helmet = require('helmet');
const { metricsMiddleware, register } = require('./metrics');
const { MemoryStore } = require('./store');

/**
 * Crea la aplicación Express. Se exporta como fábrica para poder
 * instanciarla en los tests sin abrir un puerto fijo.
 */
function createApp({ store = new MemoryStore(), version = process.env.APP_VERSION || 'dev' } = {}) {
  const app = express();
  let ready = true;

  app.disable('x-powered-by');
  app.use(helmet());
  app.use(express.json({ limit: '10kb' }));
  app.use(metricsMiddleware);

  app.get('/', (_req, res) => {
    res.json({
      name: 'tasks-api',
      version,
      endpoints: ['/api/tasks', '/healthz', '/readyz', '/metrics'],
    });
  });

  // Liveness: el proceso responde.
  app.get('/healthz', (_req, res) => res.json({ status: 'ok' }));

  // Readiness: la app está lista para recibir tráfico (se desactiva al apagar).
  app.get('/readyz', async (_req, res) => {
    if (!ready) return res.status(503).json({ status: 'shutting-down' });
    const storeOk = await store.ping().catch(() => false);
    if (!storeOk) return res.status(503).json({ status: 'store-unavailable' });
    return res.json({ status: 'ready' });
  });

  app.get('/metrics', async (_req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  });

  app.get('/api/tasks', async (_req, res) => res.json(await store.list()));

  app.get('/api/tasks/:id', async (req, res) => {
    const task = await store.get(req.params.id);
    if (!task) return res.status(404).json({ error: 'not found' });
    return res.json(task);
  });

  app.post('/api/tasks', async (req, res) => {
    const title = typeof req.body?.title === 'string' ? req.body.title.trim() : '';
    if (!title || title.length > 200) {
      return res.status(400).json({ error: 'title is required (1-200 chars)' });
    }
    return res.status(201).json(await store.create(title));
  });

  app.patch('/api/tasks/:id', async (req, res) => {
    const { done } = req.body ?? {};
    if (typeof done !== 'boolean') return res.status(400).json({ error: 'done must be boolean' });
    const task = await store.update(req.params.id, { done });
    if (!task) return res.status(404).json({ error: 'not found' });
    return res.json(task);
  });

  app.delete('/api/tasks/:id', async (req, res) => {
    if (!(await store.remove(req.params.id))) return res.status(404).json({ error: 'not found' });
    return res.status(204).end();
  });

  // Endpoint de carga sintética para demostrar el HPA (CPU-bound, acotado).
  app.get('/api/work', (req, res) => {
    const ms = Math.min(Number.parseInt(req.query.ms, 10) || 50, 500);
    const end = Date.now() + ms;
    let x = 0;
    while (Date.now() < end) x += Math.sqrt(Math.random());
    res.json({ busyMs: ms, result: Math.round(x) });
  });

  app.use((_req, res) => res.status(404).json({ error: 'not found' }));

  app.use((err, _req, res, _next) => {
    const status = err.status || 500;
    res.status(status).json({ error: status === 500 ? 'internal error' : err.message });
  });

  app.setReady = (value) => {
    ready = value;
  };

  return app;
}

module.exports = { createApp };
