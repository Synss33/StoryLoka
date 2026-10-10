import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test, { after } from 'node:test';

import { createApp } from '../src/app.js';

// Folder data sementara agar test tidak mengotori backend/data produksi.
const dataDir = mkdtempSync(join(tmpdir(), 'storyloka-sync-'));
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

/** Daftar pengguna + sesi untuk test (diurut agar antrean berjalan). */
async function registrasi(base, email) {
  const [, reg] = await post(base, '/auth/register', {
    name: 'Tester',
    email,
    password: 'rahasia123',
  });
  return reg.token;
}

const bukuBaru = (id, updatedAt, title = 'Buku A') => ({
  id,
  user_id: 1,
  title,
  author: 'Penulis',
  status: 'reading',
  updated_at: updatedAt,
  deleted: 0,
});

test('POST /sync tanpa token ditolak 401', async () => {
  await withServer(async (base) => {
    const [status, body] = await post(base, '/sync', {});
    assert.equal(status, 401);
    assert.equal(body.error.code, 'UNAUTHORIZED');
  });
});

test('POST /sync menyimpan data klien dan membalas snapshot', async () => {
  await withServer(async (base) => {
    const token = await registrasi(base, 'satu@example.com');
    const [status, body] = await post(
      base,
      '/sync',
      {
        since: 0,
        books: [bukuBaru(1, 1000, 'Offline dulu')],
        sessions: [],
        notes: [],
        reviews: [],
        blocks: [],
        feedback: [],
        settings: null,
      },
      token,
    );
    assert.equal(status, 200);
    assert.equal(typeof body.serverTime, 'number');
    assert.equal(body.books.length, 1);
    assert.equal(body.books[0].title, 'Offline dulu');
  });
});

test('POST /sync menerapkan last-write-wins berdasarkan updated_at', async () => {
  await withServer(async (base) => {
    const token = await registrasi(base, 'dua@example.com');

    // Kirim versi terbaru dulu…
    await post(base, '/sync', { books: [bukuBaru(1, 5000, 'Versi terbaru')] }, token);
    // …lalu versi lama (stale) — server TIDAK boleh mengganti.
    const [, body] = await post(
      base,
      '/sync',
      { books: [bukuBaru(1, 1000, 'Versi lama')] },
      token,
    );
    assert.equal(body.books[0].title, 'Versi terbaru');

    // Data lebih baru tetap menang.
    const [, body2] = await post(
      base,
      '/sync',
      { books: [bukuBaru(1, 9000, 'Paling baru')] },
      token,
    );
    assert.equal(body2.books[0].title, 'Paling baru');
  });
});

test('POST /sync append-only (catatan/blok) idempoten — insert-if-absent', async () => {
  await withServer(async (base) => {
    const token = await registrasi(base, 'tiga@example.com');
    const note = { id: 1, book_id: 1, type: 'note', content: 'Catatan', page: 10, created_at: 1000 };
    const blok = {
      idx: 0,
      user_id: 3,
      timestamp: 1000,
      book_id: 1,
      review_hash: 'abc',
      finished_date: 1000,
      previous_hash: '0'.repeat(64),
      hash: 'def',
    };

    // Kirim dua kali — jumlah baris di server harus tetap satu.
    await post(base, '/sync', { notes: [note], blocks: [blok] }, token);
    const [, body] = await post(base, '/sync', { notes: [note], blocks: [blok] }, token);
    assert.equal(body.notes.length, 1);
    assert.equal(body.blocks.length, 1);
  });
});

test('POST /sync field salah bentuk ditolak 400', async () => {
  await withServer(async (base) => {
    const token = await registrasi(base, 'empat@example.com');
    const [status, body] = await post(base, '/sync', { books: 'bukan-array' }, token);
    assert.equal(status, 400);
    assert.equal(body.error.code, 'INVALID_INPUT');
  });
});
