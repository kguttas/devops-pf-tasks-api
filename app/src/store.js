'use strict';

const { randomUUID } = require('node:crypto');
const { tasksGauge } = require('./metrics');

/**
 * Almacén en memoria: para tests y ejecución local con una sola instancia.
 * Todas las operaciones son async para compartir interfaz con RedisStore.
 */
class MemoryStore {
  constructor() {
    this.tasks = new Map();
  }

  async list() {
    return [...this.tasks.values()];
  }

  async get(id) {
    return this.tasks.get(id);
  }

  async create(title) {
    const task = newTask(title);
    this.tasks.set(task.id, task);
    tasksGauge.set(this.tasks.size);
    return task;
  }

  async update(id, changes) {
    const task = this.tasks.get(id);
    if (!task) return undefined;
    Object.assign(task, changes);
    return task;
  }

  async remove(id) {
    const removed = this.tasks.delete(id);
    tasksGauge.set(this.tasks.size);
    return removed;
  }

  async ping() {
    return true;
  }
}

/**
 * Almacén compartido en Redis (hash "tasks"): necesario cuando hay varias réplicas,
 * para que todas vean los mismos datos.
 */
class RedisStore {
  constructor(client) {
    this.client = client;
    this.key = 'tasks';
  }

  async list() {
    const values = await this.client.hVals(this.key);
    return values.map((v) => JSON.parse(v));
  }

  async get(id) {
    const value = await this.client.hGet(this.key, id);
    return value ? JSON.parse(value) : undefined;
  }

  async create(title) {
    const task = newTask(title);
    await this.client.hSet(this.key, task.id, JSON.stringify(task));
    tasksGauge.set(await this.client.hLen(this.key));
    return task;
  }

  async update(id, changes) {
    const task = await this.get(id);
    if (!task) return undefined;
    Object.assign(task, changes);
    await this.client.hSet(this.key, id, JSON.stringify(task));
    return task;
  }

  async remove(id) {
    const removed = (await this.client.hDel(this.key, id)) > 0;
    tasksGauge.set(await this.client.hLen(this.key));
    return removed;
  }

  async ping() {
    return (await this.client.ping()) === 'PONG';
  }
}

function newTask(title) {
  return { id: randomUUID(), title, done: false, createdAt: new Date().toISOString() };
}

/** Elige el backend según REDIS_URL. */
async function createStore(redisUrl = process.env.REDIS_URL) {
  if (!redisUrl) return new MemoryStore();
  const { createClient } = require('redis');
  const client = createClient({ url: redisUrl });
  client.on('error', (err) => console.error(JSON.stringify({ level: 'error', msg: 'redis', err: err.message })));
  await client.connect();
  return new RedisStore(client);
}

module.exports = { MemoryStore, RedisStore, createStore };
