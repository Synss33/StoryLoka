import { randomBytes, pbkdf2Sync, timingSafeEqual } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * Penyimpanan pengguna & sesi server dalam file JSON (backend/data/).
 *
 * Server menyimpan **hash miliknya sendiri** (deskripsi Bagian 5.1):
 * password dari klien di-hash ulang dengan salt acak + PBKDF2-HMAC-SHA256
 * — identik dengan skema klien (lib/core/security/password_hasher.dart)
 * agar generasi hash dapat direproduksi. Password polos tidak pernah
 * disimpan; file data tidak dikomit (lihat .gitignore).
 */

/** Default: backend/data (relatif terhadap paket ini, bukan cwd). */
const defaultDataDir = fileURLToPath(new URL('../../data', import.meta.url));

/** Bisa dioverride lewat DATA_DIR (dipakai test agar tidak mengotori data). */
function dataDir() {
  return process.env.DATA_DIR ?? defaultDataDir;
}

const usersFile = () => join(dataDir(), 'users.json');
const sessionsFile = () => join(dataDir(), 'sessions.json');

const SALT_BYTES = 16;
const HASH_BYTES = 32;
const ITERATIONS = 210000; // OWASP PBKDF2-HMAC-SHA256
const SESSION_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 hari

function readList(file) {
  if (!existsSync(file)) return [];
  try {
    const parsed = JSON.parse(readFileSync(file, 'utf8'));
    return Array.isArray(parsed) ? parsed : [];
  } catch (_) {
    // File rusak dianggap kosong (data lokal bukan sumber utama).
    return [];
  }
}

function writeList(file, list) {
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, JSON.stringify(list, null, 2), 'utf8');
}

/** Hash password + salt baru: { salt, hash, kdfParams } (hex). */
export function hashPassword(password, saltHex = randomBytes(SALT_BYTES).toString('hex')) {
  const hash = pbkdf2Sync(
    password,
    Buffer.from(saltHex, 'hex'),
    ITERATIONS,
    HASH_BYTES,
    'sha256',
  ).toString('hex');
  return {
    salt: saltHex,
    hash,
    kdfParams: JSON.stringify({
      algo: 'PBKDF2-HMAC-SHA256',
      iterations: ITERATIONS,
      hashLength: HASH_BYTES,
      saltEncoding: 'hex',
    }),
  };
}

/** Verifikasi password (perbandingan constant-time). */
export function verifyPassword(password, saltHex, expectedHashHex) {
  const actual = Buffer.from(
    pbkdf2Sync(
      password,
      Buffer.from(saltHex, 'hex'),
      ITERATIONS,
      HASH_BYTES,
      'sha256',
    ),
  );
  const expected = Buffer.from(expectedHashHex, 'hex');
  if (actual.length !== expected.length) return false;
  return timingSafeEqual(actual, expected);
}

/** Buat pengguna baru; melempar { status, code, message } bila email sudah ada. */
export function createUser({ name, email, password }) {
  const users = readList(usersFile());
  const normalized = String(email).trim().toLowerCase();
  if (users.some((u) => u.email === normalized)) {
    const err = new Error('Email sudah terdaftar.');
    err.status = 409;
    err.code = 'EMAIL_TAKEN';
    throw err;
  }
  const now = new Date().toISOString();
  const { salt, hash, kdfParams } = hashPassword(password);
  const user = {
    id: users.reduce((max, u) => Math.max(max, u.id), 0) + 1,
    name: String(name).trim(),
    email: normalized,
    passwordHash: hash,
    salt,
    kdfParams,
    createdAt: now,
    updatedAt: now,
  };
  users.push(user);
  writeList(usersFile(), users);
  return publicUser(user);
}

export function findUserByEmail(email) {
  const normalized = String(email ?? '').trim().toLowerCase();
  return readList(usersFile()).find((u) => u.email === normalized) ?? null;
}

export function getUserById(id) {
  return readList(usersFile()).find((u) => u.id === id) ?? null;
}

/** Bentuk pengguna yang aman dikirim ke klien (tanpa hash/salt). */
export function publicUser(user) {
  return { id: user.id, name: user.name, email: user.email };
}

/** Buat sesi login baru (token acak 32 byte, berlaku 7 hari). */
export function createSession(userId) {
  const sessions = readList(sessionsFile());
  const session = {
    token: randomBytes(32).toString('hex'),
    userId,
    createdAt: new Date().toISOString(),
    expiresAt: Date.now() + SESSION_TTL_MS,
  };
  sessions.push(session);
  writeList(sessionsFile(), sessions);
  return session;
}

/** Cari sesi berlaku berdasarkan token; sesi kedaluwarsa dihapus. */
export function findSession(token) {
  if (!token) return null;
  const sessions = readList(sessionsFile());
  const index = sessions.findIndex((s) => s.token === token);
  if (index < 0) return null;
  if (sessions[index].expiresAt <= Date.now()) {
    sessions.splice(index, 1);
    writeList(sessionsFile(), sessions);
    return null;
  }
  return sessions[index];
}

/** Hapus sesi (logout); true bila token memang ada. */
export function deleteSession(token) {
  const sessions = readList(sessionsFile());
  const next = sessions.filter((s) => s.token !== token);
  if (next.length === sessions.length) return false;
  writeList(sessionsFile(), next);
  return true;
}
