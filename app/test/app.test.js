'use strict';

const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('../src/app');

let server;
let base;

before(async () => {
  const app = createApp({ version: 'test' });
  await new Promise((resolve) => {
    server = app.listen(0, resolve);
  });
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => new Promise((resolve) => server.close(resolve)));

const json = (method, body) => ({
  method,
  headers: { 'content-type': 'application/json' },
  body: body === undefined ? undefined : JSON.stringify(body),
});

test('GET / devuelve información del servicio', async () => {
  const res = await fetch(`${base}/`);
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.name, 'tasks-api');
  assert.equal(body.version, 'test');
});

test('health y readiness responden 200', async () => {
  assert.equal((await fetch(`${base}/healthz`)).status, 200);
  assert.equal((await fetch(`${base}/readyz`)).status, 200);
});

test('cabeceras de seguridad presentes (helmet)', async () => {
  const res = await fetch(`${base}/`);
  assert.ok(res.headers.get('x-content-type-options'));
  assert.equal(res.headers.get('x-powered-by'), null);
});

test('CRUD de tareas', async () => {
  let res = await fetch(`${base}/api/tasks`, json('POST', { title: 'Escribir Terraform' }));
  assert.equal(res.status, 201);
  const task = await res.json();
  assert.equal(task.done, false);

  res = await fetch(`${base}/api/tasks/${task.id}`);
  assert.equal(res.status, 200);

  res = await fetch(`${base}/api/tasks/${task.id}`, json('PATCH', { done: true }));
  assert.equal((await res.json()).done, true);

  res = await fetch(`${base}/api/tasks`);
  assert.ok((await res.json()).some((t) => t.id === task.id));

  res = await fetch(`${base}/api/tasks/${task.id}`, { method: 'DELETE' });
  assert.equal(res.status, 204);

  res = await fetch(`${base}/api/tasks/${task.id}`);
  assert.equal(res.status, 404);
});

test('validación de entrada', async () => {
  assert.equal((await fetch(`${base}/api/tasks`, json('POST', {}))).status, 400);
  assert.equal((await fetch(`${base}/api/tasks`, json('POST', { title: 'x'.repeat(201) }))).status, 400);
  assert.equal((await fetch(`${base}/api/tasks/nope`, json('PATCH', { done: 'yes' }))).status, 400);
  assert.equal((await fetch(`${base}/api/tasks/nope`, json('PATCH', { done: true }))).status, 404);
  assert.equal((await fetch(`${base}/api/tasks/nope`, { method: 'DELETE' })).status, 404);
});

test('/api/work limita el tiempo de CPU', async () => {
  const res = await fetch(`${base}/api/work?ms=99999`);
  assert.equal((await res.json()).busyMs, 500);
});

test('/metrics expone métricas Prometheus', async () => {
  const res = await fetch(`${base}/metrics`);
  assert.equal(res.status, 200);
  const text = await res.text();
  assert.match(text, /http_requests_total/);
  assert.match(text, /http_request_duration_seconds_bucket/);
  assert.match(text, /tasks_total/);
});

test('ruta inexistente devuelve 404 JSON', async () => {
  const res = await fetch(`${base}/no-existe`);
  assert.equal(res.status, 404);
});
