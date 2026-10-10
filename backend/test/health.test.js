import assert from 'node:assert/strict';
import test from 'node:test';

import { createApp } from '../src/app.js';

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

test('GET /health mengembalikan status ok', async () => {
  await withServer(async (base) => {
    const res = await fetch(`${base}/health`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.status, 'ok');
    assert.equal(body.service, 'storyloka-api');
    assert.equal(typeof body.timestamp, 'string');
  });
});

test('rute tidak dikenal membalas 404 JSON', async () => {
  await withServer(async (base) => {
    const res = await fetch(`${base}/tidak-ada`);
    assert.equal(res.status, 404);
    const body = await res.json();
    assert.equal(body.error.code, 'NOT_FOUND');
  });
});
