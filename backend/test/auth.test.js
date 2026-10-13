import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test, { after } from 'node:test';

import { createApp } from '../src/app.js';

// Folder data sementara agar test tidak mengotori backend/data produksi.
// Dibaca lazy oleh store, jadi cukup diatur sebelum request pertama.
const dataDir = mkdtempSync(join(tmpdir(), 'storyloka-auth-'));
process.env.DATA_DIR = dataDir;

after(() => rmSync(dataDir, { recursive: true, force: true }));

/** Menjalankan server pada port kosong, lalu menutupnya setelah tes. */
async function withServer(run) {
  const server = createApp().listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  try {
    return await run(`http://127.0.0.1:${server.address().port}`);
  } finally {
    server.close();
  }
}

/** POST JSON; mengembalikan [status, body]. */
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

const akun = {
  name: 'Budi Santoso',
  email: 'budi@example.com',
  password: 'rahasia123',
};

test('POST /auth/register membuat akun + sesi, tanpa password polos', async () => {
  await withServer(async (base) => {
    const [status, body] = await post(base, '/auth/register', akun);
    assert.equal(status, 201);
    assert.equal(typeof body.token, 'string');
    assert.equal(body.token.length, 64);
    assert.equal(typeof body.expiresAt, 'number');
    assert.equal(body.user.email, akun.email);
    assert.equal(body.user.passwordHash, undefined);

    // File penyimpanan berisi hash PBKDF2, bukan password polos.
    const file = readFileSync(join(dataDir, 'users.json'), 'utf8');
    assert.equal(file.includes(akun.password), false);
    assert.equal(file.includes('PBKDF2-HMAC-SHA256'), true);
  });
});

test('POST /auth/register dengan email sama ditolak 409', async () => {
  await withServer(async (base) => {
    const [status, body] = await post(base, '/auth/register', akun);
    assert.equal(status, 409);
    assert.equal(body.error.code, 'EMAIL_TAKEN');
  });
});

test('POST /auth/register dengan password < 8 karakter ditolak 400', async () => {
  await withServer(async (base) => {
    const [status, body] = await post(base, '/auth/register', {
      ...akun,
      email: 'pendek@example.com',
      password: 'abc',
    });
    assert.equal(status, 400);
    assert.equal(body.error.code, 'INVALID_INPUT');
  });
});

test('POST /auth/login sukses mengembalikan token baru', async () => {
  await withServer(async (base) => {
    const [status, body] = await post(base, '/auth/login', {
      email: akun.email,
      password: akun.password,
    });
    assert.equal(status, 200);
    assert.equal(typeof body.token, 'string');
    assert.equal(body.token.length, 64);
    assert.equal(body.user.email, akun.email);
  });
});

test('POST /auth/login password salah → pesan umum 401', async () => {
  await withServer(async (base) => {
    const [status, body] = await post(base, '/auth/login', {
      email: akun.email,
      password: 'salah-banget',
    });
    assert.equal(status, 401);
    assert.equal(body.error.code, 'INVALID_CREDENTIALS');
    assert.equal(body.error.message, 'Email atau password salah');
  });
});

test('POST /auth/logout tanpa token ditolak 401', async () => {
  await withServer(async (base) => {
    const [status, body] = await post(base, '/auth/logout', {});
    assert.equal(status, 401);
    assert.equal(body.error.code, 'UNAUTHORIZED');
  });
});

test('POST /auth/logout membatalkan sesi (token tak bisa dipakai lagi)', async () => {
  await withServer(async (base) => {
    const [, login] = await post(base, '/auth/login', {
      email: akun.email,
      password: akun.password,
    });

    const [logoutStatus] = await post(base, '/auth/logout', {}, login.token);
    assert.equal(logoutStatus, 200);

    const [status, body] = await post(base, '/auth/logout', {}, login.token);
    assert.equal(status, 401);
    assert.equal(body.error.code, 'SESSION_INVALID');
  });
});
