import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * Penyimpanan data sinkronisasi per pengguna (WF-03) pada file JSON.
 *
 * Bentuk: { "<userId>": { books: {id: row}, sessions: {...}, notes: {...},
 *                          reviews: {...}, blocks: {idx: row},
 *                          feedback: {id: row}, settings: {...} } }
 *
 * Aturan konflik (deskripsi Bagian 5.2):
 * * tabel bervariabel waktu (books, sessions, feedback, settings):
 *   *last-write-wins* berdasarkan `updated_at`;
 * * tabel append-only (notes, reviews, blocks): *insert-if-absent*.
 *
 * Skala tugas akhir = penyimpanan file sederhana; bila butuh skala besar,
 * ganti dengan basis data relasional tanpa mengubah kontrak API.
 */

const defaultDataDir = fileURLToPath(new URL('../../data', import.meta.url));

function dataFile() {
  const dir = process.env.DATA_DIR ?? defaultDataDir;
  return join(dir, 'sync.json');
}

function loadAll() {
  const file = dataFile();
  if (!existsSync(file)) return {};
  try {
    const parsed = JSON.parse(readFileSync(file, 'utf8'));
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch (_) {
    return {};
  }
}

function saveAll(data) {
  const file = dataFile();
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, JSON.stringify(data, null, 2), 'utf8');
}

function ensureUser(data, userId) {
  const key = String(userId);
  if (!data[key]) {
    data[key] = {
      books: {},
      sessions: {},
      notes: {},
      reviews: {},
      blocks: {},
      feedback: {},
      settings: null,
    };
  }
  return data[key];
}

/** Simpan baris bila belum ada, atau bila `updated_at` masukan lebih baru. */
function upsertLww(map, row, key) {
  const existing = map[key];
  if (!existing) {
    map[key] = row;
    return;
  }
  const incomingTime = Number(row.updated_at ?? 0);
  const existingTime = Number(existing.updated_at ?? 0);
  if (incomingTime >= existingTime) {
    map[key] = row;
  }
}

/** Simpan baris hanya bila key belum dipakai (append-only). */
function insertIfAbsent(map, row, key) {
  if (!(key in map)) {
    map[key] = row;
  }
}

/**
 * Menerima perubahan klien dan menerapkan aturan konflik.
 * `payload` sudah divalidasi controller (field berupa array).
 */
export function applyChanges(userId, payload) {
  const data = loadAll();
  const store = ensureUser(data, userId);

  for (const row of payload.books ?? []) {
    if (row && row.id != null) upsertLww(store.books, row, String(row.id));
  }
  for (const row of payload.sessions ?? []) {
    if (row && row.id != null) upsertLww(store.sessions, row, String(row.id));
  }
  for (const row of payload.notes ?? []) {
    if (row && row.id != null) insertIfAbsent(store.notes, row, String(row.id));
  }
  for (const row of payload.reviews ?? []) {
    if (row && row.id != null) insertIfAbsent(store.reviews, row, String(row.id));
  }
  for (const row of payload.blocks ?? []) {
    // PK blok = (user_id, idx) → key lokal cukup idx.
    if (row && row.idx != null) {
      insertIfAbsent(store.blocks, row, String(row.idx));
    }
  }
  for (const row of payload.feedback ?? []) {
    // Kesan & saran = satu baris per pengguna (SCR-10) — key = user_id.
    if (row && row.user_id != null) {
      upsertLww(store.feedback, row, String(row.user_id));
    } else if (row && row.id != null) {
      upsertLww(store.feedback, row, String(row.id));
    }
  }
  if (payload.settings && payload.settings.user_id != null) {
    if (!store.settings) {
      store.settings = payload.settings;
    } else if (
      Number(payload.settings.updated_at ?? 0) >=
      Number(store.settings.updated_at ?? 0)
    ) {
      store.settings = payload.settings;
    }
  }

  saveAll(data);
}

/** Snapshot penuh milik pengguna untuk balasan dua arah. */
export function snapshot(userId) {
  const store = ensureUser(loadAll(), userId);
  return {
    books: Object.values(store.books),
    sessions: Object.values(store.sessions),
    notes: Object.values(store.notes),
    reviews: Object.values(store.reviews),
    blocks: Object.values(store.blocks),
    feedback: Object.values(store.feedback),
    settings: store.settings,
  };
}

/**
 * Simpan kesan/saran dari SCR-10 (POST /feedback) — aturan LWW per
 * pengguna (deskripsi Bagian 5.13).
 */
export function saveFeedback(userId, row) {
  const data = loadAll();
  const store = ensureUser(data, userId);
  upsertLww(store.feedback, { ...row, user_id: userId }, String(userId));
  saveAll(data);
}

/** Baris kesan/saran milik pengguna (null bila belum pernah diisi). */
export function readFeedback(userId) {
  const store = ensureUser(loadAll(), userId);
  const rows = Object.values(store.feedback);
  if (rows.length === 0) return null;
  return rows.reduce((latest, row) =>
    Number(row.updated_at ?? 0) >= Number(latest.updated_at ?? 0)
      ? row
      : latest,
  );
}
