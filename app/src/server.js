'use strict';

const { createApp } = require('./app');
const { createStore } = require('./store');

const port = Number.parseInt(process.env.PORT, 10) || 3000;

async function main() {
  const store = await createStore();
  const app = createApp({ store });

  const server = app.listen(port, () => {
    console.log(JSON.stringify({
      level: 'info', msg: 'tasks-api listening', port, store: store.constructor.name,
    }));
  });

  // Apagado ordenado: Kubernetes envía SIGTERM antes de matar el Pod.
  const shutdown = (signal) => {
    console.log(JSON.stringify({ level: 'info', msg: 'shutting down', signal }));
    app.setReady(false);
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 10_000).unref();
  };
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

main().catch((err) => {
  console.error(JSON.stringify({ level: 'fatal', msg: err.message }));
  process.exit(1);
});
