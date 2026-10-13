import { findSession, getUserById } from '../services/user.store.js';

/**
 * Middleware otorisasi: semua endpoint selain register/login wajib
 * menyertakan `Authorization: Bearer <token sesi>`
 * (deskripsi proyek Bagian 5.2).
 *
 * Bila valid, `req.user` dan `req.session` terisi untuk handler berikutnya.
 */
export function requireAuth(req, res, next) {
  const header = req.get('authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  if (!token) {
    res.status(401).json({
      error: { code: 'UNAUTHORIZED', message: 'Token sesi tidak ditemukan' },
    });
    return;
  }
  const session = findSession(token);
  if (!session) {
    res.status(401).json({
      error: { code: 'SESSION_INVALID', message: 'Sesi tidak valid atau berakhir' },
    });
    return;
  }
  const user = getUserById(session.userId);
  if (!user) {
    res.status(401).json({
      error: { code: 'SESSION_INVALID', message: 'Sesi tidak valid atau berakhir' },
    });
    return;
  }
  req.session = session;
  req.user = user;
  next();
}
