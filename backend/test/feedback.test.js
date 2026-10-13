import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test, { after } from 'node:test';

import { createApp } from '../src/app.js';

// Folder data sementara agar test tidak mengotori backend/data produksi.
const dataDir = mkdtempSync(join(tmpdir(), 'storyloka-feedback-'));
process.env.DATA_DIR = dataDir;

after(() => rmSync(dataDir, { recursive: true, force: true }));

async function withServer(run) {
  const server = createApp().listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  try {
    return await run(`http://127.0.0.1:${server.address().port}`);
  } finally {
    server.close();
  }
}

async function post(base, path, body, token) {
  const res = await fetch(`${base}${path}`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
  return [res.status, await res.json()];
}

async function get(base, path, token) {
  const res = await fetch(`${base}${path}`, {
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });
  return [res.status, await res.json()];
}

async function registrasi(base, email) {
  const [, reg] = await post(base, '/auth/register', {
    name: 'Tester',
    email,
    password: 'rahasia123',
  });
  return reg.token;
}

test('POST /feedback tanpa token ditolak 401', async () => {
  await withServer(async (base) => {
    const [status, body] = await post(base, '/feedback', { kesan: 'Bagus' });
    assert.equal(status, 401);
    assert.equal(body.error.code, 'UNAUTHORIZED');
  });
});

test('POST /feedback menyimpan isian dan GET mengembalikannya', async () => {
  await withServer(async (base) => {
    const token = await registrasi(base, 'satu@example.com');
    const [status, body] = await post(
      base,
      '/feedback',
      { kesan: 'Materi seru', saran: 'Tambah praktikum', updated_at: 1000 },
      token,
    );
    assert.equal(status, 200);
    assert.equal(body.ok, true);

    const [gStatus, gBody] = await get(base, '/feedback', token);
    assert.equal(gStatus, 200);
    assert.equal(gBody.feedback.kesan, 'Materi seru');
    assert.equal(gBody.feedback.saran, 'Tambah praktikum');
    assert.equal(gBody.feedback.updated_at, 1000);
  });
});

test('POST /feedback dua kolom kosong ditolak 400', async () => {
  await withServer(async (base) => {
    const token = await registrasi(base, 'dua@example.com');
    const [status, body] = await post(
      base,
      '/feedback',
      { kesan: '  ', saran: '' },
      token,
    );
    assert.equal(status, 400);
    assert.equal(body.error.code, 'INVALID_INPUT');
  });
});

test('POST /feedback menerapkan last-write-wins berdasarkan updated_at', async () => {
  await withServer(async (base) => {
    const token = await registrasi(base, 'tiga@example.com');

    await post(base, '/feedback', { kesan: 'Terbaru', updated_at: 9000 }, token);
    // Versi lama tidak boleh menimpa.
    await post(base, '/feedback', { kesan: 'Lama', updated_at: 1000 }, token);

    const [, gBody] = await get(base, '/feedback', token);
    assert.equal(gBody.feedback.kesan, 'Terbaru');
  });
});

test('GET /feedback sebelum pernah mengisi mengembalikan null', async () => {
  await withServer(async (base) => {
    const token = await registrasi(base, 'empat@example.com');
    const [status, body] = await get(base, '/feedback', token);
    assert.equal(status, 200);
    assert.equal(body.feedback, null);
  });
});
