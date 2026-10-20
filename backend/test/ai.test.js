import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test, { after } from 'node:test';

// Mode mock + folder data sementara: test tidak menghubungi Gemini/jaringan.
// Wajib disetel SEBELUM modul aplikasi dimuat (import statis dievaluasi lebih
// dulu → pakai import dinamis).
const dataDir = mkdtempSync(join(tmpdir(), 'storyloka-ai-'));
process.env.DATA_DIR = dataDir;
process.env.AI_MOCK = '1';

const { createApp } = await import('../src/app.js');

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

async function registrasi(base, email) {
  const [, reg] = await post(base, '/auth/register', {
    name: 'Tester',
    email,
    password: 'rahasia123',
  });
  return reg.token;
}

test('endpoint /ai/* tanpa token ditolak 401', async () => {
  await withServer(async (base) => {
    for (const path of ['/ai/chat', '/ai/summarize', '/ai/recommend']) {
      const [status, body] = await post(base, path, { message: 'halo' });
      assert.equal(status, 401, `${path} tanpa token harus 401`);
      assert.equal(body.error.code, 'UNAUTHORIZED');
    }
  });
});

test('POST /ai/chat membalas reply non-empty (mock)', async () => {
  await withServer(async (base) => {
    const token = await registrasi(base, 'chat@example.com');
    const [status, body] = await post(
      base,
      '/ai/chat',
      {
        message: 'Apa tema utama Laskar Pelangi?',
        history: [{ role: 'user', text: 'Halo' }],
        context: 'Laskar Pelangi — Andrea Hirata',
      },
      token,
    );

    assert.equal(status, 200);
    assert.equal(typeof body.reply, 'string');
    assert.ok(body.reply.length > 0, 'reply tidak boleh kosong');
    assert.equal(typeof body.serverTime, 'number');
  });
});

test('POST /ai/summarize membalas summary + tanpa api key aman', async () => {
  await withServer(async (base) => {
    const token = await registrasi(base, 'ringkas@example.com');
    const [status, body] = await post(
      base,
      '/ai/summarize',
      {
        title: 'Laskar Pelangi',
        author: 'Andrea Hirata',
        synopsis: 'Sekolah Muhammadiyah dan mimpi sepuluh anak.',
        notes: ['Tema persahabatan'],
      },
      token,
    );

    assert.equal(status, 200);
    assert.equal(typeof body.summary, 'string');
    assert.ok(body.summary.length > 0, 'summary tidak boleh kosong');
    // Bagian 5.6: klien meletakkan ringkasan + label "Dihasilkan AI".
    assert.ok(body.summary.includes('Laskar Pelangi'));
  });
});

test('POST /ai/recommend membalas daftar saran (mock)', async () => {
  await withServer(async (base) => {
    const token = await registrasi(base, 'rekomendasi@example.com');
    const [status, body] = await post(
      base,
      '/ai/recommend',
      {
        books: [
          { title: 'Laskar Pelangi', genre: 'Fiksi', rating: 5 },
          { title: 'Negeri 5 Menara', genre: 'Fiksi', rating: 4 },
        ],
      },
      token,
    );

    assert.equal(status, 200);
    assert.equal(typeof body.recommendations, 'string');
    assert.ok(body.recommendations.length > 0, 'recommendations tidak boleh kosong');
  });
});

test('POST /ai/chat dengan message kosong ditolak 400', async () => {
  await withServer(async (base) => {
    const token = await registrasi(base, 'validasi@example.com');
    const [status, body] = await post(base, '/ai/chat', { message: '   ' }, token);
    assert.equal(status, 400);
    assert.equal(body.error.code, 'BAD_REQUEST');
  });
});
