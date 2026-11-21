'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { RedisStore, MemoryStore, createStore } = require('../src/store');
const { createApp } = require('../src/app');

/** Cliente Redis simulado en memoria con la misma API (hSet/hGet/...). */
function fakeRedis() {
  const h = new Map();
  return {
    hSet: async (_k, f, v) => h.set(f, v),
    hGet: async (_k, f) => h.get(f) ?? null,
    hVals: async () => [...h.values()],
    hLen: async () => h.size,
    hDel: async (_k, f) => (h.delete(f) ? 1 : 0),
    ping: async () => 'PONG',
  };
}

test('RedisStore: CRUD sobre el hash compartido', async () => {
  const store = new RedisStore(fakeRedis());
  const t = await store.create('compartida');
  assert.equal((await store.get(t.id)).title, 'compartida');
  assert.equal((await store.update(t.id, { done: true })).done, true);
  assert.equal((await store.list()).length, 1);
  assert.equal(await store.update('x', { done: true }), undefined);
  assert.equal(await store.get('x'), undefined);
  assert.equal(await store.remove(t.id), true);
  assert.equal(await store.remove(t.id), false);
  assert.equal(await store.ping(), true);
});

test('dos instancias de la app ven los mismos datos con Redis', async () => {
  const client = fakeRedis();
  const a = createApp({ store: new RedisStore(client) });
  const b = createApp({ store: new RedisStore(client) });
  const [sa, sb] = await Promise.all([a, b].map((app) => new Promise((r) => {
    const s = app.listen(0, () => r(s));
  })));
  try {
    const res = await fetch(`http://127.0.0.1:${sa.address().port}/api/tasks`, {
      method: 'POST', headers: { 'content-type': 'application/json' }, body: '{"title":"x"}',
    });
    const { id } = await res.json();
    const other = await fetch(`http://127.0.0.1:${sb.address().port}/api/tasks/${id}`);
    assert.equal(other.status, 200);
  } finally {
    sa.close();
    sb.close();
  }
});

test('readyz devuelve 503 si el almacén no responde', async () => {
  const store = new MemoryStore();
  store.ping = async () => { throw new Error('down'); };
  const app = createApp({ store });
  const server = await new Promise((r) => { const s = app.listen(0, () => r(s)); });
  try {
    const res = await fetch(`http://127.0.0.1:${server.address().port}/readyz`);
    assert.equal(res.status, 503);
  } finally {
    server.close();
  }
});

test('createStore sin REDIS_URL usa memoria', async () => {
  assert.ok((await createStore('')) instanceof MemoryStore);
});
