import {
  createSession,
  createUser,
  deleteSession,
  findUserByEmail,
  publicUser,
  verifyPassword,
} from '../services/user.store.js';

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

/** 400 untuk input tidak valid (pesan berbahasa Indonesia). */
function badRequest(res, message) {
  res.status(400).json({ error: { code: 'INVALID_INPUT', message } });
}

/**
 * POST /auth/register — buat akun baru.
 * Balasan 201: { token, expiresAt, user } — klien langsung memakai token
 * untuk endpoint yang dilindungi (Bagian 5.2).
 */
export function register(req, res, next) {
  const { name, email, password } = req.body ?? {};
  if (typeof name !== 'string' || name.trim() === '') {
    badRequest(res, 'Nama lengkap wajib diisi.');
    return;
  }
  if (typeof email !== 'string' || !EMAIL_RE.test(email.trim())) {
    badRequest(res, 'Format email tidak valid.');
    return;
  }
  if (typeof password !== 'string' || password.length < 8) {
    badRequest(res, 'Password minimal 8 karakter.');
    return;
  }

  try {
    const user = createUser({ name, email, password });
    const session = createSession(user.id);
    res.status(201).json({
      token: session.token,
      expiresAt: session.expiresAt,
      user,
    });
  } catch (err) {
    // Duplikat email dkk. — diteruskan ke errorHandler dengan status/code.
    next(err);
  }
}

/**
 * POST /auth/login — verifikasi kredensial.
 * Kegagalan selalu memakai pesan umum yang sama (mirip TC-03 klien).
 */
export function login(req, res) {
  const { email, password } = req.body ?? {};
  if (typeof email !== 'string' || email.trim() === '') {
    badRequest(res, 'Email wajib diisi.');
    return;
  }
  if (typeof password !== 'string' || password === '') {
    badRequest(res, 'Password wajib diisi.');
    return;
  }

  const user = findUserByEmail(email);
  const ok =
    user != null &&
    verifyPassword(password, user.salt, user.passwordHash);
  if (!ok) {
    res.status(401).json({
      error: { code: 'INVALID_CREDENTIALS', message: 'Email atau password salah' },
    });
    return;
  }

  const session = createSession(user.id);
  res.status(200).json({
    token: session.token,
    expiresAt: session.expiresAt,
    user: publicUser(user),
  });
}

/**
 * POST /auth/logout — akhiri sesi (dilindungi requireAuth).
 * Token dihapus dari penyimpanan sehingga tidak bisa dipakai lagi.
 */
export function logout(req, res) {
  deleteSession(req.session.token);
  res.status(200).json({ status: 'ok' });
}
