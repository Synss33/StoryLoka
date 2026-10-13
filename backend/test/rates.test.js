import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test, { after } from 'node:test';

// Folder data sementara + mode luring: test tidak menghubungi jaringan
// dan tidak mengotori backend/data produksi. Wajib disetel SEBELUM modul
// aplikasi dimuat (import statis dievaluasi lebih dulu → pakai import dinamis).
const dataDir = mkdtempSync(join(tmpdir(), 'storyloka-rates-'));
process.env.DATA_DIR = dataDir;
process.env.RATES_OFFLINE = '1';

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

async function post(base, path, body) {
  const res = await fetch(`${base}${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
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

test('GET /rates tanpa token ditolak 401', async () => {
  await withServer(async (base) => {
    const [status, body] = await get(base, '/rates');
    assert.equal(status, 401);
    assert.equal(body.error.code, 'UNAUTHORIZED');
  });
});

test('GET /rates mengembalikan USD/EUR/JPY terhadap IDR + fetchedAt', async () => {
  await withServer(async (base) => {
    const token = await registrasi(base, 'kurs@example.com');
    const [status, body] = await get(base, '/rates', token);

    assert.equal(status, 200);
    assert.equal(typeof body.fetchedAt, 'number');
    assert.ok(body.fetchedAt >= 0);
    for (const code of ['USD', 'EUR', 'JPY']) {
      // Kurs wajib positif — kontrak tabel `rate_cache` di klien.
      assert.ok(
        Number.isFinite(body.rates[code]) && body.rates[code] > 0,
        `kurs ${code} tidak valid: ${body.rates[code]}`,
      );
    }
    // 100 USD → IDR = 100 × kurs (TC-17 dilakukan di sisi klien).
    assert.ok(body.rates.USD * 100 > 0);
  });
});
